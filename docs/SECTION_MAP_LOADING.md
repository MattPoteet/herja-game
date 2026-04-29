# Herja Section-Based Map Loading

The world map now loads in fixed GPS tile sections instead of constantly streaming every nearby tile.

## Behavior

- The map keeps one section loaded at a time.
- Each section is 7 OpenStreetMap tiles wide by 5 tiles tall.
- A 1-tile preload border is also loaded around the section.
- When the player crosses into a different section:
  - movement pauses briefly;
  - a loading overlay appears;
  - the old section is unloaded;
  - the next section requests its visible map tiles;
  - movement resumes after a short loading delay.

## Main settings

Edit these in `godot_client/scripts/WorldMap.gd`:

```gdscript
const SECTION_WIDTH_TILES: int = 7
const SECTION_HEIGHT_TILES: int = 5
const SECTION_LOAD_SECONDS: float = 1.25
const SECTION_PRELOAD_BORDER: int = 1
```

Increase `SECTION_WIDTH_TILES` and `SECTION_HEIGHT_TILES` for larger sections.
Increase `SECTION_LOAD_SECONDS` for a longer loading screen.
Increase `SECTION_PRELOAD_BORDER` to load extra edge tiles so transitions feel smoother.

## Why this helps

This reduces the number of active map tiles, structures, and nodes at one time. It also gives the game a region-transition feel instead of an endless streaming map.
