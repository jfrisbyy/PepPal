# Make demo briefs actually mirror the persona's data, and stop Theo's brief from breaking

## What's going wrong today

Two separate issues, both rooted in the same place: the Daily Brief is pulling in real-account data even when a demo persona is active.

**Theo's "couldn't generate" error**
Theo has the densest bundle of any persona — a heavy program (5/3/1 BBB, 4 day split), two compounds (BPC-157 + TB-500) with full side-effect knowledge, 138 workouts of history, weekly volumes and PRs. When that gets layered on top of the signed-in user's long-term memory and the previous brief, the model's response runs past its output cap and the JSON closes mid-sentence, which we surface as "malformed."

**Maya's brief saying one thing while her adjustments say another**
The deterministic adjustment strip (rough sleep → half-volume etc.) is built from the demo-injected vitals, so it looks right. But the narrative body comes from the AI — and the AI is being fed the *real signed-in user's* long-term profile memo (from Supabase) and, on cold start, the *real user's* most recent cloud-saved brief. The model trusts that "authoritative" history over the mock data, so the narrative reads like the real account.

## What I'll fix

- **Quarantine demo mode from the cloud brief pipeline.** When a persona is active, the brief never hydrates from Supabase, never writes back to Supabase, and never reads the real user's long-term memory or pattern memo. Persona switches start from a clean slate every time.
- **Give each persona its own seeded long-term memory.** A short, hand-tuned profile memo per persona (Maya / Priya / Theo / Marcus / Ava / Shayla) gets injected so the AI has the right "who this person is" anchor instead of falling back to the signed-in account's memo.
- **Use the persona's display name in the brief greeting.** Right now the greeting depends on `ProfileService.cachedDisplayName`, which we already set — but I'll harden it so it never falls through to "there" or the real account's first name during a persona switch.
- **Stop Theo's brief from truncating.**
  - Raise the model's output ceiling on the deep pass so dense personas have room to land valid JSON.
  - Tighten the compoundKnowledge block (cap side-effect lists, drop watch-out text on the second compound) so multi-compound personas like Theo and Marcus don't burn budget on boilerplate.
  - On a malformed response, retry once with a smaller, leaner prompt instead of immediately surfacing the error.
- **Make persona switching truly clean.** After switching personas, fully clear the in-memory previous brief, the window-done markers, the pattern memo, and the cloud-cached "latest briefing" snapshot — and only kick off the new fetch after the injected view-model state has settled.

## How I'll verify it

- Switch into Maya → the brief greeting says "Maya," references her 2,100 cal / 145g protein targets, her Upper/Lower Hypertrophy program, her squat/bench numbers, and the 4h 38m sleep + HRV -18% adjustment lines up with the narrative body (not contradicting it).
- Switch into Theo → the brief loads without the "malformed" error, references his 5/3/1 BBB block, BPC-157 + TB-500 stack, and his recent pull numbers.
- Bounce between two personas back-to-back and the second persona's brief never shows the first one's name, numbers, or program.
- Sign out of demo mode → the real account's brief returns as before.