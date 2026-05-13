# Fully populate every fake persona + stop main account data leaking through

## The problem

When you switch into a fake persona like Finn, two things go wrong:

1. **Their account looks empty** — no workouts logged, no weight history, no protocol, no meals. The server-side seed only creates feed posts and follows, nothing else.
2. **Your main account's numbers bleed through** — the weight, program day, macros, and protocol you saw on your real account stay visible because they're cached locally on the device rather than tied to a specific user.

## What changes

### Every fake persona becomes a fully lived-in account

Each of the ~25 fake personas (Finn, Ava, Marcus, Priya, etc.) will be seeded with rich, archetype-flavored data so when you tap into them everything looks alive:

- **Body & goals** — 90 days of weight history with a believable trend matched to their archetype (cutter trends down, bulker trends up, runner stays flat), starting weight and target weight on their goal card.
- **Training** — an active program named after their style (5/3/1 for lifters, marathon block for runners, PPL for the bodybuilder, etc.), 40–60 logged workouts over the past 3 months with realistic sets, RPEs, durations, and a handful of personal records.
- **Protocols & compounds** — only for personas whose archetype actually involves them (Peptide Protocols, Health Optimizer, GLP-1 Journey, the strength personas with creatine/ipamorelin, etc.). Includes vials, dose logs with site rotation, and the matching protocol week.
- **Nutrition** — macro targets sized to their body and goal, meals logged on roughly 80% of recent days with archetype-appropriate foods (rice bowls for hoopers, fig bars + gels for marathoners, weighed chicken for the comp prep persona).
- **Steps, water & daily activity** — last 30 days of step/water logs and an activity feed showing recent doses, workouts, and meals.
- **Bloodwork** — 1–2 panels for the persona archetypes that would realistically have them.
- **Today snapshot** — partially completed daily tiles (steps part-done, one meal logged, water in progress) so the home screen never looks blank.

Finn specifically will reflect his existing card: 5/3/1 BBB, ~22k kg weekly volume, creatine + ipamorelin, recent 220 kg deadlift PR, ~51-day streak.

### One-tap seeding

The Developer Settings screen gets a clearer "Fully populate all fakes" action that runs the deeper seed for every fake persona. Switching to a fake that hasn't been deeply populated yet will trigger the deep seed automatically in the background so you never land on an empty account.

### Per-account memory (no more leak-through)

The device will remember each persona's local state separately — cached weight in pounds, program day offset, adaptive macro inputs, adaptive target cache, last appearance, step goal, and the other small remembered values are scoped to whichever user is signed in. When you switch from your real account into Finn, you'll see Finn's numbers; when you switch back, your own numbers return untouched.

### Cleaner switcher UX

The Fake Account Switcher and impersonation banner will show a small badge indicating whether a persona is "fully populated" or "fresh," and a one-tap "Populate this persona" action for any that are still empty.

## Pages affected

- **Home / Today** — Finn's tiles now show his own steps, water, meals, weight, and brief based on his data.
- **Train** — his program card, workout history, and PRs reflect his archetype.
- **Body / Goals** — his weight curve, current and target weight.
- **Protocol** — empty for archetypes that don't use compounds; rich for those that do.
- **Activity & Feed** — already worked; gets a richer recent-activity strip from the new logs.
- **Developer Settings & Fake Account Switcher** — gains the deeper seed action and per-persona status.

