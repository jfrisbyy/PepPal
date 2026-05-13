# Heavy screenshot seeder — fill every feature with rich data

Make the existing "Populate all fake accounts" tool actually fill every screen with realistic, deep data so screenshots look like real power-user accounts. Runs on your current account AND every fake persona.

**What gets populated (last 60–90 days, "heavy" depth)**

- **Social feed** — 8–12 posts per persona spread over 90 days, with images attached to a healthy share of them (training, food, screenshots). Real-feeling cross likes (8+ per post), real comment threads (3–4 per post) plus a few comment replies so threads have depth. Your own account gets a similar batch of posts so your profile/grid isn't empty.
- **Groups** — your account auto-joins 5 themed groups (Heavy Tuesdays, Easy Miles Club, Hybrid Lab, Protocol Logbook, Recomp Receipts). Each group gets 25–40 recent messages from multiple personas with reactions, so the chat scrolls feel alive.
- **Direct messages** — 6–8 active DM threads on your account with named personas (Marcus, Finn, etc.), each thread 8–14 messages back-and-forth, most recent within the last day.
- **Protocols & compounds** — a realistic stack for you (e.g. titrated GLP‑1, BPC‑157, plus a recovery peptide), with active vials, dose history across the last 8–12 weeks, site rotation, and a few cost entries.
- **Workouts & programs** — a current training program assigned, 45–60 logged sessions across the last 90 days (mix of strength, run, hybrid), 6–10 PRs, and 2–3 borrowed programs from friends.
- **Nutrition** — meals logged on ~80% of days (breakfast/lunch/dinner with macros and a couple of photos), daily macro hits, a smooth weight trend line, and 3 biomarker entries (sleep, HRV, resting HR).
- **Activity / streaks / achievements** — current 47-day streak, full activity heatmap, 12+ unlocked achievements, and a populated daily-tasks history.

**How you'll use it**

In Settings → Developer → "Populate all fake accounts", pick **Heavy** and tap Run. It will now also seed your own account so every tab is screenshot-ready: Home, Feed, Groups, Messages, Protocol, Workouts, Nutrition, Profile, Activity.

The seeder is idempotent — re-running won't duplicate data, it just tops up anything thin.

**Notes**

- Images use the existing avatar/banner CDN pattern (Pravatar/Picsum seeds) so nothing breaks.
- All seeded rows respect existing RLS and table invariants.
- A separate "Wipe my seeded data" button is added next to it so you can clean up before App Store submission.

