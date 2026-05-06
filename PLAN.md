# Replace the drawn body figure with native Apple silhouettes

## What changes

Swap the hand-drawn human silhouette on the injection site rotation view for Apple's native figure symbols, used in both the protocol detail view and the guided injection flow. The result feels clinical, crisp, and always renders perfectly at any size.

## How it will look

- **Front view** uses Apple's standing front-facing figure; **Back view** uses the rear-facing figure, with the same elegant Front/Back toggle as today.
- The figure sits on the same dark editorial canvas with the soft floor shadow, vertical center beam, and ANTERIOR/POSTERIOR corner label preserved.
- A subtle teal aura still glows behind the figure for premium depth.
- **Heat zones stay** — the colored warmth blooms (cool / warm / hot / unused) continue to mask onto the figure so users instantly see which areas are overused.
- **Tappable site dots stay** in the same anatomical positions (deltoids, abdomen, thighs, glutes), with the pulsing teal ring for the suggested next site and the white check for the selected site.
- Legend (Cool / Warm / Hot / Unused / Suggested) and the labeled site row beneath the figure remain unchanged.

## Where it appears

- **Protocol detail screen** — the "Injection sites" card.
- **Guided injection flow** — the site picker step.

## Notes

- The decorative silhouette path code is removed; everything else (heat map, dots, recency logic, suggestions) is untouched.
- Falls back gracefully on older iOS versions since the figure symbols are standard SF Symbols.