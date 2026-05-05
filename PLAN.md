# Persist Apple Health to Supabase for summaries, AI, and offline fallback

## Why

Right now Apple Health data only lives in memory and a local cache on this device. That means weekly/monthly summaries have to re-query HealthKit every time, AI briefings can't reason about long-term trends, and when the app opens cold (or HealthKit hasn't refreshed yet) cards show empty placeholders instead of your last known numbers. Pushing the data to your account in the cloud fixes all three.

## What you'll get

- **Always-on numbers**: Steps, sleep, HRV, resting heart rate, calories, weight, and every other Health metric stay visible even before HealthKit finishes refreshing — the app shows your last saved values with a subtle "as of …" timestamp.
- **Real weekly & monthly summaries**: End-of-week and end-of-month recaps pulled from a true 7/30/90-day history, including averages, deltas vs. previous period, best day, and streaks.
- **Smarter AI briefings**: The morning brief and Insights agent can compare today vs. your trailing baseline, spot regressions ("HRV down 12% vs. your 30-day average"), and tie protocols/training to long-term Health changes.
- **Cross-device continuity**: If you sign in on a new phone, your Health history is already there.
- **Workout history in the cloud**: Runs, lifts, swims, cycling, and basketball workouts from Apple Health are stored so your Activity tab and AI can reference them even months later.

## How it will sync

- **On app open / foreground**: A debounced sync pushes the latest daily snapshot and any new workouts (at most once per hour to save battery and bandwidth).
- **Background observers**: HealthKit background delivery wakes the app when new Health samples arrive (e.g. you close a ring, finish a workout, log sleep) and silently uploads the delta.
- **First-time backfill**: On connect, the last 90 days of daily series + workouts are uploaded once, then only deltas after that.
- **Conflict-safe**: Every record is keyed by user + date + metric so re-syncs overwrite cleanly without duplicates.

## How it will look in the app

- Health cards on Home, Activity, and the Daily Energy/Activity strips show a faint "Updated 2h ago" line when data comes from the cloud cache instead of a live HealthKit pull.
- A new **Weekly Recap** and **Monthly Recap** card appears in the Activity tab every Monday / 1st of the month, built from the persisted history.
- AI Morning Brief gains a "Trend" line ("Sleep averaging 6h 42m this week, down from 7h 18m last week").
- Settings → Apple Health gains a "Cloud sync" row showing last upload time, total days stored, and a "Re-sync 90 days" button.

## What gets stored

- **Daily snapshots**: One row per day with all scalar metrics (steps, calories, HR, HRV, RHR, sleep stages, weight, body fat, BMI, VO2 max, hydration, mindful minutes, blood pressure, glucose, temperature, dietary macros).
- **Series points**: Per-metric time series for charts (week / month / 90-day views) so the Health detail screens load instantly without HealthKit.
- **Workouts**: Type, start/end, duration, distance, calories, average HR, source — for runs, lifts, swims, rides, basketball, etc.
- **Sleep nights**: Asleep, deep, REM, core breakdown per night.

All rows are scoped to your user account with row-level security so only you can read or write your own data.

## Privacy

- Sync only runs when the Apple Health toggle is ON. Turning it off pauses uploads (existing cloud data stays until you tap "Delete cloud Health data").
- A new "Delete all my Health data from cloud" button is added in Settings → Apple Health for full control.
