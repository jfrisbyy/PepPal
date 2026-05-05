-- Ensure avatar + banner storage buckets exist with proper RLS, and add banner_url to profiles.

-- 1) banner_url column on profiles
alter table public.profiles
    add column if not exists banner_url text;

-- 2) public storage buckets
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('banners', 'banners', true)
on conflict (id) do update set public = excluded.public;

-- 3) RLS policies for the buckets
-- Public read
drop policy if exists "Public read avatars" on storage.objects;
create policy "Public read avatars"
    on storage.objects for select
    using (bucket_id = 'avatars');

drop policy if exists "Public read banners" on storage.objects;
create policy "Public read banners"
    on storage.objects for select
    using (bucket_id = 'banners');

-- Authenticated users can write/update/delete files in their own <uid>/ prefix.
drop policy if exists "Users manage own avatars insert" on storage.objects;
create policy "Users manage own avatars insert"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Users manage own avatars update" on storage.objects;
create policy "Users manage own avatars update"
    on storage.objects for update
    to authenticated
    using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Users manage own avatars delete" on storage.objects;
create policy "Users manage own avatars delete"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Users manage own banners insert" on storage.objects;
create policy "Users manage own banners insert"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'banners'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Users manage own banners update" on storage.objects;
create policy "Users manage own banners update"
    on storage.objects for update
    to authenticated
    using (
        bucket_id = 'banners'
        and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
        bucket_id = 'banners'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Users manage own banners delete" on storage.objects;
create policy "Users manage own banners delete"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'banners'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
