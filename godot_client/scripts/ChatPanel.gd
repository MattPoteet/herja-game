extends CanvasLayer

signal message_submitted(message: String)

const MAX_VISIBLE_MESSAGES: int = 7

var panel: Panel
var messages_box: VBoxContainer
var input: LineEdit
var status_label: Label
var messages: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()
	visible = true


func focus_chat() -> void:
	visible = true
	if input != null:
		input.grab_focus()


func set_connection_status(is_connected: bool) -> void:
	if status_label == null:
		return
	status_label.text = "Online chat" if is_connected else "Chat offline"
	status_label.add_theme_color_override("font_color", Color(0.70, 0.94, 0.76) if is_connected else Color(0.95, 0.58, 0.52))


func add_system_message(message: String) -> void:
	_add_message({"name": "System", "message": message, "system": true})


func add_chat_message(sender_name: String, message: String, clan_name: String = "") -> void:
	_add_message({"name": sender_name, "message": message, "clan": clan_name, "system": false})


func _build_ui() -> void:
	layer = 45
	panel = Panel.new()
	panel.position = Vector2(16, 430)
	panel.size = Vector2(460, 250)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.055, 0.070, 0.90), Color(0.20, 0.26, 0.34), 8))
	add_child(panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.position = Vector2(12, 10)
	root.size = Vector2(436, 230)
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title: Label = Label.new()
	title.text = "Chat"
	title.custom_minimum_size = Vector2(70, 22)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68))
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Chat offline"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(status_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	messages_box = VBoxContainer.new()
	messages_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_box.add_theme_constant_override("separation", 3)
	scroll.add_child(messages_box)

	var input_row: HBoxContainer = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	root.add_child(input_row)

	input = LineEdit.new()
	input.placeholder_text = "Message nearby players"
	input.max_length = 180
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(_on_text_submitted)
	input_row.add_child(input)

	var send_button: Button = Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(72, 32)
	send_button.pressed.connect(_submit_current_text)
	input_row.add_child(send_button)

	add_system_message("Press Enter or T to chat.")


func _add_message(message: Dictionary) -> void:
	messages.append(message)
	while messages.size() > MAX_VISIBLE_MESSAGES:
		messages.pop_front()
	_redraw_messages()


func _redraw_messages() -> void:
	if messages_box == null:
		return
	for child in messages_box.get_children():
		child.queue_free()
	for message in messages:
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		if bool(message.get("system", false)):
			label.text = str(message.get("message", ""))
			label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
		else:
			var clan_text: String = ""
			if str(message.get("clan", "")) != "":
				clan_text = "[%s] " % str(message.get("clan", ""))
			label.text = "%s%s: %s" % [clan_text, str(message.get("name", "Player")), str(message.get("message", ""))]
			label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		messages_box.add_child(label)


func _on_text_submitted(_text: String) -> void:
	_submit_current_text()


func _submit_current_text() -> void:
	if input == null:
		return
	var clean_message: String = input.text.strip_edges()
	if clean_message == "":
		return
	message_submitted.emit(clean_message)
	input.text = ""
	input.release_focus()


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
