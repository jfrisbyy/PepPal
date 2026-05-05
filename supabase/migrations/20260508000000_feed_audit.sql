-- ============================================================
-- Feed audit: ensure all feed-related tables, RPCs, storage,
-- triggers, and indexes exist for production. Fully idempotent;
-- safe to run on top of existing schema.
-- ============================================================

-- ============================================================
-- feed_posts
-- ============================================================
create table if not exists public.feed_posts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    text_content text not null default '',
    media_urls text[],
    audio_url text,
    audio_duration double precision,
    tags text[],
    hashtags text[] not null default array[]::text[],
    high_five_count int not null default 0,
    repost_count int not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    edited_at timestamptz
);

-- Make sure missing columns are added on existing schemas
alter table public.feed_posts add column if not exists hashtags text[] not null default array[]::text[];
alter table public.feed_posts add column if not exists high_five_count int not null default 0;
alter table public.feed_posts add column if not exists repost_count int not null default 0;
alter table public.feed_posts add column if not exists edited_at timestamptz;
alter table public.feed_posts add column if not exists audio_url text;
alter table public.feed_posts add column if not exists audio_duration double precision;
alter table public.feed_posts add column if not exists tags text[];
alter table public.feed_posts add column if not exists media_urls text[];

create index if not exists feed_posts_user_idx on public.feed_posts(user_id, created_at desc);
create index if not exists feed_posts_created_idx on public.feed_posts(created_at desc);
create index if not exists feed_posts_tags_gin on public.feed_posts using gin(tags);
create index if not exists feed_posts_hashtags_gin on public.feed_posts using gin(hashtags);
create index if not exists feed_posts_text_trgm on public.feed_posts using gin(text_content gin_trgm_ops);

create extension if not exists pg_trgm;

alter table public.feed_posts enable row level security;

drop policy if exists "feed_posts_read_all" on public.feed_posts;
create policy "feed_posts_read_all"
on public.feed_posts for select to authenticated
using (true);

drop policy if exists "feed_posts_self_insert" on public.feed_posts;
create policy "feed_posts_self_insert"
on public.feed_posts for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "feed_posts_self_update" on public.feed_posts;
create policy "feed_posts_self_update"
on public.feed_posts for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "feed_posts_self_delete" on public.feed_posts;
create policy "feed_posts_self_delete"
on public.feed_posts for delete to authenticated
using (auth.uid() = user_id);

-- Auto-extract hashtags from text_content (so "#cardio" in body is searchable)
create or replace function public.feed_posts_extract_hashtags()
returns trigger
language plpgsql
as $$
declare
    raw text[];
begin
    raw := array(
        select distinct lower(substring(m[1] from 2))
        from regexp_matches(coalesce(new.text_content, ''), '#([A-Za-z0-9_-]+)', 'g') as m
    );
    new.hashtags := coalesce(raw, array[]::text[]);
    return new;
end;
$$;

drop trigger if exists feed_posts_extract_hashtags_trg on public.feed_posts;
create trigger feed_posts_extract_hashtags_trg
before insert or update of text_content on public.feed_posts
for each row execute function public.feed_posts_extract_hashtags();

-- ============================================================
-- post_comments (canonical column: content)
-- ============================================================
create table if not exists public.post_comments (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references public.feed_posts(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    content text not null default '',
    created_at timestamptz not null default now()
);

alter table public.post_comments add column if not exists content text not null default '';

create index if not exists post_comments_post_idx on public.post_comments(post_id, created_at asc);
create index if not exists post_comments_user_idx on public.post_comments(user_id, created_at desc);

alter table public.post_comments enable row level security;

drop policy if exists "post_comments_read_all" on public.post_comments;
create policy "post_comments_read_all"
on public.post_comments for select to authenticated using (true);

drop policy if exists "post_comments_self_insert" on public.post_comments;
create policy "post_comments_self_insert"
on public.post_comments for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "post_comments_self_update" on public.post_comments;
create policy "post_comments_self_update"
on public.post_comments for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "post_comments_self_delete" on public.post_comments;
create policy "post_comments_self_delete"
on public.post_comments for delete to authenticated
using (auth.uid() = user_id);

-- ============================================================
-- post_likes
-- ============================================================
create table if not exists public.post_likes (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references public.feed_posts(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (post_id, user_id)
);

create index if not exists post_likes_user_idx on public.post_likes(user_id);
create index if not exists post_likes_post_idx on public.post_likes(post_id);

alter table public.post_likes enable row level security;

drop policy if exists "post_likes_read_all" on public.post_likes;
create policy "post_likes_read_all"
on public.post_likes for select to authenticated using (true);

drop policy if exists "post_likes_self_insert" on public.post_likes;
create policy "post_likes_self_insert"
on public.post_likes for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "post_likes_self_delete" on public.post_likes;
create policy "post_likes_self_delete"
on public.post_likes for delete to authenticated
using (auth.uid() = user_id);

-- ============================================================
-- post_reposts
-- ============================================================
create table if not exists public.post_reposts (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references public.feed_posts(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (post_id, user_id)
);

create index if not exists post_reposts_user_idx on public.post_reposts(user_id);
create index if not exists post_reposts_post_idx on public.post_reposts(post_id);

alter table public.post_reposts enable row level security;

drop policy if exists "post_reposts_read_all" on public.post_reposts;
create policy "post_reposts_read_all"
on public.post_reposts for select to authenticated using (true);

drop policy if exists "post_reposts_self_insert" on public.post_reposts;
create policy "post_reposts_self_insert"
on public.post_reposts for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "post_reposts_self_delete" on public.post_reposts;
create policy "post_reposts_self_delete"
on public.post_reposts for delete to authenticated
using (auth.uid() = user_id);

-- ============================================================
-- Count maintenance: triggers (authoritative) + RPCs (legacy
-- callers from the app). Both are safe; triggers always reconcile.
-- ============================================================
create or replace function public.feed_posts_recount_likes(p_id uuid)
returns void language sql as $$
    update public.feed_posts
       set high_five_count = (select count(*) from public.post_likes where post_id = p_id)
     where id = p_id;
$$;

create or replace function public.feed_posts_recount_reposts(p_id uuid)
returns void language sql as $$
    update public.feed_posts
       set repost_count = (select count(*) from public.post_reposts where post_id = p_id)
     where id = p_id;
$$;

create or replace function public.post_likes_after_change()
returns trigger language plpgsql as $$
begin
    if tg_op = 'INSERT' then
        perform public.feed_posts_recount_likes(new.post_id);
    elsif tg_op = 'DELETE' then
        perform public.feed_posts_recount_likes(old.post_id);
    end if;
    return null;
end;
$$;

drop trigger if exists post_likes_after_change_trg on public.post_likes;
create trigger post_likes_after_change_trg
after insert or delete on public.post_likes
for each row execute function public.post_likes_after_change();

create or replace function public.post_reposts_after_change()
returns trigger language plpgsql as $$
begin
    if tg_op = 'INSERT' then
        perform public.feed_posts_recount_reposts(new.post_id);
    elsif tg_op = 'DELETE' then
        perform public.feed_posts_recount_reposts(old.post_id);
    end if;
    return null;
end;
$$;

drop trigger if exists post_reposts_after_change_trg on public.post_reposts;
create trigger post_reposts_after_change_trg
after insert or delete on public.post_reposts
for each row execute function public.post_reposts_after_change();

-- Legacy RPCs the iOS app already calls — kept as no-op safe wrappers
-- so older clients don't error. The triggers above are authoritative.
create or replace function public.increment_high_five_count(row_id uuid)
returns void language sql as $$
    select public.feed_posts_recount_likes(row_id);
$$;

create or replace function public.decrement_high_five_count(row_id uuid)
returns void language sql as $$
    select public.feed_posts_recount_likes(row_id);
$$;

create or replace function public.increment_repost_count(row_id uuid)
returns void language sql as $$
    select public.feed_posts_recount_reposts(row_id);
$$;

create or replace function public.decrement_repost_count(row_id uuid)
returns void language sql as $$
    select public.feed_posts_recount_reposts(row_id);
$$;

grant execute on function public.increment_high_five_count(uuid) to authenticated;
grant execute on function public.decrement_high_five_count(uuid) to authenticated;
grant execute on function public.increment_repost_count(uuid) to authenticated;
grant execute on function public.decrement_repost_count(uuid) to authenticated;

-- ============================================================
-- post-media storage bucket (public read; per-user write prefix)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('post-media', 'post-media', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Public read post-media" on storage.objects;
create policy "Public read post-media"
on storage.objects for select
using (bucket_id = 'post-media');

drop policy if exists "Users insert own post-media" on storage.objects;
create policy "Users insert own post-media"
on storage.objects for insert to authenticated
with check (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users update own post-media" on storage.objects;
create policy "Users update own post-media"
on storage.objects for update to authenticated
using (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users delete own post-media" on storage.objects;
create policy "Users delete own post-media"
on storage.objects for delete to authenticated
using (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================
-- Realtime publications for live feed updates
-- ============================================================
do $$
begin
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'feed_posts'
    ) then
        execute 'alter publication supabase_realtime add table public.feed_posts';
    end if;
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_comments'
    ) then
        execute 'alter publication supabase_realtime add table public.post_comments';
    end if;
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_likes'
    ) then
        execute 'alter publication supabase_realtime add table public.post_likes';
    end if;
exception when others then
    -- publication may not exist on local dev; ignore
    null;
end $$;

-- ============================================================
-- One-time backfill of hashtags + counts on existing rows
-- ============================================================
update public.feed_posts
   set text_content = text_content
 where hashtags is null or array_length(hashtags, 1) is null;

update public.feed_posts fp
   set high_five_count = coalesce((select count(*) from public.post_likes pl where pl.post_id = fp.id), 0),
       repost_count    = coalesce((select count(*) from public.post_reposts pr where pr.post_id = fp.id), 0);
