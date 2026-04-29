extends Node

# Attach this to an AnimatedSprite2D when you have a CapCut-exported sprite sheet.
# Expected layout: equal-sized frames in rows and columns.

@export var sprite_sheet: Texture2D
@export var frame_width := 64
@export var frame_height := 64
@export var columns := 4
@export var rows := 4
@export var animation_name := "walk_down"
@export var fps := 8.0

func build_animation(animated_sprite: AnimatedSprite2D) -> void:
	if sprite_sheet == null:
		push_warning("No sprite sheet assigned.")
		return
	var frames := SpriteFrames.new()
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, true)
	for y in rows:
		for x in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = sprite_sheet
			atlas.region = Rect2(x * frame_width, y * frame_height, frame_width, frame_height)
			frames.add_frame(animation_name, atlas)
	animated_sprite.sprite_frames = frames
	animated_sprite.play(animation_name)
