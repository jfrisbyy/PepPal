# Scale hardening — pagination, disk persistence, indexes

## 1. Per-user disk store helper

- [x] Create `PerUserDiskStore` (Application Support / `users/<uid>/<file>.json`).
- [x] Wire purge on user switch / sign-out via `LocalStateResetCoordinator`.

## 2. Move large blobs out of UserDefaults

- [x] HealthKit series cache (`HealthKitCache`) → disk (per-user).
- [x] Journey events cache (`JourneyEventService`) → disk (per-user).
- [x] Food favorites store → disk (per-user).
- [x] Story mode cache → disk (per-user).

## 3. Pagination / limits on unbounded selects

- [x] `ActivityLogService` lists.
- [x] `NutritionService.fetchMeals` window (already date-bounded, no change needed).
- [x] `TrainingProgramService.fetchPrograms`.
- [x] `MessagingService` follow / friend lists.
- [x] `CircleService.list*`.
- [x] `BasketballGameService.fetchAll`.

## 4. Supabase indexes migration

- [x] `20260515000000_perf_indexes.sql` — composite indexes on hot tables.

## 5. Realtime fan-out

- [x] `RealtimeFeedService` channel scoped per-user (was `feed-posts-global`).
- [x] `RealtimeLifecycleCoordinator` registers every Realtime subscription, tears
      them down on `UIApplication.didEnterBackground`, replays on foreground.
- [x] `AuthService.signOut()` calls `RealtimeLifecycleCoordinator.unsubscribeAll()`.
- [ ] Migrate `NotificationsRealtimeService` and `RealtimeMessagingService` to
      register through the coordinator (currently still managed by their VMs).

## 6. Account deletion / GDPR export

- [x] `super-action` edge function: `deleteAccount` action.
- [x] `delete_user_data(uuid)` SQL helper iterates every `public.<table>` with a
      `user_id` column.
- [x] Wipes per-user storage folders (`avatars`, `banners`, `body-progress`,
      `meal-photos`, `dm-media`, `protocol-note-photos`).
- [x] Deletes `auth.users` row last; client signs out.
- [x] `PrivacyDataView` now invokes `super-action.deleteAccount` (was missing
      `delete_account` function).

## 7. Migration safety

- [x] New migration `20260517000000_rls_audit_and_hardening.sql` uses
      `BEGIN/COMMIT`, idempotent `if not exists` / `do $$ ... $$` blocks.
- [x] Catalog-driven enable-RLS loop instead of hard-coded table list — picks
      up new tables automatically.

## 8. RLS policy audit

- [x] Migration enables RLS on every public table.
- [x] Backstop "owner_*" policies created for any `user_id` table that had no
      existing policy (skipped if any policy already exists, so curated rules
      on `follows`, `feed_posts`, etc. are preserved).

## 9. Image / media pipeline

- [x] `ImageCompressor` utility with kind-specific presets (avatar, banner,
      meal, progress, feed, thumbnail).
- [x] `ProfileService.uploadAvatar` / `uploadBanner` resize before upload.
- [x] Storage bucket policies for `body-progress`, `meal-photos` (private,
      per-user folder).
- [ ] Sweep remaining call sites (PhotoMealView, ProgressPhotosView,
      ChatConversationView etc.) onto `ImageCompressor` — they currently use
      ad-hoc `jpegData(compressionQuality:)`.

## 10. Crash + error reporting

- [x] `client_errors` table with RLS (owner insert/select), 30-day retention.
- [x] `super-action.logClientError` action.
- [x] `ErrorLogger` Swift service with dedupe + device/version/screen context.
- [ ] Add `ErrorLogger.shared.log(...)` calls at top-level catch sites
      (NetworkService, ViewModels). Currently only wired into PrivacyDataView.

## 11. AI key hardening (server-side proxy)

- [x] `supabase/functions/ai-proxy/index.ts` — JWT-authenticated proxy in front
      of OpenRouter. Validates the user, enforces a per-user 1-min rate limit,
      8 MB request cap, and a model allow-list, then forwards using the
      server-only `OPENROUTER_API_KEY` env.
- [x] `AIProxyClient` Swift helper — every chat-completion call routes through
      `${SUPABASE_URL}/functions/v1/ai-proxy` with the user's Supabase JWT.
- [x] Swapped call sites onto the proxy: `OpenRouterClient` (AIModelTier),
      `TodaysPlanService`, `InsightsAgentService`, `LabParsingService`,
      `NutritionAIService`, `AIProgramService`, `FinnChatViewModel`,
      `PeptideAIChatViewModel`. No service references
      `EXPO_PUBLIC_OPENROUTER_API_KEY` anymore.
- [x] Set `OPENROUTER_API_KEY` as a Supabase Function secret. `ai-proxy` is
      auto-deployed via Rork sync.
- [ ] Smoke-test a chat call end-to-end, then rotate / remove the bundled
      `EXPO_PUBLIC_OPENROUTER_API_KEY` value.

## 12. Schema bloat from JSON columns

- [ ] Audit `jsonb` columns where we filter/aggregate (notes,
      `friend_activity_events.data`, `health_daily_snapshots.payload` etc.).
- [ ] Promote frequently-queried fields to typed columns + GIN index where the
      blob stays.
