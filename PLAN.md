# Persist remaining domains to Supabase

Audit the app and close the gaps where data is still local-only (UserDefaults / in-memory)
so a user can reinstall, switch devices, or come back after a long break and find their full
stack intact.

## Already persisted (verified — no work needed)

- Protocols, `protocol_compounds`, `dose_logs`, `side_effect_logs`, `supplements`, `protocol_notes`, `daily_ratings`, `recovery_milestones`, `titration_steps`, `compound_costs`
- `workouts` (with exercises JSON), `cardio_sessions`, `training_programs` (AI-built + manual)
- `logged_meals`, `food_items` (incl. user-custom), `food_favorites`
- `bloodwork_entries`, `biomarker_results`
- `body_goals`, `weight_logs`, `body_measurements`
- `daily_tasks` (with per-date completion history)
- `personal_records`, `activity_logs` (streaks)
- `tracked_compounds`, `journey_events`, `ai_memory_facts`

## Gaps closed by this work

- [x] **`vials`** — vial inventory was UserDefaults-only. New table + sync from `VialInventoryStore`.
- [x] **`basketball_games`** — entire basketball dashboard was sample data. Persist games + shot charts (JSON).
- [x] **`macro_targets`** — user-level macro target now persisted (was local).
- [x] **`task_categories`** — custom task categories persisted (was local).
- [x] **`body_progress_photos`** + storage bucket — progress photos persist (table existed only as model).
- [x] Wire each store/VM to load from Supabase on auth and write-through on every mutation.

## Migration

Single migration `20260509000000_persistence_gaps.sql` adds the five tables above with RLS,
indexes, and the `body-progress-photos` storage bucket + policies.

## Out of scope (separate work)

- Adaptive macro recalibration history (`AdaptiveTargetService` cache) — local cache is fine.
- Vial label image bytes (`VialLabelImageStore`) — keep on device for now; URL on the row is enough for restore.
