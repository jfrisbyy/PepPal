-- 20260522000000_rls_membership_leaf_only.sql
--
-- Follow-up to 20260521000000_rls_membership_recursion_fix.sql.
--
-- The previous attempt made the circle_members / group_members SELECT policy
-- "user_id = auth.uid() OR <parent_is_public>(parent_id)". On paper that's
-- non-recursive, but in this Supabase environment SECURITY DEFINER helpers
-- with `SET row_security = off` do NOT actually bypass RLS during policy
-- evaluation, so the chain becomes:
--
--   select from circle_members
--     -> circle_members SELECT policy calls is_circle_public(circle_id)
--     -> is_circle_public queries circles
--     -> circles SELECT policy calls is_circle_member(id, auth.uid())
--     -> is_circle_member queries circle_members
--     -> re-enters circle_members SELECT policy -> RECURSION
--
-- The only way to break the chain without relying on a working RLS bypass is
-- to make the membership SELECT policies *strictly leaf*: they touch nothing
-- but their own row. Cross-row visibility ("show me everyone in this
-- circle") already goes through the SECURITY DEFINER RPCs created in the
-- previous migration (`list_circle_members`, `list_group_members`), so the
-- product surface doesn't regress.
--
-- Forward-only, idempotent.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) circle_members — strictly leaf SELECT.
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
            using (user_id = auth.uid());

        drop policy if exists "circle_members_admin_update" on public.circle_members;
        create policy "circle_members_admin_update"
            on public.circle_members for update
            to authenticated
            using (user_id = auth.uid())
            with check (user_id = auth.uid());
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) group_members — strictly leaf SELECT.
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
            using (user_id = auth.uid());

        drop policy if exists "group_members_admin_update" on public.group_members;
        create policy "group_members_admin_update"
            on public.group_members for update
            to authenticated
            using (user_id = auth.uid())
            with check (user_id = auth.uid());
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) conversation_participants — already leaf in the previous migration,
--    re-assert defensively in case an older policy snuck back in.
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
-- 4) Smoke test under the `authenticated` role with a synthetic uid.
--    Exercises every table whose policy references one of the membership
--    tables — if the chain still recurses anywhere we want to know now.
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
                raise notice 'RLS_LEAF_FIX smoke: public.% OK (% rows)', tbl, n;
            exception when others then
                perform set_config('role', 'postgres', true);
                raise exception
                    'RLS_LEAF_FIX smoke FAILED on public.%: % (SQLSTATE %)',
                    tbl, SQLERRM, SQLSTATE;
            end;
        end if;
    end loop;

    perform set_config('role', 'postgres', true);
end $$;

COMMIT;
