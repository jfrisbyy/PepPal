# Daily Brief knows current peptide level in body

**What changes**

Right now the Daily Brief only knows the dose you took and your schedule. It doesn't know how much peptide is actually circulating in your body — the same number shown on the level chart on your protocol card.

I'll feed that calculated "in body now" amount into the Daily Brief so it can reason about it the same way the chart shows it.

**Specifically**

- For each active compound, calculate the current amount in body (using the same Bateman model that powers the chart and the "in body now" line on the home protocol card).
- Pass that number into the Daily Brief alongside the dose and schedule, so the brief can say things like "Retatrutide is sitting around 4.2 mg in your system — peak window from yesterday's dose" instead of just "scheduled 6 mg weekly."
- Update the prompt rules so the brief is required to reference circulating level (not just dose) whenever it talks about the protocol — peak/trough timing, why nausea may be hitting today, whether today's training falls in a high or low level window, etc.
- Also include the percent of the last dose still active, so the brief can say things like "you're at ~62% of your last dose."

**Where you'll see it**

Same Daily Brief card on the home screen — the language just gets sharper and more accurate to what your chart is actually showing.