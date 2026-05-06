-- Storage policy consolidation pass.
--
-- Goals:
--   1. Make body-progress-photos a private bucket (was public=true).
--   2. Drop duplicate / overlapping storage.objects policies and replace
--      them with one canonical set per bucket.
--   3. Document the progress-photo bucket situation: body-progress-photos
--      is the live bucket used by BodyProgressPhotoService; body-progress
--      and progress-photos are legacy and kept only for historical data.
--
-- Idempotent: every drop is "if exists", every create is gated on the
-- policy not already existing. Safe to re-run.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Flip body-progress-photos to private (urgent)
--
-- Photos are personal/PII. The Swift client must read them via signed URLs
-- (createSignedURL) instead of getPublicURL once this lands.
-- ---------------------------------------------------------------------------
update storage.buckets
   set public = false
 where id = 'body-progress-photos';

-- ---------------------------------------------------------------------------
-- 2. Drop duplicate / legacy policies on storage.objects.
--
-- We keep one canonical naming scheme per bucket:
--   {bucket}_public_read   (only for public buckets)
--   {bucket}_owner_select  (private buckets)
--   {bucket}_owner_insert
--   {bucket}_owner_update
--   {bucket}_owner_delete
-- ---------------------------------------------------------------------------

-- avatars (public): keep read for everyone, owner-only writes
drop policy if exists "Avatars are publicly readable"     on storage.objects;
drop policy if exists "Public read avatars"               on storage.objects;
drop policy if exists "Users can upload their own avatar" on storage.objects;
drop policy if exists "Users can delete their own avatar" on storage.objects;
drop policy if exists "Users manage own avatars insert"   on storage.objects;
drop policy if exists "Users manage own avatars update"   on storage.objects;
drop policy if exists "Users manage own avatars delete"   on storage.objects;

-- banners (public)
drop policy if exists "Banners are publicly readable"     on storage.objects;
drop policy if exists "Public read banners"               on storage.objects;
drop policy if exists "Users can upload their own banner" on storage.objects;
drop policy if exists "Users can delete their own banner" on storage.objects;
drop policy if exists "Users manage own banners insert"   on storage.objects;
drop policy if exists "Users manage own banners update"   on storage.objects;
drop policy if exists "Users manage own banners delete"   on storage.objects;

-- post-media (public) — three overlapping sets existed
drop policy if exists "Post media is publicly accessible" on storage.objects;
drop policy if exists "Public read post-media"            on storage.objects;
drop policy if exists "Users can upload post media"       on storage.objects;
drop policy if exists "Users can delete own post media"   on storage.objects;
drop policy if exists "Users insert own post-media"       on storage.objects;
drop policy if exists "Users update own post-media"       on storage.objects;
drop policy if exists "Users delete own post-media"       on storage.objects;
drop policy if exists "post_media_insert"                 on storage.objects;
drop policy if exists "post_media_update"                 on storage.objects;
drop policy if exists "post_media_delete"                 on storage.objects;

-- protocol-note-photos (private) — three overlapping sets existed
drop policy if exists "note_photos_read"                  on storage.objects;
drop policy if exists "note_photos_insert"                on storage.objects;
drop policy if exists "note_photos_update"                on storage.objects;
drop policy if exists "note_photos_delete"                on storage.objects;
drop policy if exists "note_photos_insert_own"            on storage.objects;
drop policy if exists "note_photos_delete_own"            on storage.objects;
drop policy if exists "protocol_note_photos_owner_select" on storage.objects;
drop policy if exists "protocol_note_photos_owner_insert" on storage.objects;
drop policy if exists "protocol_note_photos_owner_update" on storage.objects;
drop policy if exists "protocol_note_photos_owner_delete" on storage.objects;

-- body-progress-photos (now private)
drop policy if exists "body_progress_photos_owner_read"   on storage.objects;
drop policy if exists "body_progress_photos_owner_write"  on storage.objects;
drop policy if exists "body_progress_photos_owner_update" on storage.objects;
drop policy if exists "body_progress_photos_owner_delete" on storage.objects;

-- body-progress (legacy private, kept for historical rows)
drop policy if exists "body_progress_owner_select" on storage.objects;
drop policy if exists "body_progress_owner_insert" on storage.objects;
drop policy if exists "body_progress_owner_update" on storage.objects;
drop policy if exists "body_progress_owner_delete" on storage.objects;

-- progress-photos (legacy private)
drop policy if exists "Users can upload progress photos"      on storage.objects;
drop policy if exists "Users can view own progress photos"    on storage.objects;
drop policy if exists "Users can update own progress photos"  on storage.objects;
drop policy if exists "Users can delete own progress photos"  on storage.objects;

-- chat-media (private)
drop policy if exists "Users can upload chat media"                    on storage.objects;
drop policy if exists "Users can view chat media in their conversations" on storage.objects;

-- dm-media (private) — already canonical, leave as-is
-- meal-photos (private) — already canonical, leave as-is
-- bloodwork-photos (private)
drop policy if exists "Users can upload bloodwork photos"     on storage.objects;
drop policy if exists "Users can view own bloodwork photos"   on storage.objects;
drop policy if exists "Users can delete own bloodwork photos" on storage.objects;

-- ---------------------------------------------------------------------------
-- 3. Recreate one canonical policy set per bucket.
--
-- Helper: only create a policy if it doesn't already exist.
-- ---------------------------------------------------------------------------

create or replace function public._exec_if_no_policy(p_name text, p_sql text)
returns void
language plpgsql
as $$
begin
    if not exists (
        select 1 from pg_policies
         where schemaname = 'storage' and tablename = 'objects' and policyname = p_name
    ) then
        execute p_sql;
    end if;
end $$;

-- Public buckets: avatars, banners, post-media, body-progress-photos was
-- public, now private (handled below).
select public._exec_if_no_policy('avatars_public_read',
$sql$create policy "avatars_public_read" on storage.objects
    for select to public using (bucket_id = 'avatars')$sql$);
select public._exec_if_no_policy('avatars_owner_insert',
$sql$create policy "avatars_owner_insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('avatars_owner_update',
$sql$create policy "avatars_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('avatars_owner_delete',
$sql$create policy "avatars_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

select public._exec_if_no_policy('banners_public_read',
$sql$create policy "banners_public_read" on storage.objects
    for select to public using (bucket_id = 'banners')$sql$);
select public._exec_if_no_policy('banners_owner_insert',
$sql$create policy "banners_owner_insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'banners' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('banners_owner_update',
$sql$create policy "banners_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'banners' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'banners' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('banners_owner_delete',
$sql$create policy "banners_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'banners' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

select public._exec_if_no_policy('post_media_public_read',
$sql$create policy "post_media_public_read" on storage.objects
    for select to public using (bucket_id = 'post-media')$sql$);
select public._exec_if_no_policy('post_media_owner_insert',
$sql$create policy "post_media_owner_insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('post_media_owner_update',
$sql$create policy "post_media_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'post-media' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('post_media_owner_delete',
$sql$create policy "post_media_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'post-media' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

-- Private buckets: owner-only on path's first folder.
select public._exec_if_no_policy('protocol_note_photos_owner_select',
$sql$create policy "protocol_note_photos_owner_select" on storage.objects
    for select to authenticated
    using (bucket_id = 'protocol-note-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('protocol_note_photos_owner_insert',
$sql$create policy "protocol_note_photos_owner_insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'protocol-note-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('protocol_note_photos_owner_update',
$sql$create policy "protocol_note_photos_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'protocol-note-photos' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'protocol-note-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('protocol_note_photos_owner_delete',
$sql$create policy "protocol_note_photos_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'protocol-note-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

select public._exec_if_no_policy('body_progress_photos_owner_select',
$sql$create policy "body_progress_photos_owner_select" on storage.objects
    for select to authenticated
    using (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('body_progress_photos_owner_insert',
$sql$create policy "body_progress_photos_owner_insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('body_progress_photos_owner_update',
$sql$create policy "body_progress_photos_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('body_progress_photos_owner_delete',
$sql$create policy "body_progress_photos_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'body-progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

-- Legacy buckets (still receive policies in case rows exist).
select public._exec_if_no_policy('body_progress_owner_select_legacy',
$sql$create policy "body_progress_owner_select_legacy" on storage.objects
    for select to authenticated
    using (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('body_progress_owner_insert_legacy',
$sql$create policy "body_progress_owner_insert_legacy" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('body_progress_owner_update_legacy',
$sql$create policy "body_progress_owner_update_legacy" on storage.objects
    for update to authenticated
    using (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('body_progress_owner_delete_legacy',
$sql$create policy "body_progress_owner_delete_legacy" on storage.objects
    for delete to authenticated
    using (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

select public._exec_if_no_policy('progress_photos_owner_select',
$sql$create policy "progress_photos_owner_select" on storage.objects
    for select to authenticated
    using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('progress_photos_owner_insert',
$sql$create policy "progress_photos_owner_insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('progress_photos_owner_update',
$sql$create policy "progress_photos_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('progress_photos_owner_delete',
$sql$create policy "progress_photos_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

select public._exec_if_no_policy('bloodwork_photos_owner_select',
$sql$create policy "bloodwork_photos_owner_select" on storage.objects
    for select to authenticated
    using (bucket_id = 'bloodwork-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('bloodwork_photos_owner_insert',
$sql$create policy "bloodwork_photos_owner_insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'bloodwork-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('bloodwork_photos_owner_update',
$sql$create policy "bloodwork_photos_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'bloodwork-photos' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'bloodwork-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('bloodwork_photos_owner_delete',
$sql$create policy "bloodwork_photos_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'bloodwork-photos' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

select public._exec_if_no_policy('chat_media_owner_select',
$sql$create policy "chat_media_owner_select" on storage.objects
    for select to authenticated
    using (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('chat_media_owner_insert',
$sql$create policy "chat_media_owner_insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('chat_media_owner_update',
$sql$create policy "chat_media_owner_update" on storage.objects
    for update to authenticated
    using (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (auth.uid())::text)
    with check (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);
select public._exec_if_no_policy('chat_media_owner_delete',
$sql$create policy "chat_media_owner_delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'chat-media' and (storage.foldername(name))[1] = (auth.uid())::text)$sql$);

drop function if exists public._exec_if_no_policy(text, text);

-- ---------------------------------------------------------------------------
-- 4. Document the progress-photo bucket consolidation.
--
-- Live (current code path):
--   body-progress-photos    -> BodyProgressPhotoService (table: body_progress_photos)
--                              private; client uses createSignedURL.
--
-- Legacy (kept for historical rows; safe to delete buckets once data is
-- migrated or the rows are no longer referenced):
--   body-progress           -> not referenced by current Swift code.
--   progress-photos         -> ProgressPhotosView (table: progress_photos);
--                              older flow kept until UI migrates fully to
--                              BodyProgressPhotoService.
--
-- All three are now private with identical owner-only path policies.
-- ---------------------------------------------------------------------------

COMMIT;
