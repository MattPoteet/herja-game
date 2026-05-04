extends Node

const DungeonConfig = preload("res://scripts/DungeonConfig.gd")
const GroupRewardDistributorScript = preload("res://scripts/GroupRewardDistributor.gd")
const DungeonMapScene: PackedScene = preload("res://scenes/DungeonMap.tscn")

var player: CharacterBody2D
var world_map: Node2D
var spawn_manager: Node
var hud: Node
var dungeon_map: Node2D
var reward_distributor: RefCounted
var return_position: Vector2
var hidden_world_enemies: Array[Node] = []
var current_dungeon_id: String = ""


func setup(player_node: CharacterBody2D, map_node: Node2D, spawn_node: Node, hud_node: Node) -> void:
	player = player_node
	world_map = map_node
	spawn_manager = spawn_node
	hud = hud_node
	reward_distributor = GroupRewardDistributorScript.new()


func is_dungeon_active() -> bool:
	return dungeon_map != null and is_instance_valid(dungeon_map)


func enter_dungeon(required_level: int, entrance_position: Vector2) -> void:
	if is_dungeon_active() or player == null:
		return
	return_position = player.global_position
	current_dungeon_id = "%d:%d:%d" % [required_level, int(entrance_position.x), int(entrance_position.y)]
	_pause_world(true)
	dungeon_map = DungeonMapScene.instantiate()
	dungeon_map.global_position = return_position + Vector2(0, -140)
	get_tree().current_scene.add_child(dungeon_map)
	dungeon_map.call("setup", required_level, player, hud, current_dungeon_id)
	if dungeon_map.has_signal("exit_requested"):
		dungeon_map.connect("exit_requested", Callable(self, "exit_dungeon"))
	if dungeon_map.has_signal("boss_defeated"):
		dungeon_map.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
	player.global_position = dungeon_map.global_position + Vector2(-DungeonConfig.DUNGEON_WIDTH * 0.38, 0)
	_clear_player_navigation()


func exit_dungeon() -> void:
	if not is_dungeon_active():
		return
	if is_instance_valid(dungeon_map):
		dungeon_map.queue_free()
	dungeon_map = null
	_clear_dungeon_drops()
	if player != null:
		player.global_position = return_position
		_clear_player_navigation()
	_pause_world(false)
	_set_status("Returned to the world map.")


func handle_world_tap(world_position: Vector2) -> bool:
	if not is_dungeon_active():
		return false
	if dungeon_map.has_method("handle_world_tap"):
		return bool(dungeon_map.call("handle_world_tap", world_position))
	return false


func apply_player_bounds() -> void:
	if not is_dungeon_active() or player == null:
		return
	if dungeon_map.has_method("clamp_world_position"):
		var clamped_position: Vector2 = dungeon_map.call("clamp_world_position", player.global_position)
		if clamped_position != player.global_position:
			player.global_position = clamped_position
			player.set("velocity", Vector2.ZERO)


func _on_boss_defeated() -> void:
	if reward_distributor != null and reward_distributor.has_method("distribute_boss_rewards"):
		reward_distributor.call("distribute_boss_rewards", player, int(dungeon_map.get("tier")), current_dungeon_id, hud)


func _pause_world(paused: bool) -> void:
	if world_map != null:
		world_map.visible = not paused
		world_map.set_process(not paused)
	if spawn_manager != null:
		if spawn_manager.has_method("set_spawning_paused"):
			spawn_manager.call("set_spawning_paused", paused)
		else:
			spawn_manager.set_process(not paused)
	if paused:
		hidden_world_enemies.clear()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or bool(enemy.get_meta("dungeon_enemy", false)):
				continue
			if enemy is Node2D:
				var enemy_node: Node2D = enemy as Node2D
				hidden_world_enemies.append(enemy_node)
				enemy_node.visible = false
			if enemy.has_method("set_combat_paused"):
				enemy.call("set_combat_paused", true)
	else:
		for enemy in hidden_world_enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy is Node2D:
				(enemy as Node2D).visible = true
			if enemy.has_method("set_combat_paused"):
				enemy.call("set_combat_paused", false)
		hidden_world_enemies.clear()


func _clear_player_navigation() -> void:
	if player == null:
		return
	player.set("has_move_target", false)
	player.set("move_target", player.global_position)
	player.set("active_attack_target", null)
	player.set("velocity", Vector2.ZERO)


func _clear_dungeon_drops() -> void:
	for node in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(node) and bool(node.get_meta("dungeon_drop", false)):
			node.queue_free()


func _set_status(message: String) -> void:
	if hud != null and hud.has_method("set_status"):
		hud.call("set_status", message)
