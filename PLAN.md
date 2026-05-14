# Fill the friends page with live mock friends, pulsing presence, and active groups in every demo account

**What's wrong now**
The friends tab uses real backend data first and only falls back to mock friends when the backend returns absolutely nothing. In demo mode the backend often returns an empty-but-valid payload, so the mocks never appear — leaving the page blank. Groups have no demo fallback at all, and the "currently doing" pulsing dots only seed for one or two friends with no scenario context.

**Fix**

- [x] **Always seed mock friends in demo mode.** When a demo scenario is active, skip the backend entirely and load directly from the curated mock friend list so every screenshot account has a populated friends grid.
- [x] **Scenario-aware friend cast.** Each of the six demo accounts gets a tailored friend roster that reinforces their narrative.
- [x] **Live "currently doing" pulse.** Pre-seed 3–4 friends as active right now (Running, Lifting, Cycling, Recovery walk, Mobility flow) with the existing green pulsing dot.
- [x] **Recent activity feed.** Every demo account shows a fresh activity timeline sorted newest first.
- [x] **Mock groups with members.** 3 curated groups per demo account each with 6–12 visible members, last-message previews, accent colors.
- [x] **Group activity ticker.** Inside each mock group, surface 2–3 recent member messages.
- [x] **Subtle presence rotation.** Active friends rotate every minute on the client.

**Result**
Open any of the six demo accounts → tap Community → Friends tab is full of friends with avatars, streak counts, weekly stats, pulsing "Running"/"Lifting" indicators, a live activity feed, and a Groups section with multiple populated rooms. Ready for screenshots.
