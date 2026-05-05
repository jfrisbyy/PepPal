-- Align `compound_usage_stats` with `compound_public_users`.
--
-- Previously the aggregate stats RPC counted every user with an active
-- protocol, while `compound_public_users` only returned users who:
--   - have a public profile (is_private = false), AND
--   - have stat sharing enabled, AND
--   - included 'protocols' in their shared categories.
--
-- This caused mismatches in the UI — e.g. "1 active user" displayed for a
-- compound, but the "On This Protocol" rail had nothing to show because the
-- only matching user was private. We now apply the same privacy filter to
-- the aggregate counts so the social numbers always match the people we can
-- actually surface.

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
        join public.profiles prof on prof.id = p.user_id
        join public.stat_sharing_prefs ssp on ssp.user_id = p.user_id
        where p.user_id is not null
          and coalesce(prof.is_private, false) = false
          and ssp.is_enabled = true
          and 'protocols' = any(ssp.categories)
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
