extends Node

const Balance = preload("res://scripts/Balance.gd")

var world_map: Node2D
var player: CharacterBody2D
var enemy_scene := preload("res://scenes/Enemy.tscn")
var max_enemies: int = Balance.ENEMIES_PER_AREA_MAX
var spawning_paused: bool = false
var active_section: Vector2i = Vector2i(-999999, -999999)
var area_enemy_nodes: Array[Node] = []
var pending_respawns: int = 0

func setup(map_node: Node2D, player_node: CharacterBody2D) -> void:
	world_map = map_node
	player = player_node
	if world_map != null:
		if world_map.has_method("get_active_section"):
			active_section = world_map.call("get_active_section")
		if world_map.has_signal("section_loading_started"):
			world_map.section_loading_started.connect(_on_section_loading_started)
		if world_map.has_signal("section_loading_finished"):
			world_map.section_loading_finished.connect(_on_section_loading_finished)
	load_area(active_section)

func spawn_initial_enemies() -> void:
	load_area(active_section)


func load_area(section: Vector2i) -> void:
	active_section = section
	pending_respawns = 0
	despawn_area_enemies()
	var target_count: int = randi_range(Balance.ENEMIES_PER_AREA_MIN, Balance.ENEMIES_PER_AREA_MAX)
	for i in range(target_count):
		spawn_enemy()

func spawn_enemy() -> void:
	if spawning_paused or world_map == null or player == null:
		return
	_prune_area_enemy_nodes()
	if area_enemy_nodes.size() >= max_enemies:
		return
	var enemy = enemy_scene.instantiate()
	enemy.global_position = _random_spawn_position()
	var player_level: int = 1
	if Balance.AREA_ENEMY_LEVEL_SCALING and player.get("stats") is Dictionary:
		player_level = int((player.get("stats") as Dictionary).get("level", 1))
	enemy.init(Balance.random_enemy_name_for_level(player_level), player)
	enemy.set_meta("active_area_section", _section_key(active_section))
	enemy.defeated.connect(_on_enemy_defeated)
	get_tree().current_scene.add_child(enemy)
	area_enemy_nodes.append(enemy)


func despawn_area_enemies() -> void:
	for enemy in area_enemy_nodes:
		if is_instance_valid(enemy):
			enemy.queue_free()
	area_enemy_nodes.clear()
	if player != null:
		player.set("active_attack_target", null)


func _on_enemy_defeated(enemy: Node) -> void:
	area_enemy_nodes.erase(enemy)
	if not Balance.ENEMY_RESPAWN_ENABLED:
		return
	var defeated_section_key: String = str(enemy.get_meta("active_area_section", ""))
	pending_respawns += 1
	await get_tree().create_timer(Balance.ENEMY_RESPAWN_DELAY_SECONDS).timeout
	pending_respawns = max(0, pending_respawns - 1)
	while spawning_paused:
		await get_tree().create_timer(0.5).timeout
	if defeated_section_key != _section_key(active_section):
		return
	spawn_enemy()


func set_spawning_paused(paused: bool) -> void:
	spawning_paused = paused
	set_process(not paused)


func _on_section_loading_started(_section: Vector2i) -> void:
	# World enemies are owned by one active area. Clear them before the old area unloads.
	pending_respawns = 0
	despawn_area_enemies()


func _on_section_loading_finished(section: Vector2i) -> void:
	load_area(section)


func _prune_area_enemy_nodes() -> void:
	for i in range(area_enemy_nodes.size() - 1, -1, -1):
		if not is_instance_valid(area_enemy_nodes[i]):
			area_enemy_nodes.remove_at(i)


func _random_spawn_position() -> Vector2:
	var fallback: Vector2 = world_map.random_walkable_position()
	for attempt in range(12):
		var candidate: Vector2 = world_map.random_walkable_position()
		if world_map.has_method("is_position_in_active_area") and not bool(world_map.call("is_position_in_active_area", candidate)):
			continue
		if player.global_position.distance_to(candidate) >= Balance.ENEMY_MIN_SPAWN_DISTANCE:
			return candidate
	return fallback


func _section_key(section: Vector2i) -> String:
	return "%d:%d" % [section.x, section.y]
