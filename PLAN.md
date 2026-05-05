# Redesign the program builder as 'Design Your Program' — editorial, no AI talk

## What changes

A full editorial redesign of the multi-step program builder, with all "AI / generate / building" terminology replaced by quiet, confident editorial language. The flow will feel like a tailored atelier experience, not a chatbot.

### Naming & copy

- Title across all screens: **"Design Your Program"** (replaces "AI Program Builder" / "Smart Program Builder")
- Primary action: **"Compose Program"** (replaces "Generate Program")
- Secondary actions: **"Refine"** (replaces "Regenerate"), **"Begin Program"** (replaces "Start This Program")
- Personalization callout: **"Personalized from your profile"** (replaces "Auto-filled from your profile" and "Your Data — Sending to AI")
- Removes every visible mention of "AI", "generate", "build", "sparkles", "brain" iconography

### Editorial composition

- **Hero step header** with a small uppercase kicker (e.g. "CHAPTER ONE · INTENT"), a serif headline, and a thin hairline divider — replacing the icon + bold title pattern
- Step indicator becomes a slim numbered progression ("01 — 02 — 03 — 04") with a hairline rule
- Cards adopt editorial whitespace: serif headlines, sentence-case labels, refined kickers, and softened violet accents
- Replace checkmark/checkbox circles with elegant inline radio marks; selected state uses a thin violet hairline and subtle tint
- Schedule + equipment selectors become refined pill rows with editorial spacing rather than chunky tab bars

### Composing screen (loading)

- Removes the pulsing sparkle. Shows a quiet centered layout:
  - Thin determinate-feeling progress line (animated)
  - Serif headline: **"Composing your plan."**
  - Single rotating subline of editorial phrases (e.g. "Considering your protocol.", "Sequencing your week.", "Selecting your movements.")
- Errors render in the same editorial frame with a "Try again" link

### Result screen

- Replaces the green "Program Generated" badge with a small editorial label: **"YOUR PROGRAM"** in tracked uppercase
- Program name styled as a serif display title, with a subtle pencil affordance for renaming
- Stats row reframed as editorial metadata: "4 days · 22 movements · 4 of 4 placed"
- Weekly schedule overview gets a refined typographic week strip with hairline cells
- Day cards use editorial numbering ("I · Push", "II · Pull"), serif day names, and a quieter expand affordance
- Action buttons restyled: a primary teal "Begin Program" with refined typography and a quiet "Refine" link below

### Behind the scenes

- Same underlying program-composition service and inputs — only the presentation, copy, and microcopy change
- All tracked context (protocol, body goal, weights, history) still informs the result, just framed as "personalized from your profile"

### Screens touched

- The 4-step program designer (Intent, Cadence, Equipment, Refinements)
- The composing/loading screen
- The completed program review screen
- Entry points referencing the old name updated to "Design Your Program"

