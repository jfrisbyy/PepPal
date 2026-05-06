# Intelligent notification system with smart timing & controls

## What we're building

A unified, context-aware notification system that replaces the scattered reminders we have today (vials, titration, streaks) with one smart engine. It learns your day — when you train, sleep, eat, log — and only pings you when it actually helps.

## Features

**Smart, context-aware nudges**
- **Training**: pre-session reminder timed to your usual workout window; "missed session" nudge only if today was a planned training day and nothing was logged by evening.
- **Sleep**: wind-down ping ~45 min before your average bedtime; morning "log last night's sleep" only if Apple Health didn't auto-fill.
- **Nutrition**: meal log reminders aligned to your eating pattern; hydration cue mid-afternoon; "macros off-track" alert in the evening only when meaningfully off.
- **Supplements & doses**: time-of-day reminders pulled from your protocol schedule (consolidates today's per-feature reminders).
- **Daily tasks & brief**: morning brief drop; one gentle reminder if tasks remain unchecked by late afternoon.
- **Social**: real-time push for DMs, circle mentions, buddy invites, and reactions.
- **Streaks & achievements**: milestone celebrations and a "save your streak" warning before the day ends.

**Intelligence rules (no random spam)**
- Pulls from your training schedule, sleep average, meal log times, and time zone.
- Suppresses anything already completed (no "log breakfast" if breakfast is logged).
- Frequency cap: a max number per day across all categories, with priority ordering (social > supplement > training > sleep > nutrition > tasks > streak).
- Respects quiet hours — anything that would fire inside the window gets dropped or rescheduled to the edge.

**User controls**
- New **Notifications** screen in Settings:
  - Master toggle.
  - Per-category toggles (Training, Sleep, Nutrition, Supplements, Tasks, Social, Streaks).
  - Quiet hours picker (default 10pm–7am).
  - Daily frequency cap slider (3 / 5 / 8 / unlimited).
  - "Send a test notification" button.
- Permission re-prompt flow if denied.

**In-app notification center**
- New bell icon in the home header with unread badge.
- Full-screen list grouped by Today / This week / Earlier.
- Each row: icon, category color, title, snippet, relative time, unread dot.
- Tap → deep-links to the relevant screen (workout, sleep card, DM thread, etc.).
- Swipe to dismiss; "Mark all read" action.
- History persists for 30 days.

**Delivery**
- **Local** for everything scheduled (training, sleep, supplements, tasks, daily brief).
- **Remote push** via Supabase + APNs for social/real-time events (DMs, circle activity, buddy actions).
- A daily background refresh re-plans the next 24h of local notifications based on the latest data.

## Design

- Notification copy follows your existing coach voice — short, direct, specific numbers, no emojis, no "Great job!" filler.
- Notification center uses the same card aesthetic as the home cards: rounded corners, soft shadow, category accent color on the left edge (training=orange, sleep=indigo, nutrition=green, supplements=purple, social=blue, streak=amber).
- Empty state: a calm illustration with "You're all caught up" and a subtle pulse animation.
- Settings screen uses native iOS grouped list styling with inline pickers and a small preview card showing what a notification will look like.
- Bell icon: subtle bounce + haptic when a new notification arrives while app is open.

## Screens

1. **Home header** — new bell icon with unread count badge.
2. **Notification Center** — full list of past notifications with grouping, swipe actions, deep links, and empty state.
3. **Notification Settings** (in Settings) — master toggle, category toggles, quiet hours, frequency cap, test button.
4. **Permission prompt sheet** — friendly explainer shown once on first relevant action if permissions were denied, with a button to open system Settings.

## Rollout note

This consolidates the current vial, titration, and streak reminders under one engine so there's a single place users manage everything. Existing schedules will be migrated automatically — no setup required.