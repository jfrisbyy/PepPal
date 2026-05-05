-- ============================================================
-- AI briefings, weekly/monthly summaries, and insights cache.
-- Saves the latest AI-generated narrative + module/insight payloads
-- per user so the app can serve them instantly without re-running
-- expensive Sonnet calls on every open. History is kept indefinitely
-- so the home calendar can scroll back to any past day's locked brief.
-- ============================================================

-- ----------------------------------------------------------------
-- Daily briefings (TodaysPlanResponse + trigger metadata)
-- One row per user per local day. `is_final` flips true once the
-- calendar day has ended and the row becomes the historical record.
-- ----------------------------------------------------------------
create table if not exists public.ai_daily_briefings (
    user_id uuid not null references auth.users(id) on delete cascade,
    day date not null,
    plan_response jsonb not null,            -- full TodaysPlanResponse (summary, modules, narrative, actionItems)
    data_hash text,
    trigger text not null default 'window',  -- 'window' | 'event' | 'manual'
    window_key text,                         -- 'morning' | 'afternoon' | 'evening' | null
    is_final boolean not null default false,
    generated_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (user_id, day)
);

create index if not exists ai_daily_briefings_user_day_idx
    on public.ai_daily_briefings(user_id, day desc);

alter table public.ai_daily_briefings enable row level security;

drop policy if exists "ai_daily_briefings_self_rw" on public.ai_daily_briefings;
create policy "ai_daily_briefings_self_rw"
on public.ai_daily_briefings for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Weekly summaries (one row per user per ISO week start)
-- ----------------------------------------------------------------
create table if not exists public.ai_weekly_summaries (
    user_id uuid not null references auth.users(id) on delete cascade,
    week_start date not null,                -- Monday (or Sunday per locale) of the ISO week
    summary jsonb not null,                  -- arbitrary structured weekly summary payload
    data_hash text,
    is_final boolean not null default false,
    generated_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (user_id, week_start)
);

create index if not exists ai_weekly_summaries_user_week_idx
    on public.ai_weekly_summaries(user_id, week_start desc);

alter table public.ai_weekly_summaries enable row level security;

drop policy if exists "ai_weekly_summaries_self_rw" on public.ai_weekly_summaries;
create policy "ai_weekly_summaries_self_rw"
on public.ai_weekly_summaries for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Monthly summaries (one row per user per month start)
-- ----------------------------------------------------------------
create table if not exists public.ai_monthly_summaries (
    user_id uuid not null references auth.users(id) on delete cascade,
    month_start date not null,               -- first day of the month
    summary jsonb not null,
    data_hash text,
    is_final boolean not null default false,
    generated_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (user_id, month_start)
);

create index if not exists ai_monthly_summaries_user_month_idx
    on public.ai_monthly_summaries(user_id, month_start desc);

alter table public.ai_monthly_summaries enable row level security;

drop policy if exists "ai_monthly_summaries_self_rw" on public.ai_monthly_summaries;
create policy "ai_monthly_summaries_self_rw"
on public.ai_monthly_summaries for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Insights agent investigations (hero / patterns / impact)
-- A new row is inserted on every successful refresh; the latest by
-- generated_at is the active investigation. History is kept so we
-- can show "previous insight" timelines later.
-- ----------------------------------------------------------------
create table if not exists public.ai_investigations (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    payload jsonb not null,                  -- AgentInvestigationResult (hero, patterns, impact, dataPointsChecked)
    data_hash text,
    trigger text not null default 'auto',    -- 'auto' | 'manual' | 'event'
    generated_at timestamptz not null default now()
);

create index if not exists ai_investigations_user_generated_idx
    on public.ai_investigations(user_id, generated_at desc);

alter table public.ai_investigations enable row level security;

drop policy if exists "ai_investigations_self_rw" on public.ai_investigations;
create policy "ai_investigations_self_rw"
on public.ai_investigations for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Auto-update `updated_at` on briefing/summary upserts
-- ----------------------------------------------------------------
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists ai_daily_briefings_touch on public.ai_daily_briefings;
create trigger ai_daily_briefings_touch
before update on public.ai_daily_briefings
for each row execute function public.touch_updated_at();

drop trigger if exists ai_weekly_summaries_touch on public.ai_weekly_summaries;
create trigger ai_weekly_summaries_touch
before update on public.ai_weekly_summaries
for each row execute function public.touch_updated_at();

drop trigger if exists ai_monthly_summaries_touch on public.ai_monthly_summaries;
create trigger ai_monthly_summaries_touch
before update on public.ai_monthly_summaries
for each row execute function public.touch_updated_at();
