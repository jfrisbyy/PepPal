-- ============================================================
-- Apple Health cloud persistence
-- Stores daily scalar snapshots, per-metric time series, sleep
-- nights, and workouts so the app has long-term Health context
-- for summaries, AI briefings, and empty-state fallbacks.
-- ============================================================

-- ----------------------------------------------------------------
-- Daily scalar snapshots (one row per user per local day)
-- ----------------------------------------------------------------
create table if not exists public.health_daily_snapshots (
    user_id uuid not null references auth.users(id) on delete cascade,
    day date not null,
    steps int not null default 0,
    active_calories double precision not null default 0,
    resting_calories double precision not null default 0,
    distance_meters double precision not null default 0,
    flights_climbed int not null default 0,
    exercise_minutes double precision not null default 0,
    stand_hours int not null default 0,
    sleep_hours double precision not null default 0,
    sleep_deep_hours double precision,
    sleep_rem_hours double precision,
    sleep_core_hours double precision,
    heart_rate double precision,
    resting_heart_rate double precision,
    walking_heart_rate double precision,
    hrv double precision,
    respiratory_rate double precision,
    oxygen_saturation double precision,
    vo2_max double precision,
    body_weight double precision,
    body_fat_percentage double precision,
    lean_body_mass double precision,
    waist_circumference double precision,
    bmi double precision,
    mindful_minutes double precision not null default 0,
    dietary_energy double precision not null default 0,
    dietary_protein double precision not null default 0,
    dietary_carbs double precision not null default 0,
    dietary_fat double precision not null default 0,
    dietary_water double precision not null default 0,
    blood_glucose double precision,
    blood_pressure_systolic double precision,
    blood_pressure_diastolic double precision,
    body_temperature double precision,
    captured_at timestamptz not null default now(),
    primary key (user_id, day)
);

create index if not exists health_daily_snapshots_user_day_idx
    on public.health_daily_snapshots(user_id, day desc);

alter table public.health_daily_snapshots enable row level security;

drop policy if exists "health_daily_snapshots_self_rw" on public.health_daily_snapshots;
create policy "health_daily_snapshots_self_rw"
on public.health_daily_snapshots for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Per-metric time series points (for charts / 90d trends)
-- metric examples: steps, active_calories, hrv, resting_heart_rate,
-- weight, body_fat, sleep_asleep, etc.
-- ----------------------------------------------------------------
create table if not exists public.health_series_points (
    user_id uuid not null references auth.users(id) on delete cascade,
    metric text not null,
    day date not null,
    value double precision not null default 0,
    min_value double precision,
    max_value double precision,
    captured_at timestamptz not null default now(),
    primary key (user_id, metric, day)
);

create index if not exists health_series_points_user_metric_day_idx
    on public.health_series_points(user_id, metric, day desc);

alter table public.health_series_points enable row level security;

drop policy if exists "health_series_points_self_rw" on public.health_series_points;
create policy "health_series_points_self_rw"
on public.health_series_points for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Sleep nights (per-night stage breakdown)
-- ----------------------------------------------------------------
create table if not exists public.health_sleep_nights (
    user_id uuid not null references auth.users(id) on delete cascade,
    night date not null,
    asleep_hours double precision not null default 0,
    deep_hours double precision not null default 0,
    rem_hours double precision not null default 0,
    core_hours double precision not null default 0,
    captured_at timestamptz not null default now(),
    primary key (user_id, night)
);

create index if not exists health_sleep_nights_user_night_idx
    on public.health_sleep_nights(user_id, night desc);

alter table public.health_sleep_nights enable row level security;

drop policy if exists "health_sleep_nights_self_rw" on public.health_sleep_nights;
create policy "health_sleep_nights_self_rw"
on public.health_sleep_nights for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Workouts (HKWorkout mirror)
-- ----------------------------------------------------------------
create table if not exists public.health_workouts (
    id text primary key, -- HKWorkout.uuid string for idempotent upsert
    user_id uuid not null references auth.users(id) on delete cascade,
    activity_type int not null, -- HKWorkoutActivityType raw value
    activity_name text not null default '',
    start_at timestamptz not null,
    end_at timestamptz not null,
    duration_seconds double precision not null default 0,
    distance_meters double precision not null default 0,
    calories double precision not null default 0,
    average_heart_rate double precision,
    max_heart_rate double precision,
    source_name text,
    metadata jsonb,
    captured_at timestamptz not null default now()
);

create index if not exists health_workouts_user_start_idx
    on public.health_workouts(user_id, start_at desc);
create index if not exists health_workouts_user_type_idx
    on public.health_workouts(user_id, activity_type, start_at desc);

alter table public.health_workouts enable row level security;

drop policy if exists "health_workouts_self_rw" on public.health_workouts;
create policy "health_workouts_self_rw"
on public.health_workouts for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Cloud sync state (one row per user)
-- ----------------------------------------------------------------
create table if not exists public.health_sync_state (
    user_id uuid primary key references auth.users(id) on delete cascade,
    last_full_sync_at timestamptz,
    last_delta_sync_at timestamptz,
    last_backfill_at timestamptz,
    days_stored int not null default 0,
    workouts_stored int not null default 0,
    updated_at timestamptz not null default now()
);

alter table public.health_sync_state enable row level security;

drop policy if exists "health_sync_state_self_rw" on public.health_sync_state;
create policy "health_sync_state_self_rw"
on public.health_sync_state for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
