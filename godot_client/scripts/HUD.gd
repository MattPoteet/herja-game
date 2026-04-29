extends CanvasLayer

var player: Node
var account_manager: Node
var hp_label: Label
var xp_label: Label
var gold_label: Label
var inv_label: Label
var gps_label: Label
var profile_label: Label
var status_label: Label
var attribution_label: Label


func setup(player_node: Node, manager: Node = null) -> void:
	player = player_node
	account_manager = manager
	_build_ui()
	player.health_changed.connect(_on_health_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.inventory_changed.connect(_on_inventory_changed)
	if player.has_signal("profile_changed"):
		player.profile_changed.connect(_on_profile_changed)
	if account_manager != null and account_manager.has_signal("social_changed"):
		account_manager.social_changed.connect(_on_account_social_changed)
	_refresh_all()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var panel: Panel = Panel.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(430, 216)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.92), Color(0.24, 0.30, 0.40), 16))
	add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(14, 12)
	box.size = Vector2(398, 186)
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "HERJA"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.74))
	box.add_child(title)

	profile_label = Label.new()
	hp_label = Label.new()
	xp_label = Label.new()
	gold_label = Label.new()
	inv_label = Label.new()
	gps_label = Label.new()
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [profile_label, hp_label, xp_label, gold_label, inv_label, gps_label, status_label]:
		label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98))
		box.add_child(label)
	status_label.add_theme_color_override("font_color", Color(0.86, 0.84, 0.64))

	var hint_panel: Panel = Panel.new()
	hint_panel.position = Vector2(16, 246)
	hint_panel.size = Vector2(600, 36)
	hint_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.84), Color(0.24, 0.30, 0.40), 12))
	add_child(hint_panel)

	var hint: Label = Label.new()
	hint.text = "Move: WASD / Arrows   Attack: Space   Inventory: I   Craft: C   Build: B   Save: F5   Social: O"
	hint.position = Vector2(12, 8)
	hint.add_theme_color_override("font_color", Color(0.80, 0.84, 0.91))
	hint_panel.add_child(hint)

	attribution_label = Label.new()
	attribution_label.text = "Map data © OpenStreetMap contributors"
	attribution_label.position = Vector2(16, 290)
	attribution_label.add_theme_font_size_override("font_size", 12)
	attribution_label.add_theme_color_override("font_color", Color(0.74, 0.78, 0.84))
	add_child(attribution_label)


func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _refresh_all() -> void:
	_on_profile_changed(str(player.stats.get("name", "Viking")), str(player.get("character_id")))
	_on_health_changed(int(player.stats["hp"]), int(player.stats["max_hp"]))
	_on_xp_changed(int(player.stats["xp"]), int(player.stats["level"]))
	gold_label.text = "Gold: %s" % int(player.stats["gold"])
	_on_inventory_changed(player.inventory)
	set_gps(0.0, 0.0, 0)
	set_status("Loaded. Press I for inventory, C to craft potions, B to build.")


func _on_profile_changed(player_name: String, character_id: String) -> void:
	var clan_text: String = "No Clan"
	if account_manager != null and account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		var clan: Variant = account.get("clan", {})
		if clan is Dictionary and not (clan as Dictionary).is_empty():
			clan_text = str((clan as Dictionary).get("name", "Clan"))
	var admin_text: String = "   |   ADMIN" if _is_admin() else ""
	profile_label.text = "Player: %s   |   Character: %s   |   Clan: %s%s" % [player_name, _character_display(character_id), clan_text, admin_text]


func _is_admin() -> bool:
	if account_manager == null:
		return false
	if account_manager.has_method("is_current_account_admin"):
		return bool(account_manager.call("is_current_account_admin"))
	if account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		return bool(account.get("is_admin", false))
	return false


func _on_health_changed(current: int, maximum: int) -> void:
	hp_label.text = "HP: %s / %s" % [current, maximum]


func _on_xp_changed(current: int, level: int) -> void:
	xp_label.text = "Level: %s   |   XP: %s / %s" % [level, current, level * 100]
	gold_label.text = "Gold: %s" % int(player.stats["gold"])


func _on_inventory_changed(items: Array) -> void:
	var preview: Array = items.slice(max(0, items.size() - 5), items.size())
	if preview.is_empty():
		inv_label.text = "Recent loot: none"
	else:
		inv_label.text = "Recent loot: %s" % ", ".join(preview)


func set_gps(latitude: float, longitude: float, zoom: int) -> void:
	if gps_label == null:
		return
	if zoom <= 0:
		gps_label.text = "GPS map: loading free map tiles..."
	else:
		gps_label.text = "GPS: %.5f, %.5f   |   Zoom: %d" % [latitude, longitude, zoom]


func set_status(message: String) -> void:
	if status_label == null:
		return
	status_label.text = message


func _on_account_social_changed(_account: Dictionary) -> void:
	_on_profile_changed(str(player.stats.get("name", "Viking")), str(player.get("character_id")))


func _character_display(character_id: String) -> String:
	match character_id:
		"shield_maiden": return "Shield Maiden"
		"druid": return "Druid"
		"mage": return "Mage"
		_: return "Viking"
