# Native Camera-Style Meal Log with Live Preview & Swipeable Modes

Redesign the meal logging screen to feel like the native iPhone Camera app — the camera feed is always live in the background, with swipeable mode labels at the bottom and a photo library thumbnail in the corner.

**How It Works**

- **Live camera preview fills the screen** as the default when you open "Log Meal" — no intermediate buttons or selection screens
- **Swipeable mode strip at the bottom** (like iPhone Camera's "Photo / Video / Slo-Mo" selector):
  - **Scan** — the default; live camera with a shutter button to snap a photo for AI analysis
  - **Describe** — slides up a text input over the camera to type what you ate
  - **Search** — slides up a food search interface over the camera
  - **Manual** — slides up quick-add number fields over the camera
- Swiping left/right on the mode strip (or tapping a label) switches modes with a smooth spring animation — the selected mode snaps to center and highlights, just like the native camera
- **Gallery thumbnail** in the bottom-left corner (small rounded square showing your most recent photo) — tap it to pick a photo from your library for AI analysis
- **Shutter button** (large circle, bottom center) visible in Scan mode — tap to capture and analyze
- **Close button** (X) in the top-left to dismiss
- **Meal time label** (e.g. "Lunch") shown subtly at the top

**After Capturing / Selecting a Photo**

- The live preview freezes on the captured image
- Scanning animation plays over the photo
- Results slide up from the bottom showing detected items and nutrition — same as the current result cards
- "Retake" button to go back to the live camera

**Simulator Behavior**

- On simulator (where no camera hardware exists), a clean placeholder with the camera icon is shown in place of the live feed — the mode strip, gallery button, and other modes still work normally

**Design Details**

- Dark background behind the camera feed for that native camera feel
- Mode labels in a horizontal scrollable strip with the active mode in white/bold, inactive in gray — mimics the iPhone camera's text selector
- Shutter button: white circle with a slightly smaller inner circle, matching Apple's camera button style
- Gallery thumbnail: 44×44 rounded rectangle in the bottom-left with a subtle border
- When switching to Describe/Search/Manual modes, a dark translucent panel slides up over the lower portion of the camera — the camera stays visible behind at the top as a peek
- Haptic feedback on mode switches and shutter tap

