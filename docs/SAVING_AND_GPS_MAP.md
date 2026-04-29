# Saving and GPS-Style Map

This build adds local save/load and an infinite GPS-coordinate world foundation.

## What is saved

The game writes this file automatically:

```text
user://player_save.json
```

Saved fields:

- Player name
- Level
- XP
- HP / max HP
- Attack
- Gold
- Inventory
- Last world position
- Last latitude / longitude position

The game autosaves every 8 seconds and also saves when you press `F5`.

## GPS-style map behavior

The map now uses a latitude/longitude origin and converts player movement into GPS coordinates. The default origin is Robbinsville, NC:

```text
35.3229, -83.8074
```

Movement is unrestricted. Water, forest, mountain, field, and grass tiles are visual biomes only. This keeps the game playable like Parallel Kingdom: the player can move everywhere on the map even when the real-world-style tile says water or mountain.

## Real GPS on mobile

Godot does not include one universal built-in GPS API that works across every export target by default. The project includes `GPSManager.gd`, which supports the foundation now and has plugin hooks for common mobile GPS/location plugins named:

- `GodotLocation`
- `Location`
- `GPS`

When a location plugin is added later, `GPSManager.gd` can use the device's real location as the map origin. Until then, the game uses the coordinate origin and still behaves like a GPS world.

## Testing a different GPS origin

You can create this file from code or by calling `GPSManager.set_debug_origin(latitude, longitude)`:

```text
user://gps_override.json
```

Example contents:

```json
{
  "latitude": 35.3229,
  "longitude": -83.8074
}
```

## Main files changed

- `scripts/SaveManager.gd`
- `scripts/GPSManager.gd`
- `scripts/WorldMap.gd`
- `scripts/Main.gd`
- `scripts/Player.gd`
- `scripts/HUD.gd`
- `scripts/NetworkClient.gd`
