# Herja Inventory, Potion Crafting, and Building System

This build adds a playable prototype layer for inventory, potion crafting, and Viking structure placement.

## Controls

- `I` opens the inventory panel.
- `C` opens the potion crafting tab.
- `B` opens the building tab.
- `F5` manually saves.
- `O` opens friends/clan social tools.

## Inventory

The player inventory is still a simple array of item names, but the UI now groups matching items into counts.

Examples:

- `Herb x3`
- `Wood x8`
- `Crystal Vial x1`

The player script now supports:

- `add_item(item_name)`
- `add_items(items)`
- `get_inventory_counts()`
- `has_items(recipe)`
- `remove_items(recipe)`
- `use_item(item_name)`

## New Resources and Items

The item sheet at `godot_client/art/items/items.png` now supports a 4x4 layout:

1. Herb
2. Small Gem
3. Bone Charm
4. Iron Ore
5. Wood
6. Mushroom
7. Gold Coin
8. Rusty Axe
9. Stone
10. Fur
11. Rune Dust
12. Crystal Vial
13. Health Potion
14. Greater Health Potion
15. Mead
16. Rune Tonic

Enemies now drop several of the new materials, including Stone, Fur, Rune Dust, and Crystal Vial.

## Potion Recipes

Health Potion:

- Herb x2
- Mushroom x1
- Crystal Vial x1

Greater Health Potion:

- Herb x4
- Mushroom x2
- Crystal Vial x1
- Small Gem x1

Mead:

- Herb x1
- Wood x1
- Restores 20 HP when used

Rune Tonic:

- Rune Dust x2
- Bone Charm x1
- Crystal Vial x1
- Grants 45 XP when used

## Building System

The new `BuildingManager.gd` places buildings in the world at the player's current position plus a small offset in the direction the player is facing.

Buildings are saved locally by account id under:

`user://buildings/<account_id>.json`

Available buildings:

- Campfire
- Longhouse
- Watchtower
- Rune Stone
- Alchemy Hut
- Palisade
- Dock
- Farmstead
- Shrine

The building sprites are in:

`godot_client/art/buildings/buildings.png`

## Supabase Note

Inventory progress is synced through the existing `game_accounts.inventory` field when the backend saves progress.

Buildings currently save locally per account. The next backend upgrade should add a `player_structures` table with account id, structure type, GPS coordinates, world coordinates, level, and created timestamp.
