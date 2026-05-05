# Smarter daily brief refresh + category insights on full pages

## How the daily brief will refresh

- **On new log** — any meal, workout, weight, dose, or bloodwork log immediately refreshes the daily brief and the category overviews.
- **Three time windows** — if no new log happens, the brief refreshes at most three times per day: morning (~~7am), afternoon (~~1pm), and evening (~7pm).
- **Only when the app is open** — these scheduled windows only fire when the user actually opens or returns to the app, so there are no API calls for inactive users.
- A small saved record per device tracks which windows have already run today, so opening the app multiple times in the same window won't trigger duplicate refreshes.

## Home screen changes

- The Nutrition, Activity, and Weight Loss cards on the home page will no longer show the small AI insight line — the cards stay focused on numbers, progress, and quick logging.
- Tapping a card still opens its full overview page.

## Category full pages — new "Insights" section

Each category's full page (Nutrition, Activity, Weight Loss) gets a dedicated **Insights** section in the same premium editorial style as the rest of the app:

- A serif headline and uppercase tracked eyebrow ("INSIGHT", "FUEL", "MOMENTUM", etc.)
- A short narrative paragraph generated specifically for that category
- A subtle accent rule and timestamp showing when the insight was last updated
- A gentle shimmer/refresh state when the brief is updating
- Tone-matched accent color per category (amber for nutrition, teal for activity, violet for weight)

These category insights:

- Update at the same time as the daily brief (new log, or one of the 3 daily windows when the app is opened)
- Live **only** on the category's full page — never on the home cards

## What stays the same

- The morning brief on the home screen still shows the warm narrative and deterministic status lines.
- All existing logging, navigation, and editorial styling on the cards and full pages are preserved.

