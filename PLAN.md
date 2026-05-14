# Add protocols to every demo persona + plain-English briefs

## What changes

### Every persona gets an active protocol

Right now Maya is the only persona with no peptide protocol. We'll give Maya a stack: **low-dose Retatrutide (1 mg weekly)** for her final cut pounds + **GHK-Cu (1 mg daily)** for skin and recovery support during the lean phase. Her existing rough-sleep story stays — the protocol just becomes part of her week.

Final protocol roster across all 6 demo personas:

- **Maya** — Retatrutide 1 mg weekly + GHK-Cu 1 mg daily *(new)*
- **Priya** — Tirzepatide 5 mg weekly *(unchanged)*
- **Theo** — BPC-157 250 mcg twice daily + TB-500 2.5 mg weekly *(unchanged)*
- **Marcus** — Testosterone Cypionate 100 mg weekly + Ipamorelin nightly *(unchanged)*
- **Ava** — Ipamorelin nightly *(unchanged)*
- **Shayla** — Borrowed Test Cyp at half-dose *(unchanged)*

Maya's vial inventory, dose log history, weekly schedule and compound-level sparkline data will be filled in to match the new stack so every screen renders coherently.

### Daily briefs rewritten in plain English

Every persona's brief, modules, action items, and adaptive callouts get a pass to replace insider jargon with everyday language. Examples:

- "low-FODMAP" → "skip the usual triggers — onion, garlic, beans, dairy"
- "Z2 easy" → "easy, conversational pace"
- "5/3/1 BBB" → "main lift then back-off volume sets"
- "PPL" → "Push / Pull / Legs split"
- "subq" → "under-the-skin injection"
- "PK level ~62%" → "blood level around 62% of normal"
- "RUQ discomfort" → "upper-right belly tenderness"

Biomarker abbreviations everyone sees on lab reports (HRV, RHR, ALT, LDL, AST, SHBG, E2) stay — they're added to the user's everyday vocabulary by the app itself, but we'll add a one-line context the first time each appears in a brief.

### Maya's brief gets a new protocol module

Her opening summary and narrative will weave in the Retatrutide + GHK-Cu context so the protocol stack on her home screen matches the story: she's 6 weeks into a low-dose GLP-1 finish-cut paired with GHK-Cu for skin support, and last night's rough sleep is the adaptive trigger of the day.

### Verification

After the changes I'll run the build check and the demo-mode coherence verifier that already prints persona consistency (workouts, dose logs, vials, bloodwork) so we know every persona's protocol, briefs, and home modules all line up.

### What stays the same

- Persona names, ages, goals, scenarios, headlines remain
- All five other personas' protocol stacks are unchanged
- Screenshot debug mode, friends/community mock data, and adjustments engine are untouched

