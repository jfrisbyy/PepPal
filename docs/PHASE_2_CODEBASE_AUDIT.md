# PepPal / EPTI — Phase 2 Codebase Audit

**Status:** Draft (read-only audit, no remediation in this PR)
**Scope:** iOS Swift codebase (`ios/FrisFit/`) cross-referenced against the Critical security fixes that **were merged into `main` (commits `1d52929` + `b282759`) and then reverted by commit `592b0ef` ("Restored to the previous version", `rorkagent`, 2026-05-05).**

> **READ THIS FIRST.** During this audit I discovered the two security migration files (`20260505000001_critical_security_fixes.sql` and `20260505000002_critical_security_fixes_with_check_followup.sql`) are **no longer present at `main` HEAD**. They exist at the pre-revert commit `9c099a5` but were removed by the Rork agent's automatic restore commit `592b0ef`. The Phase-1 kickoff document still describes them as "merged to main." This is itself a Critical finding — see CRITICAL-NEW-1 below — and it materially affects how this report should be read. The cross-reference assumes the **live Supabase project** still has CRIT-1..8 applied (they were applied via SQL editor before the migration files were committed, per commit `1d52929`'s message). If the live database has *also* drifted, the entire Phase 2 finding set may be moot.

## 0. TL;DR — What to fix this week

1. **Decide on the migration files.** Either (a) re-add `20260505000001_*.sql` and `20260505000002_*.sql` to `supabase/migrations/` and add a Rork-restore guard, or (b) accept that migrations are managed out-of-band and document that explicitly.
2. **Fix CRIT-2 regressions** (4 client-side `notifications` INSERT call sites): create a `SECURITY DEFINER` RPC `create_notification(target_user_id, type, title, body)` that validates the caller has a relationship to `target_user_id`, and replace all 4 client INSERTs with `.rpc("create_notification", ...)`. Sites: `MessagingService.swift:182, 244, 478` (followUser, sendFriendRequest, sendMessage) and `GroupsViewModel.swift:88-91` (sendJoinRequestNotification).
3. **Fix CRIT-7 regressions** (8 cross-user `profiles` reads): migrate to `from("profiles_public")`. Sites listed in §3.A. Note `profiles_public` exposes only `id, username, display_name, avatar_url, bio, created_at` — the iOS code currently selects extra columns (`avatar_color, active_program, total_fp, current_streak, total_workouts`) that are **not in the view**. Either extend the view or stop selecting those columns for non-self profiles.
4. **Stop swallowing errors silently** in `MessagingService.fetchProfilesByIds` (line 513) and `GroupsViewModel.sendJoinRequestNotification` (line 92). Bare `catch {}` blocks are hiding the CRIT-7 / CRIT-2 RLS denials right now — users see "no error" but functionality is silently broken.
5. **Add a deep-link / URL handler** to `FrisFitApp.swift` if magic-link or password-reset emails are used (currently absent — the app cannot consume Supabase auth callback URLs).

## 1. Methodology

- Read-only audit performed against `main` HEAD (`c960f13`) on 2026-05-05.
- Migrations read from pre-revert commit `9c099a5` because they no longer exist at HEAD.
- All call sites identified by GitHub code search + raw-fetch of every file under `ios/FrisFit/Services/` (28 files), `ios/FrisFit/ViewModels/` and `ios/FrisFit/Views/` (1 service-touching ViewModel and 1 service-touching View). Tests intentionally skipped per scope.
- Cross-reference rules:
  - **OK** = call site compatible with post-CRIT-1..8 RLS.
  - **BROKEN BY CRIT-X** = the call now returns empty / fails / silently no-ops because a CRIT-X migration changed the RLS or storage policy.
  - **NEW** = a Phase-2 finding independent of the Critical-fix sprint.

## 2. Inventory

### 2.1 Tables referenced by client (29)
`activity_logs`, `biomarker_results`, `bloodwork_entries`, `body_goals`, `body_measurements`, `circle_members`, `circles`, `conversation_participants`, `conversations`, `daily_tasks`, `direct_messages`, `dose_logs`, `feed_posts`, `follows`, `food_items`, `friend_requests`, `logged_meals`, `notifications`, `post_comments`, `post_likes`, `post_reposts`, `profiles`, `progress_photos`, `protocol_compounds`, `protocols`, `side_effect_logs`, `supplements`, `weight_logs`, `workouts`.

### 2.2 Storage buckets referenced by client (4)
`avatars`, `bloodwork-photos`, `post-media`, `progress-photos`. **No client reference to `protocol-note-photos`** — CRIT-1 (privatization) had zero client blast radius. Banner/cover-photo buckets also unused by client.

### 2.3 RPC functions referenced by client (4, all in `SocialService.swift`)
`increment_high_five_count`, `decrement_high_five_count`, `increment_repost_count`, `decrement_repost_count`. All take `row_id: postId`. Need confirmation these exist on the live DB and are SECURITY DEFINER with `auth.uid()` ownership checks (Phase 1 inventory should already cover; flagging as MEDIUM-NEW-RPC for re-verification).

### 2.4 Realtime subscriptions
**None.** Zero `.channel(` / `realtime` references in the entire repo. Item 3d of the Phase 2 scope is fully resolved with no findings.

### 2.5 Auth surface
`AuthService.swift` is the only file using `supabase.auth.*`:
- `signUp(email, password, fullName)` — L62-69, passes `full_name` in user metadata.
- `signIn(email, password)` — L71-74, plain email/password.
- `signOut()` — L76-79.
- `resetPassword(email)` — L81-84.
- `currentUserId() throws` — L86-91, returns `session.user.id.uuidString.lowercased()`.
- `authStateChanges` listener at L34-58, switches on `.initialSession`, `.signedIn`, `.signedOut`, etc.

## 3. Cross-reference table

### 3.A `profiles` reads — CRIT-7 regression hunt (HIGHEST PRIORITY)

Post-CRIT-7, `profiles` SELECT is restricted to `auth.uid() = id`. Any read of a *different* user's row returns empty. Every site below must move to `profiles_public` (id, username, display_name, avatar_url, bio, created_at).

| File:Line | Op | Filter | Status | Notes |
|---|---|---|---|---|
| `ProfileService.swift:63-71` | SELECT | `id = userId` (param) | **AMBIGUOUS** — depends on caller. If `userId == currentUserId` it works; otherwise broken. Recommend: reject calls where `userId != currentUserId` here, or branch to `profiles_public` for non-self IDs. |
| `ProfileService.swift:75-80` | UPDATE | `id = userId` | **OK** — UPDATE is RLS-restricted to self regardless; matches CRIT-3 follow-up policy. |
| `MessagingService.swift:357-363` (`fetchConversations`) | SELECT | `id = otherUserId` | **BROKEN BY CRIT-7** — returns empty; conversation list will lose author display_name/avatar. Migrate to `profiles_public`. |
| `MessagingService.swift:500-516` (`fetchProfilesByIds`) | SELECT | `id = uid` per ID | **BROKEN BY CRIT-7** — entire helper returns empty results for non-self IDs. Plus error swallowed by `catch {}` at L513 (silent). |
| `MessagingService.swift:520-530` (`searchUsers`) | SELECT | `neq id, excludeUserId` + `or(display_name.ilike, username.ilike)` | **BROKEN BY CRIT-7** — user search returns at most the current user, but `excludeUserId` is the current user, so the result is **always empty**. Migrate to `profiles_public`. |
| `SocialService.swift:127` (`fetchPosts`) | SELECT join | `*, profiles(...)` | **BROKEN BY CRIT-7** — embedded `profiles(...)` follows the parent table's RLS; non-self authors come back null. Feed displays anonymous-looking posts. Switch the relationship to `profiles_public!feed_posts_user_id_fkey` (PostgREST embedded-resource alias) or add a FK from `feed_posts.user_id` to the view alias. |
| `SocialService.swift:154` (`createPost` re-read) | SELECT join | `*, profiles(...)` | **BROKEN BY CRIT-7** for the just-created post when the author is the current user it works; for the typical case it works (creator = self). **OK in practice** but inconsistent with the broader fix — should still migrate. |
| `SocialService.swift:173` (`fetchComments`) | SELECT join | `*, profiles(...)` | **BROKEN BY CRIT-7** — comments by other users have null `profiles`. |
| `SocialService.swift:217` (`addComment` re-read) | SELECT join | `*, profiles(...)` | OK (self) — still migrate. |
| `SocialService.swift:353` (`fetchUserPosts`) | SELECT join | `*, profiles(...)` | **BROKEN BY CRIT-7** — viewing another user's profile feed loses author info on every post. |

> **`profiles_public` view column gap.** The view exposes `id, username, display_name, avatar_url, bio, created_at`. The iOS struct `SupabasePostAuthor` (SocialService.swift L34-44) decodes `id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak`. Direct migration to `profiles_public` will fail to decode `avatar_color`, `active_program`, `total_fp`, `current_streak`. Two options:
> 1. **Extend `profiles_public`** to include `avatar_color, active_program, total_fp, current_streak`. Recommended — these are not sensitive, were already public pre-CRIT-7, and align with the social-feed UI.
> 2. **Make those fields optional in the Swift struct** and accept that they'll be nil for non-self users. Lower-effort but degrades UI.

### 3.B `notifications` writes — CRIT-2 regression hunt

CRIT-2 dropped the open INSERT policy on `public.notifications` and **created no replacement**. Authenticated clients now have **zero** INSERT permission. All four call sites are broken.

| File:Line | Function | Recipient `user_id` | Status |
|---|---|---|---|
| `MessagingService.swift:182-192` | `followUser` | `followingId` (the followed user) | **BROKEN BY CRIT-2** |
| `MessagingService.swift:239-249` | `sendFriendRequest` | `receiverId` | **BROKEN BY CRIT-2** |
| `MessagingService.swift:476-484` | `sendMessage` (loops over `otherParticipants`) | each other-participant's `user_id` | **BROKEN BY CRIT-2** |
| `GroupsViewModel.swift:78-94` | `sendJoinRequestNotification` | `group.creatorID` (group owner) | **BROKEN BY CRIT-2 + silent (`catch {}` at L92)** |

Fix recommendation: introduce a `SECURITY DEFINER` RPC on the database that validates the relationship before inserting. Sketch:

```sql
CREATE OR REPLACE FUNCTION public.create_notification(
  target_user_id uuid,
  notif_type     text,
  notif_title    text,
  notif_body     text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Validate caller is allowed to notify target_user_id for this type.
  -- Pseudocode: friend, follower, conversation participant, group owner, etc.
  IF NOT EXISTS (
    SELECT 1
    FROM public.allowed_notification_pairs(auth.uid(), target_user_id, notif_type)
  ) THEN
    RAISE EXCEPTION 'not authorized to notify this user';
  END IF;
  INSERT INTO public.notifications (user_id, type, title, body)
  VALUES (target_user_id, notif_type, notif_title, notif_body);
END;
$$;
REVOKE ALL ON FUNCTION public.create_notification(uuid,text,text,text) FROM public;
GRANT EXECUTE ON FUNCTION public.create_notification(uuid,text,text,text) TO authenticated;
```

Then in Swift, replace each `from("notifications").insert(payload)` with `rpc("create_notification", params: [...])`.

### 3.C `notifications` reads/updates — OK

| File:Line | Op | Notes |
|---|---|---|
| `MessagingService.swift:535-543` (`fetchNotifications`) | SELECT `eq user_id, userId` | OK — RLS allows self-read; defense-in-depth `eq` is correct. |
| `MessagingService.swift:548-552` (`markNotificationRead`) | UPDATE `eq id, notificationId` | OK — RLS will gate to self-owned rows; missing `eq("user_id")` is a Medium defense-in-depth gap (rely on RLS only). |
| `MessagingService.swift:557-562` (`markAllNotificationsRead`) | UPDATE `eq user_id, userId` `eq is_read, false` | OK. |
| `MessagingService.swift:566-573` (`unreadNotificationCount`) | SELECT count | OK. |

### 3.D Storage — bucket + path audit

| File:Line | Bucket | Path pattern | Status |
|---|---|---|---|
| `ProfileService.swift:84-95` | `avatars` | `"\(userId)/avatar_<ts>.jpg"` | **OK** (folder-scoped). MEDIUM-NEW-1: `userId` is a parameter, not `AuthService.currentUserId()`. Defense-in-depth: derive from session. |
| `BloodworkService.swift:130-140` | `bloodwork-photos` | `"\(userId)/bloodwork_<ts>.jpg"` | **OK**. Same MEDIUM-NEW-1 caveat. |
| `SocialService.swift:316-330` | `post-media` (audio) | `"\(userId)/<UUID>.m4a"` | **OK** — CRIT-5 compliant. Same MEDIUM-NEW-1 caveat. |
| `SocialService.swift:333-347` | `post-media` (image) | `"\(userId)/<UUID>_<idx>.jpg"` | **OK** — CRIT-5 compliant. Same MEDIUM-NEW-1 caveat. |
| `ProgressPhotosView.swift:80-100` | `progress-photos` | `"\(userId)/progress_<UUID>.jpg"` | **OK** — `userId` derived from `AuthService.shared.currentUserId()` (correct pattern, model for the others). |

`protocol-note-photos` is referenced by **zero** client call sites; CRIT-1 (privatize) had no client impact.

### 3.E All other tables — defense-in-depth `user_id` filter check

Most user-scoped reads include an explicit `eq("user_id", userId)` even though RLS would already restrict — this is correct defense-in-depth. A few exceptions worth noting (LOW unless an RLS gap is found):

- `BloodworkService.swift:84` `insert bloodwork_entries` — payload presumably contains `user_id`, but the call has no defensive `.eq` (insert doesn't need one). OK.
- `BloodworkService.swift:117-121` deletes `biomarker_results` filtering only by `entry_id`. Safe iff RLS on `biomarker_results` enforces ownership transitively via parent `bloodwork_entries.user_id`. CRIT-3 follow-up explicitly mentions `biomarker_results` as Category B (indirect ownership). LOW-NEW: add explicit `entry_id IN (...)` precondition or rely on RLS.
- `SocialService.swift:352` (`fetchUserPosts`) reads `feed_posts` filtered by an arbitrary `userId` — this is a public-feed read; RLS on `feed_posts` should allow public read of non-private posts. Need confirmation that `feed_posts` SELECT policy is broader than self-only. (HIGH-NEW-FEEDREAD: verify with Phase 1 inventory.)

## 4. New Phase 2 findings (ranked)

### CRITICAL-NEW-1 — Security migrations were reverted by Rork agent on `main`

**Where:** Commit `592b0ef23294fe848885c5becd002a96392f53f9` ("Restored to the previous version") by `rorkagent`, 2026-05-05.

**What:** This commit deleted `supabase/migrations/20260505000001_critical_security_fixes.sql` and `supabase/migrations/20260505000002_critical_security_fixes_with_check_followup.sql`, plus `docs/SECURITY_FIX_ROLLBACK.md`. 480 files changed, +84,350 / −7,886 lines. The kickoff document for this audit assumes both migration files are on `main`. They are not.

**Why it matters:**
- The live Supabase project `fyvhtfbyothjozfwjcod` reportedly has the security fixes applied (per commit message of `1d52929`). Source of truth in source control no longer matches the database.
- A future `supabase db push` or branch-based deploy would attempt to "apply" only the older 5 migration files, which would not undo the live fixes (since migrations are append-only by default), but **a new developer cloning the repo will have no record of CRIT-1..8** and may write SQL or restores that re-introduce the holes.
- Any further Rork "Restore to previous version" commits could keep wiping changes that protect the database.

**Repro:**
1. `git log --oneline supabase/migrations/` on `main` — the two security fix files appear in `1d52929` and `b282759`, then are absent in `592b0ef`.
2. `https://github.com/jfrisbyy/PepPal/tree/main/supabase/migrations` — only the 5 pre-fix migrations are listed.
3. `https://github.com/jfrisbyy/PepPal/tree/9c099a5/supabase/migrations` — the two security fix files are present at the pre-revert commit.

**Fix:**
1. Re-add both migration files to `supabase/migrations/` (cherry-pick from `9c099a5` or `b282759`).
2. Add a CODEOWNERS rule (`/supabase/ @jfrisbyy`) and/or branch protection that prevents `rorkagent` from force-overwriting the migrations folder.
3. Add an integrity check in CI that fails if a "Restore to the previous version" commit touches `/supabase/`.
4. Document in PLAN.md that migrations are the source of truth and Rork-side restores must not delete them.

### CRITICAL-NEW-2 — `notifications` INSERTs are 100% broken (CRIT-2 regression in client)

See §3.B. Four call sites (`MessagingService.swift:182, 244, 478` + `GroupsViewModel.swift:88`) attempt direct INSERT into `notifications`. After CRIT-2 dropped the open INSERT policy, no replacement was added. Net effect: **no in-app notification has been delivered to any user since CRIT-2 landed**, except for any inserted server-side via service_role (none observed in the iOS client).

**User-facing symptoms:**
- Following a user no longer notifies them.
- Sending a friend request no longer notifies the recipient.
- Sending a DM no longer notifies other conversation participants.
- Requesting to join a group no longer notifies the owner — and `GroupsViewModel.sendJoinRequestNotification` swallows the error so the user sees no feedback at all.

**Fix:** RPC sketch in §3.B. Or, at minimum, narrow-scoped INSERT policies per relationship (e.g., `WITH CHECK (auth.uid() IN (SELECT user_id FROM follows WHERE following_id = NEW.user_id))` for follow notifications, etc.). RPC is cleaner because the routing logic stays in one place.

### CRITICAL-NEW-3 — Cross-user `profiles` reads break the social feed (CRIT-7 regression)

See §3.A. 8 call sites read other users' profile data through `from("profiles")`. Symptoms:

- `MessagingService.searchUsers` returns empty results — **user search is non-functional**.
- `MessagingService.fetchProfilesByIds` silently returns `[]` per ID (catch-all swallow).
- `MessagingService.fetchConversations` cannot decode `SupabasePostAuthor` for the other party — **DM list shows no names/avatars**.
- `SocialService.fetchPosts`, `fetchComments`, `fetchUserPosts` return rows with `profiles: null` — **feed/comments/profile show "Unknown user"**.

**Fix:** Migrate all cross-user reads to `from("profiles_public")`. Watch the column gap (§3.A note); decide whether to widen `profiles_public` or narrow the Swift struct. Recommendation: widen the view to include `avatar_color, active_program, total_fp, current_streak` (none are sensitive; all were public before CRIT-7).

### HIGH-NEW-1 — Silent error swallowing masks RLS denials

Empty `catch {}` blocks consume real errors. Sites:

- `MessagingService.swift:513` — inside `fetchProfilesByIds` per-ID loop. RLS denials look identical to "user doesn't exist."
- `GroupsViewModel.swift:92` — `sendJoinRequestNotification` swallows the CRIT-2 RLS denial; group owner never learns about pending join requests.

**Fix:** Replace bare catches with at minimum a `print`/`os_log` that distinguishes Supabase `PostgrestError` from network errors, and surface a user-visible toast for the `GroupsViewModel` case.

### HIGH-NEW-2 — No deep-link handler for Supabase auth callbacks

`FrisFitApp.swift` is 14 lines and has no `.onOpenURL` handler. If `resetPassword(email:)` (AuthService L81) ever sends a magic-link or recovery URL, the iOS app cannot consume it; users tap the email link, the app opens, and the URL is dropped.

**Fix:** Add `.onOpenURL { url in Task { try? await SupabaseService.shared.client.auth.session(from: url) } }` (or the Swift SDK's equivalent `auth.handle(url:)` API) to the root scene. Confirm the iOS bundle declares the matching URL scheme in `Info.plist` and Supabase Auth has the redirect URL allow-listed.

### HIGH-NEW-3 — `errorMessage` in `AuthService` is never populated

`AuthService.errorMessage` is declared (`@Observable` `var errorMessage: String?`) and reset to `nil` at the start of `signUp`/`signIn`/`signOut`/`resetPassword`, but never assigned when an error is thrown. Any UI that binds to `errorMessage` will display nothing on auth failure.

**Fix:** Wrap each call in `do/catch`, set `self.errorMessage = error.localizedDescription`, and rethrow.

### HIGH-NEW-4 — RPCs not verified to be SECURITY DEFINER with auth checks

Four counter-mutation RPCs are called from `SocialService.swift`: `increment_high_five_count`, `decrement_high_five_count`, `increment_repost_count`, `decrement_repost_count`. Their definitions are not in source control (no migration adds them) and Phase 1's function inventory should be re-checked. Threats if they are not properly defined:

- If they are SECURITY INVOKER (default), they run with the caller's privileges and require an UPDATE policy on `feed_posts` allowing column-level updates of the counter — likely missing.
- If they are SECURITY DEFINER without a `SET search_path = ...` clause, they are vulnerable to search_path injection (low practical risk on a managed DB, but lint-fail-worthy).
- They take `row_id` (an arbitrary UUID) without checking that the caller has a like/repost relationship; a malicious client can spam any post's counters.

**Fix:** Confirm function definitions in Supabase. If they exist as `SECURITY DEFINER`, add `SET search_path = public, pg_temp` and an ownership check; if they don't exist at all, the like/repost flow is currently broken silently.

### MEDIUM-NEW-1 — Storage uploads use a caller-supplied `userId` rather than the authenticated user ID

In `ProfileService.uploadAvatar`, `BloodworkService.uploadPhoto`, and `SocialService.uploadAudio`/`uploadMedia`, the storage path is built from a `userId: String` parameter passed in by the caller. The folder-scoped storage policies (CRIT-5) will reject any path that doesn't start with `auth.uid()/`, so an attacker cannot exploit this — but for defense-in-depth and to match `ProgressPhotosView` (which derives `userId` from `AuthService.shared.currentUserId()`), the same pattern should be applied.

**Fix:** Inside each upload function, do `let authedUid = try AuthService.shared.currentUserId()` and assert `authedUid == userId` (or simply ignore the parameter and use `authedUid`).

### MEDIUM-NEW-2 — `markNotificationRead` lacks defense-in-depth `user_id` filter

`MessagingService.swift:546-553` — `UPDATE notifications SET is_read=true WHERE id = notificationId`. If `notifications.id` is not globally unique to the user (very unlikely), or if RLS were ever loosened on this table, this would let one user mark another user's notification read. RLS as currently configured prevents this, but the explicit filter is cheap belt-and-braces.

**Fix:** Add `.eq("user_id", value: try AuthService.shared.currentUserId())`.

### MEDIUM-NEW-3 — `searchUsers` uses ILIKE with user-controlled fragments

`MessagingService.swift:520-530` builds an `or("display_name.ilike.%\(query)%, username.ilike.%\(query)%")` predicate by string interpolation. PostgREST will URL-encode the value, so SQL injection is not the concern — but a query containing `,`, `.`, `(`, `)`, or backslash characters can manipulate the OR-list parsing on the PostgREST side and cause a 400 or, in older `supabase-swift` versions, leak partial filter expressions into logs.

**Fix:** Sanitize `query` to alphanumerics + space + `_` before interpolation, and reject queries shorter than 2 characters.

### MEDIUM-NEW-4 — RorkJSON capabilities allow-list is permissive

`rork.json` declares `framework: "swift"` and `capabilities: ["healthkit"]`. `FrisFit.entitlements` matches (HealthKit only). However, the Rork agent has historically reverted the entire repo (see CRITICAL-NEW-1). If the Rork agent has push access, no entitlements check at the database level will save you from a server-side migration revert.

**Fix:** Document the Rork agent's push permissions and decide whether to limit them via branch protection. (Out of strict iOS-codebase scope but worth noting.)

### LOW-NEW-1 — `circles` invite-code SELECT is a public scan

`CircleService.swift:183` reads `circles` filtered by `invite_code = code.uppercased()`. This is the join-by-code flow. If RLS on `circles` SELECT requires `is_private = false` OR ownership, joining via private invite codes will fail. Confirm Phase 1 SELECT policy on `circles` allows public scan when `invite_code` is supplied; otherwise the "join private group via code" flow is broken.

### LOW-NEW-2 — `BloodworkService` deletes `biomarker_results` filtered by `entry_id` only

`BloodworkService.swift:117-121` filters delete by `entry_id` only, not also by ownership of the parent `bloodwork_entries`. Safe if `biomarker_results` SELECT/DELETE policies enforce ownership transitively (CRIT-3 follow-up Category B). If not, a malicious client could delete biomarker rows for another user's entry. Verify with Phase 1.

### LOW-NEW-3 — `Config.swift` is a placeholder

`ios/FrisFit/Config.swift` declares `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`, `EXPO_PUBLIC_OPENROUTER_API_KEY`, etc., as empty strings. They are populated at build time by Rork. **No hardcoded secrets in source control.** Good. Flagging as LOW only because the build-time injection mechanism is opaque from this audit; verify the Rork build pipeline does not log or check the populated `Config.swift` into a downstream artifact.

### LOW-NEW-4 — Push notifications entitlement absent

`FrisFit.entitlements` only declares `com.apple.developer.healthkit`. There is no `aps-environment` entitlement, so even if the `notifications` table fix lands, **APNs delivery is impossible** without it. Out of strict security scope (functional gap), but worth surfacing.

## 5. Cross-reference status of every `.from(...)` call site (132 total)

Status legend: **OK** = compatible with post-CRIT-1..8 RLS; **CRIT-X** = broken by the named CRIT fix; **NEW** = Phase-2 finding (see §4).

| File:Line | Op | Object | Status |
|---|---|---|---|
## 5. HIGH-1 (Phase 1 carry-over) — unindexed FK columns on hot iOS paths

Phase 1 listed 22 unindexed FK columns. Without re-querying the DB I cannot enumerate them here, but the iOS-side hot paths most likely to bite at scale (10k+ users) are:

- `feed_posts.user_id` — every `fetchPosts`/`fetchUserPosts` filters/joins on this. (HIGH at scale.)
- `post_comments.post_id` — every comment thread fetch.
- `post_likes.post_id` and `post_likes.user_id`.
- `direct_messages.conversation_id`.
- `conversation_participants.user_id` and `conversation_participants.conversation_id`.
- `notifications.user_id`.
- `friend_requests.receiver_id` and `sender_id`.
- `follows.follower_id` and `following_id`.
- `dose_logs.protocol_id`.
- `protocol_compounds.protocol_id`.

Recommend cross-checking these against Phase 1's 22-FK list and prioritizing indexes on whichever appear in both.

## 6. Other Phase 1 HIGH findings (carry-over status)

HIGH-2..HIGH-6 from the Phase 1 Google Doc are not re-derived here. Once Phase 1 list is shared in chat, I can map each to specific iOS call sites in a follow-up commit on this same Draft PR.

## 7. Files audited (snapshot)

- 28 files in `ios/FrisFit/Services/` (full inventory captured).
- `ios/FrisFit/Config.swift`, `ContentView.swift`, `FrisFitApp.swift`, `FrisFit.entitlements`.
- `ios/FrisFit/Views/ProgressPhotosView.swift` (only View with Supabase calls).
- `ios/FrisFit/ViewModels/{GroupsViewModel,RunningViewModel,CyclingViewModel}.swift` (Groups had Supabase calls; Running/Cycling matched the search but their `.from(` was non-Supabase — false positive).
- `supabase/migrations/` at HEAD (`c960f13`) — 5 pre-CRIT migrations only — and at `9c099a5` (pre-revert) — 2 CRIT migrations.
- Repo-root: `.gitignore`, `ios/.gitignore`, `PLAN.md`, `rork.json`. No `.env` committed (allowlisted in both `.gitignore`s).
- Tests directories (`FrisFitTests/`, `FrisFitUITests/`) **not audited for security findings** per scope; not searched for hardcoded secrets in this pass — flagged as a follow-up.

## 8. Open questions for the developer

1. Did the Rork "Restore to the previous version" commit (`592b0ef`) revert any iOS source changes that mattered? It touched 480 files. The Phase 2 audit assumes the iOS code at `c960f13` is the version you intend to ship; if any of those 480 files contained other Phase 1 follow-up work, this audit may have missed it.
2. Are the four counter RPCs (`increment_high_five_count` etc.) actually defined on the live database? They have no migration in source control.
3. Does the live `notifications` table currently have ANY `INSERT` policy for `authenticated` role, or only for `service_role`? CRIT-2 dropped the open one without adding a replacement; this audit assumes "no replacement" but a quick `pg_policies` check would confirm.
4. Is `feed_posts` SELECT public-readable for non-authors? `fetchUserPosts` would otherwise be broken.
5. Is the `circles` SELECT policy permissive enough to match by `invite_code` regardless of membership?

---

*Generated by Phase 2 Codebase Audit — read-only, no remediation in this PR. Suggested next steps in §0 punch list.*
