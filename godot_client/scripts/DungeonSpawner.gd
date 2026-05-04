extends Node2D

signal dungeon_enter_requested(required_level: int, entrance_position: Vector2)

const DungeonConfig = preload("res://scripts/DungeonConfig.gd")
const DungeonEntranceScript = preload("res://scripts/DungeonEntrance.gd")

var world_map: Node2D
var player: Node2D
var hud: Node
var entrance_layer: Node2D
var entrance_nodes: Dictionary = {}


func setup(map_node: Node2D, player_node: Node2D, hud_node: Node) -> void:
	world_map = map_node
	player = player_node
	hud = hud_node
	_ensure_layer()
	refresh_around_player()


func refresh_around_player() -> void:
	if world_map == null or player == null:
		return
	_ensure_layer()
	var active_section: Vector2i = Vector2i.ZERO
	if world_map.has_method("world_to_section"):
		active_section = world_map.call("world_to_section", player.global_position)
	var spawned: int = _count_near_player()
	var starting_count: int = spawned
	for sy in range(active_section.y - 1, active_section.y + 2):
		for sx in range(active_section.x - 1, active_section.x + 2):
			if spawned >= DungeonConfig.MAX_ENTRANCES_PER_REFRESH:
				return
			spawned += _try_spawn_for_section(Vector2i(sx, sy))
	if starting_count == 0 and _count_near_player() == 0:
		_try_spawn_for_section(active_section, true)


func dungeon_at_world_position(world_position: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = DungeonConfig.ENTRANCE_TAP_RADIUS
	for node in entrance_nodes.values():
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var entrance: Node2D = node as Node2D
		var distance: float = entrance.global_position.distance_to(world_position)
		if distance <= nearest_distance:
			nearest = entrance
			nearest_distance = distance
	return nearest


func try_enter_nearest() -> bool:
	if player == null:
		return false
	var nearest: Node2D = null
	var nearest_distance: float = DungeonConfig.ENTRANCE_TAP_RADIUS
	for node in entrance_nodes.values():
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var entrance: Node2D = node as Node2D
		var distance: float = player.global_position.distance_to(entrance.global_position)
		if distance <= nearest_distance:
			nearest = entrance
			nearest_distance = distance
	if nearest == null:
		return false
	return try_enter_entrance(nearest)


func try_enter_entrance(entrance: Node2D) -> bool:
	if entrance == null or not is_instance_valid(entrance):
		return false
	var required_level: int = int(entrance.get("required_level"))
	if entrance.has_method("can_enter") and not bool(entrance.call("can_enter", player)):
		_set_status(str(entrance.call("blocked_message")))
		return true
	dungeon_enter_requested.emit(required_level, entrance.global_position)
	return true


func _try_spawn_for_section(section: Vector2i, force_spawn: bool = false) -> int:
	var seed_value: int = int(abs(section.x * 19349663 + section.y * 83492791 + 97))
	var section_key: String = "%d:%d" % [section.x, section.y]
	if entrance_nodes.has(section_key):
		return 0
	var roll: float = float(seed_value % 10000) / 10000.0
	if not force_spawn and roll > DungeonConfig.ENTRANCE_SPAWN_CHANCE_PER_TILE:
		return 0

	var center: Vector2 = player.global_position
	if world_map.has_method("section_to_center_world"):
		center = world_map.call("section_to_center_world", section)
	var offset: Vector2 = Vector2(
		float((seed_value / 17) % 620) - 310.0,
		float((seed_value / 43) % 420) - 210.0
	)
	var position: Vector2 = center + offset
	if player.global_position.distance_to(position) < DungeonConfig.ENTRANCE_MIN_PLAYER_DISTANCE:
		if not force_spawn:
			return 0
		var direction: Vector2 = (position - player.global_position).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT.rotated(deg_to_rad(float(seed_value % 360)))
		position = player.global_position + direction * (DungeonConfig.ENTRANCE_MIN_PLAYER_DISTANCE + 120.0)
	if not _far_enough_from_other_entrances(position):
		return 0

	var required_level: int = DungeonConfig.random_tier_for_seed(seed_value)
	if force_spawn and player.get("stats") is Dictionary:
		required_level = DungeonConfig.tier_for_level(int((player.get("stats") as Dictionary).get("level", 1)))
	var entrance: Node2D = DungeonEntranceScript.new()
	entrance.call("setup", required_level)
	entrance.global_position = position
	entrance_layer.add_child(entrance)
	entrance_nodes[section_key] = entrance
	return 1


func _count_near_player() -> int:
	var count: int = 0
	for node in entrance_nodes.values():
		if is_instance_valid(node) and node is Node2D:
			if (node as Node2D).global_position.distance_to(player.global_position) < 1800.0:
				count += 1
	return count


func _far_enough_from_other_entrances(position: Vector2) -> bool:
	for node in entrance_nodes.values():
		if is_instance_valid(node) and node is Node2D:
			if (node as Node2D).global_position.distance_to(position) < DungeonConfig.ENTRANCE_MIN_DISTANCE_FROM_OTHER:
				return false
	return true


func _ensure_layer() -> void:
	if entrance_layer != null:
		return
	entrance_layer = Node2D.new()
	entrance_layer.name = "DungeonEntrances"
	entrance_layer.z_index = 24
	if world_map != null:
		world_map.add_child(entrance_layer)
	else:
		add_child(entrance_layer)


func _set_status(message: String) -> void:
	if hud != null and hud.has_method("set_status"):
		hud.call("set_status", message)
