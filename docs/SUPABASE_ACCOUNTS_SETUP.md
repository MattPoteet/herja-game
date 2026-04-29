# Herja Supabase Account Setup

This build connects Herja account creation and login to Supabase Auth through the Node backend.

## 1. Create a Supabase project

Go to Supabase and create a project.

## 2. Run the SQL schema

Open Supabase Dashboard > SQL Editor.

Paste and run:

```sql
backend/sql/schema.sql
```

This creates:

- `game_accounts`
- `friendships`
- `clans`
- `clan_members`
- `world_events`

The `game_accounts.id` value is tied directly to `auth.users.id`.

## 3. Get your keys

In Supabase Dashboard, open Project Settings > API.

Copy:

- Project URL
- anon public key
- service_role key

Never put the service role key in the Godot client. It only belongs in the backend `.env` file.

## 4. Configure backend env

Create:

```text
backend/.env
```

Use this format:

```env
PORT=8787
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SUPABASE_SERVICE_ROLE_KEY
```

## 5. Run backend

From the `backend` folder:

```bash
npm install
npm run dev
```

Test it in your browser:

```text
http://127.0.0.1:8787/health
```

You should see `supabaseConfigured: true`.

## 6. Run Herja in Godot

Open:

```text
godot_client/project.godot
```

Press Play. The account screen now expects an email and password.

Account creation flow:

1. Enter email
2. Enter password, minimum 6 characters
3. Enter player name
4. Pick character
5. Click Create Account

The backend creates a Supabase Auth user and a matching `game_accounts` row.

## Current behavior

- Create Account = Supabase Auth signup through backend
- Login = Supabase Auth login through backend
- Save = local save plus online `game_accounts` sync
- Guest = offline-only local guest account
- Friends/clans = local immediately, then sync to Supabase if logged in online

## Production note

For desktop/mobile release, deploy the backend somewhere like Render, Railway, Fly.io, or a VPS. Then update this constant in `godot_client/scripts/AccountManager.gd`:

```gdscript
const BACKEND_BASE_URL: String = "https://YOUR-BACKEND-DOMAIN.com"
```
