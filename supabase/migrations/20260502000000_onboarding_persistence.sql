-- Consolidated onboarding persistence migration.
-- Adds every column/table/policy/index the iOS onboarding flow writes to.
-- Idempotent: safe to re-run.

------------------------------------------------------------------------
-- 1) profiles columns written across the six chapters
------------------------------------------------------------------------

-- Chapter 1 — persona + identity bits the social-identity step writes
alter table public.profiles add column if not exists persona_track text;
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists avatar_color text;
alter table public.profiles add column if not exists medical_disclaimer_accepted_at timestamptz;

-- Chapter 2 — About You + gates
alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists date_of_birth date;
alter table public.profiles add column if not exists biological_sex text;
alter table public.profiles add column if not exists height_cm double precision;
alter table public.profiles add column if not exists weight_kg double precision;
alter table public.profiles add column if not exists body_fat_percent double precision;
alter table public.profiles add column if not exists activity_level text;
alter table public.profiles add column if not exists is_pregnant_or_nursing boolean;

-- Chapter 5 — Goals
alter table public.profiles add column if not exists primary_goal text;
alter table public.profiles add column if not exists secondary_goal text;
alter table public.profiles add column if not exists target_weight_kg double precision;
alter table public.profiles add column if not exists target_body_fat_percent double precision;
alter table public.profiles add column if not exists target_performance_metric text;
alter table public.profiles add column if not exists target_date date;
alter table public.profiles add column if not exists sessions_per_week integer;
alter table public.profiles add column if not exists training_modalities text[];
alter table public.profiles add column if not exists experience_level text;
alter table public.profiles add column if not exists current_program text;
alter table public.profiles add column if not exists injuries text[];
alter table public.profiles add column if not exists other_injury_note text;
alter table public.profiles add column if not exists diet_style text;
alter table public.profiles add column if not exists prior_tracker text;
alter table public.profiles add column if not exists protein_per_kg double precision;
alter table public.profiles add column if not exists allergies text[];
alter table public.profiles add column if not exists restrictions text[];
alter table public.profiles add column if not exists starter_calories integer;
alter table public.profiles add column if not exists starter_protein_g integer;
alter table public.profiles add column if not exists starter_carbs_g integer;
alter table public.profiles add column if not exists starter_fat_g integer;
alter table public.profiles add column if not exists daily_water_ml integer;
alter table public.profiles add column if not exists daily_step_floor integer;

-- Chapter 6 — Protocol & Vials
alter table public.profiles add column if not exists preferred_injection_sites text[];
alter table public.profiles add column if not exists reminder_style text;
alter table public.profiles add column if not exists morning_brief_time text;
alter table public.profiles add column if not exists dose_reminder_time text;

-- Username availability check uses case-insensitive ilike. Enforce
-- uniqueness on the lowercased value so two users can't race the same
-- handle and a non-unique index covers the lookup.
create unique index if not exists profiles_username_lower_unique_idx
    on public.profiles (lower(username))
    where username is not null;

------------------------------------------------------------------------
-- 2) disclaimer_acknowledgements (append-only audit trail)
------------------------------------------------------------------------

create table if not exists public.disclaimer_acknowledgements (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    version text not null,
    accepted_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create index if not exists disclaimer_acknowledgements_user_idx
    on public.disclaimer_acknowledgements (user_id, accepted_at desc);

alter table public.disclaimer_acknowledgements enable row level security;

drop policy if exists "users insert own ack" on public.disclaimer_acknowledgements;
create policy "users insert own ack"
    on public.disclaimer_acknowledgements
    for insert to authenticated
    with check (auth.uid() = user_id);

drop policy if exists "users read own ack" on public.disclaimer_acknowledgements;
create policy "users read own ack"
    on public.disclaimer_acknowledgements
    for select to authenticated
    using (auth.uid() = user_id);

------------------------------------------------------------------------
-- 3) journey_events (Chapter 4 timeline + auto-pin hooks)
------------------------------------------------------------------------

create table if not exists public.journey_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    lane text not null,
    timestamp timestamptz not null,
    duration_days int,
    title text not null,
    description text,
    source_type text not null,
    confidence double precision default 1.0,
    attachments text[] default '{}',
    linked_fact_ids uuid[] default '{}',
    payload text,
    created_at timestamptz not null default now()
);

create index if not exists journey_events_user_ts_idx
    on public.journey_events (user_id, timestamp desc);

alter table public.journey_events enable row level security;

drop policy if exists "users select own journey events" on public.journey_events;
create policy "users select own journey events"
    on public.journey_events
    for select to authenticated using (auth.uid() = user_id);

drop policy if exists "users insert own journey events" on public.journey_events;
create policy "users insert own journey events"
    on public.journey_events
    for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "users update own journey events" on public.journey_events;
create policy "users update own journey events"
    on public.journey_events
    for update to authenticated using (auth.uid() = user_id);

drop policy if exists "users delete own journey events" on public.journey_events;
create policy "users delete own journey events"
    on public.journey_events
    for delete to authenticated using (auth.uid() = user_id);
