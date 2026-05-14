# Cleaner protocol detail header, floating top buttons, and global screenshot chrome

## Protocol detail page — cleaner header

- Remove the "Days Left" stat and the circular adherence ring from the top of the page.
- Replace them with two more useful at-a-glance numbers:
  - **Next dose** — countdown like "in 3h 20m" (or "Now" when due, "—" when no upcoming dose).
  - **Total logged** — cumulative dose this cycle (e.g. "12.5 mg" or "1,250 mcg" using the protocol's preferred unit).
- Keep **Phase**, **Compounds**, **Doses** alongside the two new stats, in a clean evenly-spaced row with thin dividers.  
and for all demo accounts , ensure that all the charts are accurate and make sense and the dots are connected 

## Floating back & menu buttons (no nav bar)

- Hide the system navigation bar on the protocol detail page.
- Add a floating **back arrow** in the top-left and a floating **ellipsis menu** in the top-right, both as small circular glass buttons that sit above the banner image.
- They stay pinned as you scroll so the banner never covers them, and gently fade/shrink slightly once the page is scrolled (matching the Home pill feel).
- The protocol name stays as the big serif title at the top of the content (already there), so removing the nav title doesn't lose context.

## Global screenshot chrome on every page

- When the "Hide chrome for screenshots" toggle is on in Developer Settings, the floating **camera** (capture) button and chrome hiding apply across the whole app — Home, Train, Body, Nutrition, Friends, Discover, Community, and every detail page (Protocol Detail, Compound Detail, etc.).
- The capture button uses the same tile-and-stitch approach already working on Home — it finds the tallest scrollable view on whatever screen you're currently on and captures it as one tall PNG, then opens the share sheet.
- Tab bar and floating action pills/FABs are hidden everywhere while the toggle is on so nothing chrome-y leaks into screenshots.
- Capture button briefly disappears during capture so it never shows up in the resulting image.

