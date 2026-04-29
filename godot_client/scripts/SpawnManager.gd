extends Node

var world_map: Node2D
var player: CharacterBody2D
var enemy_scene := preload("res://scenes/Enemy.tscn")
var max_enemies := 30

func setup(map_node: Node2D, player_node: CharacterBody2D) -> void:
	world_map = map_node
	player = player_node
	spawn_initial_enemies()

func spawn_initial_enemies() -> void:
	for i in max_enemies:
		spawn_enemy()

func spawn_enemy() -> void:
	if world_map == null or player == null:
		return
	var enemy = enemy_scene.instantiate()
	enemy.global_position = world_map.random_walkable_position()
	var roll := randi() % 3
	if roll == 0:
		enemy.init("Wild Wisp", 30, 5, 20, 3, player)
	elif roll == 1:
		enemy.init("Forest Imp", 45, 8, 35, 6, player)
	else:
		enemy.init("Stone Boar", 65, 10, 50, 10, player)
	enemy.defeated.connect(_on_enemy_defeated)
	get_tree().current_scene.add_child(enemy)

func _on_enemy_defeated(_enemy: Node) -> void:
	await get_tree().create_timer(3.0).timeout
	spawn_enemy()
