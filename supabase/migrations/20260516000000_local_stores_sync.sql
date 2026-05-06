-- =============================================================
-- Mirror four formerly device-local stores into Supabase so they
-- follow the user across devices and account switches:
--   * RoutineStore           (already mirrored — see routines table)
--   * FoodFavoritesService   (already mirrored — see food_favorites)
--   * ConversationMuteStore  → conversation_mutes
--   * LocalModerationStore   → moderation_muted_users
--                            → moderation_muted_tags
--                            → moderation_followed_tags
--                            → moderation_keyword_filters
--                            → moderation_reports
--
-- Every table is RLS-scoped to the owning user. Compound primary
-- keys avoid duplicates without needing a separate uuid column —
-- the sets these mirror are fundamentally "(user, target) is here
-- or it isn't". Idempotent (IF NOT EXISTS / DROP POLICY IF EXISTS).
-- =============================================================

BEGIN;

-- ---------------------------------------------------------------
-- conversation_mutes — silenced direct-message threads
-- ---------------------------------------------------------------
create table if not exists public.conversation_mutes (
    user_id uuid not null references auth.users(id) on delete cascade,
    conversation_id text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, conversation_id)
);

create index if not exists conversation_mutes_user_idx
  on public.conversation_mutes(user_id);

alter table public.conversation_mutes enable row level security;
drop policy if exists "conversation_mutes_self_rw" on public.conversation_mutes;
create policy "conversation_mutes_self_rw" on public.conversation_mutes for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------
-- moderation_muted_users — viewer-side mute of another account
-- ---------------------------------------------------------------
create table if not exists public.moderation_muted_users (
    user_id uuid not null references auth.users(id) on delete cascade,
    target_user_id text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, target_user_id)
);

create index if not exists moderation_muted_users_user_idx
  on public.moderation_muted_users(user_id);

alter table public.moderation_muted_users enable row level security;
drop policy if exists "moderation_muted_users_self_rw" on public.moderation_muted_users;
create policy "moderation_muted_users_self_rw" on public.moderation_muted_users for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------
-- moderation_muted_tags — hashtags the viewer hides
-- ---------------------------------------------------------------
create table if not exists public.moderation_muted_tags (
    user_id uuid not null references auth.users(id) on delete cascade,
    tag text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, tag)
);

create index if not exists moderation_muted_tags_user_idx
  on public.moderation_muted_tags(user_id);

alter table public.moderation_muted_tags enable row level security;
drop policy if exists "moderation_muted_tags_self_rw" on public.moderation_muted_tags;
create policy "moderation_muted_tags_self_rw" on public.moderation_muted_tags for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------
-- moderation_followed_tags — hashtags the viewer subscribed to
-- ---------------------------------------------------------------
create table if not exists public.moderation_followed_tags (
    user_id uuid not null references auth.users(id) on delete cascade,
    tag text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, tag)
);

create index if not exists moderation_followed_tags_user_idx
  on public.moderation_followed_tags(user_id);

alter table public.moderation_followed_tags enable row level security;
drop policy if exists "moderation_followed_tags_self_rw" on public.moderation_followed_tags;
create policy "moderation_followed_tags_self_rw" on public.moderation_followed_tags for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------
-- moderation_keyword_filters — substrings to hide from feeds
-- ---------------------------------------------------------------
create table if not exists public.moderation_keyword_filters (
    user_id uuid not null references auth.users(id) on delete cascade,
    keyword text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, keyword)
);

create index if not exists moderation_keyword_filters_user_idx
  on public.moderation_keyword_filters(user_id);

alter table public.moderation_keyword_filters enable row level security;
drop policy if exists "moderation_keyword_filters_self_rw" on public.moderation_keyword_filters;
create policy "moderation_keyword_filters_self_rw" on public.moderation_keyword_filters for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------
-- moderation_reports — local hides from "Report" actions.
-- target_kind ∈ ('post','comment','message'); target_id is the
-- caller-defined id (post uuid, comment uuid, message id).
-- ---------------------------------------------------------------
create table if not exists public.moderation_reports (
    user_id uuid not null references auth.users(id) on delete cascade,
    target_kind text not null check (target_kind in ('post','comment','message')),
    target_id text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, target_kind, target_id)
);

create index if not exists moderation_reports_user_idx
  on public.moderation_reports(user_id, target_kind);

alter table public.moderation_reports enable row level security;
drop policy if exists "moderation_reports_self_rw" on public.moderation_reports;
create policy "moderation_reports_self_rw" on public.moderation_reports for all to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

COMMIT;
