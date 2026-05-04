extends SceneTree

const Balance = preload("res://scripts/Balance.gd")
const PlayerScript = preload("res://scripts/Player.gd")
const EnemyScript = preload("res://scripts/Enemy.gd")
const ItemDropScript = preload("res://scripts/ItemDrop.gd")
const SaveManagerScript = preload("res://scripts/SaveManager.gd")


class TestAccountManager:
	extends Node

	func get_current_account() -> Dictionary:
		return {
			"id": "smoke_test_account",
			"username": "smoke_test",
			"player_name": "Smoke Test",
			"friends": [],
			"clan": {}
		}


class TestWorldMap:
	extends Node

	func world_to_geo(world_position: Vector2) -> Dictionary:
		return {"latitude": world_position.x / 1000.0, "longitude": world_position.y / 1000.0}


var started: bool = false


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	_run()
	return false


func _run() -> void:
	var player: CharacterBody2D = PlayerScript.new()
	root.add_child(player)
	player.global_position = Vector2(120, 160)
	await process_frame

	_assert(int(player.stats["hp"]) == Balance.BASE_PLAYER_MAX_HP, "player starts at base HP")
	_assert(int(player.stats["attack"]) == Balance.BASE_PLAYER_ATTACK, "player starts at base attack")
	player.call("add_item", "Common Viking Axe")
	_assert(bool(player.call("equip_item", "Common Viking Axe")), "player can equip class gear")
	_assert(int(player.call("total_attack")) == Balance.BASE_PLAYER_ATTACK + Balance.gear_attack("Common Viking Axe"), "equipped weapon increases attack")
	player.call("add_item", "Rare Viking Axe")
	_assert(not bool(player.call("equip_item", "Rare Viking Axe")), "level requirement blocks rare gear")
	player.call("add_item", "Bone Charm")
	_assert(bool(player.call("equip_item", "Bone Charm")), "player can equip trinket")
	var hp_before_block_test: int = int(player.stats["hp"])
	player.call("take_damage", Balance.gear_defense("Bone Charm"))
	_assert(int(player.stats["hp"]) == hp_before_block_test, "equipment defense can block small hits")

	player.gain_reward(Balance.xp_required_for_level(1), 5)
	_assert(int(player.stats["level"]) == 2, "player levels from reward XP")
	_assert(int(player.stats["hp"]) == int(player.stats["max_hp"]), "level up refills HP")
	_assert(int(player.stats["gold"]) == 5, "gold reward is applied")

	player.stats["hp"] = 60
	player.call("add_item", "Mead")
	_assert(bool(player.call("use_item", "Mead")), "player can drink mead")
	_assert(int(player.stats["hp"]) == 80, "mead restores HP")
	_assert(not player.inventory.has("Mead"), "mead is consumed")

	var tonic_xp_before: int = int(player.stats["xp"])
	player.call("add_item", "Rune Tonic")
	_assert(bool(player.call("use_item", "Rune Tonic")), "player can drink rune tonic")
	_assert(int(player.stats["xp"]) > tonic_xp_before, "rune tonic grants XP")
	_assert(not player.inventory.has("Rune Tonic"), "rune tonic is consumed")

	var enemy: Area2D = EnemyScript.new()
	root.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(40, 0)
	enemy.call("init", "Wild Wisp", player)
	var empty_loot: Array[String] = [""]
	enemy.set("loot_table", empty_loot)
	await process_frame
	var xp_before: int = int(player.stats["xp"])
	enemy.call("take_damage", 999)
	await process_frame
	_assert(int(player.stats["xp"]) > xp_before, "defeating an enemy grants XP")

	var item: Area2D = ItemDropScript.new()
	root.add_child(item)
	item.global_position = player.global_position
	item.call("init", "Herb", player)
	await process_frame
	await process_frame
	_assert(player.inventory.has("Herb"), "nearby item drops enter inventory")

	var save_manager: Node = SaveManagerScript.new()
	var account_manager: Node = TestAccountManager.new()
	var world_map: Node = TestWorldMap.new()
	root.add_child(save_manager)
	root.add_child(account_manager)
	root.add_child(world_map)
	_assert(bool(save_manager.call("save_player", player, world_map, account_manager)), "save succeeds")

	var loaded_player: CharacterBody2D = PlayerScript.new()
	root.add_child(loaded_player)
	await process_frame
	_assert(bool(save_manager.call("load_player", loaded_player, world_map, account_manager)), "load succeeds")
	_assert(int(loaded_player.stats["level"]) == int(player.stats["level"]), "loaded level matches saved level")
	_assert(loaded_player.inventory.has("Herb"), "loaded inventory matches saved inventory")
	var loaded_equipment: Dictionary = loaded_player.get("equipment") as Dictionary
	_assert(str(loaded_equipment.get("weapon", "")) == "Common Viking Axe", "loaded equipment matches saved weapon")
	save_manager.call("delete_save", account_manager)

	print("Main loop smoke test passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Smoke test failed: " + message)
	quit(1)
