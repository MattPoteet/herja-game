extends CanvasLayer

signal move_changed(move_vector: Vector2)
signal attack_pressed
signal inventory_pressed
signal build_pressed
signal social_pressed
signal save_pressed

const MobilePlatform = preload("res://scripts/MobilePlatform.gd")

var actions_container: Control


func _ready() -> void:
	layer = 80
	visible = MobilePlatform.use_mobile_layout()
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var actions: VBoxContainer = VBoxContainer.new()
	actions_container = actions
	var margin: float = MobilePlatform.safe_margin()
	actions.anchor_left = 1.0
	actions.anchor_top = 1.0
	actions.anchor_right = 1.0
	actions.anchor_bottom = 1.0
	actions.offset_left = -242.0
	actions.offset_top = -220.0
	actions.offset_right = -margin
	actions.offset_bottom = -margin
	actions.add_theme_constant_override("separation", 10)
	add_child(actions)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	actions.add_child(top_row)
	top_row.add_child(_make_action_button("I", Callable(self, "_on_inventory_pressed"), Vector2(64, 58)))
	top_row.add_child(_make_action_button("B", Callable(self, "_on_build_pressed"), Vector2(64, 58)))
	top_row.add_child(_make_action_button("O", Callable(self, "_on_social_pressed"), Vector2(64, 58)))

	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	actions.add_child(bottom_row)
	bottom_row.add_child(_make_action_button("Save", Callable(self, "_on_save_pressed"), Vector2(92, 64)))
	bottom_row.add_child(_make_action_button("Attack", Callable(self, "_on_attack_pressed"), Vector2(122, 64)))


func is_screen_position_over_controls(screen_position: Vector2) -> bool:
	if not visible or actions_container == null:
		return false
	return actions_container.get_global_rect().has_point(screen_position)


func _make_action_button(text: String, callback: Callable, min_size: Vector2 = Vector2(52, 48)) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.06, 0.08, 0.11, 0.72), Color(0.24, 0.30, 0.38, 0.86)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.10, 0.13, 0.18, 0.82), Color(0.48, 0.58, 0.72, 0.92)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.86, 0.66, 0.30, 0.86), Color(0.10, 0.08, 0.04, 0.90)))
	button.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	button.pressed.connect(callback)
	return button


func _on_attack_pressed() -> void:
	attack_pressed.emit()


func _on_inventory_pressed() -> void:
	inventory_pressed.emit()


func _on_build_pressed() -> void:
	build_pressed.emit()


func _on_social_pressed() -> void:
	social_pressed.emit()


func _on_save_pressed() -> void:
	save_pressed.emit()


func _circle_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
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


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _circle_style(bg, border, 8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style
