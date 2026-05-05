-- ============================================================
-- Real persistence migration: replaces local mock/UserDefaults
-- backing for Groups, Circles, PRs, Routines, Compound tracking,
-- Food favorites, AI memory facts, and tracked compounds.
-- ============================================================

-- ============================================================
-- Personal Records
-- ============================================================
create table if not exists public.personal_records (
    user_id uuid not null references auth.users(id) on delete cascade,
    exercise_id text not null,
    exercise_name text not null,
    best_weight double precision not null default 0,
    best_one_rm double precision not null default 0,
    best_volume double precision not null default 0,
    updated_at timestamptz not null default now(),
    primary key (user_id, exercise_id)
);

alter table public.personal_records enable row level security;

drop policy if exists "personal_records_self_rw" on public.personal_records;
create policy "personal_records_self_rw"
on public.personal_records for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- Workout Routines
-- ============================================================
create table if not exists public.routines (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    notes text not null default '',
    exercises jsonb not null default '[]'::jsonb,
    times_performed int not null default 0,
    last_performed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists routines_user_idx
    on public.routines(user_id, updated_at desc);

alter table public.routines enable row level security;

drop policy if exists "routines_self_rw" on public.routines;
create policy "routines_self_rw"
on public.routines for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- Tracked Compounds (peptide watchlist)
-- ============================================================
create table if not exists public.tracked_compounds (
    user_id uuid not null references auth.users(id) on delete cascade,
    compound_name text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, compound_name)
);

alter table public.tracked_compounds enable row level security;

drop policy if exists "tracked_compounds_self_rw" on public.tracked_compounds;
create policy "tracked_compounds_self_rw"
on public.tracked_compounds for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- Food Favorites
-- ============================================================
create table if not exists public.food_favorites (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    brand text not null default '',
    serving_size text not null default '',
    serving_grams double precision not null default 0,
    calories int not null default 0,
    protein double precision not null default 0,
    carbs double precision not null default 0,
    fat double precision not null default 0,
    added_at timestamptz not null default now()
);

create index if not exists food_favorites_user_idx
    on public.food_favorites(user_id, added_at desc);

alter table public.food_favorites enable row level security;

drop policy if exists "food_favorites_self_rw" on public.food_favorites;
create policy "food_favorites_self_rw"
on public.food_favorites for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- AI Memory Facts
-- ============================================================
create table if not exists public.ai_memory_facts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    category text not null,
    content text not null,
    confidence double precision not null default 1.0,
    source text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists ai_memory_facts_user_idx
    on public.ai_memory_facts(user_id, updated_at desc);

alter table public.ai_memory_facts enable row level security;

drop policy if exists "ai_memory_facts_self_rw" on public.ai_memory_facts;
create policy "ai_memory_facts_self_rw"
on public.ai_memory_facts for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- Groups
-- ============================================================
create table if not exists public.groups (
    id uuid primary key default gen_random_uuid(),
    creator_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    description text not null default '',
    privacy text not null default 'Public', -- 'Public' | 'Private'
    accent_color_hex text not null default '#5AC8B0',
    icon_name text not null default 'person.3.fill',
    stats_config jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists groups_privacy_idx on public.groups(privacy, created_at desc);

alter table public.groups enable row level security;

-- Group members (created BEFORE policies that reference it)
create table if not exists public.group_members (
    group_id uuid not null references public.groups(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    role text not null default 'Member', -- 'Owner' | 'Admin' | 'Member'
    joined_at timestamptz not null default now(),
    is_sharing_stats boolean not null default true,
    primary key (group_id, user_id)
);

create index if not exists group_members_user_idx on public.group_members(user_id);

alter table public.group_members enable row level security;

-- Groups policies (now that group_members exists)
drop policy if exists "groups_read_public_or_member" on public.groups;
create policy "groups_read_public_or_member"
on public.groups for select to authenticated
using (
    privacy = 'Public'
    or exists (
        select 1 from public.group_members gm
        where gm.group_id = groups.id and gm.user_id = auth.uid()
    )
);

drop policy if exists "groups_creator_insert" on public.groups;
create policy "groups_creator_insert"
on public.groups for insert to authenticated
with check (auth.uid() = creator_id);

drop policy if exists "groups_admin_update" on public.groups;
create policy "groups_admin_update"
on public.groups for update to authenticated
using (
    exists (
        select 1 from public.group_members gm
        where gm.group_id = groups.id
          and gm.user_id = auth.uid()
          and gm.role in ('Owner', 'Admin')
    )
);

drop policy if exists "groups_owner_delete" on public.groups;
create policy "groups_owner_delete"
on public.groups for delete to authenticated
using (auth.uid() = creator_id);

drop policy if exists "group_members_read_visible" on public.group_members;
create policy "group_members_read_visible"
on public.group_members for select to authenticated
using (
    user_id = auth.uid()
    or exists (
        select 1 from public.group_members me
        where me.group_id = group_members.group_id and me.user_id = auth.uid()
    )
    or exists (
        select 1 from public.groups g where g.id = group_members.group_id and g.privacy = 'Public'
    )
);

drop policy if exists "group_members_self_join" on public.group_members;
create policy "group_members_self_join"
on public.group_members for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "group_members_self_leave" on public.group_members;
create policy "group_members_self_leave"
on public.group_members for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "group_members_admin_update" on public.group_members;
create policy "group_members_admin_update"
on public.group_members for update to authenticated
using (
    user_id = auth.uid()
    or exists (
        select 1 from public.group_members me
        where me.group_id = group_members.group_id
          and me.user_id = auth.uid()
          and me.role in ('Owner', 'Admin')
    )
);

-- Group messages
create table if not exists public.group_messages (
    id uuid primary key default gen_random_uuid(),
    group_id uuid not null references public.groups(id) on delete cascade,
    sender_id uuid not null references auth.users(id) on delete cascade,
    text_content text not null default '',
    attachments jsonb,
    like_count int not null default 0,
    created_at timestamptz not null default now()
);

create index if not exists group_messages_group_idx
    on public.group_messages(group_id, created_at desc);

alter table public.group_messages enable row level security;

drop policy if exists "group_messages_member_read" on public.group_messages;
create policy "group_messages_member_read"
on public.group_messages for select to authenticated
using (
    exists (
        select 1 from public.group_members gm
        where gm.group_id = group_messages.group_id and gm.user_id = auth.uid()
    )
);

drop policy if exists "group_messages_member_insert" on public.group_messages;
create policy "group_messages_member_insert"
on public.group_messages for insert to authenticated
with check (
    sender_id = auth.uid()
    and exists (
        select 1 from public.group_members gm
        where gm.group_id = group_messages.group_id and gm.user_id = auth.uid()
    )
);

drop policy if exists "group_messages_sender_delete" on public.group_messages;
create policy "group_messages_sender_delete"
on public.group_messages for delete to authenticated
using (sender_id = auth.uid());

-- Group message likes
create table if not exists public.group_message_likes (
    message_id uuid not null references public.group_messages(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (message_id, user_id)
);

alter table public.group_message_likes enable row level security;

drop policy if exists "group_message_likes_self_rw" on public.group_message_likes;
create policy "group_message_likes_self_rw"
on public.group_message_likes for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "group_message_likes_member_read" on public.group_message_likes;
create policy "group_message_likes_member_read"
on public.group_message_likes for select to authenticated
using (
    exists (
        select 1 from public.group_messages gm
        join public.group_members me on me.group_id = gm.group_id
        where gm.id = group_message_likes.message_id and me.user_id = auth.uid()
    )
);

-- Group join requests
create table if not exists public.group_join_requests (
    id uuid primary key default gen_random_uuid(),
    group_id uuid not null references public.groups(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    status text not null default 'pending',
    created_at timestamptz not null default now(),
    unique (group_id, user_id)
);

alter table public.group_join_requests enable row level security;

drop policy if exists "group_join_requests_self_rw" on public.group_join_requests;
create policy "group_join_requests_self_rw"
on public.group_join_requests for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "group_join_requests_admin_read" on public.group_join_requests;
create policy "group_join_requests_admin_read"
on public.group_join_requests for select to authenticated
using (
    exists (
        select 1 from public.group_members gm
        where gm.group_id = group_join_requests.group_id
          and gm.user_id = auth.uid()
          and gm.role in ('Owner', 'Admin')
    )
);

drop policy if exists "group_join_requests_admin_update" on public.group_join_requests;
create policy "group_join_requests_admin_update"
on public.group_join_requests for update to authenticated
using (
    exists (
        select 1 from public.group_members gm
        where gm.group_id = group_join_requests.group_id
          and gm.user_id = auth.uid()
          and gm.role in ('Owner', 'Admin')
    )
);

-- ============================================================
-- Circles (FitCircles) - extend existing tables
-- (the `circles` and `circle_members` tables already exist via CircleService;
-- we only need to add new optional columns for richer data.)
-- ============================================================
alter table public.circle_members add column if not exists total_points int not null default 0;
alter table public.circle_members add column if not exists weekly_points int not null default 0;
alter table public.circle_members add column if not exists goal_streak int not null default 0;
alter table public.circle_members add column if not exists longest_streak int not null default 0;

create table if not exists public.circle_messages (
    id uuid primary key default gen_random_uuid(),
    circle_id uuid not null references public.circles(id) on delete cascade,
    sender_id uuid not null references auth.users(id) on delete cascade,
    content text not null default '',
    image_url text,
    created_at timestamptz not null default now()
);

create index if not exists circle_messages_circle_idx on public.circle_messages(circle_id, created_at desc);

alter table public.circle_messages enable row level security;

drop policy if exists "circle_messages_member_read" on public.circle_messages;
create policy "circle_messages_member_read"
on public.circle_messages for select to authenticated
using (
    exists (select 1 from public.circle_members cm where cm.circle_id = circle_messages.circle_id and cm.user_id = auth.uid())
);

drop policy if exists "circle_messages_member_insert" on public.circle_messages;
create policy "circle_messages_member_insert"
on public.circle_messages for insert to authenticated
with check (
    sender_id = auth.uid()
    and exists (select 1 from public.circle_members cm where cm.circle_id = circle_messages.circle_id and cm.user_id = auth.uid())
);

create table if not exists public.circle_posts (
    id uuid primary key default gen_random_uuid(),
    circle_id uuid not null references public.circles(id) on delete cascade,
    author_id uuid not null references auth.users(id) on delete cascade,
    content text not null default '',
    image_url text,
    like_count int not null default 0,
    created_at timestamptz not null default now()
);

create index if not exists circle_posts_circle_idx on public.circle_posts(circle_id, created_at desc);

alter table public.circle_posts enable row level security;

drop policy if exists "circle_posts_member_read" on public.circle_posts;
create policy "circle_posts_member_read"
on public.circle_posts for select to authenticated
using (
    exists (select 1 from public.circle_members cm where cm.circle_id = circle_posts.circle_id and cm.user_id = auth.uid())
);

drop policy if exists "circle_posts_member_insert" on public.circle_posts;
create policy "circle_posts_member_insert"
on public.circle_posts for insert to authenticated
with check (
    author_id = auth.uid()
    and exists (select 1 from public.circle_members cm where cm.circle_id = circle_posts.circle_id and cm.user_id = auth.uid())
);

drop policy if exists "circle_posts_author_modify" on public.circle_posts;
create policy "circle_posts_author_modify"
on public.circle_posts for update to authenticated
using (author_id = auth.uid());

drop policy if exists "circle_posts_author_delete" on public.circle_posts;
create policy "circle_posts_author_delete"
on public.circle_posts for delete to authenticated
using (author_id = auth.uid());

create table if not exists public.circle_post_likes (
    post_id uuid not null references public.circle_posts(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    primary key (post_id, user_id)
);

alter table public.circle_post_likes enable row level security;
drop policy if exists "circle_post_likes_self_rw" on public.circle_post_likes;
create policy "circle_post_likes_self_rw"
on public.circle_post_likes for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.circle_post_comments (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references public.circle_posts(id) on delete cascade,
    author_id uuid not null references auth.users(id) on delete cascade,
    content text not null default '',
    like_count int not null default 0,
    created_at timestamptz not null default now()
);

alter table public.circle_post_comments enable row level security;
drop policy if exists "circle_post_comments_member_read" on public.circle_post_comments;
create policy "circle_post_comments_member_read"
on public.circle_post_comments for select to authenticated
using (
    exists (
        select 1 from public.circle_posts p
        join public.circle_members cm on cm.circle_id = p.circle_id
        where p.id = circle_post_comments.post_id and cm.user_id = auth.uid()
    )
);
drop policy if exists "circle_post_comments_self_insert" on public.circle_post_comments;
create policy "circle_post_comments_self_insert"
on public.circle_post_comments for insert to authenticated
with check (author_id = auth.uid());
drop policy if exists "circle_post_comments_self_modify" on public.circle_post_comments;
create policy "circle_post_comments_self_modify"
on public.circle_post_comments for update to authenticated
using (author_id = auth.uid());
drop policy if exists "circle_post_comments_self_delete" on public.circle_post_comments;
create policy "circle_post_comments_self_delete"
on public.circle_post_comments for delete to authenticated
using (author_id = auth.uid());

create table if not exists public.circle_invites (
    id uuid primary key default gen_random_uuid(),
    circle_id uuid not null references public.circles(id) on delete cascade,
    inviter_id uuid not null references auth.users(id) on delete cascade,
    invitee_id uuid not null references auth.users(id) on delete cascade,
    status text not null default 'pending',
    created_at timestamptz not null default now()
);

create index if not exists circle_invites_invitee_idx on public.circle_invites(invitee_id, status);

alter table public.circle_invites enable row level security;
drop policy if exists "circle_invites_party_rw" on public.circle_invites;
create policy "circle_invites_party_rw"
on public.circle_invites for all to authenticated
using (inviter_id = auth.uid() or invitee_id = auth.uid())
with check (inviter_id = auth.uid() or invitee_id = auth.uid());

create table if not exists public.cheerlines (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references auth.users(id) on delete cascade,
    recipient_id uuid not null references auth.users(id) on delete cascade,
    message text not null,
    expires_at timestamptz not null,
    is_read boolean not null default false,
    created_at timestamptz not null default now()
);

create index if not exists cheerlines_recipient_idx on public.cheerlines(recipient_id, created_at desc);

alter table public.cheerlines enable row level security;
drop policy if exists "cheerlines_party_rw" on public.cheerlines;
create policy "cheerlines_party_rw"
on public.cheerlines for all to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid())
with check (sender_id = auth.uid() or recipient_id = auth.uid());

-- Realtime subscriptions
alter publication supabase_realtime add table public.group_messages;
alter publication supabase_realtime add table public.circle_messages;
alter publication supabase_realtime add table public.circle_posts;
alter publication supabase_realtime add table public.cheerlines;
