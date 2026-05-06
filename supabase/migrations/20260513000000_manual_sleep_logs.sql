-- ============================================================
-- Manual sleep logs — user-entered nights of sleep
-- Complements Apple Health imports in health_sleep_nights so
-- people without HealthKit can still log hours + quality.
-- ============================================================

create table if not exists public.manual_sleep_logs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    night date not null,
    bedtime timestamptz,
    wake_time timestamptz,
    hours double precision not null default 0,
    quality int,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, night)
);

create index if not exists manual_sleep_logs_user_night_idx
    on public.manual_sleep_logs(user_id, night desc);

alter table public.manual_sleep_logs enable row level security;

drop policy if exists "manual_sleep_logs_self_rw" on public.manual_sleep_logs;
create policy "manual_sleep_logs_self_rw"
on public.manual_sleep_logs for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
