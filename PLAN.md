# Lock down RLS, storage, edge functions, abuse limits, and crash reporting

## What you'll get

A focused security pass that closes the six gaps you flagged, plus real crash/error reporting. One new database migration, edits to the two edge functions, a new Sentry integration on the iOS side, and a short audit document so you can verify nothing was missed.

## 1. RLS spot-check on cross-user tables

A new migration will hand-audit the tables where data crosses user boundaries and replace any generic policy with explicit, scoped rules:

- **follows** — anyone authenticated can read (needed for follower counts), but insert/delete only when `auth.uid() = follower_id`.
- **feed_posts / post_comments / post_likes / post_reposts** — public read stays, but we'll add visibility scoping for posts marked private (author or follower only) and confirm writes are author-only.
- **circles / circle_members** — read only if the circle is public OR the caller is a member; join/leave only on own row; admin-only update for circle settings.
- **circle_messages / circle_posts / circle_post_comments / group_messages** — read only if caller is a member of that circle/group; write only as self AND as a member.
- **direct messages / conversations** — read only if caller is sender or recipient; insert only with `auth.uid() = sender_id` and an existing conversation membership row.
- **friend_reactions / friend_nudges / cheerlines / circle_invites** — sender or recipient visibility only.
- The migration will also flag (in a `do $$ raise notice` block) any `public.*` table whose only policy is the generic backstop, so you get a list to triage.

## 2. Storage bucket policies

The same migration will assert per-user folder policies on every bucket and remove any "public read all" leftovers:

- **avatars / banners** — keep public read (profile pictures), but writes scoped to `auth.uid()` folder.
- **dm-media** — private, read/write only when path's first folder = `auth.uid()` AND the caller is a participant in the referenced conversation. Files are already accessed via signed URLs, so nothing breaks for the app.
- **protocol-note-photos** — switch to private bucket with per-user folder policy; client switches from `getPublicURL` to `createSignedURL`.
- **body-progress / meal-photos / post-media** — verify existing per-user policies, no changes expected.

## 3. JWT verification on every edge function

- **ai-proxy** — already verifies, no change.
- **super-action** — entrypoint will require JWT for every action by default. Each existing action handler keeps its current authorization (admin gating, ownership checks, etc.) but anonymous callers get a 401 before any handler runs.

## 4. ai-proxy logging hygiene

Confirmed and tightened: the proxy already does not log prompts or responses. We'll add a small logger that, on upstream failure, logs only `{ status, model, userId, errorBody }` — never the request body, never the response body, and never auth tokens. Successful calls log nothing.

## 5. Abuse limits beyond rate limit — daily token budget

ai-proxy will get a per-user daily token cap of **50,000 tokens/day** on top of the existing 30 req/min:

- A new `ai_usage_daily` table tracks `(user_id, day, prompt_tokens, completion_tokens)`.
- After each upstream call, the proxy parses `usage` from the OpenRouter response and atomically increments the row.
- Before forwarding a request, the proxy checks today's total; if ≥ 50k, it returns `429 daily_budget_exceeded` with a friendly retry-at timestamp.
- Cap is overridable per-user via a `daily_token_limit` column so you can comp power users without redeploying.

## 6. Crash + error reporting (Sentry)

Real Sentry SDK integration on iOS so you can see crashes, breadcrumbs, and abuse patterns in a real dashboard:

- Add Sentry Cocoa via Swift Package Manager.
- Initialize in `FrisFitApp.swift` with DSN read from `Config.swift` (so it's an env-driven key, not hardcoded).
- Wire breadcrumbs for screen transitions, network requests, and Supabase errors.
- Pipe `ErrorLogger.shared.log(...)` to also forward to Sentry (keeps the existing `client_errors` table as a backup queryable store).
- Strip PII from breadcrumbs (no message bodies, no auth tokens, no health values — just screen names and error types).
- Add `SENTRY_DSN` to `Config.swift` and document it as a required public env var.

## 7. Verification & follow-up

- New `RLS_AUDIT.md` document listing every public table, its read/write policy summary, and a ✅/⚠️ flag — committed alongside the migration so future migrations can be checked against it.
- `runChecks` after the Swift changes.
- Manual verification list at the end of the plan: deploy migration → smoke-test feed/circles/DMs as user A vs user B → confirm Sentry events appear → confirm 50k cap by simulating high usage.

## Deferred (called out but not in this round)

- Schema bloat from `jsonb` columns (item 12 in PLAN.md) — separate pass.
- Realtime channel teardown for `NotificationsRealtimeService` and `RealtimeMessagingService` — already on PLAN.md, separate pass.

