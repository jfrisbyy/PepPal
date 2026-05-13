-- Scenario / adaptive-brief support tables used by the fake-persona deep seed
-- All tables are idempotent (IF NOT EXISTS) and tagged with `source` so the
-- super-action seeder can wipe + reinsert fake-persona-seed rows safely.

-- ---------------------------------------------------------------------------
-- 1. recovery_log  (HRV / RHR / readiness daily rollup)
-- ---------------------------------------------------------------------------
create table if not exists public.recovery_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  hrv_ms numeric,
  hrv_baseline_ms numeric,
  hrv_delta_pct numeric,
  rhr_bpm integer,
  rhr_baseline_bpm integer,
  rhr_delta_bpm integer,
  readiness_score integer,
  notes text,
  source text default 'manual',
  created_at timestamptz not null default now(),
  unique (user_id, log_date)
);
create index if not exists recovery_log_user_date_idx on public.recovery_log (user_id, log_date desc);
alter table public.recovery_log enable row level security;
drop policy if exists "recovery_log owner" on public.recovery_log;
create policy "recovery_log owner" on public.recovery_log
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 2. meal_suggestion_override  (48h nutrition pivot after side effects, etc.)
-- ---------------------------------------------------------------------------
create table if not exists public.meal_suggestion_override (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  diet_tags text[] default '{}',
  avoid_tags text[] default '{}',
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  copy text,
  source text default 'manual',
  created_at timestamptz not null default now()
);
create index if not exists meal_suggestion_override_user_active_idx
  on public.meal_suggestion_override (user_id, expires_at desc);
alter table public.meal_suggestion_override enable row level security;
drop policy if exists "meal_suggestion_override owner" on public.meal_suggestion_override;
create policy "meal_suggestion_override owner" on public.meal_suggestion_override
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 3. compound_level_estimate  (daily estimated tissue / serum level)
-- ---------------------------------------------------------------------------
create table if not exists public.compound_level_estimate (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  compound text not null,
  log_date date not null,
  estimated_level numeric not null,
  baseline_level numeric,
  delta_pct numeric,
  source text default 'computed',
  created_at timestamptz not null default now(),
  unique (user_id, compound, log_date)
);
create index if not exists compound_level_estimate_user_compound_idx
  on public.compound_level_estimate (user_id, compound, log_date desc);
alter table public.compound_level_estimate enable row level security;
drop policy if exists "compound_level_estimate owner" on public.compound_level_estimate;
create policy "compound_level_estimate owner" on public.compound_level_estimate
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 4. bloodwork_flag  (panel-level callouts that point at a compound / marker)
-- ---------------------------------------------------------------------------
create table if not exists public.bloodwork_flag (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  panel_id uuid,
  biomarker text not null,
  trend text,
  severity text default 'info',
  related_compound text,
  message text,
  source text default 'computed',
  created_at timestamptz not null default now()
);
create index if not exists bloodwork_flag_user_idx on public.bloodwork_flag (user_id, created_at desc);
alter table public.bloodwork_flag enable row level security;
drop policy if exists "bloodwork_flag owner" on public.bloodwork_flag;
create policy "bloodwork_flag owner" on public.bloodwork_flag
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 5. nutrition_priority  (timed override on macro targets / micros)
-- ---------------------------------------------------------------------------
create table if not exists public.nutrition_priority (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  priority text not null,
  target_value numeric,
  unit text,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  reason text,
  source text default 'manual',
  created_at timestamptz not null default now()
);
create index if not exists nutrition_priority_user_active_idx
  on public.nutrition_priority (user_id, expires_at desc);
alter table public.nutrition_priority enable row level security;
drop policy if exists "nutrition_priority owner" on public.nutrition_priority;
create policy "nutrition_priority owner" on public.nutrition_priority
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 6. adaptive_decision_pending  (forked decision waiting on user input)
-- ---------------------------------------------------------------------------
create table if not exists public.adaptive_decision_pending (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scenario text not null,
  prompt text,
  branches jsonb not null default '[]'::jsonb,
  resolved_branch text,
  resolved_at timestamptz,
  expires_at timestamptz,
  source text default 'manual',
  created_at timestamptz not null default now()
);
create index if not exists adaptive_decision_pending_user_idx
  on public.adaptive_decision_pending (user_id, created_at desc);
alter table public.adaptive_decision_pending enable row level security;
drop policy if exists "adaptive_decision_pending owner" on public.adaptive_decision_pending;
create policy "adaptive_decision_pending owner" on public.adaptive_decision_pending
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 7. program_override  (deload / volume scaling applied to an active program)
-- ---------------------------------------------------------------------------
create table if not exists public.program_override (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  program_id uuid,
  override_type text not null,
  scale_pct numeric,
  starts_at date not null default current_date,
  ends_at date,
  reason text,
  source text default 'manual',
  created_at timestamptz not null default now()
);
create index if not exists program_override_user_idx
  on public.program_override (user_id, starts_at desc);
alter table public.program_override enable row level security;
drop policy if exists "program_override owner" on public.program_override;
create policy "program_override owner" on public.program_override
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 8. recovery_day_plan  (pre-built compassionate-recovery day)
-- ---------------------------------------------------------------------------
create table if not exists public.recovery_day_plan (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_date date not null,
  mobility_template_id uuid,
  meal_template_id uuid,
  dose_reminder boolean default true,
  streak_label_override text,
  notes text,
  source text default 'manual',
  created_at timestamptz not null default now(),
  unique (user_id, plan_date)
);
create index if not exists recovery_day_plan_user_idx
  on public.recovery_day_plan (user_id, plan_date desc);
alter table public.recovery_day_plan enable row level security;
drop policy if exists "recovery_day_plan owner" on public.recovery_day_plan;
create policy "recovery_day_plan owner" on public.recovery_day_plan
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 9. social_recommendation  (suggested persona / post to surface)
-- ---------------------------------------------------------------------------
create table if not exists public.social_recommendation (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid,
  target_post_id uuid,
  reason text,
  copy text,
  expires_at timestamptz,
  dismissed_at timestamptz,
  source text default 'manual',
  created_at timestamptz not null default now()
);
create index if not exists social_recommendation_user_idx
  on public.social_recommendation (user_id, created_at desc);
alter table public.social_recommendation enable row level security;
drop policy if exists "social_recommendation owner" on public.social_recommendation;
create policy "social_recommendation owner" on public.social_recommendation
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 10. borrowed_protocol  (user pulled another user's protocol into their plan)
-- ---------------------------------------------------------------------------
create table if not exists public.borrowed_protocol (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_user_id uuid,
  source_protocol_id uuid,
  protocol_name text,
  compound text,
  original_dose numeric,
  borrowed_at timestamptz not null default now(),
  source text default 'manual',
  created_at timestamptz not null default now()
);
create index if not exists borrowed_protocol_user_idx
  on public.borrowed_protocol (user_id, borrowed_at desc);
alter table public.borrowed_protocol enable row level security;
drop policy if exists "borrowed_protocol owner" on public.borrowed_protocol;
create policy "borrowed_protocol owner" on public.borrowed_protocol
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 11. protocol_adaptation  (personalized adjustment vs. borrowed source)
-- ---------------------------------------------------------------------------
create table if not exists public.protocol_adaptation (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  borrowed_protocol_id uuid references public.borrowed_protocol(id) on delete cascade,
  recommended_dose numeric,
  taper_weeks integer,
  reason jsonb not null default '{}'::jsonb,
  copy text,
  source text default 'computed',
  created_at timestamptz not null default now()
);
create index if not exists protocol_adaptation_user_idx
  on public.protocol_adaptation (user_id, created_at desc);
alter table public.protocol_adaptation enable row level security;
drop policy if exists "protocol_adaptation owner" on public.protocol_adaptation;
create policy "protocol_adaptation owner" on public.protocol_adaptation
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 12. location_log  (lightweight travel / context signal)
-- ---------------------------------------------------------------------------
create table if not exists public.location_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  label text,
  city text,
  region text,
  country text,
  latitude numeric,
  longitude numeric,
  is_travel boolean default false,
  source text default 'manual',
  created_at timestamptz not null default now()
);
create index if not exists location_log_user_idx on public.location_log (user_id, log_date desc);
alter table public.location_log enable row level security;
drop policy if exists "location_log owner" on public.location_log;
create policy "location_log owner" on public.location_log
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Service role (used by the super-action edge function) bypasses RLS, so the
-- seeder can insert/delete fake-persona-seed rows for any user_id.
-- ---------------------------------------------------------------------------
