extends Node2D

signal exit_requested
signal boss_defeated

const Balance = preload("res://scripts/Balance.gd")
const DungeonConfig = preload("res://scripts/DungeonConfig.gd")

var tier: int = DungeonConfig.MIN_DUNGEON_LEVEL
var player: CharacterBody2D
var hud: Node
var dungeon_id: String = ""
var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
var boss_alive: bool = false
var exit_marker: Node2D


func setup(required_level: int, player_node: CharacterBody2D, hud_node: Node, id_text: String) -> void:
	tier = max(DungeonConfig.MIN_DUNGEON_LEVEL, required_level)
	player = player_node
	hud = hud_node
	dungeon_id = id_text
	name = "DungeonMapLv%d" % tier
	z_index = -2
	_build_map()
	_spawn_dungeon_enemies()
	_set_status("Entered Level %d dungeon. Find and defeat the boss." % tier)


func handle_world_tap(world_position: Vector2) -> bool:
	if exit_marker != null and exit_marker.global_position.distance_to(world_position) <= 58.0:
		exit_requested.emit()
		return true
	return false


func clamp_world_position(world_position: Vector2) -> Vector2:
	var local_position: Vector2 = to_local(world_position)
	local_position.x = clamp(local_position.x, -DungeonConfig.DUNGEON_WIDTH * 0.5 + 32.0, DungeonConfig.DUNGEON_WIDTH * 0.5 - 32.0)
	local_position.y = clamp(local_position.y, -DungeonConfig.DUNGEON_HEIGHT * 0.5 + 32.0, DungeonConfig.DUNGEON_HEIGHT * 0.5 - 32.0)
	return to_global(local_position)


func _build_map() -> void:
	var floor: Polygon2D = Polygon2D.new()
	floor.polygon = PackedVector2Array([
		Vector2(-DungeonConfig.DUNGEON_WIDTH * 0.5, -DungeonConfig.DUNGEON_HEIGHT * 0.5),
		Vector2(DungeonConfig.DUNGEON_WIDTH * 0.5, -DungeonConfig.DUNGEON_HEIGHT * 0.5),
		Vector2(DungeonConfig.DUNGEON_WIDTH * 0.5, DungeonConfig.DUNGEON_HEIGHT * 0.5),
		Vector2(-DungeonConfig.DUNGEON_WIDTH * 0.5, DungeonConfig.DUNGEON_HEIGHT * 0.5)
	])
	floor.color = Color(0.07, 0.075, 0.082)
	floor.z_index = -20
	add_child(floor)

	var border: Line2D = Line2D.new()
	border.width = 18.0
	border.default_color = Color(0.18, 0.17, 0.16)
	border.add_point(Vector2(-DungeonConfig.DUNGEON_WIDTH * 0.5, -DungeonConfig.DUNGEON_HEIGHT * 0.5))
	border.add_point(Vector2(DungeonConfig.DUNGEON_WIDTH * 0.5, -DungeonConfig.DUNGEON_HEIGHT * 0.5))
	border.add_point(Vector2(DungeonConfig.DUNGEON_WIDTH * 0.5, DungeonConfig.DUNGEON_HEIGHT * 0.5))
	border.add_point(Vector2(-DungeonConfig.DUNGEON_WIDTH * 0.5, DungeonConfig.DUNGEON_HEIGHT * 0.5))
	border.add_point(Vector2(-DungeonConfig.DUNGEON_WIDTH * 0.5, -DungeonConfig.DUNGEON_HEIGHT * 0.5))
	border.z_index = -18
	add_child(border)

	for i in range(10):
		var stone: Polygon2D = Polygon2D.new()
		var x: float = randf_range(-DungeonConfig.DUNGEON_WIDTH * 0.42, DungeonConfig.DUNGEON_WIDTH * 0.42)
		var y: float = randf_range(-DungeonConfig.DUNGEON_HEIGHT * 0.34, DungeonConfig.DUNGEON_HEIGHT * 0.34)
		stone.position = Vector2(x, y)
		stone.polygon = PackedVector2Array([Vector2(-26, -10), Vector2(20, -16), Vector2(32, 10), Vector2(-18, 18)])
		stone.color = Color(0.12, 0.125, 0.13, 0.9)
		stone.z_index = -16
		add_child(stone)

	exit_marker = _make_portal_marker("Exit", Color(0.30, 0.62, 1.0))
	exit_marker.position = Vector2(-DungeonConfig.DUNGEON_WIDTH * 0.42, 0)
	add_child(exit_marker)

	var boss_marker: Node2D = _make_portal_marker("Boss", Color(1.0, 0.28, 0.18))
	boss_marker.position = Vector2(DungeonConfig.DUNGEON_WIDTH * 0.36, 0)
	boss_marker.z_index = -12
	add_child(boss_marker)


func _spawn_dungeon_enemies() -> void:
	var enemy_names: Array[String] = DungeonConfig.dungeon_enemy_names_for_tier(tier)
	var positions: Array[Vector2] = [
		Vector2(-230, -180),
		Vector2(-60, -210),
		Vector2(140, -150),
		Vector2(-180, 170),
		Vector2(70, 190),
		Vector2(255, 120)
	]
	for i in range(min(DungeonConfig.DUNGEON_ENEMY_COUNT, positions.size())):
		var enemy: Node = enemy_scene.instantiate()
		enemy.set_meta("dungeon_enemy", true)
		if enemy is Node2D:
			(enemy as Node2D).position = positions[i]
		enemy.call("init", str(enemy_names.pick_random()), player)
		if enemy.has_method("apply_dungeon_scaling"):
			enemy.call("apply_dungeon_scaling", tier, false)
		add_child(enemy)

	var boss: Node = enemy_scene.instantiate()
	boss.set_meta("dungeon_enemy", true)
	boss.set_meta("dungeon_boss", true)
	if boss is Node2D:
		(boss as Node2D).position = Vector2(DungeonConfig.DUNGEON_WIDTH * 0.36, 0)
	boss.call("init", _boss_base_enemy_name(), player)
	if boss.has_method("apply_dungeon_scaling"):
		boss.call("apply_dungeon_scaling", tier, true)
	if boss.has_signal("defeated"):
		boss.connect("defeated", Callable(self, "_on_boss_defeated"))
	add_child(boss)
	boss_alive = true


func _on_boss_defeated(_enemy: Node) -> void:
	if not boss_alive:
		return
	boss_alive = false
	boss_defeated.emit()
	_set_status("Dungeon boss defeated. Tap the Exit portal to return.")


func _boss_base_enemy_name() -> String:
	if tier >= 40:
		return "Rune Golem"
	if tier >= 20:
		return "Frost Troll"
	return "Draugr Warrior"


func _make_portal_marker(text: String, color: Color) -> Node2D:
	var marker: Node2D = Node2D.new()
	marker.z_index = 4

	var glow: Line2D = Line2D.new()
	glow.width = 4.0
	glow.default_color = Color(color.r, color.g, color.b, 0.45)
	for i in range(25):
		var angle: float = TAU * float(i) / 24.0
		glow.add_point(Vector2(cos(angle) * 42.0, sin(angle) * 28.0))
	marker.add_child(glow)

	var label: Label = Label.new()
	label.text = text
	label.position = Vector2(-38, 30)
	label.size = Vector2(76, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.72))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	marker.add_child(label)
	return marker


func _set_status(message: String) -> void:
	if hud != null and hud.has_method("set_status"):
		hud.call("set_status", message)
