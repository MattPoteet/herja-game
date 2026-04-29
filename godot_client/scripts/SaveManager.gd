extends Node

const SAVE_DIR: String = "user://saves"
const LEGACY_SAVE_PATH: String = "user://player_save.json"
const SAVE_VERSION: int = 2


func save_player(player: Node, world_map: Node, account_manager: Node = null) -> bool:
	if player == null:
		return false

	_ensure_save_dir()

	var account: Dictionary = _get_account(account_manager)
	var account_id: String = str(account.get("id", "offline"))
	var geo: Dictionary = {}
	if world_map != null and world_map.has_method("world_to_geo"):
		geo = world_map.call("world_to_geo", player.global_position)
	elif world_map != null and world_map.has_method("world_to_lat_lon"):
		var lat_lon: Vector2 = world_map.call("world_to_lat_lon", player.global_position)
		geo = {"latitude": lat_lon.x, "longitude": lat_lon.y}

	var data: Dictionary = {
		"version": SAVE_VERSION,
		"account_id": account_id,
		"username": str(account.get("username", "offline")),
		"player_name": str(player.stats.get("name", account.get("player_name", "Viking"))),
		"character_id": str(player.get("character_id")),
		"level": int(player.stats.get("level", 1)),
		"xp": int(player.stats.get("xp", 0)),
		"hp": int(player.stats.get("hp", 100)),
		"max_hp": int(player.stats.get("max_hp", 100)),
		"attack": int(player.stats.get("attack", 12)),
		"gold": int(player.stats.get("gold", 0)),
		"inventory": player.inventory.duplicate(true),
		"friends": account.get("friends", []),
		"clan": account.get("clan", {}),
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		},
		"geo_position": geo,
		"saved_at_unix": Time.get_unix_time_from_system()
	}

	var file: FileAccess = FileAccess.open(_save_path_for_account(account_id), FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file for writing.")
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	if account_manager != null and account_manager.has_method("update_progress_snapshot"):
		account_manager.call("update_progress_snapshot", player)
	if account_manager != null and account_manager.has_method("sync_progress_to_supabase"):
		account_manager.call_deferred("sync_progress_to_supabase", player, world_map)

	return true


func load_player(player: Node, world_map: Node, account_manager: Node = null) -> bool:
	if player == null:
		return false

	var account: Dictionary = _get_account(account_manager)
	var account_id: String = str(account.get("id", "offline"))
	var path: String = _save_path_for_account(account_id)

	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(LEGACY_SAVE_PATH):
			path = LEGACY_SAVE_PATH
		else:
			return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file for reading.")
		return false

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Save file is invalid JSON. Starting new game.")
		return false

	var data: Dictionary = parsed as Dictionary
	_apply_data_to_player(player, world_map, data)
	return true


func delete_save(account_manager: Node = null) -> bool:
	var account: Dictionary = _get_account(account_manager)
	var account_id: String = str(account.get("id", "offline"))
	var path: String = _save_path_for_account(account_id)
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func get_save_path(account_manager: Node = null) -> String:
	var account: Dictionary = _get_account(account_manager)
	return _save_path_for_account(str(account.get("id", "offline")))


func _apply_data_to_player(player: Node, world_map: Node, data: Dictionary) -> void:
	player.stats["name"] = str(data.get("player_name", player.stats.get("name", "Viking")))
	player.stats["level"] = int(data.get("level", player.stats.get("level", 1)))
	player.stats["xp"] = int(data.get("xp", player.stats.get("xp", 0)))
	player.stats["hp"] = int(data.get("hp", player.stats.get("hp", 100)))
	player.stats["max_hp"] = int(data.get("max_hp", player.stats.get("max_hp", 100)))
	player.stats["attack"] = int(data.get("attack", player.stats.get("attack", 12)))
	player.stats["gold"] = int(data.get("gold", player.stats.get("gold", 0)))
	player.set("character_id", str(data.get("character_id", player.get("character_id"))))

	var loaded_inventory: Array = []
	var raw_inventory: Variant = data.get("inventory", [])
	if raw_inventory is Array:
		for item in raw_inventory:
			loaded_inventory.append(str(item))
	player.inventory = loaded_inventory

	var pos: Vector2 = player.global_position
	var position_data: Variant = data.get("position", {})
	if position_data is Dictionary:
		var pos_dict: Dictionary = position_data as Dictionary
		pos = Vector2(float(pos_dict.get("x", pos.x)), float(pos_dict.get("y", pos.y)))
	elif data.has("geo_position") and world_map != null and world_map.has_method("geo_to_world"):
		var geo: Variant = data.get("geo_position", {})
		if geo is Dictionary:
			var geo_dict: Dictionary = geo as Dictionary
			pos = world_map.call(
				"geo_to_world",
				float(geo_dict.get("latitude", 0.0)),
				float(geo_dict.get("longitude", 0.0))
			)

	player.global_position = pos
	if player.has_method("refresh_after_load"):
		player.call("refresh_after_load")


func _get_account(account_manager: Node) -> Dictionary:
	if account_manager != null and account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		if not account.is_empty():
			return account
	return {"id": "offline", "username": "offline", "player_name": "Viking", "friends": [], "clan": {}}


func _save_path_for_account(account_id: String) -> String:
	return SAVE_DIR + "/" + account_id + ".json"


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
