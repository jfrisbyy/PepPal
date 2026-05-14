# Smarter search: contextual follow-ups instead of "No results"

When Pep answers an open-ended question, the awkward "No results for…" banner gets replaced by a curated set of smart, relevant follow-ups derived from what Pep just said.

### What the user will see

- After Pep finishes answering, a new **"Keep exploring"** section appears directly under the answer card.
- This section contains two layers:
  1. **Direct entity cards** — up to 3 small, tappable cards for real things in the app (a specific food, exercise, compound, or guide) that relate to the answer. Tapping opens that detail page.
  2. **Follow-up search chips** — 3–4 short, tappable suggestions like "Healthy high-protein recipes", "Foods that ease GI side effects", "Lean bulk meal ideas". Tapping runs that text as a new search.
- The "No results for…" empty state is fully hidden whenever Pep has produced an answer — so the screen never feels like a dead end.
- Loading shimmer is shown briefly while suggestions are being generated, matching the existing Pep card style.

### How it picks the suggestions

- Pep is asked, in the same call as the answer, to return 3 short follow-up queries tailored to the user's question and personal context.
- Those queries are then run through the app's libraries (foods, exercises, compounds, guides). Strong matches become direct entity cards; the rest stay as search chips.
- If Pep fails or returns nothing usable, the app falls back to local keyword extraction from the answer text so something relevant always appears.

### Visual style

- Section title in small uppercase serif ("KEEP EXPLORING") to match the existing Pep card aesthetic.
- Chips: soft pill shape, teal accent border, magnifying-glass icon on the left.
- Entity cards: compact horizontal row with the item's icon, name, and a tiny tag (Food / Exercise / Compound / Guide) in the section's accent color.
- Subtle stagger-in animation as suggestions appear.
- Light haptic on tap.

### Edge cases

- If Pep errors out → no smart-links section, the existing error/no-results behavior is preserved.
- If the query is a plain lookup (e.g. "creatine") with real results → unchanged behavior.
- Results are deduplicated against anything already showing in the main results list above.

