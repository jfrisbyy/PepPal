# Make the date eyebrow the elegant entry point to a calendar

## What changes

The small "WEDNESDAY · MAY 6" label sitting above "Good evening, Jordan" becomes the single, premium way to change the date on the home screen.

## Features

- **Tap the eyebrow date** to drop down an inline, editorial calendar strip directly beneath it — no modal, no sheet, no jarring transition.
- The strip shows a swipeable week of days with the selected date elegantly highlighted; swipe left/right to move between weeks, with smooth spring animation and subtle haptics.
- A discreet "View full month" affordance opens a polished month grid in the same inline space for deeper navigation, then collapses back to the week.
- A whisper-quiet **"Back to Today"** link appears when viewing a past or future date.
- Tapping the eyebrow again (or selecting a date) gracefully collapses the calendar.

## Design

- **Affordance:** A tiny chevron sits right after the date in the same tracked, small-caps style as the eyebrow — it rotates 180° on open. Nothing else changes about the typography.
- **Inline reveal:** The calendar slides down with a soft spring, pushing the greeting and content gently downward. The hairline rule under the eyebrow stays as the visual anchor.
- **Week strip:** Seven minimalist day cells — weekday initial in tracked caps on top, the date numeral in serif below. The selected day uses a quiet accent fill with the brand teal; today gets a small dot. Future days that have no data are softened to a low-contrast tone.
- **Month view:** Same serif numerals, generous spacing, faint hairline grid — feels like a magazine calendar page rather than a system date picker.
- **Motion:** Spring transitions throughout, gentle selection haptic on date tap, chevron rotates with the reveal.

## Cleanup

- The small date pill in the top toolbar is removed so the eyebrow is the one, unambiguous place to change dates. The toolbar keeps search, notifications, and streak.
- The existing "selected date" banner that appears for non-today dates stays as-is for context.
