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

---

# Long-Horizon User Memory (cross-session)

Goal: give Sonnet (and via `patternsMemo`, Haiku) awareness of the user's **entire history** — bloodwork from 2 months ago, a failed keto attempt in February, prior PR cycles, recurring shoulder tweaks — without blowing the context window or cost.

## Architecture

A single, rolling, AI-curated narrative per user (`profile_memo`, ~1000 tokens), plus a structured list of `significant_events` the model should never forget. Sonnet reads both on every deep run, then rewrites the memo at the end of each deep run.

Three layers fed to Sonnet:
1. **Static profile** — onboarding answers, demographics, goals, constraints (already passed today).
2. **Long-term memo** — Sonnet-curated narrative across all time. Capped ~4 KB / ~1000 tokens.
3. **Recent window** — last 7-14 days of raw logs (already passed today).

Sonnet output: brief + `patternsMemo` (today only, for Haiku) + new `profile_memo` (durable). Haiku reads memo + events but never writes.

## Significant events

Auto-detected from log writes. Captured types:
- `bloodwork_uploaded` — every panel with key markers summarized
- `program_started` / `program_abandoned` — training program changes
- `protocol_started` / `protocol_changed` — peptide/compound changes
- `weight_milestone` — ≥5% bodyweight change vs. baseline or last milestone
- `side_effect_escalation` — severity trending up week-over-week
- `pr_streak` — multiple PRs in a short window

Stored as `[{ id, at, type, summary, values?, source? }]`, capped at 100 (rolling).

## Storage

`public.user_long_term_memory` (one row per user):
- `profile_memo text` — current durable memo
- `memo_versions jsonb` — last 10 versions for rollback
- `significant_events jsonb` — capped 100 entries
- `last_updated_at`, `last_updated_by_model`
- RLS: user reads own row; same row used by client + future server jobs.

Memory editor is **not user-visible** in v1 (read-only internal context).

## Build order

- [x] Migration: `user_long_term_memory` table + RLS.
- [x] iOS `LongTermMemoryService` — fetch memo + events, append event, write memo back.
- [x] `TodaysPlanService` deep path: load memo + events, inject into context, run Sonnet memo-updater after the brief, persist new memo.
- [x] `TodaysPlanService` fast path: load memo + events, inject alongside `patternsMemo`.
- [x] Auto-detect significant events: hook `BloodworkService` (upload), `CompoundTrackingManager` / protocol VM (start/change), `BodyGoalsService` (weight milestone). Side-effect / PR detection rolls in via deep memo updater inferring from logs.
