-- 20260520000000_rls_500_hotfix.sql
--
-- Hotfix for the cluster of HTTP 500s coming out of PostgREST on the
-- messaging / groups / circles surface (Sentry: EPTI-1, trace
-- 2290af35cfc9416cb098ace5b9e73fa8, first seen May 6 ~6:34 PM EDT,
-- release 1.0.0 debug).
--
-- Root cause
-- ----------
-- The previous RLS hardening migrations ship `read_visible` / `admin_update`
-- policies on the membership tables that *select from the same table* the
-- policy protects:
--
--   * public.conversation_participants  -> "conv_participants_read_visible"
--   * public.group_members              -> "group_members_read_visible"
--                                       -> "group_members_admin_update"
--   * public.circle_members             -> "circle_members_read_visible"
--                                       -> "circle_members_admin_update"
--
-- Postgres evaluates the policy, the policy issues another SELECT against
-- the same table, which re-evaluates the policy, etc.  Postgres trips
-- "infinite recursion detected in policy for relation ..." and PostgREST
-- forwards it as a 500.  Every endpoint that joins through these tables
-- (direct_messages, group_messages, circle_messages, ...) inherits the
-- failure even though their own policies are not recursive.
--
-- Fix
-- ---
-- Replace the self-referential EXISTS subqueries with SECURITY DEFINER
-- helper functions owned by `postgres`.  SECURITY DEFINER bypasses RLS
-- on the membership tables when the helper runs, so the policy no longer
-- re-enters itself.  The helpers still take the caller's auth.uid()
-- explicitly, so cross-user reads stay gated to actual members.
--
-- This migration is forward-only and idempotent.  It does NOT loosen any
-- of the existing rules:
--   * conversations / groups / circles are still readable only by
--     participants/members (or public when applicable).
--   * Membership tables still expose only rows the caller is entitled to.
--   * `auth.uid() = user_id` backstops on per-user tables are untouched.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) SECURITY DEFINER membership helpers.
--    All owned by postgres, search_path pinned, EXECUTE granted to
--    authenticated only.  Marked STABLE so the planner can cache.
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
as $$
    select exists (
        select 1
        from public.conversation_participants
        where conversation_id = p_conversation_id
          and user_id = p_user_id
    );
$$;

create or replace function public.is_group_member(
    p_group_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.group_members
        where group_id = p_group_id
          and user_id = p_user_id
    );
$$;

create or replace function public.is_group_admin(
    p_group_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.group_members
        where group_id = p_group_id
          and user_id = p_user_id
          and role in ('Owner', 'Admin')
    );
$$;

create or replace function public.is_group_public(
    p_group_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.groups
        where id = p_group_id
          and privacy = 'Public'
    );
$$;

create or replace function public.is_circle_member(
    p_circle_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.circle_members
        where circle_id = p_circle_id
          and user_id = p_user_id
    );
$$;

create or replace function public.is_circle_admin(
    p_circle_id uuid,
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.circle_members
        where circle_id = p_circle_id
          and user_id = p_user_id
          and role in ('Owner', 'Admin')
    );
$$;

create or replace function public.is_circle_public(
    p_circle_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.circles
        where id = p_circle_id
          and coalesce(is_private, false) = false
    );
$$;

-- Lock down + grant.  authenticated needs EXECUTE so RLS policies can
-- call these.  Service role inherits everything via superuser.
do $$
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
        execute format('alter function public.%s owner to postgres', fn);
        execute format('revoke all on function public.%s from public', fn);
        execute format('revoke all on function public.%s from anon', fn);
        execute format('grant execute on function public.%s to authenticated', fn);
        execute format('grant execute on function public.%s to service_role', fn);
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2) conversation_participants — replace recursive SELECT policy.
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
            using (
                user_id = auth.uid()
                or public.is_conversation_member(conversation_id, auth.uid())
            );
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) conversations — rewrite to call the helper (not a recursion bug, but
--    the EXISTS subquery hits the now-fixed policy via the planner; using
--    the helper is faster and removes the join-time RLS evaluation).
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'conversations'
    ) then
        drop policy if exists "conversations_participant_read" on public.conversations;
        create policy "conversations_participant_read"
            on public.conversations for select
            to authenticated
            using (public.is_conversation_member(id, auth.uid()));

        drop policy if exists "conversations_participant_update" on public.conversations;
        create policy "conversations_participant_update"
            on public.conversations for update
            to authenticated
            using (public.is_conversation_member(id, auth.uid()));
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4) direct_messages — rewrite to call the helper.
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'direct_messages'
    ) then
        drop policy if exists "direct_messages_participant_read" on public.direct_messages;
        create policy "direct_messages_participant_read"
            on public.direct_messages for select
            to authenticated
            using (public.is_conversation_member(conversation_id, auth.uid()));

        drop policy if exists "direct_messages_sender_insert" on public.direct_messages;
        create policy "direct_messages_sender_insert"
            on public.direct_messages for insert
            to authenticated
            with check (
                sender_id = auth.uid()
                and public.is_conversation_member(conversation_id, auth.uid())
            );
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5) group_members — replace BOTH recursive policies (read + admin_update).
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
                or public.is_group_member(group_id, auth.uid())
                or public.is_group_public(group_id)
            );

        drop policy if exists "group_members_admin_update" on public.group_members;
        create policy "group_members_admin_update"
            on public.group_members for update
            to authenticated
            using (
                user_id = auth.uid()
                or public.is_group_admin(group_id, auth.uid())
            );
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6) groups — rewrite to call the helper (consistency + perf).
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'groups'
    ) then
        drop policy if exists "groups_read_public_or_member" on public.groups;
        create policy "groups_read_public_or_member"
            on public.groups for select
            to authenticated
            using (
                privacy = 'Public'
                or public.is_group_member(id, auth.uid())
            );

        drop policy if exists "groups_admin_update" on public.groups;
        create policy "groups_admin_update"
            on public.groups for update
            to authenticated
            using (public.is_group_admin(id, auth.uid()));
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7) group_messages, group_message_likes, group_join_requests — rewrite.
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'group_messages'
    ) then
        drop policy if exists "group_messages_member_read" on public.group_messages;
        create policy "group_messages_member_read"
            on public.group_messages for select
            to authenticated
            using (public.is_group_member(group_id, auth.uid()));

        drop policy if exists "group_messages_member_insert" on public.group_messages;
        create policy "group_messages_member_insert"
            on public.group_messages for insert
            to authenticated
            with check (
                sender_id = auth.uid()
                and public.is_group_member(group_id, auth.uid())
            );
    end if;
end $$;

do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'group_message_likes'
    ) then
        drop policy if exists "group_message_likes_member_read" on public.group_message_likes;
        create policy "group_message_likes_member_read"
            on public.group_message_likes for select
            to authenticated
            using (
                exists (
                    select 1 from public.group_messages gm
                    where gm.id = group_message_likes.message_id
                      and public.is_group_member(gm.group_id, auth.uid())
                )
            );
    end if;
end $$;

do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'group_join_requests'
    ) then
        drop policy if exists "group_join_requests_admin_read" on public.group_join_requests;
        create policy "group_join_requests_admin_read"
            on public.group_join_requests for select
            to authenticated
            using (public.is_group_admin(group_id, auth.uid()));

        drop policy if exists "group_join_requests_admin_update" on public.group_join_requests;
        create policy "group_join_requests_admin_update"
            on public.group_join_requests for update
            to authenticated
            using (public.is_group_admin(group_id, auth.uid()));
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8) circle_members — replace BOTH recursive policies (read + admin_update).
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'circle_members'
    ) then
        drop policy if exists "circle_members_read_visible" on public.circle_members;
        create policy "circle_members_read_visible"
            on public.circle_members for select
            to authenticated
            using (
                user_id = auth.uid()
                or public.is_circle_member(circle_id, auth.uid())
                or public.is_circle_public(circle_id)
            );

        drop policy if exists "circle_members_admin_update" on public.circle_members;
        create policy "circle_members_admin_update"
            on public.circle_members for update
            to authenticated
            using (
                user_id = auth.uid()
                or public.is_circle_admin(circle_id, auth.uid())
            );
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9) circles — rewrite to call the helper.
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'circles'
    ) then
        drop policy if exists "circles_read_public_or_member" on public.circles;
        create policy "circles_read_public_or_member"
            on public.circles for select
            to authenticated
            using (
                coalesce(is_private, false) = false
                or public.is_circle_member(id, auth.uid())
            );

        drop policy if exists "circles_admin_update" on public.circles;
        create policy "circles_admin_update"
            on public.circles for update
            to authenticated
            using (
                auth.uid() = owner_id
                or public.is_circle_admin(id, auth.uid())
            );
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 10) circle_messages, circle_posts, circle_post_comments — rewrite.
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'circle_messages'
    ) then
        drop policy if exists "circle_messages_member_read" on public.circle_messages;
        create policy "circle_messages_member_read"
            on public.circle_messages for select
            to authenticated
            using (public.is_circle_member(circle_id, auth.uid()));

        drop policy if exists "circle_messages_member_insert" on public.circle_messages;
        create policy "circle_messages_member_insert"
            on public.circle_messages for insert
            to authenticated
            with check (
                sender_id = auth.uid()
                and public.is_circle_member(circle_id, auth.uid())
            );
    end if;
end $$;

do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'circle_posts'
    ) then
        drop policy if exists "circle_posts_member_read" on public.circle_posts;
        create policy "circle_posts_member_read"
            on public.circle_posts for select
            to authenticated
            using (public.is_circle_member(circle_id, auth.uid()));

        drop policy if exists "circle_posts_member_insert" on public.circle_posts;
        create policy "circle_posts_member_insert"
            on public.circle_posts for insert
            to authenticated
            with check (
                author_id = auth.uid()
                and public.is_circle_member(circle_id, auth.uid())
            );
    end if;
end $$;

do $$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'circle_post_comments'
    ) then
        drop policy if exists "circle_post_comments_member_read" on public.circle_post_comments;
        create policy "circle_post_comments_member_read"
            on public.circle_post_comments for select
            to authenticated
            using (
                exists (
                    select 1 from public.circle_posts p
                    where p.id = circle_post_comments.post_id
                      and public.is_circle_member(p.circle_id, auth.uid())
                )
            );
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 11) Smoke test under the `authenticated` role so any remaining recursion
--     or missing-grant error trips the migration here, not at runtime.
--     We use a synthetic auth.uid() (the all-zeros UUID, which exists in
--     no row) so the SELECTs must succeed and return zero rows; if any
--     policy still recurses or references a missing column, Postgres will
--     raise immediately and abort the migration.
-- ---------------------------------------------------------------------------
do $$
declare
    tbl text;
    tables text[] := array[
        'conversation_participants',
        'conversations',
        'direct_messages',
        'group_members',
        'groups',
        'group_messages',
        'group_join_requests',
        'circle_members',
        'circles',
        'circle_messages',
        'circle_posts',
        'circle_post_comments',
        'follows',
        'feed_posts'
    ];
    n int;
begin
    -- Pretend to be an authenticated user with a known-impossible UUID.
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
                raise notice 'RLS_HOTFIX smoke: public.% OK (% rows visible to synthetic uid)', tbl, n;
            exception when others then
                raise exception
                    'RLS_HOTFIX smoke FAILED on public.%: % (SQLSTATE %)',
                    tbl, SQLERRM, SQLSTATE;
            end;
        end if;
    end loop;

    -- Reset role for the rest of the transaction.
    perform set_config('role', 'postgres', true);
end $$;

COMMIT;
