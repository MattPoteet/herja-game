# Free GPS Map Mode

This build replaces the old random green/blue block map with a free OpenStreetMap tile layer.

## What it does

- Uses live raster tiles from `https://tile.openstreetmap.org/{z}/{x}/{y}.png` for development/testing.
- Converts player world position to real latitude/longitude using Web Mercator math.
- Lets the player move freely across the GPS-based map.
- Draws Viking-style game markers on top of the real map layer:
  - Longhouse
  - Rune Stone
  - Watchtower
  - Dock
  - Farmstead
  - Shrine
- Displays latitude/longitude in the HUD.
- Displays OpenStreetMap attribution in the HUD.

## Important usage note

OpenStreetMap data is free, but the public tile servers are community-funded and not meant for heavy commercial game traffic. This is good for your prototype. For a released Android/iOS/Desktop game, use your own tile server or a tile provider plan that allows your traffic.

## Main files changed

- `godot_client/scripts/WorldMap.gd`
- `godot_client/scripts/Main.gd`
- `godot_client/scripts/HUD.gd`
- `godot_client/scripts/Player.gd`

## Where the starting location is set

In `WorldMap.gd`:

```gdscript
const DEFAULT_LATITUDE: float = 35.3229
const DEFAULT_LONGITUDE: float = -83.8074
const DEFAULT_ZOOM: int = 16
```

Change those values to start the game somewhere else.

## How Viking structures work

The structures are currently deterministic markers generated from the visible map tile coordinates. Later, these should be saved to Supabase by GPS coordinates, like:

```json
{
  "type": "longhouse",
  "name": "Raven Hall",
  "lat": 35.3229,
  "lon": -83.8074,
  "owner_id": "player_123",
  "level": 1
}
```

Then every player sees the same buildings in the same real-world positions.
