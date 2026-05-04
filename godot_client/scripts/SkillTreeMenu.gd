extends CanvasLayer

const SkillConfig = preload("res://scripts/SkillConfig.gd")

var player: Node
var hud: Node
var panel: Panel
var class_label: Label
var points_label: Label
var status_label: Label
var skill_list: VBoxContainer


func setup(player_node: Node, hud_node: Node = null) -> void:
	player = player_node
	hud = hud_node
	_build_ui()
	visible = false
	if player != null and player.has_signal("skills_changed"):
		player.skills_changed.connect(_on_skills_changed)


func toggle_visible() -> void:
	visible = not visible
	if visible:
		_refresh()


func _build_ui() -> void:
	layer = 62
	panel = Panel.new()
	panel.position = Vector2(450, 54)
	panel.size = Vector2(430, 620)
	add_child(panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(16, 14)
	scroll.size = Vector2(398, 592)
	panel.add_child(scroll)

	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

	var title: Label = Label.new()
	title.text = "Skill Tree"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	class_label = Label.new()
	class_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(class_label)

	points_label = Label.new()
	points_label.add_theme_font_size_override("font_size", 16)
	root.add_child(points_label)

	var respec_button: Button = Button.new()
	respec_button.text = "Reset Skills"
	respec_button.pressed.connect(_on_respec_pressed)
	root.add_child(respec_button)

	skill_list = VBoxContainer.new()
	skill_list.add_theme_constant_override("separation", 6)
	root.add_child(skill_list)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(func() -> void:
		visible = false
	)
	root.add_child(close_button)


func _refresh() -> void:
	if player == null:
		return
	var class_type: String = str(player.get("character_id"))
	class_label.text = "Class: %s" % _class_display(class_type)
	points_label.text = "Available skill points: %d" % int(player.call("available_skill_points"))
	for child in skill_list.get_children():
		child.queue_free()
	for skill in SkillConfig.skills_for_class(class_type):
		_add_skill_row(skill as Dictionary)


func _add_skill_row(skill: Dictionary) -> void:
	var skill_id: String = str(skill.get("id", ""))
	var rank: int = int(player.call("unlocked_skill_rank", skill_id))
	var max_rank: int = int(skill.get("max_rank", 1))
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	skill_list.add_child(row)

	var title: Label = Label.new()
	title.text = "%s  Rank %d/%d  Lv %d  %s" % [
		str(skill.get("name", "Skill")),
		rank,
		max_rank,
		int(skill.get("required_level", 1)),
		str(skill.get("type", "passive")).capitalize()
	]
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68) if rank > 0 else Color(0.72, 0.76, 0.82))
	row.add_child(title)

	var description: Label = Label.new()
	description.text = "%s\n%s" % [str(skill.get("description", "")), _requirements_text(skill)]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	row.add_child(description)

	var buttons: HBoxContainer = HBoxContainer.new()
	row.add_child(buttons)

	var unlock_button: Button = Button.new()
	unlock_button.text = "Unlock" if rank == 0 else "Rank Up"
	unlock_button.disabled = rank >= max_rank
	unlock_button.pressed.connect(func() -> void:
		_unlock_skill(skill_id)
	)
	buttons.add_child(unlock_button)

	var use_button: Button = Button.new()
	use_button.text = "Use"
	var kind: String = str(skill.get("type", ""))
	use_button.disabled = rank <= 0 or kind == SkillConfig.SKILL_TYPE_PASSIVE
	use_button.pressed.connect(func() -> void:
		_use_skill(skill_id)
	)
	buttons.add_child(use_button)


func _requirements_text(skill: Dictionary) -> String:
	var parts: Array[String] = ["Requires level %d" % int(skill.get("required_level", 1))]
	var prereqs: Dictionary = skill.get("prerequisites", {}) as Dictionary
	for prereq_id in prereqs.keys():
		var prereq: Dictionary = SkillConfig.skill_definition(str(player.get("character_id")), str(prereq_id))
		parts.append("Requires %s Rank %d" % [str(prereq.get("name", prereq_id)), int(prereqs[prereq_id])])
	return " | ".join(parts)


func _unlock_skill(skill_id: String) -> void:
	var result: Dictionary = player.call("unlock_skill", skill_id) as Dictionary
	if bool(result.get("ok", false)):
		status_label.text = "Skill unlocked."
		_set_hud_status("Skill unlocked.")
	else:
		status_label.text = str(result.get("error", "Could not unlock skill."))
	_refresh()


func _use_skill(skill_id: String) -> void:
	var result: Dictionary = player.call("use_skill_ability", skill_id) as Dictionary
	status_label.text = "Ability used." if bool(result.get("ok", false)) else str(result.get("error", "Ability failed."))
	_set_hud_status(status_label.text)


func _on_respec_pressed() -> void:
	var result: Dictionary = player.call("reset_skill_tree") as Dictionary
	status_label.text = "Skill tree reset." if bool(result.get("ok", false)) else str(result.get("error", "Could not reset skills."))
	_refresh()


func _on_skills_changed(_skill_state: Dictionary) -> void:
	if visible:
		_refresh()


func _set_hud_status(message: String) -> void:
	if hud != null and hud.has_method("set_status"):
		hud.call("set_status", message)


func _class_display(class_type: String) -> String:
	match class_type:
		"shield_maiden": return "Shield Maiden"
		"druid": return "Druid"
		"mage": return "Mage"
		_: return "Viking"
