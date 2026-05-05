extends CanvasLayer

signal menu_pressed

const Balance = preload("res://scripts/Balance.gd")
const MobilePlatform = preload("res://scripts/MobilePlatform.gd")

var player: Node
var account_manager: Node
var hp_label: Label
var xp_label: Label
var gold_label: Label
var inv_label: Label
var gps_label: Label
var profile_label: Label
var clan_label: Label
var status_label: Label
var attribution_label: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var panel: Panel
var menu_button: Button


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

	panel = Panel.new()
	var is_mobile: bool = MobilePlatform.use_mobile_layout()
	var viewport: Vector2 = MobilePlatform.viewport_size()
	var margin: float = MobilePlatform.safe_margin()
	panel.position = Vector2(margin, margin)
	panel.size = Vector2(viewport.x - margin * 2.0, 190) if is_mobile else Vector2(360, 176)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.070, 0.090, 0.92), Color(0.22, 0.27, 0.34), 8))
	add_child(panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.position = Vector2(14, 12)
	root.size = Vector2(panel.size.x - 28.0, panel.size.y - 24.0)
	root.add_theme_constant_override("separation", 8 if is_mobile else 7)
	panel.add_child(root)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title: Label = _make_label("HERJA", 21 if is_mobile else 18, Color(0.96, 0.90, 0.68))
	title.custom_minimum_size = Vector2(76, 26) if is_mobile else Vector2(66, 22)
	header.add_child(title)

	profile_label = _make_label("Viking", 17 if is_mobile else 15, Color(0.93, 0.96, 1.0))
	profile_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(profile_label)

	clan_label = _make_label("No Clan", 13 if is_mobile else 12, Color(0.68, 0.76, 0.86))
	clan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clan_label.custom_minimum_size = Vector2(86, 22)
	header.add_child(clan_label)

	var bars: VBoxContainer = VBoxContainer.new()
	bars.add_theme_constant_override("separation", 5)
	root.add_child(bars)

	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	bars.add_child(hp_row)
	hp_label = _make_label("HP", 15 if is_mobile else 13, Color(0.98, 0.86, 0.84))
	hp_label.custom_minimum_size = Vector2(108, 22) if is_mobile else Vector2(92, 18)
	hp_row.add_child(hp_label)
	hp_bar = _make_bar(Color(0.82, 0.20, 0.18))
	hp_row.add_child(hp_bar)

	var xp_row: HBoxContainer = HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	bars.add_child(xp_row)
	xp_label = _make_label("XP", 15 if is_mobile else 13, Color(0.80, 0.88, 1.0))
	xp_label.custom_minimum_size = Vector2(108, 22) if is_mobile else Vector2(92, 18)
	xp_row.add_child(xp_label)
	xp_bar = _make_bar(Color(0.24, 0.48, 0.90))
	xp_row.add_child(xp_bar)

	var stats: HBoxContainer = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	root.add_child(stats)
	gold_label = _make_chip("Gold 0")
	gps_label = _make_chip("GPS loading")
	stats.add_child(gold_label)
	stats.add_child(gps_label)

	inv_label = _make_label("Recent loot: none", 14 if is_mobile else 12, Color(0.78, 0.84, 0.92))
	inv_label.clip_text = true
	root.add_child(inv_label)

	status_label = _make_label("", 14 if is_mobile else 12, Color(0.92, 0.86, 0.58))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 32)
	root.add_child(status_label)

	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.position = Vector2(margin, panel.position.y + panel.size.y + 12.0) if is_mobile else Vector2(16, 204)
	menu_button.size = Vector2(126, 52) if is_mobile else Vector2(104, 34)
	menu_button.add_theme_font_size_override("font_size", 16 if is_mobile else 14)
	menu_button.add_theme_stylebox_override("normal", _panel_style(Color(0.13, 0.16, 0.22, 0.92), Color(0.35, 0.46, 0.60), 8))
	menu_button.add_theme_stylebox_override("hover", _panel_style(Color(0.18, 0.23, 0.31, 0.96), Color(0.47, 0.60, 0.78), 8))
	menu_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.10, 0.13, 0.18, 0.96), Color(0.47, 0.60, 0.78), 8))
	menu_button.add_theme_color_override("font_color", Color(0.95, 0.97, 0.99))
	menu_button.pressed.connect(func() -> void:
		menu_pressed.emit()
	)
	add_child(menu_button)

	attribution_label = _make_label("Map data (c) OpenStreetMap contributors", 11 if is_mobile else 11, Color(0.64, 0.70, 0.78))
	attribution_label.position = Vector2(margin, viewport.y - margin - 24.0) if is_mobile else Vector2(16, 246)
	add_child(attribution_label)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_chip(text: String) -> Label:
	var label: Label = _make_label(text, 14 if MobilePlatform.use_mobile_layout() else 12, Color(0.88, 0.92, 0.98))
	label.custom_minimum_size = Vector2(0, 30) if MobilePlatform.use_mobile_layout() else Vector2(0, 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _panel_style(Color(0.10, 0.12, 0.16, 0.86), Color(0.20, 0.25, 0.32), 6))
	return label


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18) if MobilePlatform.use_mobile_layout() else Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _panel_style(Color(0.10, 0.12, 0.16, 0.90), Color(0.16, 0.19, 0.24), 5))
	bar.add_theme_stylebox_override("fill", _bar_fill_style(fill_color))
	return bar


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
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _bar_fill_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _refresh_all() -> void:
	_on_profile_changed(str(player.stats.get("name", "Viking")), str(player.get("character_id")))
	_on_health_changed(int(player.stats["hp"]), int(player.stats["max_hp"]))
	_on_xp_changed(int(player.stats["xp"]), int(player.stats["level"]))
	gold_label.text = "Gold %s" % int(player.stats["gold"])
	_on_inventory_changed(player.inventory)
	set_gps(0.0, 0.0, 0)
	set_status("Loaded. Inventory I, craft C, build B.")


func _on_profile_changed(player_name: String, character_id: String) -> void:
	var clan_text: String = "No Clan"
	if account_manager != null and account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		var clan: Variant = account.get("clan", {})
		if clan is Dictionary and not (clan as Dictionary).is_empty():
			clan_text = str((clan as Dictionary).get("name", "Clan"))
	var admin_text: String = " ADMIN" if _is_admin() else ""
	profile_label.text = "%s  %s%s" % [player_name, _character_display(character_id), admin_text]
	clan_label.text = clan_text


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
	hp_label.text = "HP %s / %s" % [current, maximum]
	if hp_bar != null:
		hp_bar.max_value = max(1, maximum)
		hp_bar.value = clamp(current, 0, maximum)


func _on_xp_changed(current: int, level: int) -> void:
	var required: int = Balance.xp_required_for_level(level)
	xp_label.text = "Lv %s  XP %s / %s" % [level, current, required]
	if xp_bar != null:
		xp_bar.max_value = required
		xp_bar.value = clamp(current, 0, required)
	gold_label.text = "Gold %s" % int(player.stats["gold"])


func _on_inventory_changed(items: Array) -> void:
	var preview: Array = items.slice(max(0, items.size() - 4), items.size())
	if preview.is_empty():
		inv_label.text = "Recent loot: none"
	else:
		inv_label.text = "Recent loot: %s" % ", ".join(preview)


func set_gps(latitude: float, longitude: float, zoom: int) -> void:
	if gps_label == null:
		return
	if zoom <= 0:
		gps_label.text = "GPS loading"
	else:
		gps_label.text = "%.4f, %.4f  z%d" % [latitude, longitude, zoom]


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
