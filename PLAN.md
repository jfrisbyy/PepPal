# Replace test users with 25 realistic, fully-behaving fake accounts

## Problem

The current seeded test accounts feel fake — they don't show up correctly in follower/following counts, have no posts, no avatars or banners, and aren't truly discoverable. We'll replace them with a curated set of 25 realistic accounts that behave exactly like real users everywhere in the app.

## What changes for users

- **A shared global pool of 25 realistic personas** — every signed-in user discovers the same set, so the app feels alive on day one.
- **Real-looking profiles**: distinct names, handles, bios, avatar photos, banner images, current streaks, active programs, total points.
- **They count as real**:
  - Show up in your Following list and Following count.
  - Show up in their own Followers count (each fake follows you back, plus follows several other fakes — so their numbers look organic).
  - Appear in Community Discover, search results, suggested users, and leaderboards.
- **Realistic feed activity**: each persona has 3–6 recent posts (workout updates, PRs, meal photos, reflections, hashtags) spread across the last 2 weeks, so the feed always has fresh content - ensure this does not sound like random ai generated content - have it be extremely realistic and human like 
- **Recent activity & workouts**: each has a streak, a few logged workouts, and an active program reference so their profile pages look lived-in.
- **Messageable**: you can open a DM thread with any of them like any other user (replies stay quiet — no fake bot responses).

## Design

- 25 hand-crafted personas spanning the app's audiences — strength, hybrid, running, cycling, basketball, peptide protocols, recomp, yoga/mobility — each with a unique voice in their bio and posts.
- Avatars and banners use AI-generated portraits + scenic/gym/outdoor cover images so the grid looks editorial, not stock.
- Inter-fake follow graph (each fake follows ~6–10 others) so their profiles show realistic follower counts even before any real user joins.

## How it works

- A one-time global seed runs server-side and is idempotent — safe to re-run, won't duplicate.
- New real signups automatically get all 25 fakes added to their Following list (and the fakes follow them back), so counts and feed populate immediately.
- Developer Settings keeps the manual "Seed/Refresh/Clear" controls for testing.
- The old `peppal-test-*` accounts are migrated/cleared and replaced by the new persona set with stable IDs.

## Pages affected

- **Profile (yours and theirs)** — counts, follower/following lists, banner + avatar render.
- **Community Discover & Search** — fakes appear as suggested and searchable.
- **Feed** — populated with posts from fakes you follow.
- **Messages** — fakes appear in new-conversation picker and can be opened as threads.
- **Friends/Stats** — fakes show real stats pulled from their seeded data (no more in-memory mock overlay needed).

## Out of scope

- Fakes won't reply to DMs or react to your posts (would require background jobs / look spammy).
- No live presence simulation beyond the existing two demo personas.

