# Reimagine Global Search as a Spotlight-style discovery surface

A full upgrade of the home search experience — opened from the existing pill icon — that turns search into a fast, intelligent way to find anything in EPTI and take action. - this should retain our premium editorial feel 

## The new search experience

**On open (no query yet) — a true discovery surface, not an empty screen:**

- **Quick actions row** at the top: Log workout · Add meal · Log dose · New post · Scan barcode — one-tap shortcuts to common flows.
- **Recent items** — actual things you've recently viewed (exercises, compounds, people, foods), with their thumbnails — not just past search strings.
- **Trending now** — popular searches across the EPTI community, refreshed periodically.
- **Suggested for you** — a few curated picks: people you might know, exercises trending in your training style, popular compounds.
- **Recent searches** stays available, but compact.

**As you type:**

- **Ask EPTI card** appears at the very top — a natural-language answer powered by AI for questions like "high-protein dinner ideas" or "best peptide for fat loss." Tap to open a full conversation.
- **Smart ranking** — prefix matches surface first, then word-boundary matches, then fuzzy matches with typo tolerance (e.g. "bnch press" still finds Bench Press).
- **Matched text is highlighted** in the result rows so you instantly see why something matched.
- **Richer result rows**:
  - Foods show a calorie badge and serving size
  - Exercises show a muscle-group chip and equipment
  - Compounds show peptide type with a colored category dot
  - People show their avatar and @username
  - Circles show member count and private/public state
  - Posts show a relative timestamp ("2h ago") and author avatar

**Voice search:**

- A microphone button in the search bar starts speech-to-text dictation. Speak naturally; the transcript fills the search field live and triggers results.

**Tap behavior — every result is now actionable:**

- Foods open a food detail / "log this food" sheet
- Circles navigate into the circle
- Posts navigate to the post in feed
- Exercises, compounds, people already work and stay the same

## Design

- **Spotlight-feel layout** — clean sectioned list on the editorial-style background, with the green-dot accent reserved for the AI answer card and active scope chip.
- **Smooth motion** — sections fade and slide as you switch scopes; the AI card morphs in with a soft spring as you type.
- **Scope chips** stay where they are but get subtle press feedback and a sliding selection indicator.
- **Empty state** is replaced entirely by the discovery surface; "no results" gets a friendlier message with one or two suggested alternatives ("Did you mean…?").
- **Highlights** use a subtle teal underline/weight, not a jarring background color, to keep the editorial feel.
- **Haptics** on scope change, voice start/stop, and result tap.

## What stays the same

- Opens from the existing top-right pill icon on the home dashboard — no new home-screen real estate.
- Existing scopes (All, Exercises, Foods, Compounds, Users, Circles, Posts) and the "See all in scope" link.
- Recent searches storage continues to work.

