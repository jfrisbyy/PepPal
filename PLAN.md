# Streamline Training page with editorial polish

## What's changing on the Training page

The Train tab has accumulated overlapping sections. I'll tighten it into a focused, editorial layout while preserving every existing capability.

### New page flow (Train mode)

1. **Inline header** — minimal, just the mode switcher icon (kept).
2. **Mode pill bar** — horizontal pills for Run / Ride / Hoops / Swim etc. (kept).
3. **Today hero (unified)** — replaces the separate Today's Session card *and* the Routines carousel:
  - Large serif day name with an "01 — TODAY" eyebrow
  - If a program is active: shows today's exercises + a single "Begin Workout" CTA, with the program name as a small chip linking to program management
  - If no program but routines exist: shows top routines as a clean editorial list with one-tap start
  - If neither: a quiet "Quick Start" CTA + ghost "Browse Routines" button
  - The cluttered "OR — Quick / Log Sport / New Program" triple-button row is **removed**
4. **Weekly strip** — one horizontal row: consistency ring · sessions · volume. Replaces the 2×2 grid.
5. **Progress (02)** — two clean tiles side-by-side: "Personal Records" (latest PR + count) and "Recovery" (worst-status muscle + count). Tap either to open the full Progress sheet.
6. **Coach card** — Sport coach card kept (one tile, unchanged).
7. **Library** — slim row link to Exercise Library (kept, slightly tightened).
8. **History (03)** — compressed rows: tighter padding, single-line meta, smaller chevron, capped at 5 items. "SEE ALL" opens a dedicated full-history sheet.

### What's being removed

- Dead/unused section code (old consistency ring card, weekly insights grid, separate PR list, weekly volume bars, muscle recovery grid, warmup section, templates carousel, dual action buttons block) — these are defined but no longer rendered, removing them reduces file size and confusion.
- The standalone Routines section (merged into Today hero).
- The "OR" secondary actions row inside Today's Session.
- One of the duplicate stat tiles (consistency was shown twice).

### Sport dashboards (Running / Cycling / Basketball / Swimming / Soccer / Tennis)

Apply the same editorial header treatment — eyebrow number labels (e.g. "01 — TODAY"), serif headline, muted accent rule line — without changing any content, stats, or actions inside.

### Visual style

- Premium editorial: serif headlines, tracked-uppercase eyebrows ("01 — TODAY", "02 — PROGRESS", "03 — HISTORY"), thin gradient rule lines, muted teal accents
- Single primary teal CTA per screen, ghost secondary
- Glass surfaces with subtle borders (consistent with rest of app)
- Smooth spring transitions on state changes

### Not changing

- All actions still reachable: New Program (via program chip menu), Log Sport (via sport mode pills), Quick Workout (via Today hero CTA when no program)
- All existing sheets and navigation destinations remain wired
- TrainViewModel and data flow untouched
- Sport dashboards keep all their functionality

