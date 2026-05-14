# Editorial Biomarkers view with richer demo bloodwork

## A new home for your lab story

Add a polished **Biomarkers** section that turns raw lab numbers into something you'd actually want to read — calm, editorial, and instantly scannable.

### What you'll be able to do

- Open a dedicated **Biomarkers** screen from Home and Profile
- See every tracked marker as its own tile with the latest value, status (low / normal / high), and a tiny trend line showing how it's moved over time
- Tap any tile to drill into the full history chart and notes
- Filter the grid by category — Hormones, Metabolic, Liver, Lipids, Thyroid, Kidney
- See an "Out of range" pill at the top showing how many markers need attention
- Still log new panels through the existing tracking screen — nothing removed

### Design

- **Editorial hero** at the top: large serif "Biomarkers" title, a one-line subtitle with the date of the latest draw ("Last draw · 7 days ago · 13 markers"), and a quiet status ribbon of dots showing in-range vs flagged
- **Category chips** that scroll horizontally below the hero — selected chip uses the category's accent color
- **Biomarker tiles** in a two-column grid, each card:
  - Marker name in semibold, unit in muted small caps
  - Big rounded value, color-coded by status (green / amber / red / blue)
  - A whisper-thin sparkline of the last 3–6 panels in the marker's color
  - Small delta vs. previous panel ("↑ 16 vs last")
- **Glass cards** with subtle inner shadow, generous whitespace, and a thin colored top accent matching the category
- Soft fade animations as tiles appear, gentle press feedback, and a haptic tap on drill-in
- Empty state is editorial too — a single sentence and one "Add lab results" button

### Richer demo data

- Each of the six demo personas gets at least three lab panels spanning the last ~6 months so trends actually tell a story
- Maya: baseline → recomp check-in → recent panel showing IGF-1 and lipids moving with training
- Theo: pre-injury → mid-rehab → recent recovery panel
- Ava: pre-season → base block → mid-block, showing endurance-typical thyroid and HDL shifts
- Shayla: pre-protocol baseline → 6-week check → recent panel showing the half-dose effect
- Marcus and Priya keep their existing three-panel arcs (already strong)

### Screens

- **Biomarkers (new)** — editorial hero, category chips, marker tile grid
- **Marker detail** — existing detail view, reached by tapping any tile
- **Bloodwork Tracking (unchanged)** — still where you log and review full panels by date, linked from the new view via a "Log a panel" button
- **Home & Profile** — new entry point card/row that opens the Biomarkers screen

