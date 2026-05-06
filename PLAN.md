# Reimagine Basketball mode for everyday hoopers

## The shift

Today the basketball page leads with PPG / RPG / APG — numbers most casual hoopers don't track and don't relate to. We'll flip the experience so the everyday player feels seen first, while keeping a "Serious mode" toggle for the box-score crowd.

Every screen, card, sheet, and modal will be rebuilt in our editorial premium style: serif headlines, tracked uppercase eyebrows, hairline gradient borders, glass cards on a warm court-orange accent.

## What changes for the user

- **Casual by default.** The dashboard talks about *runs*, *sessions*, *streaks*, and *how it felt* — not averages. Box-score stats live behind a quiet "Serious mode" toggle in settings.
- **One-tap logging.** The primary action becomes "Log a Run." Default flow asks only: type of session, how long, vibe (energy / legs / confidence), and optional notes. Points/rebounds are tucked behind a "+ Add box score" expander for the days you want them.
- **Run context.** Each session can record court / gym name, who you played with (free-text tags), and a vibe rating — turning your log into a journal of your hoop life, not a spreadsheet.  
after logging a session based on the context given we should auto calculate the calories burned and add it to our activity card and logs for their total calorie burn 
- 

## New dashboard (top to bottom)

1. **Hero card** — "Welcome back, [name]" with this week's run count, current streak, and a single editorial line ("3 runs this week — best in a month").
2. **Hoop Streak & Consistency** — a 12-week heatmap calendar. Tap any cell to peek at that day's session.
3. **Weekly Focus** — one skill in the spotlight ("This week: catch-and-shoot"). Pulls a recommended drill and shows your progress on it.
4. **Goals** — set personal targets like "3 sessions a week" or "100 makes a week." Animated progress rings, celebratory haptic when you hit one.
5. **Recent Runs feed** — editorial-style cards: court name, who you ran with, duration, vibe, a one-line note. Tappable for full detail.
6. **Drill Progress** — small horizontal scroller of drills you've worked on, with mastery levels (Touched → Working → Sharp → Locked-in).
7. **Practice Plans** — your saved plans + featured templates (Solo Shooting 30, Pre-Game Warmup, Handles 20, Conditioning Killer, Form Fix).
8. **Drill Library entry** — expanded library with a guided runner.
9. **Serious mode** (only when toggled on) — restores the PPG/FG%/3PT% rings, shot chart, scoring trend, and confidence-vs-FG insight cards.

## New & redesigned screens

- **Log a Run sheet** — soft, editorial, single-screen (no 4-step wizard for casual mode). Session type chips, big duration dial, three vibe sliders (Energy, Legs, Confidence), location field, "ran with" chips, notes. "+ Add box score" reveals the existing stat counters; "+ Add shot chart" reveals the shot-chart tool.
- **Run Detail** — replaces the box-score-heavy Game Detail for casual sessions. Shows court, partners, vibe arc, notes, drills completed if any. Editorial typography with a hero line summarizing the run.
- **Drill Library (expanded)** — grow to ~50 drills across Shooting, Ball Handling, Defense, Conditioning, Finishing, Footwork, IQ. Filter by category, difficulty, duration, and equipment (hoop / no hoop / partner needed). Each drill gets a richer detail page: purpose, how-to steps, coaching cues, video placeholder, related drills, and a "personal best" tracker.
- **Guided Drill Runner** — full-screen, distraction-free. Big timer, drill name in serif, coaching cue cycling underneath, set/rep counters, "Mark complete" → quick log of makes/attempts or reps. Haptics on each interval.
- **Practice Plan Templates** — pre-built plans surfaced on a new "Templates" tab inside the library; tap to clone or run as-is.
- **Plan Runner** — step through your plan one drill at a time with a progress rail, auto-advance with a rest timer between drills, end-of-plan summary screen.
- **Goals editor** — pick from suggested goals or create custom (frequency, makes, drill mastery). Shown in dashboard rings.
- **Weekly Focus detail** — why this skill, recommended drills, your progress, "swap focus" option.
- **Serious Mode toggle** — lives in basketball settings, surfaces all the stat-heavy cards and the full 4-step game logger when on.

## Design language (every surface)

- Court-orange accent on near-black with subtle warm gradient backgrounds
- Serif display headlines, uppercase tracked eyebrows ("HOOP STREAK", "RECENT RUNS")
- Hairline gradient borders around glass cards
- Spring animations on number changes, streak fills, ring progress
- Light haptics on log actions, milestone hits, drill completions
- Empty states that feel curated, not blank — single illustration + one editorial line + clear primary action

## What stays

- Existing shot chart, full box-score logger, scoring trend, season averages, confidence insight — all preserved and resurfaced under Serious mode for users who want them.
- Existing drills and Supabase sync continue to work; new fields (location, partners, vibe, mastery) layer on top.

