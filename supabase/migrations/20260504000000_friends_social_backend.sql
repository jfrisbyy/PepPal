-- Friends social backend: weekly stat snapshots, sharing prefs sync,
-- reactions, nudges, activity events, and push registry helpers.

-- ============================================================
-- Stat sharing prefs (synced version of UserDefaults)
-- ============================================================
create table if not exists public.stat_sharing_prefs (
    user_id uuid primary key references auth.users(id) on delete cascade,
    is_enabled boolean not null default false,
    audience text not null default 'friends', -- friends | followers
    categories text[] not null default array[
        'streak','workouts','volume','steps','calories','water','prs','nutrition','protocols','programs','sets'
    ],
    updated_at timestamptz not null default now()
);

alter table public.stat_sharing_prefs enable row level security;

drop policy if exists "stat_sharing_prefs_self_rw" on public.stat_sharing_prefs;
create policy "stat_sharing_prefs_self_rw"
on public.stat_sharing_prefs
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Friends can read each other's prefs (mutually-following or followers, gated client side)
drop policy if exists "stat_sharing_prefs_read_followers" on public.stat_sharing_prefs;
create policy "stat_sharing_prefs_read_followers"
on public.stat_sharing_prefs
for select
to authenticated
using (
    is_enabled = true
    and exists (
        select 1 from public.follows f
        where f.follower_id = auth.uid()
          and f.following_id = stat_sharing_prefs.user_id
    )
);

-- ============================================================
-- Weekly stat snapshots (one row per user per ISO week)
-- ============================================================
create table if not exists public.friend_stat_snapshots (
    user_id uuid not null references auth.users(id) on delete cascade,
    week_start date not null, -- Monday of the ISO week
    weekly_workouts int not null default 0,
    weekly_volume_kg int not null default 0,
    weekly_steps int not null default 0,
    weekly_calories int not null default 0,
    weekly_water_ml int not null default 0,
    streak int not null default 0,
    latest_pr text,
    active_program text,
    active_protocol text,
    updated_at timestamptz not null default now(),
    primary key (user_id, week_start)
);

create index if not exists friend_stat_snapshots_user_idx
    on public.friend_stat_snapshots (user_id, week_start desc);

alter table public.friend_stat_snapshots enable row level security;

drop policy if exists "friend_stat_snapshots_owner_rw" on public.friend_stat_snapshots;
create policy "friend_stat_snapshots_owner_rw"
on public.friend_stat_snapshots
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "friend_stat_snapshots_friends_read" on public.friend_stat_snapshots;
create policy "friend_stat_snapshots_friends_read"
on public.friend_stat_snapshots
for select
to authenticated
using (
    exists (
        select 1 from public.stat_sharing_prefs p
        where p.user_id = friend_stat_snapshots.user_id
          and p.is_enabled = true
    )
    and exists (
        select 1 from public.follows f
        where f.follower_id = auth.uid()
          and f.following_id = friend_stat_snapshots.user_id
    )
);

-- ============================================================
-- Reactions on a friend's snapshot or activity event
-- ============================================================
create table if not exists public.friend_reactions (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references auth.users(id) on delete cascade,
    receiver_id uuid not null references auth.users(id) on delete cascade,
    target text not null, -- e.g. "snapshot:streak", "event:<uuid>"
    emoji text not null,
    created_at timestamptz not null default now()
);

create index if not exists friend_reactions_receiver_idx
    on public.friend_reactions (receiver_id, created_at desc);
create index if not exists friend_reactions_pair_target_idx
    on public.friend_reactions (sender_id, receiver_id, target);

alter table public.friend_reactions enable row level security;

drop policy if exists "friend_reactions_sender_insert" on public.friend_reactions;
create policy "friend_reactions_sender_insert"
on public.friend_reactions
for insert
to authenticated
with check (auth.uid() = sender_id);

drop policy if exists "friend_reactions_visible" on public.friend_reactions;
create policy "friend_reactions_visible"
on public.friend_reactions
for select
to authenticated
using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "friend_reactions_sender_delete" on public.friend_reactions;
create policy "friend_reactions_sender_delete"
on public.friend_reactions
for delete
to authenticated
using (auth.uid() = sender_id);

-- ============================================================
-- Nudges (with cooldown)
-- ============================================================
create table if not exists public.friend_nudges (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references auth.users(id) on delete cascade,
    receiver_id uuid not null references auth.users(id) on delete cascade,
    kind text not null,
    created_at timestamptz not null default now()
);

create index if not exists friend_nudges_receiver_idx
    on public.friend_nudges (receiver_id, created_at desc);
create index if not exists friend_nudges_sender_pair_idx
    on public.friend_nudges (sender_id, receiver_id, created_at desc);

alter table public.friend_nudges enable row level security;

drop policy if exists "friend_nudges_sender_insert" on public.friend_nudges;
create policy "friend_nudges_sender_insert"
on public.friend_nudges
for insert
to authenticated
with check (auth.uid() = sender_id);

drop policy if exists "friend_nudges_visible" on public.friend_nudges;
create policy "friend_nudges_visible"
on public.friend_nudges
for select
to authenticated
using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- ============================================================
-- Activity events (PR, protocol_started, protocol_finished,
-- sharing_on, weekly_recap)
-- ============================================================
create table if not exists public.friend_activity_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    type text not null,
    title text not null,
    subtitle text,
    data jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists friend_activity_events_user_time_idx
    on public.friend_activity_events (user_id, created_at desc);

alter table public.friend_activity_events enable row level security;

drop policy if exists "friend_activity_events_owner_rw" on public.friend_activity_events;
create policy "friend_activity_events_owner_rw"
on public.friend_activity_events
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "friend_activity_events_friends_read" on public.friend_activity_events;
create policy "friend_activity_events_friends_read"
on public.friend_activity_events
for select
to authenticated
using (
    exists (
        select 1 from public.follows f
        where f.follower_id = auth.uid()
          and f.following_id = friend_activity_events.user_id
    )
);

-- ============================================================
-- Helpful: ensure follows table has the index used above.
-- (No-op if already present.)
-- ============================================================
create index if not exists follows_follower_following_idx
    on public.follows (follower_id, following_id);
