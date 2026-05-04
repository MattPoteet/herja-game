-- Herja Supabase schema
-- Run this in Supabase SQL Editor before testing account creation.

create extension if not exists pgcrypto;

create table if not exists public.game_accounts (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  player_name text not null default 'Viking',
  character_id text not null default 'viking',
  level integer not null default 1,
  xp integer not null default 0,
  hp integer not null default 100,
  max_hp integer not null default 100,
  attack integer not null default 12,
  gold integer not null default 0,
  inventory jsonb not null default '[]'::jsonb,
  skills jsonb not null default '{"available_skill_points":0,"total_skill_points_earned":0,"unlocked_skills":{}}'::jsonb,
  last_position jsonb not null default '{}'::jsonb,
  last_latitude double precision,
  last_longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.game_accounts add column if not exists skills jsonb not null default '{"available_skill_points":0,"total_skill_points_earned":0,"unlocked_skills":{}}'::jsonb;

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.game_accounts(id) on delete cascade,
  friend_account_id uuid references public.game_accounts(id) on delete set null,
  friend_name text not null,
  status text not null default 'accepted',
  created_at timestamptz not null default now(),
  unique(account_id, friend_name)
);

create table if not exists public.friend_invites (
  id uuid primary key default gen_random_uuid(),
  sender_account_id uuid not null references public.game_accounts(id) on delete cascade,
  receiver_account_id uuid references public.game_accounts(id) on delete cascade,
  receiver_name text not null,
  sender_name text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique(sender_account_id, receiver_name)
);

create table if not exists public.clans (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  founder_account_id uuid references public.game_accounts(id) on delete set null,
  leader_account_id uuid references public.game_accounts(id) on delete set null,
  perk_type text not null default 'xp_boost',
  max_members integer not null default 100,
  wins integer not null default 0,
  losses integer not null default 0,
  draws integer not null default 0,
  reputation integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.clans add column if not exists leader_account_id uuid references public.game_accounts(id) on delete set null;
alter table public.clans add column if not exists perk_type text not null default 'xp_boost';
alter table public.clans add column if not exists max_members integer not null default 100;
alter table public.clans add column if not exists wins integer not null default 0;
alter table public.clans add column if not exists losses integer not null default 0;
alter table public.clans add column if not exists draws integer not null default 0;
alter table public.clans add column if not exists reputation integer not null default 0;

create table if not exists public.clan_members (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  account_id uuid not null references public.game_accounts(id) on delete cascade,
  role text not null default 'Member',
  joined_at timestamptz not null default now(),
  unique(clan_id, account_id),
  unique(account_id)
);

create unique index if not exists clan_members_one_clan_per_account
  on public.clan_members(account_id);

create table if not exists public.clan_wars (
  id uuid primary key default gen_random_uuid(),
  attacking_clan_id uuid not null references public.clans(id) on delete cascade,
  defending_clan_id uuid not null references public.clans(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  completed_at timestamptz,
  scheduled_battle_id uuid,
  attacking_score integer not null default 0,
  defending_score integer not null default 0,
  check (attacking_clan_id <> defending_clan_id)
);

create table if not exists public.clan_battles (
  id uuid primary key default gen_random_uuid(),
  war_id uuid references public.clan_wars(id) on delete set null,
  clan_a_id uuid not null references public.clans(id) on delete cascade,
  clan_b_id uuid not null references public.clans(id) on delete cascade,
  scheduled_start_time timestamptz not null,
  actual_start_time timestamptz,
  end_time timestamptz,
  status text not null default 'scheduled',
  clan_a_score integer not null default 0,
  clan_b_score integer not null default 0,
  winning_clan_id uuid references public.clans(id) on delete set null,
  created_by_leader_id uuid references public.game_accounts(id) on delete set null
);

create table if not exists public.clan_battle_participants (
  id uuid primary key default gen_random_uuid(),
  battle_id uuid not null references public.clan_battles(id) on delete cascade,
  account_id uuid not null references public.game_accounts(id) on delete cascade,
  clan_id uuid not null references public.clans(id) on delete cascade,
  kills integer not null default 0,
  deaths integer not null default 0,
  damage_dealt integer not null default 0,
  healing_done integer not null default 0,
  reward_claimed boolean not null default false,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  unique(battle_id, account_id)
);

create table if not exists public.world_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.game_accounts enable row level security;
alter table public.friendships enable row level security;
alter table public.friend_invites enable row level security;
alter table public.clans enable row level security;
alter table public.clan_members enable row level security;
alter table public.clan_wars enable row level security;
alter table public.clan_battles enable row level security;
alter table public.clan_battle_participants enable row level security;
alter table public.world_events enable row level security;

-- Safe client-side policies. The Herja backend uses the service role key and bypasses RLS.
drop policy if exists "players can read own account" on public.game_accounts;
drop policy if exists "players can update own account" on public.game_accounts;
drop policy if exists "players can insert own account" on public.game_accounts;
drop policy if exists "players can read visible accounts" on public.game_accounts;

create policy "players can read own account"
  on public.game_accounts for select
  to authenticated
  using (auth.uid() = id);

create policy "players can insert own account"
  on public.game_accounts for insert
  to authenticated
  with check (auth.uid() = id);

create policy "players can update own account"
  on public.game_accounts for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "players can manage own friendships" on public.friendships;
drop policy if exists "players can read own friendships" on public.friendships;
create policy "players can read own friendships"
  on public.friendships for select
  to authenticated
  using (auth.uid() = account_id);
create policy "players can manage own friendships"
  on public.friendships for all
  to authenticated
  using (auth.uid() = account_id)
  with check (auth.uid() = account_id);

drop policy if exists "players can read own friend invites" on public.friend_invites;
drop policy if exists "players can manage sent friend invites" on public.friend_invites;
drop policy if exists "players can update received friend invites" on public.friend_invites;
create policy "players can read own friend invites"
  on public.friend_invites for select
  to authenticated
  using (auth.uid() = sender_account_id or auth.uid() = receiver_account_id);
create policy "players can manage sent friend invites"
  on public.friend_invites for insert
  to authenticated
  with check (auth.uid() = sender_account_id);
create policy "players can update received friend invites"
  on public.friend_invites for update
  to authenticated
  using (auth.uid() = receiver_account_id)
  with check (auth.uid() = receiver_account_id);

drop policy if exists "players can read clans" on public.clans;
create policy "players can read clans"
  on public.clans for select
  to authenticated
  using (true);

drop policy if exists "players can read clan members" on public.clan_members;
drop policy if exists "players can manage own clan membership" on public.clan_members;
create policy "players can read clan members"
  on public.clan_members for select
  to authenticated
  using (true);
create policy "players can manage own clan membership"
  on public.clan_members for all
  to authenticated
  using (auth.uid() = account_id)
  with check (auth.uid() = account_id);

drop policy if exists "players can read clan wars" on public.clan_wars;
create policy "players can read clan wars"
  on public.clan_wars for select
  to authenticated
  using (true);

drop policy if exists "players can read clan battles" on public.clan_battles;
create policy "players can read clan battles"
  on public.clan_battles for select
  to authenticated
  using (true);

drop policy if exists "players can read battle participants" on public.clan_battle_participants;
create policy "players can read battle participants"
  on public.clan_battle_participants for select
  to authenticated
  using (true);

drop policy if exists "authenticated read world events" on public.world_events;
create policy "authenticated read world events"
  on public.world_events for select
  to authenticated
  using (true);
