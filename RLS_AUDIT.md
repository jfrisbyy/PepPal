# RLS audit — May 2026

This file is the source of truth for what each public table allows. Use it
as a checklist when adding new tables or policies. The SQL lives in:

- `supabase/migrations/20260517000000_rls_audit_and_hardening.sql`
  (catalog-driven enable-RLS loop + generic owner_* backstop)
- `supabase/migrations/20260518000000_rls_storage_abuse_hardening.sql`
  (explicit cross-user policies + storage bucket lockdown + ai_usage_daily)

## Legend

- ✅ Reviewed, scoped policy in place.
- ⚠️ Backstop only (`auth.uid() = user_id`). Fine for purely-private data,
  but should be reviewed if the table grows social/cross-user reads.
- 🔓 Intentionally readable by all authenticated users (e.g. public feed).

## Cross-user tables

| Table | Read | Write | Status |
|---|---|---|---|
| `follows` | any authenticated | only as `follower_id` | ✅ |
| `feed_posts` | any authenticated | only as `user_id` | ✅ 🔓 read |
| `post_comments` | any authenticated | only as `user_id` | ✅ 🔓 read |
| `post_likes` | any authenticated | only as `user_id` | ✅ 🔓 read |
| `post_reposts` | any authenticated | only as `user_id` | ✅ 🔓 read |
| `circles` | public circle OR member | creator inserts, admins update, creator deletes | ✅ |
| `circle_members` | self / co-member / public-circle peers | self join+leave, admins update | ✅ |
| `circle_messages` | members of the circle | members as themselves | ✅ |
| `circle_posts` | members of the circle | members as themselves; author updates/deletes | ✅ |
| `circle_post_comments` | members of the circle | members as themselves | ✅ |
| `circle_post_likes` | self read/write | self only | ✅ |
| `circle_invites` | sender or invitee | sender or invitee | ✅ |
| `groups` | public OR member | creator inserts, admins update, creator deletes | ✅ |
| `group_members` | self / co-member / public-group peers | self join+leave, admins update | ✅ |
| `group_messages` | members of the group | members as themselves | ✅ |
| `group_message_likes` | members of the group | self only | ✅ |
| `group_join_requests` | self + admins | self insert, admins update | ✅ |
| `cheerlines` | sender or recipient | sender or recipient | ✅ |
| `conversations` | participants only | any authenticated insert; participants update | ✅ |
| `conversation_participants` | participants of same conversation | self only (cannot pull a stranger in) | ✅ |
| `direct_messages` | participants of the conversation | only as sender + must be participant | ✅ |
| `friend_reactions` | sender or receiver | sender insert/delete | ✅ |
| `friend_nudges` | sender or receiver | sender insert | ✅ |
| `friend_activity_events` | self or follower | self only | ✅ |
| `friend_stat_snapshots` | self or follower (when sharing on) | self only | ✅ |
| `stat_sharing_prefs` | self or follower | self only | ✅ |

## Per-user data tables (backstop is correct)

These tables hold data that should never cross user boundaries; the
generic `auth.uid() = user_id` backstop is the right policy:

`user_preferences`, `disclaimer_acknowledgements`, `journey_events`,
`personal_records`, `routines`, `tracked_compounds`, `food_favorites`,
`ai_memory_facts`, `ai_daily_briefings`, `ai_weekly_summaries`,
`health_daily_snapshots`, `health_series_points`, `health_sleep_nights`,
`health_workouts`, `health_sync_state`, `compound_usage_stats`,
`manual_sleep_logs`, `protocol_notes`, `daily_ratings`,
`recovery_milestones`, `progress_photos`, `device_tokens`,
`conversation_mutes`, `client_errors`, `ai_usage_daily` (read-only client),
plus any new `user_id`-keyed table picked up by the catalog loop.

## Storage buckets

| Bucket | Public? | Path | Notes |
|---|---|---|---|
| `avatars` | yes (read) | `<auth.uid>/...` for writes | profile display |
| `banners` | yes (read) | `<auth.uid>/...` for writes | profile display |
| `post-media` | yes (read) | `<auth.uid>/...` for writes | feed images/audio |
| `dm-media` | **no** | `<auth.uid>/...` r+w | accessed via signed URLs |
| `protocol-note-photos` | **no** (changed in 20260518) | `<auth.uid>/...` r+w | client uses `createSignedURL` (1y) |
| `body-progress` | no | `<auth.uid>/...` r+w | private |
| `meal-photos` | no | `<auth.uid>/...` r+w | private |

## Edge functions

| Function | JWT required at entrypoint? | Notes |
|---|---|---|
| `ai-proxy` | ✅ yes | + 30 req/min, + 50k tokens/day, + model allow-list, + 8MB cap |
| `super-action` | ✅ yes (in `requireUser` before action switch) | per-action checks layered on top |

## Abuse / cost controls

- `ai-proxy` enforces a per-user daily token budget (default **50,000**
  tokens/day, overridable via `ai_usage_daily.daily_token_limit`).
- Token usage is updated by the proxy via `public.ai_usage_increment(...)`
  RPC after each successful upstream call.
- Clients can read their own usage from `ai_usage_daily` (RLS allows
  owner select; insert/update/delete are revoked from `authenticated`).

## Logging hygiene

- `ai-proxy`:
  - Successful calls: **nothing logged**.
  - Upstream non-2xx: `{ event, status, model, user (sha-256 prefix), error (≤512 chars) }`.
  - Fetch failure: `{ event, model, user (sha-256 prefix), error (≤256 chars) }`.
  - **Never** logs request body, response body, prompts, completions, or JWTs.
- Sentry (`CrashReportingService`):
  - `sendDefaultPii = false`.
  - Outgoing events are run through `scrubString` to redact JWTs and bearer tokens.
  - Tag keys containing `token`, `secret`, `password`, `auth`, `email` are dropped.

## Re-audit checklist (run before every release)

1. `select tablename from pg_tables where schemaname = 'public'`
   → diff against this file. New rows = new policies needed.
2. `select * from pg_policies where schemaname = 'public' order by tablename;`
   → confirm every cross-user table has explicit policies (not just `owner_*`).
3. `select id, public from storage.buckets;`
   → confirm `dm-media` and `protocol-note-photos` are still `public = false`.
4. Trigger a known-error path in dev → confirm Sentry receives the event,
   and `client_errors` shows the row.
5. Burn 50,001 tokens with a test user → confirm `ai-proxy` returns
   `daily_budget_exceeded` with `retry_after_seconds`.
