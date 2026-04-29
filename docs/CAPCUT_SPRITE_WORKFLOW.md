# CapCut Sprite Sheet Workflow

CapCut is not a dedicated pixel-art animation tool, but you can use it to create animated frames, then combine those frames into a sprite sheet for Godot.

## Recommended frame specs

- Character frame size: 64x64 PNG with transparent background
- Monster frame size: 64x64 or 96x96 PNG
- Tile size: 64x64 PNG
- Animation length: 4 to 8 frames per direction
- Keep the character centered in every frame
- Keep feet aligned at the same Y position across frames

## CapCut steps

1. Create a square project.
2. Add your character image with a transparent background.
3. Animate a small movement: idle bounce, walking cycle, attack swing, or spell cast.
4. Export the animation as a video.
5. Extract frames from the video using CapCut export options or any frame extractor.
6. Rename frames in order: `001.png`, `002.png`, `003.png`, `004.png`.
7. Put those frames into a folder, for example: `frames/player_walk_down`.
8. Run the included Python sprite sheet tool:

```bash
pip install pillow
python tools/make_spritesheet.py --input frames/player_walk_down --output godot_client/art/characters/player_walk_down.png --columns 4
```

## Prompt template for CapCut AI image/video tools

Use prompts like this:

```text
Top-down fantasy RPG character sprite, 64x64 game asset, full body centered, transparent background, simple clean outline, readable silhouette, idle walking animation, consistent character design, no text, no shadows outside the character, pixel-art friendly, four-frame loop.
```

For monsters:

```text
Top-down fantasy RPG monster sprite, small forest imp, 64x64 game asset, transparent background, clean silhouette, simple readable details, idle breathing animation, four-frame loop, no text.
```

## Godot import setup

1. Copy the generated PNG into `godot_client/art/characters/`.
2. In Godot, select the image and set filtering to nearest/disabled for crisp sprites.
3. Use `SpriteSheetLoader.gd` or create an `AnimatedSprite2D` with a `SpriteFrames` resource.
4. Match the exported frame width, frame height, columns, and rows.
