extends Node2D

signal structures_changed(structures: Array)

const BUILDINGS_SAVE_DIR: String = "user://buildings"
const STRUCTURE_SHEET_PATH: String = "res://art/buildings/buildings.png"
const STRUCTURE_SIZE: int = 64
const STRUCTURE_COLUMNS: int = 4

const STRUCTURE_DATA: Dictionary = {
	"campfire": {
		"name": "Campfire",
		"index": 0,
		"recipe": {"Wood": 3, "Stone": 2},
		"description": "A small campfire. Good starter landmark."
	},
	"longhouse": {
		"name": "Longhouse",
		"index": 1,
		"recipe": {"Wood": 12, "Iron Ore": 3, "Fur": 2},
		"description": "Core Viking settlement building."
	},
	"watchtower": {
		"name": "Watchtower",
		"index": 2,
		"recipe": {"Wood": 8, "Iron Ore": 2},
		"description": "Marks territory and watches roads."
	},
	"rune_stone": {
		"name": "Rune Stone",
		"index": 3,
		"recipe": {"Stone": 5, "Rune Dust": 2, "Small Gem": 1},
		"description": "A magical Viking landmark."
	},
	"alchemy_hut": {
		"name": "Alchemy Hut",
		"index": 4,
		"recipe": {"Wood": 10, "Mushroom": 3, "Crystal Vial": 1},
		"description": "Potion crafting shelter."
	},
	"palisade": {
		"name": "Palisade",
		"index": 5,
		"recipe": {"Wood": 6, "Iron Ore": 1},
		"description": "Defensive wall marker."
	},
	"dock": {
		"name": "Dock",
		"index": 6,
		"recipe": {"Wood": 10, "Iron Ore": 2},
		"description": "Coastal building for ships and trade."
	},
	"farmstead": {
		"name": "Farmstead",
		"index": 7,
		"recipe": {"Wood": 6, "Herb": 4, "Mushroom": 2},
		"description": "Basic resource settlement."
	},
	"shrine": {
		"name": "Shrine",
		"index": 8,
		"recipe": {"Stone": 6, "Bone Charm": 2, "Rune Dust": 3},
		"description": "A sacred Norse shrine."
	}
}

var player: Node2D
var account_manager: Node
var hud: Node
var structures: Array = []
var texture_cache: Texture2D


func setup(player_node: Node2D, manager: Node = null, hud_node: Node = null) -> void:
	player = player_node
	account_manager = manager
	hud = hud_node
	z_index = 4
	_load_structures()
	_redraw_structures()


func get_structure_types() -> Array[String]:
	var types: Array[String] = []
	for key in STRUCTURE_DATA.keys():
		types.append(str(key))
	return types


func get_structure_data(structure_type: String) -> Dictionary:
	return (STRUCTURE_DATA.get(structure_type, {}) as Dictionary).duplicate(true)


func is_admin_builder() -> bool:
	if account_manager == null:
		return false
	if account_manager.has_method("is_current_account_admin"):
		return bool(account_manager.call("is_current_account_admin"))
	if account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		return bool(account.get("is_admin", false))
	return false


func build_structure(structure_type: String) -> bool:
	if player == null:
		return false
	if not STRUCTURE_DATA.has(structure_type):
		_set_status("Unknown building type.")
		return false

	var data: Dictionary = STRUCTURE_DATA[structure_type] as Dictionary
	var recipe: Dictionary = data.get("recipe", {}) as Dictionary

	var admin_build: bool = is_admin_builder()
	if not admin_build:
		if not player.has_method("has_items") or not bool(player.call("has_items", recipe)):
			_set_status("Not enough materials for %s." % str(data.get("name", structure_type)))
			return false

		if not player.has_method("remove_items") or not bool(player.call("remove_items", recipe)):
			_set_status("Could not remove build materials.")
			return false

	var offset: Vector2 = Vector2(0, 96)
	var facing_vector: Vector2 = player.get("facing") as Vector2
	if facing_vector.length() > 0.0:
		offset = facing_vector.normalized() * 96.0

	var build_position: Vector2 = player.global_position + offset
	var structure: Dictionary = {
		"id": _make_structure_id(structure_type),
		"type": structure_type,
		"name": str(data.get("name", structure_type)),
		"x": build_position.x,
		"y": build_position.y,
		"level": 1,
		"built_at_unix": Time.get_unix_time_from_system()
	}

	structures.append(structure)
	_spawn_structure_node(structure)
	_save_structures()
	structures_changed.emit(structures.duplicate(true))
	if admin_build:
		_set_status("Admin built %s without materials." % str(structure.get("name", "building")))
	else:
		_set_status("Built %s." % str(structure.get("name", "building")))
	return true


func remove_nearest_structure(max_distance: float = 80.0) -> bool:
	if player == null:
		return false
	var closest_index: int = -1
	var closest_distance: float = max_distance
	for i: int in range(structures.size()):
		var structure: Dictionary = structures[i] as Dictionary
		var pos: Vector2 = Vector2(float(structure.get("x", 0.0)), float(structure.get("y", 0.0)))
		var distance: float = player.global_position.distance_to(pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	if closest_index < 0:
		_set_status("No nearby building to remove.")
		return false
	var removed: Dictionary = structures[closest_index] as Dictionary
	structures.remove_at(closest_index)
	_redraw_structures()
	_save_structures()
	structures_changed.emit(structures.duplicate(true))
	_set_status("Removed %s." % str(removed.get("name", "building")))
	return true


func _redraw_structures() -> void:
	for child in get_children():
		child.queue_free()
	for structure in structures:
		if structure is Dictionary:
			_spawn_structure_node(structure as Dictionary)


func _spawn_structure_node(structure: Dictionary) -> void:
	var node: Node2D = Node2D.new()
	node.name = "Structure_%s" % str(structure.get("id", "building"))
	node.position = Vector2(float(structure.get("x", 0.0)), float(structure.get("y", 0.0)))
	node.z_index = 4
	add_child(node)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = _get_structure_texture(str(structure.get("type", "campfire")))
	sprite.centered = true
	sprite.scale = Vector2(1.15, 1.15)
	sprite.z_index = 4
	node.add_child(sprite)

	var label: Label = Label.new()
	label.name = "NameLabel"
	label.text = str(structure.get("name", "Building"))
	label.position = Vector2(-42, -54)
	label.z_index = 9
	node.add_child(label)


func _get_structure_texture(structure_type: String) -> Texture2D:
	if texture_cache == null and ResourceLoader.exists(STRUCTURE_SHEET_PATH):
		texture_cache = load(STRUCTURE_SHEET_PATH) as Texture2D
	if texture_cache == null:
		return null
	var data: Dictionary = STRUCTURE_DATA.get(structure_type, STRUCTURE_DATA["campfire"]) as Dictionary
	var index: int = int(data.get("index", 0))
	var column: int = index % STRUCTURE_COLUMNS
	var row: int = int(index / STRUCTURE_COLUMNS)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture_cache
	atlas.region = Rect2(float(column * STRUCTURE_SIZE), float(row * STRUCTURE_SIZE), float(STRUCTURE_SIZE), float(STRUCTURE_SIZE))
	return atlas


func _save_structures() -> bool:
	_ensure_save_dir()
	var data: Dictionary = {
		"version": 1,
		"account_id": _account_id(),
		"structures": structures,
		"saved_at_unix": Time.get_unix_time_from_system()
	}
	var file: FileAccess = FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("Could not save buildings.")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _load_structures() -> void:
	structures = []
	var path: String = _save_path()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var data: Dictionary = parsed as Dictionary
		var raw: Variant = data.get("structures", [])
		if raw is Array:
			for structure in raw:
				if structure is Dictionary:
					structures.append((structure as Dictionary).duplicate(true))


func _account_id() -> String:
	if account_manager != null and account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		if not account.is_empty():
			return str(account.get("id", "offline"))
	return "offline"


func _save_path() -> String:
	return BUILDINGS_SAVE_DIR + "/" + _account_id() + ".json"


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILDINGS_SAVE_DIR))


func _make_structure_id(structure_type: String) -> String:
	return (structure_type + ":" + str(Time.get_unix_time_from_system()) + ":" + str(randi())).sha256_text().substr(0, 16)


func _set_status(message: String) -> void:
	if hud != null and hud.has_method("set_status"):
		hud.call("set_status", message)
