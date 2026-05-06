# Floating action pill + Day/Week/Month tabs in the calendar reveal

## What changes on the home screen

### 1. Day / Week / Month inside the calendar reveal

- Tapping the editorial eyebrow ("Wednesday · May 6") still drops the calendar down beneath it.
- The footer of the reveal is replaced with a tracked, small-caps segmented control: **DAY · WEEK · MONTH**.
  - **Day** shows the existing magazine week strip (swipe between weeks, tap a date).
  - **Week** shows a clean list of recent weeks with the selected week highlighted, plus prev/next chevrons and a "Current" link when off-week.
  - **Month** shows the magazine month grid you have today, plus prev/next month chevrons and a "Current" link when off-month.
- Picking Day/Week/Month here also drives what the home page renders below (daily plan, weekly summary, or monthly summary) — they stay in lockstep.
- "Back to Today / Current" link still appears on the right of the footer when you're not on the present day/week/month.
- All transitions use the same gentle spring + crossfade as today.

### 2. Fully floating action pill (search · bell · streak)

- The top navigation bar background is removed entirely on the home screen — content scrolls cleanly underneath, nothing visually blocking the editorial text.
- Search, notifications, and the streak counter are merged into **one unified floating pill** in the top-right safe area:
  - Magnifying glass · bell (with unread dot) · vertical hairline · flame + streak number.
  - Soft card-surface fill with a hairline border, gentle shadow — feels like it's hovering over the page.
- On scroll, the pill **fades and shrinks slightly** (~88% scale, ~70% opacity) for an even cleaner read, then snaps back to full size when the page settles.
- Tapping each segment still opens the same destinations (Global Search, Notification Center, Streak Info).
- Haptic selection feedback is preserved.

### 3. Small cleanups

- Remove the now-redundant standalone toolbar items (search/bell/streak) since they live in the floating pill.
- Keep all existing date-driven content (daily/weekly/monthly summaries) wired to the same view model state — no data behavior changes.

