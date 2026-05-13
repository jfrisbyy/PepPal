# Expand adaptive adjustments to rewrite every daily target, not just workouts

## What changes for the user

Today, when the brief says "rough sleep — cut volume in half," only the workout gets rewritten on Accept. After this update, a single **Accept** on the brief can rewrite **any combination** of today's targets — workout, protein/carbs/calories, water, steps, dosing, and tonight's wind-down — based on what the underlying signals call for.

The brief stays conversational and short. The "why" is woven into the brief paragraph itself (one or two sentences). Underneath, a pulsing line shows the exact bundle of adjustments in plain language. you can accept all or skip all , or you can also individually accept or skip on each individual adjustment 

## How it will feel

- **One brief, one bundle.** Example after a rough night of sleep:
  - Pulsing strip shows three lines, stacked:
    - "Halve working sets on today's lifts"
    - "Protein floor 160g · ease carbs to 180g"
    - "Bump water to 3.5L · wind-down by 9:30pm"
  - One **Apply to today** button accepts all three. One **Skip** dismisses all three.
- **Smart expiration.** Accepted adjustments stay active until the signal that caused them clears — e.g. the halved workout reverts as soon as a good night's sleep is logged, the water bump reverts when hydration normalizes, the deload reverts when recovery score recovers. No manual cleanup.
- **Undo always available** from the brief while the bundle is active, with a small "ADJUSTED" badge showing on the affected screens (Train, Nutrition, Water tile, Steps tile, Dose card) so users always know why a number looks different from baseline.
- **Honest "why" in the brief itself.** The conversational paragraph briefly names the signal driving the bundle ("your RHR is up 6 bpm and you slept 5.1h…") so the user can verify the connection without opening a popover.

## How accuracy is enforced

The system is **deterministic-first, AI-narrated**:

1. Local detectors scan sleep, recovery (HRV/RHR), side-effect logs, dose log, bloodwork flags, streaks, and yesterday's nutrition/hydration/step adherence.
2. From each detector, the code builds a **typed bundle** of structured changes (e.g. `halveSets` + `proteinFloor(160)` + `waterDelta(+750ml)` + `windDown(21:30)`). This bundle is the source of truth — never the model.
3. The brief prompt receives a compact **"today's context"** block: every relevant baseline target (water, steps, protein/carb/cal targets, dose schedule, sleep target, current RHR/HRV/sleep, side effects from last 48h) plus the deterministic bundle.
4. The AI's job is **only to narrate** the bundle in a warm, conversational voice and surface the "why" inside the paragraph. It can't invent changes the code didn't authorize.
5. Each line in the pulsing strip is rendered from the typed bundle, not the model output — so the Accept button always does exactly what the line says.

## Scope of rewritable targets

- **Workout** — already wired (halve sets/reps, deload %, mobility-only).
- **Nutrition** — temporary overrides on protein floor, carb ceiling/floor, calorie target, and a "small + frequent meals" flag the Nutrition screen reads.
- **Water** — temporary delta on daily ml goal (e.g. +750ml on headache days).
- **Steps** — temporary daily step goal (e.g. cap at 6k on heavy GI days, raise on recovery days).
- **Dosing** — non-destructive: shift today's dose window, mark as "re-anchor," or insert a "hold doubling up" guardrail; never auto-doses.
- **Sleep** — earlier wind-down target tonight, surfaced on the home tile and as a quiet evening reminder.

## Where overrides surface across the app

- **Train** — already shows the halved/deloaded session.
- **Nutrition / Daily Energy** — protein/carb/calorie targets read the override and show a small "Adaptive" chip with one-line reason.
- **Water tile** — goal ring uses the adjusted goal; chip explains the bump.
- **Step tile** — goal number and ring use the adjusted goal.
- **Dose card** — shifted window or re-anchor banner.
- **Home brief header** — pulsing strip lists every active line and an Undo.

## New scenarios that become possible

- **Rough sleep** → halve sets + protein floor + earlier wind-down.
- **GI side effect** → small frequent meals flag + lower carbs + cap steps at 6k.
- **Headache logged** → +750ml water + electrolyte nudge + skip overhead.
- **Missed weekly dose** → hold training steady + protein floor + re-anchor reminder tonight.
- **Bloodwork flagged** → hold everything steady through next recheck (no rewrites, just a freeze banner).
- **Bad RHR week** → 60% deload + cap steps + bump water + earlier wind-down.
- **Streak break** → no rewrites; one-line "small log restarts it" message only.

## Out of scope (for this pass)

- Persisting overrides to Supabase / cross-device sync (kept on-device for now, same as today's decision storage).
- Tuning the exact deterministic thresholds — using the existing ones from the current signals service.
- Re-running the brief mid-day if a signal clears (auto-revert happens silently; the brief itself refreshes on its normal cadence).

