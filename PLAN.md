# Real protocol usage stats on Discover (live counts + public users)

## What this fixes

Today, Discover shows hardcoded "users" numbers next to every compound (e.g. "1,856 users"). These are mock and never change. We'll replace them with real, live counts derived from who actually has each compound in an active or recently-finished protocol — and let people tap a compound to see the public users running it.

## Features

- **Real user counts per compound** — every compound card on Discover shows the true number of people currently running it (active protocols + anyone who finished it in the last 90 days).
- **Trending This Week (hybrid ranking)** — new protocol starts in the last 7 days count double, added to the total active users, so genuinely rising compounds rise to the top.
- **"Who's running this" list** — tapping into a compound's detail page shows a horizontal rail of public users currently on it (only people whose profile is public and who've opted into sharing protocols). Each avatar opens their profile.
- **Privacy-safe** — counts include everyone, but the user list only shows people with public profiles and protocol-sharing turned on. Private accounts are counted but never named.
- **Auto-refreshes** — counts update whenever a protocol is started, ended, or deleted, so numbers stay accurate without manual refresh.
- **Graceful empty state** — brand-new compounds with zero users show "Be the first" instead of "0 users".

## Design

- Numbers stay in the existing editorial mono style ("1.2K users", "287 users"). No layout changes to cards.
- On the compound detail page, a new compact section titled "RUNNING THIS · 04" sits above existing community content, showing up to 12 circular avatars in a horizontal scroll with a "+N more" pill at the end.
- Trending rail keeps its current look; only the ranking logic changes underneath.
- A subtle "↑ 23 this week" delta appears under the user count on trending cards when new starts are non-zero, in the compound's accent color.

## Behavior details

- Counts are computed server-side via a Postgres view, so the app just reads one number per compound — fast and consistent across devices.
- If the user is offline or the count fails to load, the card falls back to the last cached value rather than showing 0.
- Tapping an avatar in "Running this" opens that user's profile in the existing profile screen.
- The Trending section refreshes on pull-to-refresh and on app foreground (debounced to once per 5 minutes).

## Data we'll persist (Supabase)

- A `compound_usage_stats` view that aggregates, per compound name: total active users, total recent users (active + finished within 90 days), and new-start count in the last 7 days. Built on the existing `protocols` + `protocol_compounds` tables — no new writes required from the app.
- A `compound_public_users` view that lists user IDs + profile info for people running each compound, filtered to public profiles with protocol-sharing enabled.
- Row-level security ensures only public, opted-in profiles surface in the user list.

## Migration

One new SQL migration file with the two views, indexes on `protocol_compounds.compound_name` and `protocols.is_active` for fast lookups, and grants for the anon/authenticated roles. Safe to run on top of the existing schema — no destructive changes.

## What stays mock (for now)

The static `communityUsers` numbers in `CompoundDatabase.swift` remain as a fallback for compounds that have zero real users yet, so the catalog never looks empty on a fresh install. Once a compound has ≥1 real user, the live count takes over.
