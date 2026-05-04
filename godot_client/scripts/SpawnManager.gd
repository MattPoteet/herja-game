extends Node

const Balance = preload("res://scripts/Balance.gd")

var world_map: Node2D
var player: CharacterBody2D
var enemy_scene := preload("res://scenes/Enemy.tscn")
var max_enemies: int = Balance.MAX_ACTIVE_ENEMIES
var spawning_paused: bool = false

func setup(map_node: Node2D, player_node: CharacterBody2D) -> void:
	world_map = map_node
	player = player_node
	spawn_initial_enemies()

func spawn_initial_enemies() -> void:
	for i in min(Balance.INITIAL_ENEMY_COUNT, max_enemies):
		spawn_enemy()

func spawn_enemy() -> void:
	if spawning_paused or world_map == null or player == null:
		return
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return
	var enemy = enemy_scene.instantiate()
	enemy.global_position = _random_spawn_position()
	var player_level: int = 1
	if player.get("stats") is Dictionary:
		player_level = int((player.get("stats") as Dictionary).get("level", 1))
	enemy.init(Balance.random_enemy_name_for_level(player_level), player)
	enemy.defeated.connect(_on_enemy_defeated)
	get_tree().current_scene.add_child(enemy)

func _on_enemy_defeated(_enemy: Node) -> void:
	await get_tree().create_timer(Balance.ENEMY_RESPAWN_SECONDS).timeout
	while spawning_paused:
		await get_tree().create_timer(0.5).timeout
	spawn_enemy()


func set_spawning_paused(paused: bool) -> void:
	spawning_paused = paused
	set_process(not paused)


func _random_spawn_position() -> Vector2:
	var fallback: Vector2 = world_map.random_walkable_position()
	for attempt in range(12):
		var candidate: Vector2 = world_map.random_walkable_position()
		if player.global_position.distance_to(candidate) >= Balance.ENEMY_MIN_SPAWN_DISTANCE:
			return candidate
	return fallback
