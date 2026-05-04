extends Area2D

signal defeated(enemy: Node)

const Balance = preload("res://scripts/Balance.gd")
const DungeonConfig = preload("res://scripts/DungeonConfig.gd")
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

const ENEMY_TEXTURE_PATHS: Dictionary = {
	"Wild Wisp": "res://art/enemies/generated/wild_wisp.png",
	"Forest Imp": "res://art/enemies/generated/forest_imp.png",
	"Stone Boar": "res://art/enemies/generated/stone_boar.png",
	"Draugr Warrior": "res://art/enemies/generated/draugr_warrior.png",
	"Frost Troll": "res://art/enemies/generated/frost_troll.png",
	"Rune Golem": "res://art/enemies/generated/rune_golem.png"
}

const ENEMY_VISUAL_SCALES: Dictionary = {
	"Wild Wisp": 0.34,
	"Forest Imp": 0.32,
	"Stone Boar": 0.35,
	"Draugr Warrior": 0.34,
	"Frost Troll": 0.42,
	"Rune Golem": 0.40
}

var enemy_name: String = "Wild Wisp"
var display_name: String = ""
var hp: int = 30
var max_hp: int = 30
var attack: int = 5
var xp_reward: int = 20
var gold_reward: int = 3
var loot_table: Array[String] = ["Herb", "Small Gem", "Bone Charm", ""]
var target: Node2D
var move_speed: float = 42.0
var chase_range: float = 240.0
var attack_range: float = 32.0
var preferred_range: float = 28.0
var attack_cooldown: float = 1.25
var attack_timer: float = 0.0
var is_attacking: bool = false
var combat_paused: bool = false
var facing_direction: String = "down"

var animated_sprite: AnimatedSprite2D
var name_label: Label
var health_bar: ProgressBar
var item_drop_scene: PackedScene = preload("res://scenes/ItemDrop.tscn")


func _ready() -> void:
	add_to_group("enemies")
	_setup_enemy_visuals()


func init(spawn_name: String, player: Node2D) -> void:
	enemy_name = spawn_name
	display_name = ""
	target = player

	var data: Dictionary = Balance.enemy_data(enemy_name)
	hp = int(data.get("hp", hp))
	max_hp = hp
	attack = int(data.get("attack", attack))
	xp_reward = int(data.get("xp", xp_reward))
	gold_reward = int(data.get("gold", gold_reward))
	move_speed = float(data.get("move_speed", move_speed))
	chase_range = float(data.get("chase_range", chase_range))
	attack_range = float(data.get("attack_range", attack_range))
	preferred_range = float(data.get("preferred_range", preferred_range))
	attack_cooldown = float(data.get("attack_cooldown", attack_cooldown))
	var raw_loot: Variant = data.get("loot", loot_table)
	if raw_loot is Array:
		loot_table.clear()
		for item in raw_loot:
			loot_table.append(str(item))

	_setup_enemy_visuals()


func _process(delta: float) -> void:
	if combat_paused:
		_play_idle()
		return
	if target == null:
		_play_idle()
		return
	if attack_timer > 0.0:
		attack_timer = max(0.0, attack_timer - delta)

	var to_player: Vector2 = target.global_position - global_position
	var distance: float = to_player.length()

	if is_attacking:
		_play_idle()
	elif distance < chase_range and distance > preferred_range:
		_update_facing_direction(to_player)
		global_position += to_player.normalized() * move_speed * delta
		_play_walk()
	elif distance <= attack_range:
		_update_facing_direction(to_player)
		_play_idle()
		if attack_timer <= 0.0:
			_attack_target()
	else:
		_play_idle()


func take_damage(amount: int) -> void:
	var damage: int = max(0, amount)
	if damage <= 0:
		return
	_show_floating_text("-%d" % damage, Color(1.0, 0.72, 0.28))
	_flash_hit()
	hp -= damage
	_update_health_bar()

	if hp <= 0:
		var target_level: int = 1
		var target_character: String = "viking"
		if target != null:
			if target.get("stats") is Dictionary:
				target_level = int((target.get("stats") as Dictionary).get("level", 1))
			target_character = str(target.get("character_id"))
		var is_dungeon_boss: bool = bool(get_meta("dungeon_boss", false))
		var loot: String = _roll_loot(target_level, target_character)

		if not is_dungeon_boss and target != null and target.has_method("gain_reward"):
			target.call("gain_reward", xp_reward, gold_reward, "")
			_show_floating_text("+%d XP  +%d gold" % [xp_reward, gold_reward], Color(0.84, 1.0, 0.52), Vector2(0, -72))

		if not is_dungeon_boss and loot != "":
			_spawn_item_drop(loot)

		defeated.emit(self)
		queue_free()


func apply_dungeon_scaling(required_level: int, is_boss: bool = false) -> void:
	var tier: int = max(DungeonConfig.MIN_DUNGEON_LEVEL, required_level)
	var level_factor: float = max(1.0, float(tier) / 10.0)
	var health_multiplier: float = DungeonConfig.DUNGEON_ENEMY_HEALTH_MULTIPLIER
	var attack_multiplier: float = DungeonConfig.DUNGEON_ENEMY_ATTACK_MULTIPLIER
	var xp_multiplier: float = DungeonConfig.DUNGEON_ENEMY_XP_MULTIPLIER
	var gold_multiplier: float = DungeonConfig.DUNGEON_ENEMY_GOLD_MULTIPLIER
	if is_boss:
		health_multiplier *= DungeonConfig.BOSS_HEALTH_MULTIPLIER
		attack_multiplier *= DungeonConfig.BOSS_ATTACK_MULTIPLIER
		xp_multiplier *= DungeonConfig.BOSS_XP_MULTIPLIER
		gold_multiplier *= DungeonConfig.BOSS_GOLD_MULTIPLIER
		set_meta("dungeon_boss", true)
		display_name = "Dungeon Boss"
		scale = Vector2(1.35, 1.35)
	else:
		display_name = "Dungeon %s" % enemy_name
	hp = int(round((float(hp) + level_factor * 18.0) * health_multiplier))
	max_hp = hp
	attack = int(round((float(attack) + level_factor * 2.0) * attack_multiplier))
	xp_reward = int(round(float(xp_reward + tier * 3) * xp_multiplier))
	gold_reward = int(round(float(gold_reward + tier) * gold_multiplier))
	chase_range += 30.0
	attack_range += 4.0
	preferred_range += 4.0
	_setup_enemy_visuals()


func _roll_loot(target_level: int, target_character: String) -> String:
	if bool(get_meta("dungeon_enemy", false)) and not bool(get_meta("dungeon_boss", false)):
		if randf() <= DungeonConfig.DUNGEON_ENEMY_BONUS_GEAR_CHANCE:
			var gear: String = Balance.random_gear_for_level(max(target_level, DungeonConfig.MIN_DUNGEON_LEVEL), target_character)
			if gear != "":
				return gear
	return Balance.random_enemy_loot(enemy_name, target_level, target_character)


func _attack_target() -> void:
	if target == null or is_attacking or combat_paused:
		return
	is_attacking = true
	attack_timer = attack_cooldown
	var start_position: Vector2 = global_position
	var to_player: Vector2 = target.global_position - global_position
	var attack_direction: Vector2 = to_player.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.DOWN

	_warn_attack()
	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(self) or target == null or combat_paused:
		is_attacking = false
		return

	var current_to_player: Vector2 = target.global_position - global_position
	if current_to_player.length() > attack_range + 12.0:
		is_attacking = false
		return

	var lunge_position: Vector2 = start_position + attack_direction * _lunge_distance()
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", lunge_position, 0.08)
	tween.tween_property(self, "global_position", start_position, 0.12)

	if not combat_paused and target != null and global_position.distance_to(target.global_position) <= attack_range + 8.0 and target.has_method("take_damage"):
		target.call("take_damage", attack)

	await get_tree().create_timer(0.16).timeout
	if is_instance_valid(self):
		is_attacking = false


func set_combat_paused(paused: bool) -> void:
	combat_paused = paused
	set_process(not paused)
	if paused:
		is_attacking = false
		_play_idle()


func _warn_attack() -> void:
	if animated_sprite == null:
		return
	animated_sprite.modulate = Color(1.0, 0.78, 0.34)
	var tween: Tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.18)


func _lunge_distance() -> float:
	return float(Balance.enemy_data(enemy_name).get("lunge_distance", 10.0))


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
	animated_sprite.scale = Vector2.ONE * _visual_scale()
	animated_sprite.sprite_frames = _build_enemy_sprite_frames()
	animated_sprite.play("idle_down")

	name_label = get_node_or_null("NameLabel") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "NameLabel"
		add_child(name_label)

	name_label.text = display_name if display_name != "" else enemy_name
	name_label.position = Vector2(-36, -48)
	name_label.z_index = 12

	health_bar = get_node_or_null("HealthBar") as ProgressBar
	if health_bar == null:
		health_bar = ProgressBar.new()
		health_bar.name = "HealthBar"
		add_child(health_bar)
	health_bar.position = Vector2(-30, -30)
	health_bar.size = Vector2(60, 7)
	health_bar.show_percentage = false
	health_bar.z_index = 14
	health_bar.add_theme_stylebox_override("background", _bar_style(Color(0.08, 0.05, 0.04, 0.88), 3))
	health_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.76, 0.14, 0.10, 0.96), 3))
	_update_health_bar()


func _setup_collision() -> void:
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape


func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = max(1, max_hp)
	health_bar.value = clamp(hp, 0, max_hp)
	health_bar.visible = hp < max_hp


func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _flash_hit() -> void:
	if animated_sprite == null:
		return
	animated_sprite.modulate = Color(1.0, 0.42, 0.32)
	var tween: Tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.16)


func _show_floating_text(text: String, color: Color, offset: Vector2 = Vector2(0, -46)) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var label: Label = Label.new()
	label.text = text
	label.global_position = global_position + offset
	label.z_index = 100
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(label)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -28), 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.18)
	tween.finished.connect(label.queue_free)


func _build_enemy_sprite_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()

	if frames.has_animation("default"):
		frames.remove_animation("default")

	var generated_frames: SpriteFrames = _build_generated_enemy_frames()
	if generated_frames != null:
		return generated_frames

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


func _build_generated_enemy_frames() -> SpriteFrames:
	var texture_path: String = str(ENEMY_TEXTURE_PATHS.get(enemy_name, ""))
	if texture_path == "":
		return null
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		push_warning("Enemy texture could not load for %s: %s" % [enemy_name, texture_path])
		return null

	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var directions: Array[String] = ["down", "left", "right", "up"]
	for direction in directions:
		var idle_name: String = "idle_" + direction
		var walk_name: String = "walk_" + direction
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 1.0)
		frames.add_frame(idle_name, texture)

		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, 4.0)
		frames.add_frame(walk_name, texture)
		frames.add_frame(walk_name, texture)

	return frames


func _visual_scale() -> float:
	if ENEMY_TEXTURE_PATHS.has(enemy_name):
		return float(ENEMY_VISUAL_SCALES.get(enemy_name, 0.35))
	return 1.0


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
		_play_sprite_animation(anim_name)


func _play_walk() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var anim_name: String = "walk_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		_play_sprite_animation(anim_name)


func _play_sprite_animation(anim_name: String) -> void:
	if animated_sprite.animation == anim_name and animated_sprite.is_playing():
		return
	animated_sprite.play(anim_name)


func _spawn_item_drop(item_name: String) -> void:
	var drop: Node = item_drop_scene.instantiate()
	if bool(get_meta("dungeon_enemy", false)):
		drop.set_meta("dungeon_drop", true)

	if drop is Node2D:
		var drop_node: Node2D = drop as Node2D
		drop_node.global_position = global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))

	if drop.has_method("init"):
		drop.call("init", item_name, target)

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.call_deferred("add_child", drop)
