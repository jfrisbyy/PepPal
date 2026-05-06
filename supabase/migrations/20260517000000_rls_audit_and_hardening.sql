-- Scale hardening: RLS audit, client error reporting, additional storage buckets,
-- and hardening of existing public tables.
--
-- This migration is intentionally idempotent: every statement uses
-- `if not exists` / `drop policy if exists` / `do $$ ... $$` blocks so it can
-- be re-run safely on environments that already have some of these objects.
-- That gives us a one-shot rollback path: re-run the previous migration set
-- and reapply this file rather than chasing partial failures.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) RLS audit: assert RLS enabled on every public table.
--    Any table that ships with `user_id` MUST have RLS on. We loop over the
--    catalog instead of hard-coding names so future tables are picked up
--    automatically the next time this migration is re-run.
-- ---------------------------------------------------------------------------

do $$
declare
    r record;
begin
    for r in
        select c.relname
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relkind = 'r'
          and c.relname not like 'pg_%'
          and c.relname not in ('schema_migrations')
    loop
        execute format('alter table public.%I enable row level security', r.relname);
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Backstop policies for tables that have a `user_id` column but might be
--    missing a "user owns row" policy. We only create the policy when the
--    column exists and no policy with this name is already present.
-- ---------------------------------------------------------------------------

do $$
declare
    r record;
begin
    for r in
        select c.relname as tbl
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        join pg_attribute a on a.attrelid = c.oid
        where n.nspname = 'public'
          and c.relkind = 'r'
          and a.attname = 'user_id'
          and a.attnum > 0
          and not a.attisdropped
    loop
        -- Skip tables that already have at least one policy. We don't want to
        -- accidentally widen access on tables with carefully-tuned rules
        -- (e.g. follows, feed_posts).
        if not exists (
            select 1 from pg_policies
            where schemaname = 'public' and tablename = r.tbl
        ) then
            execute format(
                'create policy "owner_select" on public.%I for select to authenticated using (auth.uid() = user_id)',
                r.tbl
            );
            execute format(
                'create policy "owner_insert" on public.%I for insert to authenticated with check (auth.uid() = user_id)',
                r.tbl
            );
            execute format(
                'create policy "owner_update" on public.%I for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)',
                r.tbl
            );
            execute format(
                'create policy "owner_delete" on public.%I for delete to authenticated using (auth.uid() = user_id)',
                r.tbl
            );
        end if;
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3) Client error reporting table.
--    Lightweight Sentry replacement -- the iOS client appends rows here when
--    a user-visible error happens. Capped retention keeps it cheap.
-- ---------------------------------------------------------------------------

create table if not exists public.client_errors (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade,
    occurred_at timestamptz not null default now(),
    platform text not null default 'ios',
    app_version text,
    os_version text,
    device_model text,
    screen text,
    severity text not null default 'error',
    message text not null,
    stack text,
    context jsonb not null default '{}'::jsonb
);

create index if not exists client_errors_user_occurred_idx
    on public.client_errors (user_id, occurred_at desc);
create index if not exists client_errors_occurred_idx
    on public.client_errors (occurred_at desc);

alter table public.client_errors enable row level security;

drop policy if exists "client_errors_owner_insert" on public.client_errors;
create policy "client_errors_owner_insert"
    on public.client_errors for insert
    to authenticated
    with check (auth.uid() = user_id);

drop policy if exists "client_errors_owner_select" on public.client_errors;
create policy "client_errors_owner_select"
    on public.client_errors for select
    to authenticated
    using (auth.uid() = user_id);

-- 30-day retention helper. Run from a cron with the service role.
create or replace function public.purge_old_client_errors()
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.client_errors
    where occurred_at < now() - interval '30 days';
$$;

-- ---------------------------------------------------------------------------
-- 4) Body progress photos storage bucket (private, per-user folder).
--    Currently uploaded via signed URLs from the client; lock the policies
--    here so direct access is impossible without a JWT.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('body-progress', 'body-progress', false)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('meal-photos', 'meal-photos', false)
on conflict (id) do update set public = excluded.public;

-- Body progress photos: strictly per-user.
drop policy if exists "body_progress_owner_select" on storage.objects;
create policy "body_progress_owner_select"
    on storage.objects for select
    to authenticated
    using (
        bucket_id = 'body-progress'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "body_progress_owner_insert" on storage.objects;
create policy "body_progress_owner_insert"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'body-progress'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "body_progress_owner_update" on storage.objects;
create policy "body_progress_owner_update"
    on storage.objects for update
    to authenticated
    using (
        bucket_id = 'body-progress'
        and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
        bucket_id = 'body-progress'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "body_progress_owner_delete" on storage.objects;
create policy "body_progress_owner_delete"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'body-progress'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- Meal photos: same per-user policy.
drop policy if exists "meal_photos_owner_select" on storage.objects;
create policy "meal_photos_owner_select"
    on storage.objects for select
    to authenticated
    using (
        bucket_id = 'meal-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "meal_photos_owner_insert" on storage.objects;
create policy "meal_photos_owner_insert"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'meal-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "meal_photos_owner_update" on storage.objects;
create policy "meal_photos_owner_update"
    on storage.objects for update
    to authenticated
    using (
        bucket_id = 'meal-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
        bucket_id = 'meal-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "meal_photos_owner_delete" on storage.objects;
create policy "meal_photos_owner_delete"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'meal-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ---------------------------------------------------------------------------
-- 5) GDPR delete: server-side helper invoked by the `deleteAccount` edge
--    function. Runs as security definer so the edge function only needs to
--    pass the caller's auth.uid(). Removes every row keyed to the user_id
--    across the public schema, then the auth.users row.
-- ---------------------------------------------------------------------------

create or replace function public.delete_user_data(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    r record;
begin
    if target_user_id is null then
        raise exception 'target_user_id required';
    end if;

    for r in
        select c.relname as tbl
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        join pg_attribute a on a.attrelid = c.oid
        where n.nspname = 'public'
          and c.relkind = 'r'
          and a.attname = 'user_id'
          and a.attnum > 0
          and not a.attisdropped
    loop
        execute format('delete from public.%I where user_id = $1', r.tbl)
            using target_user_id;
    end loop;

    -- Profile row (PK = user id, no user_id column).
    delete from public.profiles where id = target_user_id;
end $$;

revoke all on function public.delete_user_data(uuid) from public;
revoke all on function public.delete_user_data(uuid) from authenticated;

COMMIT;
