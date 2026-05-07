-- ============================================================
-- Ensure public.profiles has an explicit, permissive SELECT
-- policy for authenticated users.
--
-- Symptom that drove this: when impersonating a fake test
-- account on the Community / Discover page, all OTHER users
-- rendered as "Unknown" / "@user". The iOS client's
-- `socialUserFromAuthor` falls back to those strings whenever
-- the embedded `profiles` join on `feed_posts` returns null.
--
-- Root cause: 20260517's RLS audit enables RLS on every public
-- table (including `profiles`), but no migration ever defined a
-- SELECT policy on `profiles`. Real-account environments worked
-- only because a permissive read policy had been added via the
-- Supabase dashboard. Newly-provisioned/refreshed databases —
-- and any session where that dashboard policy was wiped — saw
-- the embed return null for everyone except the caller (whose
-- own row is sometimes readable via auth.uid() coincidence /
-- service-role writes during onboarding).
--
-- Fix: define the policy explicitly so it lives in source
-- control and is identical across environments. Avatars,
-- usernames, display names, and the small public stats columns
-- are already considered public information by the rest of the
-- app (feeds, search, mentions, leaderboards), so a blanket
-- read-to-authenticated policy matches the existing data model.
--
-- Idempotent: drop-if-exists then create.
-- ============================================================

BEGIN;

alter table public.profiles enable row level security;

drop policy if exists "profiles_read_all" on public.profiles;
create policy "profiles_read_all"
    on public.profiles
    for select
    to authenticated
    using (true);

-- Keep writes locked to the row owner. These mirror the policies
-- the dashboard typically had; defining them here makes the
-- environment self-describing.
drop policy if exists "profiles_self_insert" on public.profiles;
create policy "profiles_self_insert"
    on public.profiles
    for insert
    to authenticated
    with check (auth.uid() = id);

drop policy if exists "profiles_self_update" on public.profiles;
create policy "profiles_self_update"
    on public.profiles
    for update
    to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

drop policy if exists "profiles_self_delete" on public.profiles;
create policy "profiles_self_delete"
    on public.profiles
    for delete
    to authenticated
    using (auth.uid() = id);

COMMIT;
