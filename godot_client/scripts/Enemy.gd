extends Area2D

signal defeated(enemy: Node)

const ENEMY_SHEET_PATH: String = "res://art/enemies/enemies.png"
const ITEM_DROP_SCENE_PATH: String = "res://scenes/ItemDrop.tscn"
const FRAME_SIZE: int = 64
const FRAME_COLUMNS: int = 4
const DIRECTION_ROWS: int = 4

const ENEMY_ROW_OFFSETS: Dictionary = {
	"Wild Wisp": 0,
	"Forest Imp": 4,
	"Stone Boar": 8
}

var enemy_name: String = "Wild Wisp"
var hp: int = 30
var attack: int = 5
var xp_reward: int = 20
var gold_reward: int = 3
var loot_table: Array[String] = ["Herb", "Small Gem", "Bone Charm", ""]
var target: Node2D
var move_speed: float = 42.0
var facing_direction: String = "down"

var animated_sprite: AnimatedSprite2D
var name_label: Label
var item_drop_scene: PackedScene = preload("res://scenes/ItemDrop.tscn")


func _ready() -> void:
	add_to_group("enemies")
	_setup_enemy_visuals()


func init(spawn_name: String, spawn_hp: int, spawn_attack: int, xp: int, gold: int, player: Node2D) -> void:
	enemy_name = spawn_name
	hp = spawn_hp
	attack = spawn_attack
	xp_reward = xp
	gold_reward = gold
	target = player

	match enemy_name:
		"Wild Wisp":
			move_speed = 55.0
			loot_table = ["Herb", "Small Gem", "Rune Dust", "Crystal Vial", "", ""]
		"Forest Imp":
			move_speed = 48.0
			loot_table = ["Herb", "Wood", "Mushroom", "Fur", "Stone", "Crystal Vial"]
		"Stone Boar":
			move_speed = 38.0
			loot_table = ["Bone Charm", "Iron Ore", "Small Gem", "Stone", "Rune Dust", "Crystal Vial"]
		_:
			move_speed = 42.0
			loot_table = ["Herb", "Small Gem", "Bone Charm", "Stone", "Wood", ""]

	_setup_enemy_visuals()


func _process(delta: float) -> void:
	if target == null:
		_play_idle()
		return

	var to_player: Vector2 = target.global_position - global_position
	var distance: float = to_player.length()

	if distance < 240.0 and distance > 32.0:
		_update_facing_direction(to_player)
		global_position += to_player.normalized() * move_speed * delta
		_play_walk()
	elif distance <= 32.0:
		_update_facing_direction(to_player)
		_play_idle()
		if randi() % 45 == 0 and target.has_method("take_damage"):
			target.call("take_damage", attack)
	else:
		_play_idle()


func take_damage(amount: int) -> void:
	hp -= amount

	if hp <= 0:
		var loot: String = loot_table.pick_random()

		if target != null and target.has_method("gain_reward"):
			target.call("gain_reward", xp_reward, gold_reward, "")

		if loot != "":
			_spawn_item_drop(loot)

		defeated.emit(self)
		queue_free()


func _setup_enemy_visuals() -> void:
	_setup_collision()

	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)

	animated_sprite.centered = true
	animated_sprite.position = Vector2(0, -6)
	animated_sprite.z_index = 8
	animated_sprite.sprite_frames = _build_enemy_sprite_frames()
	animated_sprite.play("idle_down")

	name_label = get_node_or_null("NameLabel") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "NameLabel"
		add_child(name_label)

	name_label.text = enemy_name
	name_label.position = Vector2(-36, -48)
	name_label.z_index = 12


func _setup_collision() -> void:
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape


func _build_enemy_sprite_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()

	if frames.has_animation("default"):
		frames.remove_animation("default")

	if not ResourceLoader.exists(ENEMY_SHEET_PATH):
		return frames

	var texture: Texture2D = load(ENEMY_SHEET_PATH) as Texture2D
	if texture == null:
		return frames

	var directions: Array[String] = ["down", "left", "right", "up"]
	var row_offset: int = int(ENEMY_ROW_OFFSETS.get(enemy_name, 0))

	for row: int in range(DIRECTION_ROWS):
		var idle_name: String = "idle_" + directions[row]
		var walk_name: String = "walk_" + directions[row]

		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 1.0)

		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, 6.0)

		for column: int in range(FRAME_COLUMNS):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				float(column * FRAME_SIZE),
				float((row_offset + row) * FRAME_SIZE),
				float(FRAME_SIZE),
				float(FRAME_SIZE)
			)

			if column == 0:
				frames.add_frame(idle_name, atlas)

			frames.add_frame(walk_name, atlas)

	return frames


func _update_facing_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	else:
		if direction.y > 0.0:
			facing_direction = "down"
		else:
			facing_direction = "up"


func _play_idle() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var anim_name: String = "idle_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func _play_walk() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var anim_name: String = "walk_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func _spawn_item_drop(item_name: String) -> void:
	var drop: Node = item_drop_scene.instantiate()

	if drop is Node2D:
		var drop_node: Node2D = drop as Node2D
		drop_node.global_position = global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))

	if drop.has_method("init"):
		drop.call("init", item_name, target)

	get_tree().current_scene.call_deferred("add_child", drop)
