# Six bulletproof demo personas baked into the app for screenshots

## The approach

Instead of fighting Supabase seeding, we ship six **fully hardcoded demo personas** as Swift data inside the app. When you tap one in the new Demo Mode menu, the whole app reads from that persona's bundled data — dashboard, workouts, meals, protocols, labs, sleep, social, profile. No network, no edge functions, no RLS, no flakiness. Same data every time, perfect for screenshots.

## The six personas (each tuned to one scenario)

1. **Maya — Rough Sleep → Adaptive Lift**
  Hypertrophy lifter. 4h 38m sleep last night, sleep score 54, HRV ‑18%, RHR +6. Today is leg day. Dashboard surfaces the half-volume adaptive bundle with one-tap accept.
2. **Priya — Side Effect → Nutrition Pivot**
  GLP-1 journey. Tirzepatide dose yesterday, GI discomfort logged 4h ago. Nutrition tab swapped to low-FODMAP for 48h; camera meal log flags a burrito with a swap suggestion.
3. **Theo — Missed Dose → Recalibrated Everything**
  Peptide protocols. Wednesday's BPC-157 missed. Compound level sparkline dips, Saturday's heavy pull session carries a soft warning, next dose pushed forward.
4. **Marcus — Bloodwork Shifted → Protocol + Plate Changes**
  Health optimizer. Three panels showing ALT 38→52→68 and LDL 118→138→162. Two compounds flagged, omega-3 + fiber priorities active, hydration goal bumped, provider-conversation prompt.
5. **Ava — RHR Elevated 5 Days → Illness/Overtraining Fork**
  Endurance runner. Five mornings of RHR +8 with normal sleep. Two-path adaptive prompt on dashboard with real branches.
6. **Shayla — Friend's protocol borrow + your context**  
You borrow Marcus's cut protocol from the feed → App doesn't just copy it. It cross-checks against your current bloodwork, your sleep baseline, and your training load, then says *"Marcus runs this at 5mg — based on your labs and recovery, start at 2.5mg for 2 weeks."* The social feature becomes safer than Reddit because your data is the filter.

## What every persona ships with

Each of the six gets a complete, realistic 180-day history baked in:

- **Profile**: name, archetype, avatar, bio, current/longest streak tuned to scenario
- **Dashboard**: today's Daily Brief written for the scenario, today's tasks, banners, recovery score
- **Workouts**: active program + archived prior block, 90–120 logged sessions over 180 days with sets/reps/RPE/notes, 8–15 PRs scaled to archetype
- **Nutrition**: 150 days of meals at 3–5/day (~600 rows), macro targets, water + step logs
- **Protocols**: active stack + completed prior stack, 4–6 vials, 120 days of dose logs with site rotation
- **Bloodwork**: 3–4 panels spaced 8–12 weeks apart, 18–25 biomarkers each
- **Sleep**: 90 nights with realistic variance
- **Social**: a populated feed of posts/comments from the other five personas, 2–3 group memberships with active members and posts, 3–5 DM threads with real conversation history, a friends list full of friends that also have mock data and recent activity logs and profiles 
- **Achievements**: badges, milestones, daily-task history at ~75% completion

## How it plugs in

- A new **Demo Mode** entry in Developer Settings (and a hidden long-press on the profile avatar) opens a clean picker showing just these six cards with the scenario name, archetype, and a one-line teaser.
- Tapping a persona flips a global Demo Mode flag and swaps the active "user" in memory. All view models read from the persona's bundled dataset instead of Supabase while Demo Mode is on.
- An exit button in the top status bar returns to your real account.
- Old bloat removed: the conflicting "refresh fake personas / fully populate / seed 25 fakes / generate fake activity" buttons get deleted. Demo Mode is the single source of truth.

## Design

- Demo picker uses a dark hero card per persona with the scenario headline ("Rough sleep → adaptive lift"), persona name + archetype chip, and a tiny stat strip (streak, workouts, protocol).
- A subtle persistent pill at the top of the screen reads **"Demo: Maya"** so screenshots can be retaken cleanly and you always know you're in demo mode.
- Everything else looks exactly like the real app — that's the point.

## Pages / Screens

- **Demo Mode picker** (new) — six persona cards, scenario-first.
- **Dashboard** — reads scenario-specific Daily Brief + adaptive banner for the active persona.
- **Workouts, Nutrition, Protocols, Bloodwork, Sleep, Social, Profile** — all transparently sourced from the persona's bundled dataset when Demo Mode is on.
- **Developer Settings** — cleaned up: old fake-persona controls removed, replaced by a single "Open Demo Mode" entry.

## Out of scope

- No changes to Supabase, no edge function edits, no migrations.
- Real accounts are untouched; Demo Mode is purely a local read-layer override.

## Confirm before I build

- Six personas as listed, or include Jordan (borrowed protocol) as #7?
- OK to fully delete the old fake-persona seeder buttons / edge-function action handlers from the client UI (server code untouched, just hidden)?

