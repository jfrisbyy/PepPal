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
