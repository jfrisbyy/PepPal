# Side-by-side cycle comparison with trend charts & protocol overlays

## What you'll be able to do

- Pick two or more past/active cycles and see how they stack up against each other on a single beautiful, editorial trend chart.
- Toggle between metrics — body weight, IGF-1 & other biomarkers, side effect frequency, sleep & HRV, strength/training volume, and cumulative dose.
- See each cycle as its own colored line, with shaded phase bands (Loading, Maintenance, Tapering, Off) and small vertical markers wherever dose changed.
- Flip the x-axis between **Cycle Week** (best for "is this cycle better than my last?") and **Calendar Date** (best for "what was happening in my life then?").
- See a clean header summary per cycle — average dose, peak biomarker change, side-effect count, adherence — so the chart story is backed by hard numbers.

## How you'll get there

- **From Protocol History:** new "Compare" mode in the top bar — tap to multi-select cycles, then a Compare button slides up.
- **From a Protocol Detail page:** a "Compare to past cycle" button near the header opens the same view with this cycle pre-selected.

## What you'll see

**Cycle Comparison screen**

- A premium editorial header naming the cycles being compared (e.g. *"Reta Cycle 2 vs Cycle 1"*), each in its assigned color.
- A horizontal metric selector (Weight · IGF-1 · Glucose · Side Effects · Sleep · HRV · Volume · Cumulative Dose) — feels like flipping through Apple Health tabs.
- The hero trend chart, full width, with:
  - One overlaid line per cycle in its color.
  - Soft phase bands behind the lines (Loading = blue tint, Maintenance = teal, Tapering = amber, Off = gray).
  - Small vertical tick markers at every dose change or phase transition.
  - Tap-and-hold scrubber that shows each cycle's value at that point.
- Below the chart, a row of comparison cards — one per cycle — with the headline stat for the selected metric (e.g. "+12% IGF-1 by week 8") and a one-line takeaway.
- A bottom "Insights" strip that summarizes the comparison in plain English (e.g. *"This cycle is trending 8% better on IGF-1 with half the side-effect days."*).
- Toggle pill at the top right: **Cycle Week ↔ Calendar Date**.

## Design feel

- Dark editorial canvas, generous spacing, thin precise lines, rounded chart corners, subtle glass on the metric pills.
- Each cycle gets a distinct, harmonious color from the existing teal/violet/blue/amber palette so overlays never look noisy.
- Smooth spring animation when switching metrics — chart lines redraw in place.
- Light haptic on metric switch and on scrubber tick crossings.

## Demo data

- Maya and the other demo accounts will get 2–3 realistic past cycles seeded with weight, IGF-1, glucose, sleep/HRV, training volume, side effects, and dose logs — so the comparison view tells a real story the first time it's opened.

## Floating chrome

- The existing Hide-Chrome and Screenshot floating buttons will continue to work on this new screen so it can be captured cleanly for marketing.

