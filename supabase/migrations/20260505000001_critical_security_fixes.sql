-- =============================================================================
-- PepPal / EPTI — Critical security fixes from Supabase audit
-- =============================================================================
-- This migration applies the 8 Critical findings from docs/SUPABASE_AUDIT.md.
-- Order is deliberate: storage and per-table fixes first, profiles last
-- because CRIT-7 has client-side blast radius.
--
-- Apply order:
--   CRIT-1  protocol-note-photos bucket: privatize + scope read policy
--   CRIT-2  notifications: lock down INSERT policy
--   CRIT-5  post-media: folder-scope INSERT/UPDATE/DELETE
--   CRIT-6  avatars/banners: drop duplicate read policies
--   CRIT-4  drop confirmed duplicate policies (training_programs, etc.)
--   CRIT-3  bulk-add WITH CHECK to UPDATE policies missing it
--   CRIT-8  circle_members: tighten to "members of circles I'm in"
--   CRIT-7  profiles: restrict SELECT to self, expose profiles_public view
--
-- Wrapped in a single transaction. If ANY statement fails, nothing applies.
-- Re-runnable: every DROP uses IF EXISTS, every CREATE uses IF NOT EXISTS
-- where the object type supports it.
--
-- Applied to production Supabase project fyvhtfbyothjozfwjcod on 2026-05-05.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- CRIT-1 — protocol-note-photos: privatize bucket + tighten read policy
-- -----------------------------------------------------------------------------
UPDATE storage.buckets
   SET public = false
 WHERE id = 'protocol-note-photos';

DROP POLICY IF EXISTS note_photos_read   ON storage.objects;
DROP POLICY IF EXISTS note_photos_insert ON storage.objects;
DROP POLICY IF EXISTS note_photos_update ON storage.objects;
DROP POLICY IF EXISTS note_photos_delete ON storage.objects;

CREATE POLICY note_photos_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'protocol-note-photos'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  );

CREATE POLICY note_photos_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'protocol-note-photos'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  );

CREATE POLICY note_photos_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'protocol-note-photos'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'protocol-note-photos'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  );

CREATE POLICY note_photos_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'protocol-note-photos'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  );

-- -----------------------------------------------------------------------------
-- CRIT-2 — notifications: replace open INSERT policy
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Notifications can be created for users" ON public.notifications;
DROP POLICY IF EXISTS notifications_insert_open               ON public.notifications;

-- -----------------------------------------------------------------------------
-- CRIT-5 — post-media: folder-scope INSERT/UPDATE/DELETE
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS post_media_insert ON storage.objects;
DROP POLICY IF EXISTS post_media_update ON storage.objects;
DROP POLICY IF EXISTS post_media_delete ON storage.objects;

CREATE POLICY post_media_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'post-media'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  );

CREATE POLICY post_media_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'post-media'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'post-media'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  );

CREATE POLICY post_media_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'post-media'
    AND (SELECT auth.uid())::text = (storage.foldername(name))[1]
  );

-- -----------------------------------------------------------------------------
-- CRIT-6 — drop duplicate avatar/banner read policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Banner images are publicly accessible" ON storage.objects;

-- -----------------------------------------------------------------------------
-- CRIT-4 — drop confirmed duplicate policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "users update own programs" ON public.training_programs;

-- TODO REVIEW (not applied here): body_measurements and chat_messages have
-- both an ALL policy and per-command policies. Decide which to keep before
-- adding to a future migration.

-- -----------------------------------------------------------------------------
-- CRIT-3 — bulk-add WITH CHECK to UPDATE policies missing it
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  r           record;
  std_qual_a  text := '(auth.uid() = user_id)';
  std_qual_b  text := '((SELECT auth.uid()) = user_id)';
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname, qual
    FROM pg_policies
    WHERE schemaname = 'public'
      AND cmd = 'UPDATE'
      AND with_check IS NULL
  LOOP
    IF r.qual IN (std_qual_a, std_qual_b) THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I USING (%s) WITH CHECK (%s)',
        r.policyname, r.schemaname, r.tablename, r.qual, r.qual
      );
      RAISE NOTICE 'CRIT-3 fixed: %.% policy %', r.schemaname, r.tablename, r.policyname;
    ELSE
      RAISE NOTICE 'CRIT-3 SKIPPED (non-standard qual, manual review): %.% policy % qual=%',
        r.schemaname, r.tablename, r.policyname, r.qual;
    END IF;
  END LOOP;
END
$$;

-- -----------------------------------------------------------------------------
-- CRIT-8 — circle_members: only members of a circle can see its membership
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Circle members are viewable by everyone" ON public.circle_members;
DROP POLICY IF EXISTS circle_members_select ON public.circle_members;

CREATE POLICY circle_members_select ON public.circle_members
  FOR SELECT TO authenticated
  USING (
    circle_id IN (
      SELECT cm.circle_id
      FROM public.circle_members cm
      WHERE cm.user_id = (SELECT auth.uid())
    )
  );

-- -----------------------------------------------------------------------------
-- CRIT-7 — profiles: restrict SELECT to self, expose profiles_public view
-- -----------------------------------------------------------------------------
-- *** CLIENT IMPACT *** Any iOS code path that does
--   supabase.from("profiles").select(...).eq("id", otherUserId)
-- will start returning empty after this. Update those call sites to read
-- from profiles_public instead.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by everyone"        ON public.profiles;
DROP POLICY IF EXISTS profiles_select_public                     ON public.profiles;

DROP POLICY IF EXISTS profiles_select_self ON public.profiles;
CREATE POLICY profiles_select_self ON public.profiles
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

CREATE OR REPLACE VIEW public.profiles_public AS
  SELECT
    id,
    username,
    display_name,
    avatar_url,
    bio,
    created_at
  FROM public.profiles;

GRANT SELECT ON public.profiles_public TO anon, authenticated;

ALTER VIEW public.profiles_public SET (security_invoker = true);

-- =============================================================================
COMMIT;
-- =============================================================================

