-- ============================================================
-- Persistence gaps: vials, basketball games, macro targets,
-- task categories, body progress photos.
-- Each table has RLS scoped to the owning user.
-- ============================================================

-- ----------------------------------------------------------------
-- vials — peptide vial inventory (replaces UserDefaults store)
-- ----------------------------------------------------------------
create table if not exists public.vials (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    client_id uuid not null,                       -- stable client UUID for sync
    compound_name text not null,
    vial_size_mg double precision not null,
    diluent_ml double precision,
    reconstituted_on timestamptz,
    storage text not null default 'Fridge',
    lot_number text default '',
    vial_number text default '',
    expiration_date timestamptz,
    typical_dose_mcg double precision not null default 0,
    mcg_used double precision not null default 0,
    bud_days integer not null default 30,
    label_image_filename text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, client_id)
);

create index if not exists vials_user_idx on public.vials(user_id, created_at desc);
create index if not exists vials_user_compound_idx on public.vials(user_id, compound_name);

alter table public.vials enable row level security;
drop policy if exists "vials_self_rw" on public.vials;
create policy "vials_self_rw" on public.vials for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop trigger if exists vials_touch on public.vials;
create trigger vials_touch before update on public.vials
    for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------
-- basketball_games — games + shot charts (shot chart stored as jsonb)
-- ----------------------------------------------------------------
create table if not exists public.basketball_games (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    client_id uuid not null,
    played_at timestamptz not null default now(),
    session_type text not null,
    result text,                                    -- 'W' | 'L' | null
    team_score integer,
    opponent_score integer,
    duration_minutes integer not null default 0,
    confidence_rating integer not null default 5,
    performance_rating integer not null default 5,
    notes text default '',
    stats jsonb not null default '{}'::jsonb,       -- BasketballGameStats fields
    shot_chart jsonb not null default '[]'::jsonb,  -- [{ zone, made }]
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, client_id)
);

create index if not exists basketball_games_user_idx
    on public.basketball_games(user_id, played_at desc);

alter table public.basketball_games enable row level security;
drop policy if exists "basketball_games_self_rw" on public.basketball_games;
create policy "basketball_games_self_rw" on public.basketball_games for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop trigger if exists basketball_games_touch on public.basketball_games;
create trigger basketball_games_touch before update on public.basketball_games
    for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------
-- macro_targets — single row per user, the active target
-- ----------------------------------------------------------------
create table if not exists public.macro_targets (
    user_id uuid primary key references auth.users(id) on delete cascade,
    calories integer not null default 2000,
    protein_g integer not null default 150,
    carbs_g integer not null default 200,
    fat_g integer not null default 70,
    source text not null default 'manual',          -- 'manual' | 'adaptive' | 'onboarding'
    updated_at timestamptz not null default now()
);

alter table public.macro_targets enable row level security;
drop policy if exists "macro_targets_self_rw" on public.macro_targets;
create policy "macro_targets_self_rw" on public.macro_targets for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop trigger if exists macro_targets_touch on public.macro_targets;
create trigger macro_targets_touch before update on public.macro_targets
    for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------
-- task_categories — custom user-defined daily task categories
-- ----------------------------------------------------------------
create table if not exists public.task_categories (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    client_id uuid not null,
    name text not null,
    color_hex text,
    icon text,
    sort_order integer not null default 0,
    created_at timestamptz not null default now(),
    unique (user_id, client_id)
);

create index if not exists task_categories_user_idx
    on public.task_categories(user_id, sort_order asc);

alter table public.task_categories enable row level security;
drop policy if exists "task_categories_self_rw" on public.task_categories;
create policy "task_categories_self_rw" on public.task_categories for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- body_progress_photos — before/after photos with storage URL
-- ----------------------------------------------------------------
create table if not exists public.body_progress_photos (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    captured_at timestamptz not null default now(),
    label text default '',
    photo_url text,
    storage_path text,                              -- path in body-progress-photos bucket
    orientation text,                               -- 'front' | 'side' | 'back'
    weight_lbs double precision,
    note text,
    created_at timestamptz not null default now()
);

create index if not exists body_progress_photos_user_idx
    on public.body_progress_photos(user_id, captured_at desc);

alter table public.body_progress_photos enable row level security;
drop policy if exists "body_progress_photos_self_rw" on public.body_progress_photos;
create policy "body_progress_photos_self_rw" on public.body_progress_photos for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Storage bucket for progress photos
-- Files are stored under <user_id>/<filename> so RLS can scope by folder.
-- ----------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('body-progress-photos', 'body-progress-photos', true)
on conflict (id) do nothing;

drop policy if exists "body_progress_photos_owner_read" on storage.objects;
create policy "body_progress_photos_owner_read" on storage.objects
    for select to authenticated
    using (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "body_progress_photos_owner_write" on storage.objects;
create policy "body_progress_photos_owner_write" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "body_progress_photos_owner_update" on storage.objects;
create policy "body_progress_photos_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "body_progress_photos_owner_delete" on storage.objects;
create policy "body_progress_photos_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);
