extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal xp_changed(current: int, level: int)
signal inventory_changed(items: Array)
signal profile_changed(player_name: String, character_id: String)

const SPEED: float = 180.0
const ATTACK_RANGE: float = 70.0

const VIKING_WALK_PATH: String = "res://art/characters/viking/viking_walk.png"
const VIKING_ATTACK_PATH: String = "res://art/characters/viking/viking_attack.png"

const SPRITE_COLUMNS: int = 4
const SPRITE_ROWS: int = 4
const SPRITE_SCALE: Vector2 = Vector2(0.18, 0.18)

var stats: Dictionary = {
	"name": "Viking",
	"level": 1,
	"xp": 0,
	"hp": 100,
	"max_hp": 100,
	"attack": 12,
	"gold": 0
}

var inventory: Array = []

var facing: Vector2 = Vector2.DOWN
var facing_direction: String = "down"
var is_attacking: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var character_id: String = "viking"

var animated_sprite: AnimatedSprite2D
var name_label: Label


func _ready() -> void:
	_ensure_input_actions()
	_setup_player_visuals()
	health_changed.emit(stats["hp"], stats["max_hp"])
	xp_changed.emit(stats["xp"], stats["level"])


func _physics_process(_delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 0.0:
		facing = input_vector.normalized()
		_update_facing_direction(input_vector)
	velocity = input_vector * SPEED
	move_and_slide()
	_update_animation(input_vector)
	if Input.is_action_just_pressed("attack"):
		attack_nearest_enemy()


func attack_nearest_enemy() -> void:
	if is_attacking:
		return
	_play_attack_animation()
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var closest_distance: float = ATTACK_RANGE
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		var distance: float = global_position.distance_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = enemy_node
	if closest != null and closest.has_method("take_damage"):
		closest.call("take_damage", int(stats["attack"]))


func gain_reward(xp_amount: int, gold_amount: int, item_name: String = "") -> void:
	stats["xp"] += xp_amount
	stats["gold"] += gold_amount
	if item_name != "":
		inventory.append(item_name)
		inventory_changed.emit(inventory)
	while int(stats["xp"]) >= int(stats["level"]) * 100:
		stats["xp"] = int(stats["xp"]) - int(stats["level"]) * 100
		stats["level"] = int(stats["level"]) + 1
		stats["max_hp"] = int(stats["max_hp"]) + 10
		stats["attack"] = int(stats["attack"]) + 2
		stats["hp"] = int(stats["max_hp"])
	xp_changed.emit(int(stats["xp"]), int(stats["level"]))
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))


func apply_account_profile(account: Dictionary) -> void:
	if account.is_empty():
		return
	stats["name"] = str(account.get("player_name", stats.get("name", "Viking")))
	character_id = str(account.get("character_id", character_id))
	if account.has("level"):
		stats["level"] = int(account.get("level", stats.get("level", 1)))
	if account.has("xp"):
		stats["xp"] = int(account.get("xp", stats.get("xp", 0)))
	if account.has("gold"):
		stats["gold"] = int(account.get("gold", stats.get("gold", 0)))
	if account.has("hp"):
		stats["hp"] = int(account.get("hp", stats.get("hp", 100)))
	if account.has("max_hp"):
		stats["max_hp"] = int(account.get("max_hp", stats.get("max_hp", 100)))
	if account.has("attack"):
		stats["attack"] = int(account.get("attack", stats.get("attack", 12)))
	if account.has("inventory") and account.get("inventory") is Array:
		inventory = (account.get("inventory") as Array).duplicate(true)
	_apply_character_style()
	refresh_after_load()


func set_character(new_character_id: String) -> void:
	character_id = new_character_id
	_apply_character_style()
	profile_changed.emit(str(stats.get("name", "Viking")), character_id)


func refresh_after_load() -> void:
	if name_label != null:
		name_label.text = str(stats.get("name", "Viking"))
	_apply_character_style()
	health_changed.emit(int(stats.get("hp", 100)), int(stats.get("max_hp", 100)))
	xp_changed.emit(int(stats.get("xp", 0)), int(stats.get("level", 1)))
	inventory_changed.emit(inventory)
	profile_changed.emit(str(stats.get("name", "Viking")), character_id)


func _apply_character_style() -> void:
	if animated_sprite == null:
		return
	match character_id:
		"shield_maiden": animated_sprite.modulate = Color(1.08, 0.92, 0.98)
		"druid": animated_sprite.modulate = Color(0.82, 1.08, 0.82)
		"mage": animated_sprite.modulate = Color(0.82, 0.90, 1.15)
		_: animated_sprite.modulate = Color.WHITE


func add_item(item_name: String) -> void:
	if item_name == "":
		return
	inventory.append(item_name)
	inventory_changed.emit(inventory)


func add_items(items: Array) -> void:
	for item in items:
		var item_name: String = str(item)
		if item_name != "":
			inventory.append(item_name)
	inventory_changed.emit(inventory)


func get_inventory_counts() -> Dictionary:
	var counts: Dictionary = {}
	for item in inventory:
		var item_name: String = str(item)
		counts[item_name] = int(counts.get(item_name, 0)) + 1
	return counts


func has_items(recipe: Dictionary) -> bool:
	var counts: Dictionary = get_inventory_counts()
	for item_name in recipe.keys():
		if int(counts.get(item_name, 0)) < int(recipe[item_name]):
			return false
	return true


func remove_items(recipe: Dictionary) -> bool:
	if not has_items(recipe):
		return false
	for item_name in recipe.keys():
		var needed: int = int(recipe[item_name])
		var removed: int = 0
		var i: int = inventory.size() - 1
		while i >= 0 and removed < needed:
			if str(inventory[i]) == str(item_name):
				inventory.remove_at(i)
				removed += 1
			i -= 1
	inventory_changed.emit(inventory)
	return true


func use_item(item_name: String) -> bool:
	var index: int = inventory.find(item_name)
	if index < 0:
		return false
	match item_name:
		"Health Potion":
			stats["hp"] = min(int(stats.get("max_hp", 100)), int(stats.get("hp", 100)) + 35)
		"Greater Health Potion":
			stats["hp"] = min(int(stats.get("max_hp", 100)), int(stats.get("hp", 100)) + 75)
		_:
			return false
	inventory.remove_at(index)
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))
	inventory_changed.emit(inventory)
	return true


func take_damage(amount: int) -> void:
	stats["hp"] = max(0, int(stats["hp"]) - amount)
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))
	if int(stats["hp"]) <= 0:
		respawn()


func respawn() -> void:
	if spawn_position != Vector2.ZERO:
		global_position = spawn_position
	else:
		global_position = Vector2(640, 360)
	stats["hp"] = int(stats["max_hp"])
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))


func _setup_player_visuals() -> void:
	_setup_collision()
	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
	animated_sprite.centered = true
	animated_sprite.position = Vector2(0, -24)
	animated_sprite.scale = SPRITE_SCALE
	animated_sprite.z_index = 10
	var sprite_frames: SpriteFrames = _build_viking_sprite_frames()
	if sprite_frames != null:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("idle_down")
	else:
		_draw_placeholder()
	_setup_name_label()
	_apply_character_style()


func _setup_collision() -> void:
	if get_node_or_null("CollisionShape2D") != null:
		return
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 16.0
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	collision.position = Vector2(0, 8)
	add_child(collision)


func _setup_name_label() -> void:
	name_label = get_node_or_null("NameLabel") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "NameLabel"
		add_child(name_label)
	name_label.text = str(stats["name"])
	name_label.position = Vector2(-30, -68)
	name_label.z_index = 20


func _build_viking_sprite_frames() -> SpriteFrames:
	if not ResourceLoader.exists(VIKING_WALK_PATH):
		return null
	if not ResourceLoader.exists(VIKING_ATTACK_PATH):
		return null
	var walk_texture: Texture2D = load(VIKING_WALK_PATH) as Texture2D
	var attack_texture: Texture2D = load(VIKING_ATTACK_PATH) as Texture2D
	if walk_texture == null or attack_texture == null:
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_directional_animations(frames, walk_texture, "idle", 1, true, 1.0)
	_add_directional_animations(frames, walk_texture, "walk", 4, true, 7.0)
	_add_directional_animations(frames, attack_texture, "attack", 4, false, 10.0)
	return frames


func _add_directional_animations(frames: SpriteFrames, texture: Texture2D, prefix: String, columns_to_use: int, loop: bool, speed: float) -> void:
	var directions: Array[String] = ["down", "left", "right", "up"]
	var frame_width: int = int(texture.get_width() / SPRITE_COLUMNS)
	var frame_height: int = int(texture.get_height() / SPRITE_ROWS)
	for row: int in range(SPRITE_ROWS):
		var anim_name: String = prefix + "_" + directions[row]
		if frames.has_animation(anim_name):
			frames.remove_animation(anim_name)
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, speed)
		for column: int in range(columns_to_use):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(float(column * frame_width), float(row * frame_height), float(frame_width), float(frame_height))
			frames.add_frame(anim_name, atlas)


func _update_facing_direction(input_vector: Vector2) -> void:
	if abs(input_vector.x) > abs(input_vector.y):
		if input_vector.x > 0.0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	else:
		if input_vector.y > 0.0:
			facing_direction = "down"
		else:
			facing_direction = "up"


func _update_animation(input_vector: Vector2) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if is_attacking:
		return
	var anim_name: String = ""
	if input_vector.length() > 0.0:
		anim_name = "walk_" + facing_direction
	else:
		anim_name = "idle_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func _play_attack_animation() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var anim_name: String = "attack_" + facing_direction
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		return
	is_attacking = true
	animated_sprite.play(anim_name)
	await animated_sprite.animation_finished
	is_attacking = false


func _draw_placeholder() -> void:
	var body: ColorRect = ColorRect.new()
	body.name = "PlaceholderBody"
	body.color = Color(0.2, 0.8, 0.4)
	body.size = Vector2(28, 34)
	body.position = Vector2(-14, -17)
	add_child(body)


func _ensure_input_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("attack", [KEY_SPACE])
	_add_key_action("interact", [KEY_E])


func _add_key_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key in keys:
		var exists: bool = false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				var key_event: InputEventKey = event as InputEventKey
				if key_event.keycode == key:
					exists = true
		if not exists:
			var new_event: InputEventKey = InputEventKey.new()
			new_event.keycode = key
			InputMap.action_add_event(action_name, new_event)
