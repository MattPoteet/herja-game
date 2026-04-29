# Herja

A cross-platform starter project for a game inspired by the old location-based fantasy MMO style of Parallel Kingdom.

This is built as a Godot 4 client plus a lightweight Node.js backend. Godot can export to Android, iOS, Windows, macOS, and Linux from the same project.

## What is included

- Godot 4 client project
- Procedural tile-based overworld
- Player movement
- Basic combat
- Enemy spawning
- Loot, XP, level, gold, and inventory starter logic
- WebSocket presence backend
- Supabase starter SQL schema
- CapCut sprite sheet workflow
- Python tool to build sprite sheets from exported frames

## Folder structure

```text
godot_client/       Godot 4 game client
backend/            Node.js WebSocket/API backend
backend/sql/        Supabase schema
tools/              Sprite-sheet helper tools
docs/               CapCut workflow notes
```

## How to run the game client

1. Install Godot 4.x.
2. Open the `godot_client` folder in Godot.
3. Press Play.

The starter uses placeholder ColorRect graphics so it runs before you add art.

## How to run the backend

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

The Godot client currently points to:

```text
ws://127.0.0.1:8787
```

You can change that in:

```text
godot_client/scripts/NetworkClient.gd
```

## Supabase setup

1. Create a Supabase project.
2. Open Supabase SQL Editor.
3. Run `backend/sql/schema.sql`.
4. Put your Supabase URL and service role key in `backend/.env`.

For production, tighten Row Level Security policies. The starter schema uses broad read policies to make development easier.

## Export targets

Godot supports:

- Android APK/AAB
- iOS Xcode project export
- Windows desktop
- macOS desktop
- Linux desktop
- Web builds if you later want browser play

For iOS, you still need a Mac and Apple Developer account. For Android, install Godot Android export templates and Android Studio SDK tools.

## Production roadmap

Build in this order:

1. Replace placeholder rectangles with CapCut sprite sheets.
2. Add login/account creation.
3. Save player profiles and inventory to Supabase.
4. Add remote player rendering from WebSocket presence snapshots.
5. Add quests and resource nodes.
6. Add location-based optional mode using phone GPS.
7. Add anti-cheat validation on the backend.
8. Add party/guild/chat systems.
9. Add monetization only after the core loop feels good.

## Important note

This is not a finished MMO. It is a working starter foundation with the code organized so you can build toward a Parallel Kingdom-style game without starting from zero.

## Viking sprite integration

This build includes the Viking sprite sheets in:

- `godot_client/art/characters/viking/viking_walk.png`
- `godot_client/art/characters/viking/viking_attack.png`

`Player.gd` now creates the `AnimatedSprite2D` and animation frames automatically at runtime. You do not need to manually slice the sheet in Godot.

Controls:

- Move: WASD or arrow keys
- Attack: Space

If the sprite looks blurry, click each PNG in Godot and set Import > Filter to Nearest, then Reimport.

## Added: Accounts, Character Pick, Friends, and Clan

This build includes a local account/login prototype inside Godot.

When the game starts, the player sees an account screen where they can:

- create an account
- login
- continue the last account
- create a guest account
- name the player
- choose a character: Viking, Shield Maiden, Druid, or Mage

The save system is account-based and stores:

- player name
- character choice
- level / XP
- HP
- gold
- inventory
- last world position
- last GPS coordinate
- friends
- clan

Controls:

```text
WASD / Arrows = move
Space = attack
F5 = manual save
O = friends/clan panel
```

See `docs/ACCOUNTS_FRIENDS_CLANS.md` for details.

## Inventory / Crafting / Building Update

This zip includes the new Herja inventory, potion crafting, and Viking building prototype.

Controls:

- `I` inventory
- `C` craft potions
- `B` build structures
- `F5` save
- `O` social menu

New files:

- `godot_client/scripts/InventoryMenu.gd`
- `godot_client/scripts/BuildingManager.gd`
- `godot_client/art/items/items.png`
- `godot_client/art/buildings/buildings.png`
- `docs/INVENTORY_CRAFTING_BUILDING.md`
