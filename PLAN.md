# Merge Pep Chat into Global Search with smart question detection

## What we're doing

Combining Pep chat with the global search bar so users get one smart entry point. The standalone "Chat with Pep" button goes away — every conversational question now happens right in search, in their full personal context.

## How search behaves

- **Looking something up** ("bicep curl", "oatmeal", "@kayla", "BPC-157") → standard search results, exactly like today.
- **Asking a question** ("how much protein after a workout?", "is BPC safe with TB-500?", "what should I eat tonight?") → a hero "Ask Pep" answer card slides to the top with a streaming, context-aware reply. Any matching app results still appear underneath.
- **Mixed queries** ("best chest exercise") → both: Pep's quick take on top, real exercise results below.

## How EPTI knows it's a question

A lightweight on-device classifier checks for: question marks, natural-language openers (how, why, should, is, can, what, when, does, vs, better than, compare), conversational length (5+ words), and whether the query exactly matches an item in the library. Library hits lead with results. Clear questions lead with Pep. Mixed = both.

## The Ask Pep answer card

- Hero-sized card pinned to the top of results when a question is detected.
- Streaming text with a subtle thinking shimmer and pulsing green dot.
- "ASK PEP" eyebrow in the editorial serif.
- Full personal context — your weight, goal, active protocol, recent workouts, today's nutrition, bloodwork, and Apple Health — feeds every answer (same depth as the old Pep chat).
- Tap the card → opens full Pep conversation with the question pre-loaded so the thread continues seamlessly.
- Voice dictation works the same: speak a question, get an answer card; speak a name, get results.

## What gets removed

- The standalone "Chat with Pep" floating action button and the "Ask Pep" quick-action chip in search — Pep now lives inside search itself.
- "Chat about this plan" and other contextual Pep entry points stay exactly as they are.

## What stays the same

- Same magnifying glass entry point on the home dashboard.
- Same scope chips, recents, trending, suggested sections, and result rows.
- Same Pep chat surface for "About this plan" and other contextual flows.
- Quick actions (log meal, start workout, etc.) untouched aside from the Ask Pep tile being removed.

## Bug fix

The recent crash when typing certain "no result" queries — the "did you mean" suggestion was running an unsafe ranking pass on long candidate lists. The suggestion logic gets hardened with bounded inputs and safe fallbacks so it can never trip the Swift safety check again.