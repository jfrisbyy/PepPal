# Make the Daily Brief actually narrate each demo persona's hero story

## Implementation checklist

- [x] **1. Wipe & regenerate the brief on persona switch** — clear `TodaysPlanViewModel` cache + planResponse, then force-refresh from `HomeView.onReceive(.demoPersonaChanged)`.
- [x] **2. Tune persona mock data so hero signals fire**
  - [x] Theo: stop logging BPC-157 for last 3 days so `missedDose` fires (isDaily → daysSince >= 2).
  - [x] Ava: bump today's RHR to 71+ and inject a 5-morning elevated-RHR pattern so `poorRecovery` fires.
  - [x] Shayla: raise sleep above 6.5h so `roughSleep` doesn't crowd out the borrowed-protocol signal.
- [x] **3. Baseline targets follow persona** — push macro/water/step goals + first name into `NutritionViewModel`, `WaterViewModel`, `UserDefaults("step_goal")`, `InsightsDataStore.firstName`.
- [x] **4. New `borrowedProtocol` adaptive signal** — fires on protocol notes/name marked "Borrowed"; emits a dose-domain accept/skip line.
- [x] **5. Coherence self-test** — after persona load, verify the hero signal is present in the day's bundle.

## Background

The brief is built by `TodaysPlanService.assembleContext` + `AdaptiveSignalsService.buildSignals`. Signals → AdaptiveBundle → `AdaptiveAdjustmentService.ingest` → strip with accept/skip per line. Persona switch goes through `DemoModeManager.activate` → `DemoDataInjector.injectShared` (singletons) + HomeView's `.onReceive(.demoPersonaChanged)` → `injectInto` (view-models). Brief was not being refreshed after that injection.

## What you'll see after this

- Switch to **Maya** → "Slept 4.6h vs your 7.1h average — halving working sets on today's upper-body."
- Switch to **Priya** → "GI discomfort 4h after yesterday's Tirzepatide — low-FODMAP, protein-forward 48h."
- Switch to **Theo** → "BPC-157 missed 3 days running. Re-anchor tonight; Saturday's heavy pull stays with a soft cap."
- Switch to **Marcus** → "ALT 38 → 52 → 68, LDL up 44. Hold steady through next recheck."
- Switch to **Ava** → "RHR up 8 bpm for 5 mornings, sleep normal. Two-path day."
- Switch to **Shayla** → "Marcus runs Test Cyp at 100 mg — your labs say 50 mg for two more weeks."

All adaptive-strip lines remain accept/skip-capable (handled by existing `AdaptiveAdjustmentService`).
