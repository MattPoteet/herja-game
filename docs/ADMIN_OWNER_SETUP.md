# Herja Owner/Admin Account

This build supports owner/admin privileges for only the configured account email.

## What admin mode does

When the logged-in account email is listed in `ADMIN_EMAILS`, the game returns `is_admin: true` to Godot. That account can:

- Craft potions without ingredients
- Build structures without materials
- See `ADMIN` in the HUD and inventory screen

Regular users still need normal materials.

## Configure your owner account

In `herja/backend/.env`, add your email:

```env
ADMIN_EMAILS=matthewpoteet1@gmail.com
```

You can add more later with commas, but keep only your email if you want it restricted:

```env
ADMIN_EMAILS=matthewpoteet1@gmail.com
```

Restart the backend after editing `.env`:

```bash
cd herja/backend
npm run dev
```

Then log out/in from the game so the account reloads with admin status.

## Current craft/build items already in the game

Materials and loot:

- Wood
- Stone
- Herb
- Mushroom
- Crystal Vial
- Rune Dust
- Bone Charm
- Small Gem
- Iron Ore
- Fur

Crafted consumables:

- Health Potion
- Greater Health Potion
- Mead
- Rune Tonic

Buildable structures:

- Campfire
- Longhouse
- Watchtower
- Rune Stone
- Alchemy Hut
- Palisade
- Dock
- Farmstead
- Shrine
