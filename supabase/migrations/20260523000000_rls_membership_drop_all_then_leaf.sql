-- 20260523000000_rls_membership_drop_all_then_leaf.sql
--
-- Follow-up to 20260522000000_rls_membership_leaf_only.sql.
--
-- Smoke kept failing with "infinite recursion detected in policy for relation
-- circle_members" even after we added a strictly-leaf SELECT policy. Reason:
-- Postgres OR's together ALL permissive policies of the same command on a
-- relation. Earlier migrations (rls_audit_and_hardening, rls_500_hotfix,
-- rls_membership_recursion_fix) each created their own SELECT policies on
-- circle_members / group_members / conversation_participants under different
-- names. The leaf policy we added doesn't replace them — it just unions with
-- them — so the old recursive expressions keep firing.
--
-- This migration enumerates and DROPS every existing permissive policy on the
-- three membership tables, then re-creates exactly one SELECT, one
-- INSERT/DELETE for self, and one UPDATE-self policy each. All strictly leaf.
-- Cross-row visibility for "list members of a circle/group" continues to flow
-- through the SECURITY DEFINER RPCs (`list_circle_members`, `list_group_members`).
--
-- Forward-only, idempotent.

BEGIN;

-- ---------------------------------------------------------------------------
-- Helper: drop every policy on a public table.
-- ---------------------------------------------------------------------------
do $outer$
declare
    tbl text;
    pol record;
    membership_tables text[] := array[
        'circle_members',
        'group_members',
        'conversation_participants'
    ];
begin
    foreach tbl in array membership_tables loop
        if exists (
            select 1 from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relname = tbl
        ) then
            for pol in
                select polname
                from pg_policy p
                join pg_class c on c.oid = p.polrelid
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relname = tbl
            loop
                execute format(
                    'drop policy if exists %I on public.%I',
                    pol.polname, tbl
                );
            end loop;
        end if;
    end loop;
end
$outer$;

-- ---------------------------------------------------------------------------
-- circle_members — leaf-only policies.
-- ---------------------------------------------------------------------------
do $body$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'circle_members'
    ) then
        execute 'alter table public.circle_members enable row level security';

        execute $p$
            create policy "circle_members_select_self"
                on public.circle_members for select
                to authenticated
                using (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "circle_members_insert_self"
                on public.circle_members for insert
                to authenticated
                with check (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "circle_members_update_self"
                on public.circle_members for update
                to authenticated
                using (user_id = auth.uid())
                with check (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "circle_members_delete_self"
                on public.circle_members for delete
                to authenticated
                using (user_id = auth.uid())
        $p$;
    end if;
end
$body$;

-- ---------------------------------------------------------------------------
-- group_members — leaf-only policies.
-- ---------------------------------------------------------------------------
do $body$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'group_members'
    ) then
        execute 'alter table public.group_members enable row level security';

        execute $p$
            create policy "group_members_select_self"
                on public.group_members for select
                to authenticated
                using (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "group_members_insert_self"
                on public.group_members for insert
                to authenticated
                with check (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "group_members_update_self"
                on public.group_members for update
                to authenticated
                using (user_id = auth.uid())
                with check (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "group_members_delete_self"
                on public.group_members for delete
                to authenticated
                using (user_id = auth.uid())
        $p$;
    end if;
end
$body$;

-- ---------------------------------------------------------------------------
-- conversation_participants — leaf-only policies.
-- ---------------------------------------------------------------------------
do $body$
begin
    if exists (
        select 1 from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'conversation_participants'
    ) then
        execute 'alter table public.conversation_participants enable row level security';

        execute $p$
            create policy "conv_participants_select_self"
                on public.conversation_participants for select
                to authenticated
                using (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "conv_participants_insert_self"
                on public.conversation_participants for insert
                to authenticated
                with check (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "conv_participants_update_self"
                on public.conversation_participants for update
                to authenticated
                using (user_id = auth.uid())
                with check (user_id = auth.uid())
        $p$;

        execute $p$
            create policy "conv_participants_delete_self"
                on public.conversation_participants for delete
                to authenticated
                using (user_id = auth.uid())
        $p$;
    end if;
end
$body$;

-- ---------------------------------------------------------------------------
-- Smoke test under the `authenticated` role with a synthetic uid.
-- ---------------------------------------------------------------------------
do $smoke$
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
                raise notice 'RLS_DROP_THEN_LEAF smoke: public.% OK (% rows)', tbl, n;
            exception when others then
                perform set_config('role', 'postgres', true);
                raise exception
                    'RLS_DROP_THEN_LEAF smoke FAILED on public.%: % (SQLSTATE %)',
                    tbl, SQLERRM, SQLSTATE;
            end;
        end if;
    end loop;

    perform set_config('role', 'postgres', true);
end
$smoke$;

COMMIT;
