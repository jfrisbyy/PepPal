# Adaptive intelligence baked into the Daily Brief

Instead of building separate "adaptive cards," the cross-stream scenarios live inside the existing Daily Brief — one prominent "adaptive callout" that names the trigger ("rough sleep last night") and the specific adjustment ("split today's reps in half, hit form over load"). Same surface, but the brief now visibly reasons across sleep, side effects, dose, bloodwork, RHR, and streak data.

**Scope (this pass)**

- [x] `AdaptiveSignalsService` — deterministic detector that scans local stores (sleep, HK recovery, side effects, dose log, bloodwork, RHR/HRV, streak, nutrition) and emits 0–3 high-confidence scenarios per refresh. Each scenario has a `trigger` (what fired it), a `domainImpact` (what should change today), and a `headline` summary fed to the model.
- [x] Scenarios covered:
  - Rough sleep → halve reps / form day
  - Side effect logged (nausea / GI / headache) → nutrition + training adjustment
  - Missed dose → re-anchor schedule, watch for level dip / appetite return
  - Bloodwork shift (new flagged value) → flag follow-up, adjust supplement/training if relevant
  - Bad RHR / HRV week → recovery-first day plan
  - Streak break → recovery framing, single small action to restart
- [x] Plumb signals through `ContextBundle.adaptiveSignals` and `toPromptString()`.
- [x] `BriefNarrative.adaptiveCallout` (optional `{trigger, recommendation}`) added to JSON contract.
- [x] System prompt requires emitting `adaptiveCallout` when signals exist and forbids the brief from contradicting them.
- [x] Render `adaptiveCallout` in `PlanBriefHeaderView` as a distinct strip directly below WATCH FOR (different accent so it reads as "today's adjustment").
- [x] runChecks passes.

**Apply/Skip pass (this turn)**

- [x] Extend `Signal` with a deterministic `BriefAdjustment { summary, kind, magnitude }` so each conversational callout is paired with an actionable one-liner.
- [x] `AdaptiveAdjustmentService` — per-day decision store (`accepted` / `dismissed`) + transform that rewrites today's `ProgramDay` based on adjustment kind (halve sets, halve reps, deload 60%, mobility/form-only).
- [x] `TrainViewModel.todayWorkoutDays` overlays the override transparently when today has an accepted decision, so the change flows everywhere the workout is read.
- [x] Brief strip redesign in `PlanBriefHeaderView`: trigger label, one-line adjustment, a pulsing scan line, and Apply / Skip buttons. After Apply the strip morphs into a checkmark confirmation with a tap-to-undo.
- [x] State survives brief refreshes for the same calendar day.
- [x] runChecks passes.
