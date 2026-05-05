# Persist briefings & insights with smart, time-based refresh

## What this does

Stops re-running expensive AI generation on every app open. Briefings and insights are saved to the cloud, served instantly from cache, and only refreshed at meaningful moments — preserving a full history users can scroll back through.

## Refresh behavior

- **Time-of-day windows**: auto-refresh once per window when the user opens the app — 6 AM, 1 PM, and 6 PM. If the user never opens the app during a window, nothing is generated (no work for inactive users).
- **Event-driven refresh**: regenerate after meaningful new logs — a dose, a meal, a workout, a supplement, a body metric, a basketball game, etc.
- **Otherwise instant**: every other app open serves the last saved briefing from the cloud with no AI call and no spinner.
- **Manual override**: pull-to-refresh always forces a fresh generation.

## What gets persisted

- Daily briefings (one final version saved per day, plus intra-day versions overwritten until the day ends)
- Weekly summaries
- Monthly summaries
- Home-screen insights / AI strip lines
- Each entry stores: date, type, generated-at timestamp, trigger reason (time window / event / manual), and the underlying snapshot of stats it was based on

## History & calendar

- Past days, weeks, and months are kept permanently per user
- Home-screen calendar date picker: tapping a previous date loads that day's **final** saved briefing instantly from the cloud — no regeneration
- Weekly/monthly views show the locked summary for completed periods
- Today's briefing keeps updating through the day; once the day ends it's locked as the "final" version for history



## Behind the scenes

- New cloud tables for briefings, weekly summaries, monthly summaries, and insights — each scoped to the signed-in user with privacy rules
- A lightweight scheduler in the app decides on each open: "is there a fresh-enough briefing? if not, which window are we in, and is regeneration warranted?"
- Logging actions (meal, dose, workout…) flag the current briefing as stale so the next open regenerates
- Migration file provided for clean copy-paste into Supabase, matching the style of the previous migrations

