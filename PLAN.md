# Add a Sleep card to the homepage with manual logging + Apple Health sync

## What you'll get

A new **Sleep** card lives in the Activity section of the home page, right alongside Energy, Training, Nutrition, and Water. It shows last night at a glance, lets you log a night yourself in seconds, and expands into a full Sleep & Recovery page when you want the deeper picture.

### Features
- See last night's hours and quality on the home card with a tiny 7-night bar trail.
- Auto-pulls from Apple Health when connected — no manual entry needed.
- If Apple Health isn't connected (or last night is missing), the card invites you to log manually.
- Quick "Log sleep" button opens a sheet to enter bedtime, wake time, quality, and an optional note.
- Quality captured as a 1–10 slider with a descriptive label (Restless → Excellent).
- Hours auto-calculate from bedtime/wake time, but you can override.
- Source badge shows whether the night came from Apple Health or you logged it.
- Tapping the card opens the full Sleep & Recovery page.
- Manual entries sync to your account so they show up across devices and feed into trends, the daily brief, and correlations.

### Design (compact card)
- Same dark glass card styling as the Energy and Nutrition cards — rounded, subtle border, soft shadow.
- Top row: moon icon, "Sleep" title, small "Log" pill button on the right (violet accent).
- Big rounded number for hours slept last night with a small "h" suffix, plus a quality chip ("Good · 7/10") next to it.
- Tiny 7-bar mini chart underneath showing the last week, with last night highlighted.
- Bottom row: source badge ("Apple Health" or "Logged") and a chevron hinting at the detail page.
- Empty state: friendly "Log last night's sleep" prompt with a single tap-to-open button.

### Design (manual log sheet)
- Bedtime and wake-time pickers stacked, with auto-calculated total hours shown live.
- 1–10 quality slider with color gradient (red → amber → green) and dynamic label.
- Optional notes field (multi-line, "How did you feel?").
- Save button pinned to bottom; haptic confirm on save.

### Design (full Sleep & Recovery page — already exists, enhanced)
- Reuses the existing Sleep & Recovery view with a new "Log a night" button in the toolbar.
- Manually-logged nights blend into the same chart and stages breakdown as Apple Health nights.
- Adds a small "Recent entries" list so you can edit or delete a night you logged.

### Where it appears
- **Home → Activity section**: between the Training card and Nutrition card.
- **Sleep & Recovery page**: opens when you tap the card (already exists, lightly upgraded).
- **Manual log sheet**: opens when you tap the "Log" pill or the empty-state button.

### Behind-the-scenes touches
- Manually-logged sleep flows into the daily brief, weekly summary, training correlations, and biomarker trends just like Apple Health data.
- Cached locally so the card renders instantly, then refreshes from Apple Health and the cloud.
