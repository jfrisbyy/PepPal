# Make search find guides and always answer questions

**The problem**

Right now if you type a how-to question like "how do i reconstitute", search shows nothing. Two things are broken:

1. The search index only covers exercises, foods, compounds, people, circles and posts. It has no entry for the how-to material that lives on the Discover page (the Beginner's Guide chapters, the Reconstitution Calculator, etc.), so those never surface.
2. The Ask Pep answer card only appears once Pep finishes thinking. On a slow network, if the request hiccups, the card silently disappears and the screen looks empty.

**What changes**

- Add a new "Guides & Tools" results group. It indexes every chapter of the Beginner's Guide (Reconstitution, Injection technique, Storage, Reading a COA, Safety basics, etc.), the Reconstitution Calculator, the Syringe Draw Guide, and a handful of other in-app tools. Each row deep-links straight into the relevant guide chapter or tool.
- Searching natural-language phrases like "how do i reconstitute", "how to inject", "store peptides" now lights up these guides as proper results, alongside any matching compounds. So "how do i reconstitute" surfaces: the Reconstitution chapter of the Beginner's Guide, the Reconstitution Calculator, and the Syringe Draw Guide.
- Add a new "Guides" scope chip next to Exercises / Foods / Compounds so you can filter to just how-to content.
- Trending suggestions on the empty search screen now include a few how-to phrases ("how to reconstitute", "how to inject", "reading a COA") to teach the new behavior.
- The Ask Pep answer card is now sticky for any question — even if Pep is still thinking, errors out, or returns nothing useful, the card stays on screen with a clear status (thinking, retry, or "tap to ask in chat") so the question always has a visible home.
- Tapping a guide row opens straight into that chapter; tapping the calculator opens the calculator with the right preset.

**Result**

Type "how do i reconstitute" and you immediately see Pep's personalized answer at the top, plus the Reconstitution guide chapter, the Reconstitution Calculator, and the Syringe Draw Guide right below — never an empty screen again.