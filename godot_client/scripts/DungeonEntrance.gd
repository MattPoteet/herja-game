extends Node2D

const DungeonConfig = preload("res://scripts/DungeonConfig.gd")

var required_level: int = DungeonConfig.MIN_DUNGEON_LEVEL
var label: Label


func setup(level_requirement: int) -> void:
	required_level = max(DungeonConfig.MIN_DUNGEON_LEVEL, level_requirement)
	name = "DungeonEntranceLv%d" % required_level
	add_to_group("dungeon_entrances")
	_build_marker()


func can_enter(player: Node) -> bool:
	return _player_level(player) >= required_level


func blocked_message() -> String:
	return "You must be level %d to enter this dungeon." % required_level


func display_text() -> String:
	return "Dungeon - Level %d Required" % required_level


func _player_level(player: Node) -> int:
	if player != null and player.get("stats") is Dictionary:
		return int((player.get("stats") as Dictionary).get("level", 1))
	return 1


func _build_marker() -> void:
	for child in get_children():
		child.queue_free()

	z_index = 18

	var shadow: Polygon2D = Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-62, 28),
		Vector2(-36, 10),
		Vector2(36, 10),
		Vector2(62, 28),
		Vector2(30, 44),
		Vector2(-34, 44)
	])
	shadow.color = Color(0.0, 0.0, 0.0, 0.45)
	shadow.z_index = -4
	add_child(shadow)

	var glow: Line2D = Line2D.new()
	glow.width = 5.0
	glow.default_color = Color(0.58, 0.38, 1.0, 0.42)
	for i in range(25):
		var angle: float = TAU * float(i) / 24.0
		glow.add_point(Vector2(cos(angle) * 55.0, sin(angle) * 28.0 + 8.0))
	glow.z_index = -3
	add_child(glow)

	var arch: Line2D = Line2D.new()
	arch.width = 13.0
	arch.default_color = Color(0.28, 0.29, 0.32)
	arch.add_point(Vector2(-42, 30))
	arch.add_point(Vector2(-42, -14))
	arch.add_point(Vector2(-30, -44))
	arch.add_point(Vector2(0, -58))
	arch.add_point(Vector2(30, -44))
	arch.add_point(Vector2(42, -14))
	arch.add_point(Vector2(42, 30))
	arch.z_index = 1
	add_child(arch)

	var arch_highlight: Line2D = Line2D.new()
	arch_highlight.width = 3.0
	arch_highlight.default_color = Color(0.82, 0.72, 0.48, 0.86)
	arch_highlight.add_point(Vector2(-36, 26))
	arch_highlight.add_point(Vector2(-34, -12))
	arch_highlight.add_point(Vector2(-22, -36))
	arch_highlight.add_point(Vector2(0, -48))
	arch_highlight.add_point(Vector2(22, -36))
	arch_highlight.add_point(Vector2(34, -12))
	arch_highlight.add_point(Vector2(36, 26))
	arch_highlight.z_index = 3
	add_child(arch_highlight)

	var portal: Polygon2D = Polygon2D.new()
	portal.polygon = PackedVector2Array([
		Vector2(-24, 27),
		Vector2(-24, -10),
		Vector2(-14, -34),
		Vector2(0, -42),
		Vector2(14, -34),
		Vector2(24, -10),
		Vector2(24, 27)
	])
	portal.color = Color(0.10, 0.05, 0.18, 0.94)
	portal.z_index = 2
	add_child(portal)

	var rune: Label = Label.new()
	rune.text = "Lv %d" % required_level
	rune.position = Vector2(-24, -18)
	rune.size = Vector2(48, 24)
	rune.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rune.add_theme_font_size_override("font_size", 15)
	rune.add_theme_color_override("font_color", Color(0.95, 0.87, 0.48))
	rune.add_theme_color_override("font_shadow_color", Color.BLACK)
	rune.add_theme_constant_override("shadow_offset_x", 1)
	rune.add_theme_constant_override("shadow_offset_y", 1)
	rune.z_index = 5
	add_child(rune)

	label = Label.new()
	label.text = display_text()
	label.position = Vector2(-82, 42)
	label.size = Vector2(164, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.98, 0.91, 0.62))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 6
	add_child(label)
