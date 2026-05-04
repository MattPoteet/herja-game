# Accounts, Characters, Friends, and Clans

This build adds a local prototype account flow to the Godot client.

## What works now

- New user can create an account on the device.
- User can log back in.
- User can name their player.
- User can pick a starter character:
  - Viking
  - Shield Maiden
  - Druid
  - Mage
- Save data is tied to the selected account:
  - player name
  - character choice
  - level / XP
  - HP
  - gold
  - inventory
  - last position
  - last GPS coordinate
- Press F5 to manually save.
- Autosave runs every few seconds.
- Press O to open friends/clan menu.
- Friends, pending friend invites, notifications, and clan are saved locally for the selected account.
- The social panel can send friend invites, accept incoming invites, decline incoming invites, and remove friends.
- Notifications appear in the social panel and briefly in the HUD status line.

## Current limitation

This is a local-account prototype. It is enough for testing the game loop and UI. For real online accounts across iOS, Android, and desktop, connect this to Supabase Auth or a custom auth backend.

## Online database foundation

The backend SQL now includes starter tables for:

- `game_accounts`
- `friendships`
- `friend_invites`
- `clans`
- `clan_members`

Those tables are in:

```text
backend/sql/schema.sql
```

## Controls

```text
WASD / Arrows = move
Space = attack
F5 = save
O = friends/clan panel
```
