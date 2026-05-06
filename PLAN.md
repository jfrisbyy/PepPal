# Pre-Session command center — full-screen detail view

## Overview
A full-screen pre-session brief that opens when you tap the Training card on the home page. It's your editorial "before the lift" command center — readiness, fuel, history, warmup, and today's exercises — all wrapped in the same premium feel as the rest of the app, ending in a Review-then-Start flow.

## How you get there
- [x] Tapping the Training card on the home page pushes the new pre-session view as a full-screen detail page (same navigation pattern as Program Detail).
- [x] The card itself stays as a glanceable summary; deeper context lives on this page.
- [x] A clear back button returns you home; a floating bottom bar carries the primary action.

## What you'll see (top to bottom)

**1. Editorial header**
- [x] Program name, week & day position (e.g. "W3 · DAY 4/6"), today's split name in serif type, and a focus tag (Push / Pull / Legs / etc).
- [x] Subtle progress bar showing where today sits in the current mesocycle.

**2. Readiness check**
- [x] Quick read of sleep, soreness, energy, and current peptide level in your body (pulled from the chart calculation, not just dosage).
- [x] Each metric shown as a compact ring or bar with a single-line interpretation ("Recovery looking strong — push intensity").
- [x] Tap to log today's readiness if missing.

**3. Today's focus & coaching cue**
- [x] One AI-generated sentence framing the session ("Strength block — top set on bench, accessories at RPE 7").

**4. Estimated timeline**
- [x] Visual stacked timeline: Warmup → Main work → Cooldown, with minute estimates and total session duration.

**5. Warmup & mobility flow**
- [x] 3–5 suggested warmup movements specific to today's split (e.g. band pull-aparts before push day).
- [x] Each as a small row with reps/duration; tap to expand technique notes.

**6. Last time you trained this**
- [x] Date of last identical session, total volume, any PRs hit, and a one-line trend ("+8% volume vs last week").

**7. Today's exercises**
- [x] Clean list with target sets × reps and the working weight pulled from your last session.
- [x] Each row shows last-session performance inline ("Last: 185×5,5,4").
- [ ] Swipe or tap to edit target weight, swap exercise, or add notes before starting (target weight editable in Review sheet; swap/notes deferred).

**8. Fueling & hydration**
- [x] Short pre-workout tips: suggested carbs, hydration target, caffeine timing, and a peptide-aware note when relevant (e.g. timing around current compound levels).

## Primary action
- [x] Sticky bottom bar with a single button: **"Review & Start"**.
- [x] Tapping it opens a quick-edit step (confirm/adjust today's exercises, weights, set count) then drops you straight into the active workout flow.

## Design language
- [x] Matches the existing premium editorial style: serif headlines, monospaced micro-labels with tracking, glass cards, blue accent for the Train surface.
- [x] Subtle entrance: sections fade and rise in sequence on appear.
- [x] Haptic tap on Review & Start; spring transitions throughout.
- [x] Empty/missing states are graceful (e.g. no last-session data → "First time running this split — set your starting weights").

## Out of scope for this pass
- Music / playlist suggestions (deferred).
- Real-time biometric polling during the session itself.
