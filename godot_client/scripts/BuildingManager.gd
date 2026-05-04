extends Node2D

signal structures_changed(structures: Array)

const BUILDINGS_SAVE_DIR: String = "user://buildings"
const STRUCTURE_SHEET_PATH: String = "res://art/buildings/buildings_v2.png"
const STRUCTURE_SIZE: int = 128
const STRUCTURE_COLUMNS: int = 4
const USE_DISTANCE: float = 120.0
const NEARBY_ENEMY_DISTANCE: float = 190.0

const STRUCTURE_DATA: Dictionary = {
	"campfire": {
		"name": "Campfire",
		"index": 0,
		"recipe": {"Wood": 3, "Stone": 2},
		"description": "Rest near it to recover 25 HP.",
		"use": "Rest",
		"cooldown": 25.0
	},
	"longhouse": {
		"name": "Longhouse",
		"index": 1,
		"recipe": {"Wood": 12, "Iron Ore": 3, "Fur": 2},
		"description": "Sets your respawn point and fully restores HP.",
		"use": "Set Home",
		"cooldown": 60.0
	},
	"watchtower": {
		"name": "Watchtower",
		"index": 2,
		"recipe": {"Wood": 8, "Iron Ore": 2},
		"description": "Scouts nearby enemies and briefly marks them.",
		"use": "Scout",
		"cooldown": 35.0
	},
	"rune_stone": {
		"name": "Rune Stone",
		"index": 3,
		"recipe": {"Stone": 5, "Rune Dust": 2, "Small Gem": 1},
		"description": "Channels runes for bonus XP.",
		"use": "Channel",
		"cooldown": 90.0
	},
	"alchemy_hut": {
		"name": "Alchemy Hut",
		"index": 4,
		"recipe": {"Wood": 10, "Mushroom": 3, "Crystal Vial": 1},
		"description": "Brews a Health Potion if you bring Herb and Mushroom.",
		"use": "Brew",
		"cooldown": 45.0
	},
	"palisade": {
		"name": "Palisade",
		"index": 5,
		"recipe": {"Wood": 6, "Iron Ore": 1},
		"description": "Drives back nearby enemies and hurts them.",
		"use": "Defend",
		"cooldown": 30.0
	},
	"dock": {
		"name": "Dock",
		"index": 6,
		"recipe": {"Wood": 10, "Iron Ore": 2},
		"description": "Collects trade income.",
		"use": "Trade",
		"cooldown": 90.0
	},
	"farmstead": {
		"name": "Farmstead",
		"index": 7,
		"recipe": {"Wood": 6, "Herb": 4, "Mushroom": 2},
		"description": "Harvests herbs, mushrooms, and wood.",
		"use": "Harvest",
		"cooldown": 75.0
	},
	"shrine": {
		"name": "Shrine",
		"index": 8,
		"recipe": {"Stone": 6, "Bone Charm": 2, "Rune Dust": 3},
		"description": "Blesses you with healing and XP.",
		"use": "Bless",
		"cooldown": 120.0
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


func use_nearest_structure(max_distance: float = USE_DISTANCE) -> bool:
	if player == null:
		return false
	var nearest: Dictionary = _nearest_structure(max_distance)
	if nearest.is_empty():
		_set_status("No nearby building to use.")
		return false
	return use_structure(str(nearest.get("id", "")))


func use_structure(structure_id: String) -> bool:
	var index: int = _structure_index_by_id(structure_id)
	if index < 0:
		_set_status("Building not found.")
		return false

	var structure: Dictionary = structures[index] as Dictionary
	var structure_type: String = str(structure.get("type", "campfire"))
	var data: Dictionary = STRUCTURE_DATA.get(structure_type, STRUCTURE_DATA["campfire"]) as Dictionary
	var now: float = Time.get_unix_time_from_system()
	var ready_at: float = float(structure.get("ready_at_unix", 0.0))
	if ready_at > now:
		_set_status("%s ready in %ds." % [str(data.get("name", "Building")), int(ceil(ready_at - now))])
		return false

	var used: bool = false
	match structure_type:
		"campfire":
			used = _heal_player(25)
		"longhouse":
			used = _use_longhouse(structure)
		"watchtower":
			used = _use_watchtower(structure)
		"rune_stone":
			used = _grant_reward(18, 0)
		"alchemy_hut":
			used = _use_alchemy_hut()
		"palisade":
			used = _use_palisade(structure)
		"dock":
			used = _grant_reward(0, 8)
		"farmstead":
			used = _use_farmstead()
		"shrine":
			used = _use_shrine()
		_:
			_set_status("%s has no use yet." % str(data.get("name", "Building")))

	if not used:
		return false

	structure["ready_at_unix"] = now + float(data.get("cooldown", 30.0))
	structures[index] = structure
	_redraw_structures()
	_save_structures()
	structures_changed.emit(structures.duplicate(true))
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

	var type_name: String = str(structure.get("type", "campfire"))
	var data: Dictionary = STRUCTURE_DATA.get(type_name, STRUCTURE_DATA["campfire"]) as Dictionary
	var accent: Color = _structure_accent(type_name)

	var shadow: Polygon2D = Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(-42, 14),
		Vector2(-22, 2),
		Vector2(28, 2),
		Vector2(48, 14),
		Vector2(24, 27),
		Vector2(-30, 27)
	])
	shadow.color = Color(0.0, 0.0, 0.0, 0.34)
	shadow.z_index = 1
	node.add_child(shadow)

	var base: Polygon2D = Polygon2D.new()
	base.name = "BasePlate"
	base.polygon = PackedVector2Array([
		Vector2(-38, 10),
		Vector2(-18, -2),
		Vector2(25, -2),
		Vector2(43, 10),
		Vector2(20, 22),
		Vector2(-27, 22)
	])
	base.color = Color(0.18, 0.15, 0.11, 0.72)
	base.z_index = 2
	node.add_child(base)

	var ring: Line2D = Line2D.new()
	ring.name = "UseRing"
	ring.width = 2.0
	ring.default_color = accent
	ring.modulate.a = 0.42
	ring.z_index = 3
	for i in range(25):
		var angle: float = TAU * float(i) / 24.0
		ring.add_point(Vector2(cos(angle) * 44.0, sin(angle) * 19.0 + 9.0))
	node.add_child(ring)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = _get_structure_texture(type_name)
	sprite.centered = true
	sprite.position = Vector2(0, -11)
	sprite.scale = Vector2(0.72, 0.72)
	sprite.z_index = 5
	node.add_child(sprite)

	_add_structure_details(node, type_name, accent)

	var label: Label = Label.new()
	label.name = "NameLabel"
	label.text = str(structure.get("name", "Building"))
	label.position = Vector2(-54, -72)
	label.size = Vector2(108, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 9
	node.add_child(label)

	var use_label: Label = Label.new()
	use_label.name = "UseLabel"
	use_label.text = "E: %s" % str(data.get("use", "Use"))
	use_label.position = Vector2(-46, 33)
	use_label.size = Vector2(92, 18)
	use_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	use_label.add_theme_font_size_override("font_size", 11)
	use_label.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	use_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	use_label.add_theme_constant_override("shadow_offset_x", 1)
	use_label.add_theme_constant_override("shadow_offset_y", 1)
	use_label.z_index = 9
	node.add_child(use_label)


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


func _nearest_structure(max_distance: float) -> Dictionary:
	var closest: Dictionary = {}
	var closest_distance: float = max_distance
	for structure in structures:
		if not structure is Dictionary:
			continue
		var structure_dict: Dictionary = structure as Dictionary
		var pos: Vector2 = Vector2(float(structure_dict.get("x", 0.0)), float(structure_dict.get("y", 0.0)))
		var distance: float = player.global_position.distance_to(pos)
		if distance <= closest_distance:
			closest_distance = distance
			closest = structure_dict
	return closest


func _structure_index_by_id(structure_id: String) -> int:
	for i in range(structures.size()):
		var structure: Dictionary = structures[i] as Dictionary
		if str(structure.get("id", "")) == structure_id:
			return i
	return -1


func _heal_player(amount: int) -> bool:
	if player == null:
		return false
	var current: int = int(player.stats.get("hp", 0))
	var maximum: int = int(player.stats.get("max_hp", 1))
	if current >= maximum:
		_set_status("You are already at full HP.")
		return false
	player.stats["hp"] = min(maximum, current + amount)
	if player.has_signal("health_changed"):
		player.health_changed.emit(int(player.stats["hp"]), maximum)
	_set_status("Restored %d HP." % min(amount, maximum - current))
	return true


func _grant_reward(xp: int, gold: int) -> bool:
	if player == null or not player.has_method("gain_reward"):
		return false
	player.call("gain_reward", xp, gold, "")
	if xp > 0 and gold > 0:
		_set_status("Gained %d XP and %d gold." % [xp, gold])
	elif xp > 0:
		_set_status("Gained %d XP." % xp)
	else:
		_set_status("Collected %d gold." % gold)
	return true


func _use_longhouse(structure: Dictionary) -> bool:
	if player == null:
		return false
	player.set("spawn_position", Vector2(float(structure.get("x", 0.0)), float(structure.get("y", 0.0))))
	var maximum: int = int(player.stats.get("max_hp", 1))
	player.stats["hp"] = maximum
	if player.has_signal("health_changed"):
		player.health_changed.emit(maximum, maximum)
	_set_status("Home set. HP restored.")
	return true


func _use_watchtower(structure: Dictionary) -> bool:
	var origin: Vector2 = Vector2(float(structure.get("x", 0.0)), float(structure.get("y", 0.0)))
	var marked: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node.global_position.distance_to(origin) > NEARBY_ENEMY_DISTANCE:
			continue
		marked += 1
		_mark_enemy(enemy_node)
	_set_status("Watchtower spotted %d nearby enemies." % marked)
	return true


func _use_alchemy_hut() -> bool:
	var recipe: Dictionary = {"Herb": 1, "Mushroom": 1}
	if player == null or not player.has_method("has_items") or not player.has_method("remove_items") or not player.has_method("add_item"):
		return false
	if not bool(player.call("has_items", recipe)):
		_set_status("Alchemy Hut needs Herb x1 and Mushroom x1.")
		return false
	if not bool(player.call("remove_items", recipe)):
		return false
	player.call("add_item", "Health Potion")
	_set_status("Brewed a Health Potion.")
	return true


func _use_palisade(structure: Dictionary) -> bool:
	var origin: Vector2 = Vector2(float(structure.get("x", 0.0)), float(structure.get("y", 0.0)))
	var hit: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		var distance: float = enemy_node.global_position.distance_to(origin)
		if distance > NEARBY_ENEMY_DISTANCE:
			continue
		hit += 1
		if enemy_node.has_method("take_damage"):
			enemy_node.call("take_damage", 8)
		var push: Vector2 = (enemy_node.global_position - origin).normalized()
		if push == Vector2.ZERO:
			push = Vector2.RIGHT
		enemy_node.global_position += push * 36.0
	_set_status("Palisade drove back %d enemies." % hit)
	return true


func _use_farmstead() -> bool:
	if player == null or not player.has_method("add_items"):
		return false
	player.call("add_items", ["Herb", "Herb", "Mushroom", "Wood"])
	_set_status("Harvested Herb x2, Mushroom x1, Wood x1.")
	return true


func _use_shrine() -> bool:
	_heal_player(15)
	if player != null and player.has_method("gain_reward"):
		player.call("gain_reward", 10, 0, "")
	_set_status("Shrine blessing restored HP and granted 10 XP.")
	return true


func _mark_enemy(enemy: Node2D) -> void:
	enemy.modulate = Color(1.0, 0.92, 0.42)
	var tween: Tween = enemy.create_tween()
	tween.tween_property(enemy, "modulate", Color.WHITE, 4.0)


func _structure_accent(structure_type: String) -> Color:
	match structure_type:
		"campfire": return Color(1.0, 0.40, 0.12, 0.95)
		"longhouse": return Color(0.78, 0.46, 0.22, 0.90)
		"watchtower": return Color(0.96, 0.80, 0.45, 0.90)
		"rune_stone": return Color(0.52, 0.38, 1.0, 0.92)
		"alchemy_hut": return Color(0.28, 0.92, 0.60, 0.88)
		"palisade": return Color(0.68, 0.42, 0.20, 0.86)
		"dock": return Color(0.22, 0.62, 1.0, 0.86)
		"farmstead": return Color(0.58, 0.88, 0.28, 0.86)
		"shrine": return Color(0.76, 0.58, 1.0, 0.90)
		_: return Color(0.95, 0.78, 0.36, 0.86)


func _add_structure_details(node: Node2D, structure_type: String, accent: Color) -> void:
	if structure_type == "campfire":
		_add_glow(node, Vector2(0, -22), 18.0, accent)
	elif structure_type == "rune_stone" or structure_type == "shrine":
		_add_glow(node, Vector2(0, -26), 24.0, accent)
	elif structure_type == "watchtower":
		_add_flag(node, Vector2(10, -46), accent)
	elif structure_type == "dock":
		_add_water_line(node)
	elif structure_type == "farmstead":
		_add_crop_rows(node)
	elif structure_type == "palisade":
		_add_spikes(node)
	elif structure_type == "alchemy_hut":
		_add_glow(node, Vector2(-10, -12), 16.0, accent)


func _add_glow(node: Node2D, center: Vector2, radius: float, color: Color) -> void:
	var glow: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(18):
		var angle: float = TAU * float(i) / 18.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	glow.polygon = points
	glow.color = Color(color.r, color.g, color.b, 0.20)
	glow.z_index = 4
	node.add_child(glow)


func _add_flag(node: Node2D, position: Vector2, color: Color) -> void:
	var pole: Line2D = Line2D.new()
	pole.width = 2.0
	pole.default_color = Color(0.22, 0.14, 0.07)
	pole.add_point(position)
	pole.add_point(position + Vector2(0, 28))
	pole.z_index = 7
	node.add_child(pole)

	var flag: Polygon2D = Polygon2D.new()
	flag.polygon = PackedVector2Array([position, position + Vector2(18, 5), position + Vector2(0, 12)])
	flag.color = color
	flag.z_index = 8
	node.add_child(flag)


func _add_water_line(node: Node2D) -> void:
	for i in range(3):
		var line: Line2D = Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.28, 0.58, 0.86, 0.62)
		line.add_point(Vector2(-30, 18 + i * 5))
		line.add_point(Vector2(32, 15 + i * 5))
		line.z_index = 4
		node.add_child(line)


func _add_crop_rows(node: Node2D) -> void:
	for i in range(3):
		var row: Line2D = Line2D.new()
		row.width = 3.0
		row.default_color = Color(0.34, 0.58, 0.18, 0.88)
		row.add_point(Vector2(-32 + i * 14, 14))
		row.add_point(Vector2(-18 + i * 14, 25))
		row.z_index = 4
		node.add_child(row)


func _add_spikes(node: Node2D) -> void:
	for i in range(4):
		var spike: Polygon2D = Polygon2D.new()
		var x: float = -27.0 + i * 18.0
		spike.polygon = PackedVector2Array([Vector2(x, -7), Vector2(x + 8, -25), Vector2(x + 16, -7)])
		spike.color = Color(0.50, 0.30, 0.14, 0.92)
		spike.z_index = 4
		node.add_child(spike)
