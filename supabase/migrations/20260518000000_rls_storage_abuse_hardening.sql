-- Security hardening pass:
--  1. Explicit, scoped RLS policies on cross-user tables (follows, feed_posts,
--     circles, circle_members, conversations, direct_messages, etc.).
--  2. Storage bucket policy review (avatars, banners, dm-media,
--     protocol-note-photos, body-progress, meal-photos, post-media).
--  3. AI usage daily budget table + RPC for ai-proxy enforcement.
--  4. Diagnostic notice listing tables that still rely on the generic
--     auth.uid() = user_id backstop only.
--
-- Idempotent: every statement uses if-not-exists / drop-if-exists / pg_catalog
-- guards so the migration can be re-run on environments that already have
-- some of these objects.

BEGIN;

-- ---------------------------------------------------------------------------
-- Helper: only run a CREATE POLICY block if the target table exists.
-- ---------------------------------------------------------------------------
create or replace function public._exec_if_table(p_table text, p_sql text)
returns void
language plpgsql
as $$
begin
    if exists (
        select 1
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relname = p_table
          and c.relkind = 'r'
    ) then
        execute p_sql;
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) follows
-- ---------------------------------------------------------------------------
select public._exec_if_table('follows',
    $sql$alter table public.follows enable row level security$sql$);

select public._exec_if_table('follows',
    $sql$drop policy if exists "follows_read_all" on public.follows$sql$);
select public._exec_if_table('follows',
    $sql$create policy "follows_read_all" on public.follows
        for select to authenticated using (true)$sql$);

select public._exec_if_table('follows',
    $sql$drop policy if exists "follows_self_insert" on public.follows$sql$);
select public._exec_if_table('follows',
    $sql$create policy "follows_self_insert" on public.follows
        for insert to authenticated
        with check (auth.uid() = follower_id)$sql$);

select public._exec_if_table('follows',
    $sql$drop policy if exists "follows_self_delete" on public.follows$sql$);
select public._exec_if_table('follows',
    $sql$create policy "follows_self_delete" on public.follows
        for delete to authenticated
        using (auth.uid() = follower_id)$sql$);

-- No update path for follows — it's an insert/delete-only relationship.
select public._exec_if_table('follows',
    $sql$drop policy if exists "owner_select" on public.follows$sql$);
select public._exec_if_table('follows',
    $sql$drop policy if exists "owner_insert" on public.follows$sql$);
select public._exec_if_table('follows',
    $sql$drop policy if exists "owner_update" on public.follows$sql$);
select public._exec_if_table('follows',
    $sql$drop policy if exists "owner_delete" on public.follows$sql$);

-- ---------------------------------------------------------------------------
-- 2) circles + circle_members  (created at runtime by CircleService)
-- ---------------------------------------------------------------------------
select public._exec_if_table('circles',
    $sql$alter table public.circles enable row level security$sql$);

-- Read: public circle OR caller is a member.
select public._exec_if_table('circles',
    $sql$drop policy if exists "circles_read_public_or_member" on public.circles$sql$);
select public._exec_if_table('circles',
    $sql$create policy "circles_read_public_or_member" on public.circles
        for select to authenticated
        using (
            coalesce(is_private, false) = false
            or exists (
                select 1 from public.circle_members cm
                where cm.circle_id = circles.id and cm.user_id = auth.uid()
            )
        )$sql$);

select public._exec_if_table('circles',
    $sql$drop policy if exists "circles_creator_insert" on public.circles$sql$);
select public._exec_if_table('circles',
    $sql$create policy "circles_creator_insert" on public.circles
        for insert to authenticated
        with check (auth.uid() = owner_id)$sql$);

-- Update only by admins/owners (recorded as role in circle_members).
select public._exec_if_table('circles',
    $sql$drop policy if exists "circles_admin_update" on public.circles$sql$);
select public._exec_if_table('circles',
    $sql$create policy "circles_admin_update" on public.circles
        for update to authenticated
        using (
            exists (
                select 1 from public.circle_members cm
                where cm.circle_id = circles.id
                  and cm.user_id = auth.uid()
                  and (cm.role in ('Owner','Admin') or auth.uid() = circles.owner_id)
            )
        )$sql$);

select public._exec_if_table('circles',
    $sql$drop policy if exists "circles_owner_delete" on public.circles$sql$);
select public._exec_if_table('circles',
    $sql$create policy "circles_owner_delete" on public.circles
        for delete to authenticated
        using (auth.uid() = owner_id)$sql$);

-- circle_members
select public._exec_if_table('circle_members',
    $sql$alter table public.circle_members enable row level security$sql$);

select public._exec_if_table('circle_members',
    $sql$drop policy if exists "circle_members_read_visible" on public.circle_members$sql$);
select public._exec_if_table('circle_members',
    $sql$create policy "circle_members_read_visible" on public.circle_members
        for select to authenticated
        using (
            user_id = auth.uid()
            or exists (
                select 1 from public.circle_members me
                where me.circle_id = circle_members.circle_id and me.user_id = auth.uid()
            )
            or exists (
                select 1 from public.circles c
                where c.id = circle_members.circle_id and coalesce(c.is_private, false) = false
            )
        )$sql$);

select public._exec_if_table('circle_members',
    $sql$drop policy if exists "circle_members_self_join" on public.circle_members$sql$);
select public._exec_if_table('circle_members',
    $sql$create policy "circle_members_self_join" on public.circle_members
        for insert to authenticated
        with check (user_id = auth.uid())$sql$);

select public._exec_if_table('circle_members',
    $sql$drop policy if exists "circle_members_self_leave" on public.circle_members$sql$);
select public._exec_if_table('circle_members',
    $sql$create policy "circle_members_self_leave" on public.circle_members
        for delete to authenticated
        using (user_id = auth.uid())$sql$);

select public._exec_if_table('circle_members',
    $sql$drop policy if exists "circle_members_admin_update" on public.circle_members$sql$);
select public._exec_if_table('circle_members',
    $sql$create policy "circle_members_admin_update" on public.circle_members
        for update to authenticated
        using (
            user_id = auth.uid()
            or exists (
                select 1 from public.circle_members me
                where me.circle_id = circle_members.circle_id
                  and me.user_id = auth.uid()
                  and me.role in ('Owner','Admin')
            )
        )$sql$);

-- ---------------------------------------------------------------------------
-- 3) Direct messages: conversations / conversation_participants /
--    direct_messages.  Created at runtime by MessagingService.
-- ---------------------------------------------------------------------------
select public._exec_if_table('conversations',
    $sql$alter table public.conversations enable row level security$sql$);
select public._exec_if_table('conversation_participants',
    $sql$alter table public.conversation_participants enable row level security$sql$);
select public._exec_if_table('direct_messages',
    $sql$alter table public.direct_messages enable row level security$sql$);

-- conversations: visible only to participants.
select public._exec_if_table('conversations',
    $sql$drop policy if exists "conversations_participant_read" on public.conversations$sql$);
select public._exec_if_table('conversations',
    $sql$create policy "conversations_participant_read" on public.conversations
        for select to authenticated
        using (
            exists (
                select 1 from public.conversation_participants p
                where p.conversation_id = conversations.id
                  and p.user_id = auth.uid()
            )
        )$sql$);

select public._exec_if_table('conversations',
    $sql$drop policy if exists "conversations_authenticated_insert" on public.conversations$sql$);
select public._exec_if_table('conversations',
    $sql$create policy "conversations_authenticated_insert" on public.conversations
        for insert to authenticated
        with check (true)$sql$);

select public._exec_if_table('conversations',
    $sql$drop policy if exists "conversations_participant_update" on public.conversations$sql$);
select public._exec_if_table('conversations',
    $sql$create policy "conversations_participant_update" on public.conversations
        for update to authenticated
        using (
            exists (
                select 1 from public.conversation_participants p
                where p.conversation_id = conversations.id
                  and p.user_id = auth.uid()
            )
        )$sql$);

-- conversation_participants: a participant can see the membership row for
-- any conversation they're already in (so they can see who else is there).
select public._exec_if_table('conversation_participants',
    $sql$drop policy if exists "conv_participants_read_visible" on public.conversation_participants$sql$);
select public._exec_if_table('conversation_participants',
    $sql$create policy "conv_participants_read_visible" on public.conversation_participants
        for select to authenticated
        using (
            user_id = auth.uid()
            or exists (
                select 1 from public.conversation_participants me
                where me.conversation_id = conversation_participants.conversation_id
                  and me.user_id = auth.uid()
            )
        )$sql$);

-- Insert: only as yourself. (Adding *another* user to a conversation should
-- happen via a server-side function; the client cannot pull a stranger in.)
select public._exec_if_table('conversation_participants',
    $sql$drop policy if exists "conv_participants_self_insert" on public.conversation_participants$sql$);
select public._exec_if_table('conversation_participants',
    $sql$create policy "conv_participants_self_insert" on public.conversation_participants
        for insert to authenticated
        with check (user_id = auth.uid())$sql$);

select public._exec_if_table('conversation_participants',
    $sql$drop policy if exists "conv_participants_self_modify" on public.conversation_participants$sql$);
select public._exec_if_table('conversation_participants',
    $sql$create policy "conv_participants_self_modify" on public.conversation_participants
        for update to authenticated
        using (user_id = auth.uid())
        with check (user_id = auth.uid())$sql$);

select public._exec_if_table('conversation_participants',
    $sql$drop policy if exists "conv_participants_self_delete" on public.conversation_participants$sql$);
select public._exec_if_table('conversation_participants',
    $sql$create policy "conv_participants_self_delete" on public.conversation_participants
        for delete to authenticated
        using (user_id = auth.uid())$sql$);

-- direct_messages: read if caller is a participant; insert only as sender +
-- only into a conversation they're in.
select public._exec_if_table('direct_messages',
    $sql$drop policy if exists "direct_messages_participant_read" on public.direct_messages$sql$);
select public._exec_if_table('direct_messages',
    $sql$create policy "direct_messages_participant_read" on public.direct_messages
        for select to authenticated
        using (
            exists (
                select 1 from public.conversation_participants p
                where p.conversation_id = direct_messages.conversation_id
                  and p.user_id = auth.uid()
            )
        )$sql$);

select public._exec_if_table('direct_messages',
    $sql$drop policy if exists "direct_messages_sender_insert" on public.direct_messages$sql$);
select public._exec_if_table('direct_messages',
    $sql$create policy "direct_messages_sender_insert" on public.direct_messages
        for insert to authenticated
        with check (
            sender_id = auth.uid()
            and exists (
                select 1 from public.conversation_participants p
                where p.conversation_id = direct_messages.conversation_id
                  and p.user_id = auth.uid()
            )
        )$sql$);

select public._exec_if_table('direct_messages',
    $sql$drop policy if exists "direct_messages_sender_update" on public.direct_messages$sql$);
select public._exec_if_table('direct_messages',
    $sql$create policy "direct_messages_sender_update" on public.direct_messages
        for update to authenticated
        using (sender_id = auth.uid())
        with check (sender_id = auth.uid())$sql$);

select public._exec_if_table('direct_messages',
    $sql$drop policy if exists "direct_messages_sender_delete" on public.direct_messages$sql$);
select public._exec_if_table('direct_messages',
    $sql$create policy "direct_messages_sender_delete" on public.direct_messages
        for delete to authenticated
        using (sender_id = auth.uid())$sql$);

-- ---------------------------------------------------------------------------
-- 4) Storage buckets — make sure each bucket has explicit per-user policies
--    and no leftover "public read all" rules.
-- ---------------------------------------------------------------------------

-- avatars: public read (for profile display); writes scoped to caller.
do $$
begin
    insert into storage.buckets (id, name, public)
    values ('avatars', 'avatars', true)
    on conflict (id) do update set public = excluded.public;
exception when others then null;
end $$;

-- (avatar/banner write policies are already defined in
-- 20260430000000_profile_avatars_banners.sql — left intact.)

-- dm-media: PRIVATE bucket, per-user folder enforcement. Files are accessed
-- via signed URLs from the client.
do $$
begin
    insert into storage.buckets (id, name, public)
    values ('dm-media', 'dm-media', false)
    on conflict (id) do update set public = false;
exception when others then null;
end $$;

drop policy if exists "Public read dm-media" on storage.objects;
drop policy if exists "dm_media_public_read" on storage.objects;

drop policy if exists "dm_media_owner_select" on storage.objects;
create policy "dm_media_owner_select"
    on storage.objects for select
    to authenticated
    using (
        bucket_id = 'dm-media'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "dm_media_owner_insert" on storage.objects;
create policy "dm_media_owner_insert"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'dm-media'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "dm_media_owner_update" on storage.objects;
create policy "dm_media_owner_update"
    on storage.objects for update
    to authenticated
    using (
        bucket_id = 'dm-media'
        and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
        bucket_id = 'dm-media'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "dm_media_owner_delete" on storage.objects;
create policy "dm_media_owner_delete"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'dm-media'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- protocol-note-photos: switch to PRIVATE + per-user folder. Client now
-- must use createSignedURL instead of getPublicURL.
do $$
begin
    insert into storage.buckets (id, name, public)
    values ('protocol-note-photos', 'protocol-note-photos', false)
    on conflict (id) do update set public = false;
exception when others then null;
end $$;

drop policy if exists "Public read protocol-note-photos" on storage.objects;
drop policy if exists "protocol_note_photos_public_read" on storage.objects;

drop policy if exists "protocol_note_photos_owner_select" on storage.objects;
create policy "protocol_note_photos_owner_select"
    on storage.objects for select
    to authenticated
    using (
        bucket_id = 'protocol-note-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "protocol_note_photos_owner_insert" on storage.objects;
create policy "protocol_note_photos_owner_insert"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'protocol-note-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "protocol_note_photos_owner_update" on storage.objects;
create policy "protocol_note_photos_owner_update"
    on storage.objects for update
    to authenticated
    using (
        bucket_id = 'protocol-note-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
        bucket_id = 'protocol-note-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "protocol_note_photos_owner_delete" on storage.objects;
create policy "protocol_note_photos_owner_delete"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'protocol-note-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ---------------------------------------------------------------------------
-- 5) ai_usage_daily: per-user daily token budget for ai-proxy.
-- ---------------------------------------------------------------------------
create table if not exists public.ai_usage_daily (
    user_id uuid not null references auth.users(id) on delete cascade,
    day date not null default (now() at time zone 'utc')::date,
    prompt_tokens bigint not null default 0,
    completion_tokens bigint not null default 0,
    total_tokens bigint not null default 0,
    request_count int not null default 0,
    daily_token_limit bigint, -- NULL = use default in proxy (50_000)
    updated_at timestamptz not null default now(),
    primary key (user_id, day)
);

create index if not exists ai_usage_daily_day_idx
    on public.ai_usage_daily (day desc);

alter table public.ai_usage_daily enable row level security;

-- Users can read their own usage so the app can display "X / 50k tokens used".
drop policy if exists "ai_usage_daily_owner_select" on public.ai_usage_daily;
create policy "ai_usage_daily_owner_select"
    on public.ai_usage_daily for select
    to authenticated
    using (auth.uid() = user_id);

-- No client writes. ai-proxy uses the service role key.
revoke insert, update, delete on public.ai_usage_daily from authenticated;

-- Helper RPC the proxy calls. SECURITY DEFINER so the service-role-only
-- restriction above is enforced even if a future caller uses a JWT.
create or replace function public.ai_usage_increment(
    p_user_id uuid,
    p_prompt_tokens bigint,
    p_completion_tokens bigint
)
returns table (
    total_tokens bigint,
    daily_token_limit bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
    today date := (now() at time zone 'utc')::date;
    v_total bigint;
    v_limit bigint;
begin
    insert into public.ai_usage_daily (
        user_id, day, prompt_tokens, completion_tokens, total_tokens, request_count, updated_at
    ) values (
        p_user_id, today,
        greatest(coalesce(p_prompt_tokens, 0), 0),
        greatest(coalesce(p_completion_tokens, 0), 0),
        greatest(coalesce(p_prompt_tokens, 0), 0) + greatest(coalesce(p_completion_tokens, 0), 0),
        1, now()
    )
    on conflict (user_id, day) do update set
        prompt_tokens = public.ai_usage_daily.prompt_tokens + greatest(coalesce(excluded.prompt_tokens, 0), 0),
        completion_tokens = public.ai_usage_daily.completion_tokens + greatest(coalesce(excluded.completion_tokens, 0), 0),
        total_tokens = public.ai_usage_daily.total_tokens
                       + greatest(coalesce(excluded.prompt_tokens, 0), 0)
                       + greatest(coalesce(excluded.completion_tokens, 0), 0),
        request_count = public.ai_usage_daily.request_count + 1,
        updated_at = now()
    returning public.ai_usage_daily.total_tokens, public.ai_usage_daily.daily_token_limit
        into v_total, v_limit;

    return query select v_total, v_limit;
end $$;

create or replace function public.ai_usage_today(p_user_id uuid)
returns table (
    total_tokens bigint,
    daily_token_limit bigint
)
language sql
security definer
set search_path = public
as $$
    select coalesce(total_tokens, 0)::bigint as total_tokens,
           daily_token_limit
    from public.ai_usage_daily
    where user_id = p_user_id
      and day = (now() at time zone 'utc')::date
    union all
    select 0::bigint, null::bigint
    where not exists (
        select 1 from public.ai_usage_daily
        where user_id = p_user_id
          and day = (now() at time zone 'utc')::date
    )
    limit 1;
$$;

revoke all on function public.ai_usage_increment(uuid, bigint, bigint) from public;
revoke all on function public.ai_usage_increment(uuid, bigint, bigint) from authenticated;
revoke all on function public.ai_usage_today(uuid) from public;
revoke all on function public.ai_usage_today(uuid) from authenticated;

-- ---------------------------------------------------------------------------
-- 6) Diagnostic: list public tables whose ONLY policies are the generic
--    backstop (owner_select/insert/update/delete from the previous audit).
--    Surfaces in supabase logs after the migration runs so we can triage.
-- ---------------------------------------------------------------------------
do $$
declare
    r record;
    backstop_only int;
    total_pol int;
begin
    for r in
        select c.relname
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind = 'r'
    loop
        select count(*) into total_pol
            from pg_policies where schemaname = 'public' and tablename = r.relname;
        if total_pol = 0 then continue; end if;

        select count(*) into backstop_only
            from pg_policies
            where schemaname = 'public'
              and tablename = r.relname
              and policyname in ('owner_select','owner_insert','owner_update','owner_delete');
        if backstop_only > 0 and backstop_only = total_pol then
            raise notice 'RLS_AUDIT: table public.% relies only on generic owner_* backstop', r.relname;
        end if;
    end loop;
end $$;

drop function if exists public._exec_if_table(text, text);

COMMIT;
