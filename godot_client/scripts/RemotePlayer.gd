extends Node2D

const VIKING_WALK_PATH: String = "res://art/characters/viking/viking_walk.png"
const SHIELD_MAIDEN_WALK_PATH: String = "res://art/characters/shield_maiden/shield_maiden_walk.png"
const SPRITE_COLUMNS: int = 4
const SPRITE_ROWS: int = 4
const SPRITE_SCALE: Vector2 = Vector2(0.18, 0.18)

var player_id: String = ""
var target_position: Vector2 = Vector2.ZERO
var last_position: Vector2 = Vector2.ZERO
var display_name: String = "Player"
var username: String = ""
var level: int = 1
var character_id: String = "viking"
var loaded_character_id: String = ""
var clan_name: String = ""
var facing_direction: String = "down"
var has_initial_position: bool = false

var animated_sprite: AnimatedSprite2D
var name_label: Label
var clan_label: Label


func _ready() -> void:
	_setup_visuals()


func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, min(1.0, delta * 8.0))
	_update_animation()


func apply_state(state: Dictionary) -> void:
	last_position = target_position
	target_position = Vector2(float(state.get("x", target_position.x)), float(state.get("y", target_position.y)))
	if not has_initial_position:
		global_position = target_position
		has_initial_position = true
	display_name = str(state.get("name", display_name))
	username = str(state.get("username", username))
	level = int(state.get("level", level))
	character_id = str(state.get("characterId", state.get("character_id", character_id)))
	clan_name = str(state.get("clan", clan_name))
	_update_direction(target_position - last_position)
	_apply_character_style()
	_update_labels()


func _setup_visuals() -> void:
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.centered = true
	animated_sprite.position = Vector2(0, -24)
	animated_sprite.scale = SPRITE_SCALE
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.82)
	animated_sprite.z_index = 9
	add_child(animated_sprite)

	var sprite_frames: SpriteFrames = _build_sprite_frames()
	if sprite_frames != null:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("idle_down")
	else:
		_draw_placeholder()

	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.position = Vector2(-42, -72)
	name_label.z_index = 20
	add_child(name_label)

	clan_label = Label.new()
	clan_label.name = "ClanLabel"
	clan_label.position = Vector2(-42, -52)
	clan_label.z_index = 20
	add_child(clan_label)

	_update_labels()
	_apply_character_style()


func _update_labels() -> void:
	if name_label != null:
		name_label.text = "%s  Lv.%d" % [display_name, level]
	if clan_label != null:
		clan_label.text = clan_name
		clan_label.visible = clan_name != ""


func _apply_character_style() -> void:
	if animated_sprite == null:
		return
	if loaded_character_id != character_id:
		var sprite_frames: SpriteFrames = _build_sprite_frames()
		if sprite_frames != null:
			animated_sprite.sprite_frames = sprite_frames
			loaded_character_id = character_id
	match character_id:
		"druid": animated_sprite.modulate = Color(0.82, 1.08, 0.82, 0.82)
		"mage": animated_sprite.modulate = Color(0.82, 0.90, 1.15, 0.82)
		_: animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.82)


func _update_direction(delta_position: Vector2) -> void:
	if delta_position.length() < 1.0:
		return
	if abs(delta_position.x) > abs(delta_position.y):
		if delta_position.x > 0.0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	else:
		if delta_position.y > 0.0:
			facing_direction = "down"
		else:
			facing_direction = "up"


func _update_animation() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var moving: bool = global_position.distance_to(target_position) > 2.0
	var anim_name: String = "walk_" + facing_direction if moving else "idle_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		_play_sprite_animation(anim_name)


func _build_sprite_frames() -> SpriteFrames:
	var walk_path: String = _walk_sprite_path()
	if not ResourceLoader.exists(walk_path):
		return null
	var walk_texture: Texture2D = load(walk_path) as Texture2D
	if walk_texture == null:
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_directional_animations(frames, walk_texture, "idle", 1, true, 1.0)
	_add_directional_animations(frames, walk_texture, "walk", 4, true, 7.0)
	return frames


func _walk_sprite_path() -> String:
	match character_id:
		"shield_maiden": return SHIELD_MAIDEN_WALK_PATH
		_: return VIKING_WALK_PATH


func _add_directional_animations(frames: SpriteFrames, texture: Texture2D, prefix: String, columns_to_use: int, loop: bool, speed: float) -> void:
	var directions: Array[String] = ["down", "left", "right", "up"]
	var frame_width: int = int(floor(float(texture.get_width()) / float(SPRITE_COLUMNS)))
	var frame_height: int = int(floor(float(texture.get_height()) / float(SPRITE_ROWS)))
	for row: int in range(SPRITE_ROWS):
		var anim_name: String = prefix + "_" + directions[row]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, speed)
		for column: int in range(columns_to_use):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(float(column * frame_width), float(row * frame_height), float(frame_width), float(frame_height))
			frames.add_frame(anim_name, atlas)


func _play_sprite_animation(anim_name: String) -> void:
	if animated_sprite.animation == anim_name and animated_sprite.is_playing():
		return
	animated_sprite.play(anim_name)


func _draw_placeholder() -> void:
	var body: ColorRect = ColorRect.new()
	body.name = "PlaceholderBody"
	body.color = Color(0.2, 0.55, 1.0, 0.82)
	body.size = Vector2(28, 34)
	body.position = Vector2(-14, -17)
	body.z_index = 9
	add_child(body)
