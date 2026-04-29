# Enemy and Item Sprite Integration

This build adds parsed sprite sheets for the starter enemies and loot items.

## Added sprite sheets

Enemy sheet:

```text
godot_client/art/enemies/enemies.png
```

Layout:

```text
4 columns x 12 rows
64 x 64 px per frame
Rows 0-3   = Wild Wisp
Rows 4-7   = Forest Imp
Rows 8-11  = Stone Boar
Each enemy uses:
Row 0/4/8   = down
Row 1/5/9   = left
Row 2/6/10  = right
Row 3/7/11  = up
```

Item sheet:

```text
godot_client/art/items/items.png
```

Layout:

```text
4 columns x 2 rows
64 x 64 px per icon
0 Herb
1 Small Gem
2 Bone Charm
3 Iron Ore
4 Wood
5 Mushroom
6 Gold Coin
7 Rusty Axe
```

## Code added

```text
godot_client/scripts/Enemy.gd
godot_client/scripts/ItemDrop.gd
godot_client/scenes/ItemDrop.tscn
godot_client/scripts/Player.gd
```

Enemies now load their frames from `enemies.png`.

When an enemy dies:
1. Player gets XP and gold immediately.
2. The enemy may drop an item on the map.
3. Walking over the item adds it to the inventory and updates the HUD.

## Godot import settings

In Godot, click these PNG files and set:

```text
Filter: Nearest
Mipmaps: Off
Repeat: Disabled
```

Then click **Reimport**.

