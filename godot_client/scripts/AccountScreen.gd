extends CanvasLayer

signal account_ready(account: Dictionary)

var account_manager

var mode: String = "login"

var email_input: LineEdit
var password_input: LineEdit
var player_name_input: LineEdit
var character_select: OptionButton
var status_label: Label
var continue_button: Button
var primary_button: Button
var mode_switch_button: Button
var form_title_label: Label
var player_name_wrap: VBoxContainer
var character_wrap: VBoxContainer


func setup(manager) -> void:
	account_manager = manager
	_build_ui()
	_update_continue_button()
	_update_mode_ui()


func _build_ui() -> void:
	layer = 100
	for child in get_children():
		child.queue_free()

	var dim: ColorRect = ColorRect.new()
	dim.name = "DimBackground"
	dim.color = Color(0.03, 0.035, 0.05, 0.96)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	add_child(dim)

	var root: Control = Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var brand_box: VBoxContainer = VBoxContainer.new()
	brand_box.position = Vector2(118, 92)
	brand_box.size = Vector2(400, 250)
	brand_box.add_theme_constant_override("separation", 8)
	root.add_child(brand_box)

	var game_title: Label = Label.new()
	game_title.text = "HERJA"
	game_title.add_theme_font_size_override("font_size", 50)
	game_title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72))
	brand_box.add_child(game_title)

	var game_subtitle: Label = Label.new()
	game_subtitle.text = "A Viking GPS adventure"
	game_subtitle.add_theme_font_size_override("font_size", 20)
	game_subtitle.add_theme_color_override("font_color", Color(0.74, 0.81, 0.91))
	brand_box.add_child(game_subtitle)

	var brand_copy: Label = Label.new()
	brand_copy.text = "Explore the real world, gather materials, fight roaming creatures, craft potions, and build Viking settlements with friends and clans."
	brand_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brand_copy.custom_minimum_size = Vector2(380, 120)
	brand_copy.add_theme_color_override("font_color", Color(0.80, 0.84, 0.89))
	brand_box.add_child(brand_copy)

	var card: Panel = Panel.new()
	card.name = "AccountCard"
	card.position = Vector2(620, 70)
	card.size = Vector2(440, 610)
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.12, 0.17, 0.98), Color(0.34, 0.40, 0.52), 18))
	root.add_child(card)

	var card_contents: VBoxContainer = VBoxContainer.new()
	card_contents.position = Vector2(28, 24)
	card_contents.size = Vector2(384, 560)
	card_contents.add_theme_constant_override("separation", 10)
	card.add_child(card_contents)

	var card_eyebrow: Label = Label.new()
	card_eyebrow.text = "WELCOME BACK"
	card_eyebrow.add_theme_font_size_override("font_size", 12)
	card_eyebrow.add_theme_color_override("font_color", Color(0.58, 0.72, 0.95))
	card_contents.add_child(card_eyebrow)

	form_title_label = Label.new()
	form_title_label.add_theme_font_size_override("font_size", 28)
	form_title_label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.98))
	card_contents.add_child(form_title_label)

	var help_label: Label = Label.new()
	help_label.text = "Sign in to keep your player, saves, inventory, friends, and clan synced to your Herja account."
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_color_override("font_color", Color(0.77, 0.80, 0.87))
	card_contents.add_child(help_label)

	email_input = _make_line_edit("Email address")
	card_contents.add_child(_labeled("Email", email_input))

	password_input = _make_line_edit("Password")
	password_input.secret = true
	card_contents.add_child(_labeled("Password", password_input))

	player_name_input = _make_line_edit("Player name")
	player_name_wrap = _labeled("Player Name", player_name_input)
	card_contents.add_child(player_name_wrap)

	character_select = OptionButton.new()
	character_select.custom_minimum_size = Vector2(0, 42)
	character_select.add_theme_stylebox_override("normal", _input_style())
	character_select.add_theme_stylebox_override("hover", _input_style(Color(0.14, 0.17, 0.24), Color(0.50, 0.62, 0.85)))
	character_select.add_item("Viking", 0)
	character_select.set_item_metadata(0, "viking")
	character_select.add_item("Shield Maiden", 1)
	character_select.set_item_metadata(1, "shield_maiden")
	character_select.add_item("Druid", 2)
	character_select.set_item_metadata(2, "druid")
	character_select.add_item("Mage", 3)
	character_select.set_item_metadata(3, "mage")
	character_wrap = _labeled("Character", character_select)
	card_contents.add_child(character_wrap)

	primary_button = Button.new()
	primary_button.custom_minimum_size = Vector2(0, 46)
	_primary_button_style(primary_button)
	primary_button.pressed.connect(_on_primary_pressed)
	card_contents.add_child(primary_button)

	mode_switch_button = Button.new()
	mode_switch_button.flat = true
	mode_switch_button.add_theme_color_override("font_color", Color(0.62, 0.76, 0.95))
	mode_switch_button.pressed.connect(_on_switch_mode_pressed)
	card_contents.add_child(mode_switch_button)

	var session_buttons: HBoxContainer = HBoxContainer.new()
	session_buttons.add_theme_constant_override("separation", 8)
	card_contents.add_child(session_buttons)

	continue_button = Button.new()
	continue_button.text = "Continue Last"
	_secondary_button_style(continue_button)
	continue_button.pressed.connect(_on_continue_pressed)
	session_buttons.add_child(continue_button)

	var guest_button: Button = Button.new()
	guest_button.text = "Offline Guest"
	_secondary_button_style(guest_button)
	guest_button.pressed.connect(_on_guest_pressed)
	session_buttons.add_child(guest_button)

	status_label = Label.new()
	status_label.text = "Enter your email and password to continue."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 56)
	status_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.60))
	card_contents.add_child(status_label)

	var note_panel: Panel = Panel.new()
	note_panel.custom_minimum_size = Vector2(0, 82)
	note_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.13, 0.9), Color(0.22, 0.27, 0.36), 12))
	card_contents.add_child(note_panel)

	var note_label: Label = Label.new()
	note_label.position = Vector2(12, 10)
	note_label.size = Vector2(352, 60)
	note_label.text = "Tip: Continue Last uses your previous session. Offline Guest is good for local testing."
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.add_theme_font_size_override("font_size", 12)
	note_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.84))
	note_panel.add_child(note_label)


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


func _input_style(bg: Color = Color(0.11, 0.14, 0.20), border: Color = Color(0.28, 0.35, 0.46)) -> StyleBoxFlat:
	return _panel_style(bg, border, 10)


func _make_line_edit(placeholder: String) -> LineEdit:
	var input: LineEdit = LineEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size = Vector2(0, 42)
	input.add_theme_stylebox_override("normal", _input_style())
	input.add_theme_stylebox_override("focus", _input_style(Color(0.14, 0.17, 0.24), Color(0.56, 0.70, 0.94)))
	input.add_theme_stylebox_override("read_only", _input_style())
	input.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.60, 0.69))
	return input


func _labeled(label_text: String, control: Control) -> VBoxContainer:
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	wrap.add_child(label)
	wrap.add_child(control)
	return wrap


func _primary_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.39, 0.25, 0.11), Color(0.82, 0.69, 0.45), 12))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.48, 0.32, 0.14), Color(0.92, 0.80, 0.54), 12))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.31, 0.20, 0.09), Color(0.92, 0.80, 0.54), 12))
	button.add_theme_color_override("font_color", Color(0.98, 0.97, 0.92))


func _secondary_button_style(button: Button) -> void:
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.12, 0.15, 0.22), Color(0.29, 0.36, 0.49), 10))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.16, 0.19, 0.27), Color(0.44, 0.54, 0.70), 10))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.10, 0.13, 0.18), Color(0.44, 0.54, 0.70), 10))
	button.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))


func _selected_character_id() -> String:
	var selected_index: int = character_select.selected
	if selected_index < 0:
		return "viking"
	var metadata: Variant = character_select.get_item_metadata(selected_index)
	if metadata == null:
		return "viking"
	return str(metadata)


func _on_primary_pressed() -> void:
	if account_manager == null:
		return
	if mode == "create":
		status_label.text = "Creating account..."
		var result: Dictionary = await account_manager.create_account(
			email_input.text,
			password_input.text,
			player_name_input.text,
			_selected_character_id()
		)
		_handle_result(result)
	else:
		status_label.text = "Logging in..."
		var result: Dictionary = await account_manager.login_account(email_input.text, password_input.text)
		_handle_result(result)


func _on_switch_mode_pressed() -> void:
	if mode == "login":
		mode = "create"
	else:
		mode = "login"
	_update_mode_ui()


func _update_mode_ui() -> void:
	if form_title_label == null:
		return
	var is_create: bool = mode == "create"
	form_title_label.text = "Create Account" if is_create else "Login"
	primary_button.text = "Create Account" if is_create else "Login"
	mode_switch_button.text = "Already have an account? Log in" if is_create else "Need an account? Create one"
	player_name_wrap.visible = is_create
	character_wrap.visible = is_create
	status_label.text = "Choose a player name and starting character." if is_create else "Enter your email and password to continue."


func _on_continue_pressed() -> void:
	if account_manager == null:
		return
	var result: Dictionary = account_manager.call("continue_last_session") as Dictionary
	_handle_result(result)


func _on_guest_pressed() -> void:
	if account_manager == null:
		return
	var result: Dictionary = account_manager.call("create_guest_account") as Dictionary
	_handle_result(result)


func _handle_result(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		var account: Dictionary = result.get("account", {}) as Dictionary
		status_label.text = "Loading " + str(account.get("player_name", "player")) + "..."
		account_ready.emit(account)
		queue_free()
	else:
		status_label.text = str(result.get("error", "Account error."))


func _update_continue_button() -> void:
	if continue_button == null or account_manager == null:
		return
	continue_button.disabled = not bool(account_manager.call("has_last_session"))
