# Twitter-style dense feed redesign

## Goal

Make the feed page show more posts at once and feel cleaner — without touching the logo, mode picker, or filter bar at the top.

## What changes

**Post layout — edge-to-edge rows**

- Replace the boxed "card with shadow" look with edge-to-edge rows separated by a single hairline divider, like X/Twitter or Threads.
- Avatar moves to a left rail (smaller, ~36pt) with the post content flowing to its right, so the username, timestamp, text, and media all share one tight column.
- Username, handle, "·", and relative time sit on a single line. The "edited" tag becomes a tiny dot indicator instead of its own line.
- Tighter vertical rhythm between posts — roughly 30–40% more posts visible per screen.

**Media — shorter and smaller**

- Single photo: capped to a shorter 5:4-ish ratio (instead of 16:9 letterbox), rounded but no heavy padding.
- Multi-photo grid: smaller cells, tighter gaps.
- Voice message, workout log, and shared program cards: shrunk to a compact pill row with a smaller icon, single-line title, and inline meta — about 40% less vertical space.

**Action bar — tighter**

- Remove the divider line above the actions.
- Smaller icons (13–14pt) with counts in caption weight.
- Like / comment / repost / share spaced evenly across the row in a single compact line, sitting flush under the content with minimal padding.
- Keep all existing behavior: heart bounce, haptics, repost toggle, share sheet, menu.  
  
we will also add a subtle search button on the right side on the same line as the "all, following, tags" pills, this search allows you to search by user, tag, keyword, etc , when clicking the search icon it should animate into a full search bar 

**Cleanliness touches**

- Hairline divider color tuned to be subtle in both light and dark mode.
- Post tap target stays the whole content area; avatar and username remain their own tap targets to the profile.
- The three-dot menu shrinks and aligns to the timestamp row instead of taking its own column.

## What stays the same

- EPTI logo header, community mode picker, and filter chips above the feed — untouched.
- hashtag taps, mention taps, report/block/mute, skeleton loader, empty states, "you're all caught up" footer, infinite scroll.
- All post types (text, photo, voice, workout, market link) still render — just more compactly.
- Pull to refresh, like/comment/repost/share logic, and deep-link routing.

## Result

A feed that reads like a clean editorial timeline: roughly 1.5× the posts visible per screen, less visual noise between rows, and media that supports the post instead of dominating it.