# Hardcode the Daily Brief per demo persona (for screenshots)

## Why we're doing this

The AI-generated brief has been brittle across persona switches: it either pulls in the real-account memo, truncates JSON on dense personas (Theo, Marcus), or shows "3am, nothing logged" at off-hours because today's persona meals haven't been "logged yet" in the live context. We've patched it multiple times and it still drifts. For screenshots we need 100% determinism — the brief must mirror the persona's cross-stream "aha" scenario, every time, with no AI roundtrip.

## What I'll do

- **Add `DemoBriefLibrary`** — one hand-crafted `TodaysPlanResponse` per persona (Maya, Priya, Theo, Marcus, Ava, Shayla) that bakes in the exact cross-stream scenario from the brief:
  - Maya: rough sleep → half-volume leg day
  - Priya: dose-day GI → low-FODMAP nutrition pivot
  - Theo: missed BPC-157 → Saturday pull soft-warning
  - Marcus: ALT/LDL drift → omega-3 + provider conversation
  - Ava: RHR +8 for 5 days → overtraining vs illness fork
  - Shayla: borrowed Marcus's stack → start at half-dose
  Each response has a full `narrative` (greeting/headline/body/watchFor/adaptiveCallout), `summary`, `modules` (protocol/nutrition/training/body where relevant), and 2-4 `actionItems`.
- **Short-circuit `TodaysPlanViewModel`** — when `DemoModeProbe.isActive`, every refresh path (`refreshForWindowIfDue`, `handleDataChange`, `forceRefresh`, `loadCachedPlan`) sets `planResponse` directly from the library and skips the AI call entirely. No more "could not generate," no more stale time references.
- **Repaint on persona switch** — `resetForPersonaSwitch` immediately re-applies the hardcoded brief for the new scenario instead of leaving an empty shimmer.

## How I'll verify it

- Switch into any of the 6 personas → brief loads instantly with persona-specific narrative, modules, and adaptive callout that match the persona's mock data.
- No network call to the AI proxy in demo mode.
- Switch personas back-to-back → second persona's brief shows immediately, no leftover content.
- Sign out of demo mode → real account's AI brief returns as before.
