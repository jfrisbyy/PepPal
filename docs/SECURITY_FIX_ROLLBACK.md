# Security Fix Rollback Plan

**Scope:** This document covers rollback procedures for the migrations introduced in PR #1 (`db/critical-security-migrations`):

- `supabase/migrations/20260505000001_critical_security_fixes.sql`
- `supabase/migrations/20260505000002_critical_security_fixes_with_check_followup.sql`

These migrations applied the 8 Critical findings from the Supabase audit on 2026-05-05.

---

## TL;DR — Read This First

**Do not roll these migrations back as a first response to a problem.**

Each fix closes a real security hole. Rolling back reopens the hole. If a specific fix breaks a client-side code path during normal use, the correct response is almost always to **fix forward** — patch the client to use the new pattern (e.g., switch to `profiles_public`, route notification writes through an Edge Function) rather than reopen the underlying vulnerability.

Use this document to:

1. Diagnose which fix is implicated when something breaks (the "If you see..." section).
2. Understand the correct fix-forward path for each.
3. Only as a last resort, execute a rollback for a specific fix block while you build the proper fix-forward.

Every fix can be rolled back individually — you should never need to roll back the entire migration.

---

## Diagnosis: If you see this symptom, it's probably this fix

| Symptom | Likely cause | Fix-forward path |
|---|---|---|
| iOS users report their protocol-note photos no longer load. Network logs show 400/403 from Supabase Storage. | CRIT-1 — bucket is now private, public URLs no longer work. | Update client to call `createSignedUrl(...)` instead of using the public URL directly. Confirm uploads land in a path starting with the user's UUID (`<auth-uid>/...`). |
| iOS app fails to write a notification (e.g., welcome notification on signup). PostgREST returns 401/403 on INSERT to `notifications`. | CRIT-2 — direct client INSERT path removed. | Move the write into an Edge Function that uses `service_role`. Client calls the Edge Function, function writes the notification. |
| User screens that show *another user's* profile (e.g., circle members, post author bylines, follow lists) are blank or show only the auth user's own data. | CRIT-7 — `profiles` SELECT is now self-only. | Switch those call sites from `from("profiles")` to `from("profiles_public")`. Add columns to the view if you need additional non-sensitive fields. |
| Circle membership list is empty for a user even though they're a member. | CRIT-8 — `circle_members` SELECT is now scoped to "circles I'm in". | Confirm the user's own `circle_members` row exists. The new policy should allow them to see all members of any circle they belong to. If still empty, check that the policy's self-referencing subquery is intact (re-run verification SQL). |
| Post media uploads fail with 403 even though the user is signed in. | CRIT-5 — `post-media` INSERT now requires upload path to start with `<auth-uid>/`. | Update the client upload code to prefix paths with the user's UUID. |
| Some background job that reassigned ownership of rows (e.g., admin tooling, data migration) starts failing. | CRIT-3 / follow-up — UPDATE policies now have WITH CHECK preventing user_id reassignment. | Run the job as `service_role` (which bypasses RLS) via an Edge Function, not as the affected user. |
| A profile screen that displayed someone else's full row (DOB, weight, current peptide, etc.) now shows nothing. | CRIT-7 acting as designed — those columns aren't in `profiles_public`, intentionally. | **This is the fix working.** Confirm the data was meant to be exposed before adding the column to `profiles_public`. If yes, add it to the view. If no, redesign the screen. |

---

## General principles

1. **Roll back the smallest possible block.** Never roll back both migrations wholesale — every block in those migrations closes an independent finding. Cherry-pick the specific block whose fix is causing the breakage.
2. **Apply rollbacks via a new forward migration**, not by editing or reverting the existing migration files. The original files should remain in version control as the historical record.
3. **Wrap each rollback in `BEGIN; ... COMMIT;`** so partial application is impossible.
4. **Run the audit's verification SQL after rollback** to confirm the original state is restored.
5. **Open an incident ticket.** Any rollback of a security fix is a security event. Document who rolled back, why, and the planned fix-forward timeline.

---

## Per-fix rollback procedures

### CRIT-1 — protocol-note-photos bucket

**What rolling back does:** Re-exposes user protocol photos. Anyone with a URL can read another user's photos. **Do not do this in production.**

**Forward fix instead:** Have the client use `createSignedUrl(name, expiresIn)` to generate short-lived URLs. The bucket stays private; signed URLs work for legitimate access.

**If you must roll back:**

```sql
BEGIN;

DROP POLICY IF EXISTS note_photos_read   ON storage.objects;
DROP POLICY IF EXISTS note_photos_insert ON storage.objects;
DROP POLICY IF EXISTS note_photos_update ON storage.objects;
DROP POLICY IF EXISTS note_photos_delete ON storage.objects;

UPDATE storage.buckets SET public = true WHERE id = 'protocol-note-photos';

-- Recreate the original loose read policy (as best we can reconstruct).
CREATE POLICY note_photos_read ON storage.objects
  FOR SELECT
  USING (bucket_id = 'protocol-note-photos');

COMMIT;
```

### CRIT-2 — notifications INSERT

**What rolling back does:** Re-opens the notification spoofing vector. Any authenticated user can insert notifications addressed to other users. **Do not do this in production.**

**Forward fix instead:** Edge Function with `service_role`:

```typescript
// supabase/functions/create-notification/index.ts (sketch)
import { createClient } from 'jsr:@supabase/supabase-js@2'
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)
// validate auth, validate inputs, then insert as service_role
```

**If you must roll back:**

```sql
BEGIN;
CREATE POLICY "Notifications can be created for users" ON public.notifications
  FOR INSERT TO public
  WITH CHECK (true);
COMMIT;
```

### CRIT-3 (and follow-up) — WITH CHECK on UPDATE policies

**What rolling back does:** Re-opens the user_id reassignment vulnerability. Users can transfer their own rows to other users by setting `user_id = '<other-uuid>'` during UPDATE. Silent data corruption risk.

**Forward fix instead:** Almost never necessary to roll back. The standard `ALTER POLICY ... WITH CHECK (...)` pattern is conservative — it only blocks UPDATEs where the *post-update* row would no longer pass the existing USING clause. Legitimate user updates of their own rows continue to work.

**If you must roll back a specific table's policy:**

```sql
BEGIN;

-- Postgres does not allow nulling WITH CHECK via ALTER POLICY.
-- Must DROP and CREATE.
DROP POLICY "<policy_name>" ON public.<table>;
CREATE POLICY "<policy_name>" ON public.<table> FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);
  -- intentionally no WITH CHECK clause

COMMIT;
```

Repeat for each policy you need to roll back.

### CRIT-4 — training_programs duplicate UPDATE policy

**What rolling back does:** Recreates a redundant policy. No security impact (both policies were equivalent), just cosmetic clutter.

**If you must roll back:**

```sql
BEGIN;
CREATE POLICY "users update own programs" ON public.training_programs
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
COMMIT;
```

### CRIT-5 — post-media folder scoping

**What rolling back does:** Re-allows any authenticated user to upload to any path within `post-media`, including paths that look like another user's namespace.

**Forward fix instead:** Update the client to upload to `<auth-uid>/<post-id>/<filename>`.

**If you must roll back:**

```sql
BEGIN;

DROP POLICY IF EXISTS post_media_insert ON storage.objects;
DROP POLICY IF EXISTS post_media_update ON storage.objects;
DROP POLICY IF EXISTS post_media_delete ON storage.objects;

CREATE POLICY post_media_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'post-media');

CREATE POLICY post_media_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'post-media')
  WITH CHECK (bucket_id = 'post-media');

CREATE POLICY post_media_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'post-media');

COMMIT;
```

### CRIT-6 — duplicate avatar/banner read policies

**What rolling back does:** Recreates redundant public-read policies. No security impact (both were equivalent public reads).

**If you must roll back:**

```sql
BEGIN;
CREATE POLICY "Avatar images are publicly accessible" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Banner images are publicly accessible" ON storage.objects
  FOR SELECT USING (bucket_id = 'banners');
COMMIT;
```

### CRIT-7 — profiles SELECT + profiles_public view

**This is the rollback most likely to actually be needed**, because it has the largest client blast radius. Before rolling back, do a careful audit of which client code paths actually need cross-user profile data and what columns they need.

**Forward fix instead (preferred):**

1. Identify the screens that broke. Phase 2 of the audit will catalog these systematically.
2. For each, determine which columns of *another user's* profile they need to display.
3. Add those columns to `profiles_public` if they're not sensitive:

```sql
CREATE OR REPLACE VIEW public.profiles_public AS
  SELECT
    id, username, display_name, avatar_url, bio, created_at,
    -- add columns here as needed:
    pronouns, header_image_url
  FROM public.profiles;
```

4. Update the iOS code to read from `profiles_public` instead of `profiles` for cross-user reads.

**If you must roll back the entire CRIT-7 fix:**

```sql
BEGIN;

DROP VIEW IF EXISTS public.profiles_public;

DROP POLICY IF EXISTS profiles_select_self ON public.profiles;

CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
  FOR SELECT USING (true);

COMMIT;
```

⚠️ This re-exposes every column on `profiles` to every authenticated user. If `profiles` contains DOB, weight, current peptide, goals, etc., those become readable across all users. Treat as a temporary measure only.

### CRIT-8 — circle_members SELECT scoping

**What rolling back does:** Re-allows any authenticated user to enumerate the membership of any circle.

**Forward fix instead:** This rarely needs rolling back. The new policy permits a user to see all members of any circle they themselves are in, which covers the legitimate use case (showing the member list of a circle you've joined). If a use case requires showing membership of circles you haven't joined (e.g., a public discovery view), expose that via a dedicated, explicitly-public view rather than reopening the underlying table.

**If you must roll back:**

```sql
BEGIN;

DROP POLICY IF EXISTS circle_members_select ON public.circle_members;

CREATE POLICY "Circle members are viewable by everyone" ON public.circle_members
  FOR SELECT USING (true);

COMMIT;
```

---

## Rollback verification

After applying any rollback, run these queries to confirm the rolled-back state is what you expect. The expected outcomes here are **inverse** of the original verification — i.e., what you'd see on the pre-fix database:

```sql
-- CRIT-1 rolled back: should show public = true
SELECT id, public FROM storage.buckets WHERE id = 'protocol-note-photos';

-- CRIT-2 rolled back: should show one INSERT policy with with_check = true
SELECT policyname, with_check FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'notifications' AND cmd = 'INSERT';

-- CRIT-7 rolled back: should show a SELECT policy with qual = true on profiles
SELECT policyname, qual FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'profiles' AND cmd = 'SELECT';
```

If those queries don't show the expected rolled-back state, the rollback didn't fully apply — investigate before considering the rollback complete.

---

## After any rollback

1. **File a security incident ticket** describing what was rolled back, why, and when.
2. **Set a deadline** for the proper fix-forward. A rolled-back security fix should not stay rolled back for more than a few days under normal circumstances.
3. **Notify whoever else has admin access** to the Supabase project that a security policy was reverted.
4. **Re-apply the original fix** as soon as the client-side fix-forward is shipped. Use a new migration file (don't edit history).
5. **Re-run the audit's verification SQL** to confirm the original secure state is restored.

---

## Contact / questions

If you're reading this because something broke after the security fixes were applied and you're trying to decide whether to roll back: **file an incident ticket and bring in another set of eyes before reverting.** A blank screen is recoverable in minutes; a re-exposed protocol-note-photos bucket is not.
