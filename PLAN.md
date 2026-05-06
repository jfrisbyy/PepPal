# Enhance the Sleep card with a night-sky scene, goal tracking & peptide insights

## What you'll see

The Sleep card on the home page becomes a small, atmospheric "night sky" panel that feels alive even before you've logged anything — and gets richer with every night you track.

### Hero visual
- A custom **night sky scene** as the card backdrop: deep indigo→violet gradient, a soft glowing crescent moon, and a scatter of subtle twinkling stars.
- The moon gently breathes (slow scale + glow pulse). A few stars twinkle on a long, calm cycle so the card feels alive without being distracting.
- When you have data, the moon position shifts subtly based on hours slept (low/empty = lower horizon, full goal = high in the sky).

### Empty state — rotating "stacked" hook
A single tappable hero block that rotates through three messages every few seconds, with smooth crossfades:
1. **Why sleep matters** — "Growth peptides peak in deep sleep. Track nights to see the impact."
2. **Connect Apple Health** — "Import last night automatically" with a quick connect button.
3. **Set a sleep goal** — "Aim for 7–9 hrs. Tap to set your target."

Each message has its own icon + accent. A row of three tiny dots shows which message is active; users can tap a dot to jump.

Below the hook: a primary **"Going to bed"** button (see Quick action) and a smaller **"Log past night"** secondary link.

### "Going to bed" quick action
- Tapping starts a **sleep window** — the card switches to a calm "Sleeping…" state with the moon centered, stars dimmed, and a live elapsed-hours counter.
- Tomorrow morning (or when reopened), it prompts: "How did you sleep?" → quick quality slider + hours auto-filled from the window → one-tap save.
- A small "Cancel sleep" option is always available.

### Once you have data (1+ nights)
The card fills with three layered pieces of information, each compact:

**1. Hours vs Goal (hero readout)**
- Big rounded "7:42 h" number on the left.
- A slim **goal progress bar** underneath: filled portion = last night, faint marker line at goal (e.g. 8h).
- Quality chip stays where it is.

**2. Week strip — richer**
- The 7 mini bars stay, but now with:
  - A horizontal **goal line** drawn across at your target hours.
  - **Sleep debt this week** label below: e.g. "−2.3 h debt this week" (red) or "On track" (teal).
  - Today's bar pulses softly.

**3. Insight rotator (one line at a time, swaps every ~5s)**
Rotates through context-aware insights:
- 💊 **Peptide tie-in**: "GH peaks in deep sleep — your 7.5h last night supports recovery."
- 🏋️ **Training correlation teaser**: "You sleep 0.6h more on training days." (only if enough data)
- 📉 **Sleep debt nudge**: "You're 2.3h short this week — aim for 8h tonight."
- ✨ **Streak**: "4 nights logged in a row"

Tapping the insight line opens the full Sleep & Recovery detail view scrolled to the relevant section.

### Footer
- Source badge (Apple Health / Logged) on the left.
- "Going to bed" or "Log" button stays accessible on the right depending on state.
- Chevron to open full detail view.

## Card states summary

- **Empty / no data**: night sky scene + rotating 3-message hook + "Going to bed" CTA + small "Log past night" link.
- **Sleeping (window active)**: calm scene, centered moon, live elapsed hours, "Wake up & log" + "Cancel" options.
- **Has data**: night sky scene (subtler), hours vs goal, richer week strip with goal line + sleep debt, rotating insight line.

## Notes
- The night sky is a layered, performance-friendly visual (gradient + moon shape + a handful of star points), not a heavy effect — it stays smooth even on the home feed.
- Sleep goal defaults to 8 h; tappable to change in the empty-state hook or from the detail view.
- All animations respect Reduce Motion (scene becomes static; insight rotator becomes a static stack).