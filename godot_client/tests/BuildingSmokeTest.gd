extends SceneTree

const PlayerScript = preload("res://scripts/Player.gd")
const BuildingManagerScript = preload("res://scripts/BuildingManager.gd")


class AdminAccountManager:
	extends Node

	func get_current_account() -> Dictionary:
		return {"id": "building_smoke_test", "username": "builder", "player_name": "Builder", "is_admin": true}

	func is_current_account_admin() -> bool:
		return true


class TestHud:
	extends Node

	var last_status: String = ""

	func set_status(message: String) -> void:
		last_status = message


var started: bool = false


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	_run()
	return false


func _run() -> void:
	var player: CharacterBody2D = PlayerScript.new()
	var account_manager: Node = AdminAccountManager.new()
	var hud: Node = TestHud.new()
	var buildings: Node2D = BuildingManagerScript.new()
	root.add_child(player)
	root.add_child(account_manager)
	root.add_child(hud)
	root.add_child(buildings)
	player.global_position = Vector2(300, 300)
	await process_frame

	buildings.call("setup", player, account_manager, hud)
	buildings.set("structures", [])
	_assert(bool(buildings.call("build_structure", "campfire")), "admin can build campfire")
	player.stats["hp"] = 50
	_assert(bool(buildings.call("use_nearest_structure")), "campfire can be used")
	_assert(int(player.stats["hp"]) == 75, "campfire heals 25 HP")
	_assert(not bool(buildings.call("use_nearest_structure")), "campfire cooldown blocks immediate reuse")

	player.global_position += Vector2(140, 0)
	_assert(bool(buildings.call("build_structure", "farmstead")), "admin can build farmstead")
	_assert(bool(buildings.call("use_nearest_structure")), "farmstead can be used")
	_assert(player.inventory.has("Herb"), "farmstead adds harvest items")

	buildings.call("remove_nearest_structure")
	print("Building smoke test passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Building smoke test failed: " + message)
	quit(1)
