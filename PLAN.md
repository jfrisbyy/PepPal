# Daily Brief — Sonnet / Haiku split

Goal: cut briefing cost ~70% while keeping the user experience identical to today's "always Sonnet" behavior. Haiku must read like Sonnet — same tone, same depth, same specificity. The user must not be able to tell which model produced any given brief.

## Model schedule

- **Sonnet (deep)** — runs twice per day on device-local time:
  - Morning window (first foreground after 6:00 AM)
  - Evening window (first foreground after 6:00 PM)
  - Sonnet output now includes a compact `patternsMemo` — a distilled "what to know about this user across their full history" string Haiku reuses verbatim as authority for the rest of the day.
- **Haiku (fast)** — every other refresh:
  - Anchored 1:00 PM run (always fires once per day, even if no logs)
  - Any user log (meal, workout, weight, dose, side effect, bloodwork) with **30s debounce** — rapid-fire logs collapse into one regen
  - Manual pull-to-refresh
- Haiku is given: latest `patternsMemo` from Sonnet, the previous full brief, and the new context bundle. Its job is to produce a brief in the exact same shape with the same tone, updated for what changed.

## Push notification

- Daily 1:00 PM local notification ("Midday brief is ready") nudges the user to open the app. On open, the 1pm Haiku refresh runs (or has already run during a foreground session).

## Persistence

- `patternsMemo` rides inside `TodaysPlanResponse.patternsMemo` and persists in the existing `ai_daily_briefings.plan_response` jsonb. No schema migration needed.
- `model_tier` is recorded inline in the JSON for analytics.

## Quality guardrails

- Haiku system prompt explicitly inherits the full Sonnet voice prompt and is told to preserve language, sentence shape, and depth — only swap in updated numbers and re-evaluate which actions / modules apply now.
- If `patternsMemo` is missing (cold start), Haiku falls back to running the full Sonnet prompt itself so output never degrades.

## Tasks

- [x] Add `patternsMemo` to `TodaysPlanResponse`.
- [x] Split `TodaysPlanService` into `generateDeep` (Sonnet, emits memo) and `generateFast` (Haiku, consumes memo + previous brief).
- [x] `TodaysPlanViewModel`: tier selection per window, 30s event debounce, 1pm Haiku anchor, memo persistence, local push scheduling.
- [x] Schedule recurring 1pm local notification.
