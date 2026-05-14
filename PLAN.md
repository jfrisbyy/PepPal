# Make Maya's peptide chart show a continuous, accurate level curve

**The issue**

Maya's stack mixes two very different peptides:
- **Retatrutide** — half-life ~6 days, dosed weekly. Should look like a smooth rolling wave that builds over weeks.
- **GHK-Cu** — half-life under an hour, dosed daily. Each dose spikes and clears in a few hours.

Right now the chart samples the curve at evenly spaced intervals (~every 1¾ hours on the 7-day view). For Retatrutide that's fine, but for GHK-Cu each spike is briefer than the sample spacing, so the curve only catches the tip of each spike at random — producing the "bunch of disconnected dots" you saw. The line also visually breaks at the "Now" marker because past and future are drawn as two separate series.

**What I'll fix**

- **Add dense sampling around every logged dose**, so fast peptides like GHK-Cu show the actual rise-and-fall shape after each injection instead of being missed by the regular sample grid. Slow peptides like Retatrutide stay perfectly smooth.
- **Stitch the past and projected-future line into one continuous curve** so it doesn't visually break at the "Now" line. The future portion stays dotted to indicate projection; the past stays solid — they just meet cleanly at "Now."
- **Keep the dose dots** sitting exactly on the curve at each injection time, with the line passing through them rather than floating beside them.
- **Apply this everywhere the chart appears**: protocol detail hero chart, compound detail page chart, and the small inline sparkline on protocol cards — so every persona's chart (Maya, Theo's BPC-157/TB-500, Marcus's Ipamorelin, etc.) reads as a real pharmacokinetic curve.

**Result for Maya specifically**

- **Retatrutide** — a smooth wave that climbs across her 6 weekly doses and settles into a steady ~1.8–2 mg circulating level, with the dotted projection trailing forward from today.
- **GHK-Cu** — a daily sawtooth that clearly spikes up after each morning dose and clears by evening, with two visible gaps where she skipped doses while traveling. You'll be able to scrub across any moment and see exactly how much was in her body.

No copy or layout changes — just the chart itself becoming accurate and properly connected.