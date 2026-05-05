-- Compound usage stats: real, live counts of who is running each compound.
-- Powers the Discover page user counts, the "Trending This Week" ranking,
-- and the "Running This" rail on the compound detail page.
--
-- This migration adds:
--   1. Indexes for fast lookups on protocol_compounds.compound_name and protocols.is_active.
--   2. A SECURITY DEFINER RPC `compound_usage_stats()` returning aggregate counts per
--      lowercased compound name. Aggregates only — no PII leaves the server.
--   3. A SECURITY DEFINER RPC `compound_public_users(p_compound text)` returning the
--      user list for a single compound, filtered to public profiles whose owners have
--      enabled stat sharing AND included 'protocols' in their shared categories.
--
-- "Recent" = protocols still active OR finished (is_active=false) with start_date within
-- the last 90 days, capturing people who just wrapped a cycle.
-- "New starts" = protocols whose start_date is within the last 7 days.

-- ============================================================
-- 1) Indexes
-- ============================================================
create index if not exists protocol_compounds_compound_name_idx
    on public.protocol_compounds (lower(compound_name));

create index if not exists protocols_is_active_idx
    on public.protocols (is_active);

create index if not exists protocols_start_date_idx
    on public.protocols (start_date desc);

-- ============================================================
-- 2) Aggregate stats RPC
-- ============================================================
-- Returns one row per (lowercased) compound_name with:
--   active_users      — distinct users with an is_active=true protocol containing this compound
--   recent_users      — distinct users active OR with start_date in last 90 days
--   new_starts_7d     — distinct users whose protocol containing this compound started in last 7 days
--   trending_score    — new_starts_7d * 2 + active_users (hybrid)

create or replace function public.compound_usage_stats()
returns table (
    compound_name text,
    active_users int,
    recent_users int,
    new_starts_7d int,
    trending_score int
)
language sql
stable
security definer
set search_path = public
as $$
    with joined as (
        select
            lower(pc.compound_name) as cname,
            p.user_id,
            p.is_active,
            p.start_date
        from public.protocol_compounds pc
        join public.protocols p on p.id = pc.protocol_id
        where p.user_id is not null
    )
    select
        cname as compound_name,
        count(distinct user_id) filter (where is_active = true)::int as active_users,
        count(distinct user_id) filter (
            where is_active = true
               or start_date >= (current_date - interval '90 days')
        )::int as recent_users,
        count(distinct user_id) filter (
            where start_date >= (current_date - interval '7 days')
        )::int as new_starts_7d,
        (
            count(distinct user_id) filter (where start_date >= (current_date - interval '7 days')) * 2
          + count(distinct user_id) filter (where is_active = true)
        )::int as trending_score
    from joined
    group by cname;
$$;

grant execute on function public.compound_usage_stats() to anon, authenticated;

-- ============================================================
-- 3) Public users running a specific compound
-- ============================================================
-- Returns profile rows for users currently running `p_compound` (case-insensitive)
-- whose profiles are public AND who have stat sharing enabled with 'protocols' shared.

create or replace function public.compound_public_users(p_compound text)
returns table (
    id uuid,
    display_name text,
    username text,
    avatar_url text,
    avatar_color text,
    active_program text,
    total_fp int,
    current_streak int,
    dose_mcg double precision,
    frequency text,
    started_at timestamptz,
    total_weeks int
)
language sql
stable
security definer
set search_path = public
as $$
    select
        prof.id,
        prof.display_name,
        prof.username,
        prof.avatar_url,
        prof.avatar_color,
        prof.active_program,
        prof.total_fp,
        prof.current_streak,
        pc.dose_mcg,
        pc.frequency,
        p.start_date as started_at,
        p.total_weeks
    from public.protocol_compounds pc
    join public.protocols p on p.id = pc.protocol_id
    join public.profiles prof on prof.id = p.user_id
    join public.stat_sharing_prefs ssp on ssp.user_id = p.user_id
    where p.is_active = true
      and lower(pc.compound_name) = lower(p_compound)
      and coalesce(prof.is_private, false) = false
      and ssp.is_enabled = true
      and 'protocols' = any(ssp.categories)
    order by p.start_date desc nulls last;
$$;

grant execute on function public.compound_public_users(text) to anon, authenticated;
