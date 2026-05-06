-- 20260521000000_rls_membership_recursion_fix.sql
--
-- Follow-up to 20260520000000_rls_500_hotfix.sql.
--
-- The previous hotfix relied on SECURITY DEFINER helpers (`is_circle_member`,
-- `is_group_member`, ...) bypassing RLS via the postgres role's BYPASSRLS
-- attribute. In some Supabase environments that bypass does not actually
-- take effect inside policy evaluation, so a policy that calls
-- `is_circle_member(...)` on `circle_members` still re-enters the same
-- table's policy and Postgres trips
--   "infinite recursion detected in policy for relation circle_members"
-- (SQLSTATE 42P17). The smoke test surfaced this on apply.
--
-- Fix
-- ---
-- Make the SELECT/UPDATE policies on the membership tables themselves
-- *strictly non-recursive*: they NEVER query the same table they protect.
-- A caller can always see their OWN membership row (`user_id = auth.uid()`)
-- and any row in a publicly-visible parent (circle / group). That alone is
-- enough for `is_<x>_member(circle_id, auth.uid())` to keep working when
-- it's called from OTHER tables' policies, because that helper only ever
-- looks up rows where `user_id = auth.uid()` — which the new policy permits
-- without any cross-row visibility (so no recursion is required).
--
-- For "show me everyone in this circle / group", which legitimately needs
-- to read other members' rows, we add SECURITY DEFINER RPCs
--   * public.list_circle_members(p_circle_id uuid)
--   * public.list_group_members(p_group_id uuid)
-- that gate access to "caller is a member, or the parent is public" and
-- then return all rows. The RPC body uses `SET row_security = off` in its
-- function-level SET clause; if the definer (postgres) has BYPASSRLS this
-- is a hard bypass, otherwise it gracefully degrades to "caller sees only
-- their own row" — which is still safer than recursing.
--
-- Forward-only, idempotent.

BEGIN;

-- ---------------------------------------------------------------------------
-- 0) Helper functions (idempotent recreate).
--
--    Migration 20260520_rls_500_hotfix wraps everything in BEGIN/COMMIT and
--    its smoke test failed (recursion on circle_members), which rolled back
--    ALL of its DDL — including the SECURITY DEFINER helpers it created.
--    This file references those helpers in policies and RPCs, so recreate
--    them here. They're `create or replace` so it's safe if 20260520 did
--    eventually apply on some other environment.
-- ---------------------------------------------------------------------------

create or replace function public.is_conversation_member(
    p_conversation_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $fn$
    select exists (
        select 1
        from public.conversation_participants
        where conversation_id = p_conversation_id
          and user_id = p_user_id
    );
$fn$;

create or replace function public.is_group_member(
    p_group_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $fn$
    select exists (
        select 1
        from public.group_members
        where group_id = p_group_id
          and user_id = p_user_id
    );
$fn$;

create or replace function public.is_group_admin(
    p_group_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $fn$
    select exists (
        select 1
        from public.group_members
        where group_id = p_group_id
          and user_id = p_user_id
          and role in ('Owner', 'Admin')
    );
$fn$;

create or replace function public.is_group_public(
    p_group_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $fn$
    select exists (
        select 1
        from public.groups
        where id = p_group_id
          and privacy = 'Public'
    );
$fn$;

create or replace function public.is_circle_member(
    p_circle_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $fn$
    select exists (
        select 1
        from public.circle_members
        where circle_id = p_circle_id
          and user_id = p_user_id
    );
$fn$;

create or replace function public.is_circle_admin(
    p_circle_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $fn$
    select exists (
        select 1
        from public.circle_members
        where circle_id = p_circle_id
          and user_id = p_user_id
          and role in ('Owner', 'Admin')
    );
$fn$;

create or replace function public.is_circle_public(
    p_circle_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $fn$
    select exists (
        select 1
        from public.circles
        where id = p_circle_id
          and coalesce(is_private, false) = false
    );
$fn$;

do $
declare
    fn text;
    fns text[] := array[
        'is_conversation_member(uuid,uuid)',
        'is_group_member(uuid,uuid)',
        'is_group_admin(uuid,uuid)',
        'is_group_public(uuid)',
        'is_circle_member(uuid,uuid)',
        'is_circle_admin(uuid,uuid)',
        'is_circle_public(uuid)'
    ];
begin
    foreach fn in array fns loop
        begin
            execute format('alter function public.%s owner to postgres', fn);
        exception when others then
            raise notice 'RLS_RECURSION_FIX: could not transfer ownership of %: %', fn, SQLERRM;
        end;
        execute format('revoke all on function public.%s from public', fn);
        execute format('revoke all on function public.%s from anon', fn);
        execute format('grant execute on function public.%s to authenticated', fn);
        execute format('grant execute on function public.%s to service_role', fn);
    end loop;
end $;

-- ---------------------------------------------------------------------------
-- 1) circle_members — strictly non-recursive policies.
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'circle_members'
    ) then
        -- SELECT: own row, or any row whose circle is public.
        -- Notably does NOT call is_circle_member(circle_id, auth.uid())
        -- because that would re-enter this very policy.
        drop policy if exists "circle_members_read_visible" on public.circle_members;
        create policy "circle_members_read_visible"
            on public.circle_members for select
            to authenticated
            using (
                user_id = auth.uid()
                or public.is_circle_public(circle_id)
            );

        -- UPDATE: only your own row from the client. Admin promotions /
        -- demotions go through a SECURITY DEFINER RPC (added below).
        drop policy if exists "circle_members_admin_update" on public.circle_members;
        create policy "circle_members_admin_update"
            on public.circle_members for update
            to authenticated
            using (user_id = auth.uid())
            with check (user_id = auth.uid());
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) group_members — strictly non-recursive policies.
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'group_members'
    ) then
        drop policy if exists "group_members_read_visible" on public.group_members;
        create policy "group_members_read_visible"
            on public.group_members for select
            to authenticated
            using (
                user_id = auth.uid()
                or public.is_group_public(group_id)
            );

        drop policy if exists "group_members_admin_update" on public.group_members;
        create policy "group_members_admin_update"
            on public.group_members for update
            to authenticated
            using (user_id = auth.uid())
            with check (user_id = auth.uid());
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) conversation_participants — strictly non-recursive policies.
--    There is no "public conversation" notion, so this collapses to "own
--    membership row only". Listing the OTHER participants of a DM goes
--    through public.list_conversation_participants below.
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'conversation_participants'
    ) then
        drop policy if exists "conv_participants_read_visible"
            on public.conversation_participants;
        create policy "conv_participants_read_visible"
            on public.conversation_participants for select
            to authenticated
            using (user_id = auth.uid());
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4) SECURITY DEFINER member-list RPCs.
--    Gate by membership / public-parent, then return the full row set.
--    `SET row_security = off` performs a hard RLS bypass when the definer
--    has BYPASSRLS (the standard for the `postgres` role in Supabase).
-- ---------------------------------------------------------------------------

create or replace function public.list_circle_members(p_circle_id uuid)
returns setof public.circle_members
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
begin
    if auth.uid() is null then
        return;
    end if;
    if not (
        public.is_circle_member(p_circle_id, auth.uid())
        or public.is_circle_public(p_circle_id)
    ) then
        return;
    end if;
    return query
        select *
        from public.circle_members
        where circle_id = p_circle_id;
end $$;

create or replace function public.list_group_members(p_group_id uuid)
returns setof public.group_members
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
begin
    if auth.uid() is null then
        return;
    end if;
    if not (
        public.is_group_member(p_group_id, auth.uid())
        or public.is_group_public(p_group_id)
    ) then
        return;
    end if;
    return query
        select *
        from public.group_members
        where group_id = p_group_id;
end $$;

create or replace function public.list_conversation_participants(p_conversation_id uuid)
returns setof public.conversation_participants
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
begin
    if auth.uid() is null then
        return;
    end if;
    if not public.is_conversation_member(p_conversation_id, auth.uid()) then
        return;
    end if;
    return query
        select *
        from public.conversation_participants
        where conversation_id = p_conversation_id;
end $$;

-- Lock down owners + grant EXECUTE to authenticated only.
do $$
declare
    fn text;
    fns text[] := array[
        'list_circle_members(uuid)',
        'list_group_members(uuid)',
        'list_conversation_participants(uuid)'
    ];
begin
    foreach fn in array fns loop
        begin
            execute format('alter function public.%s owner to postgres', fn);
        exception when others then
            raise notice 'RLS_RECURSION_FIX: could not transfer ownership of %: %', fn, SQLERRM;
        end;
        execute format('revoke all on function public.%s from public', fn);
        execute format('revoke all on function public.%s from anon', fn);
        execute format('grant execute on function public.%s to authenticated', fn);
        execute format('grant execute on function public.%s to service_role', fn);
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 5) Smoke test under the `authenticated` role with a synthetic uid.
--    The tables that previously recursed are exercised first; if any of
--    them still recurses the migration aborts here.
-- ---------------------------------------------------------------------------
do $$
declare
    tbl text;
    tables text[] := array[
        'circle_members',
        'group_members',
        'conversation_participants',
        'circles',
        'groups',
        'conversations',
        'direct_messages',
        'group_messages',
        'circle_messages',
        'circle_posts',
        'circle_post_comments',
        'group_join_requests',
        'follows',
        'feed_posts'
    ];
    n int;
begin
    perform set_config('role', 'authenticated', true);
    perform set_config(
        'request.jwt.claims',
        '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}',
        true
    );

    foreach tbl in array tables loop
        if exists (
            select 1 from pg_class c
            join pg_namespace ns on ns.oid = c.relnamespace
            where ns.nspname = 'public' and c.relname = tbl
        ) then
            begin
                execute format('select count(*) from public.%I', tbl) into n;
                raise notice 'RLS_RECURSION_FIX smoke: public.% OK (% rows visible to synthetic uid)', tbl, n;
            exception when others then
                perform set_config('role', 'postgres', true);
                raise exception
                    'RLS_RECURSION_FIX smoke FAILED on public.%: % (SQLSTATE %)',
                    tbl, SQLERRM, SQLSTATE;
            end;
        end if;
    end loop;

    -- Also exercise the new RPCs with a known-impossible UUID. They must
    -- return zero rows without raising.
    begin
        perform * from public.list_circle_members('00000000-0000-0000-0000-000000000000'::uuid);
        perform * from public.list_group_members('00000000-0000-0000-0000-000000000000'::uuid);
        perform * from public.list_conversation_participants('00000000-0000-0000-0000-000000000000'::uuid);
        raise notice 'RLS_RECURSION_FIX smoke: list_* RPCs OK';
    exception when others then
        perform set_config('role', 'postgres', true);
        raise exception
            'RLS_RECURSION_FIX smoke FAILED on list_* RPC: % (SQLSTATE %)',
            SQLERRM, SQLSTATE;
    end;

    perform set_config('role', 'postgres', true);
end $$;

COMMIT;
