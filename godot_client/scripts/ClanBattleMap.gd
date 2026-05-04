extends Node2D

const ClanConfig = preload("res://scripts/ClanConfig.gd")

var battle_data: Dictionary = {}


func setup(data: Dictionary) -> void:
	battle_data = data.duplicate(true)
	name = "ClanBattleMap"
	_build_field()


func _build_field() -> void:
	var field: Polygon2D = Polygon2D.new()
	field.polygon = PackedVector2Array([
		Vector2(-620, -360),
		Vector2(620, -360),
		Vector2(620, 360),
		Vector2(-620, 360)
	])
	field.color = Color(0.10, 0.14, 0.08)
	field.z_index = -20
	add_child(field)

	var center_line: Line2D = Line2D.new()
	center_line.width = 6.0
	center_line.default_color = Color(0.62, 0.54, 0.32, 0.8)
	center_line.add_point(Vector2(0, -330))
	center_line.add_point(Vector2(0, 330))
	add_child(center_line)

	_add_spawn_zone(Vector2(-450, 0), Color(0.20, 0.38, 0.86, 0.42), "Clan A Spawn")
	_add_spawn_zone(Vector2(450, 0), Color(0.86, 0.22, 0.16, 0.42), "Clan B Spawn")
	_add_objective_marker(Vector2.ZERO)


func _add_spawn_zone(pos: Vector2, color: Color, text: String) -> void:
	var zone: Polygon2D = Polygon2D.new()
	zone.position = pos
	zone.polygon = PackedVector2Array([
		Vector2(-120, -180),
		Vector2(120, -180),
		Vector2(120, 180),
		Vector2(-120, 180)
	])
	zone.color = color
	add_child(zone)

	var label: Label = Label.new()
	label.text = text
	label.position = pos + Vector2(-70, -210)
	label.size = Vector2(140, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.72))
	add_child(label)


func _add_objective_marker(pos: Vector2) -> void:
	var ring: Line2D = Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(0.95, 0.76, 0.30, 0.85)
	for i in range(33):
		var angle: float = TAU * float(i) / 32.0
		ring.add_point(pos + Vector2(cos(angle) * 70.0, sin(angle) * 70.0))
	add_child(ring)

	var label: Label = Label.new()
	label.text = "Center Objective"
	label.position = pos + Vector2(-80, 78)
	label.size = Vector2(160, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.54))
	add_child(label)
