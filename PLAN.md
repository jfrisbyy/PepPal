# Swipe between tabs while screenshot mode hides the bar

**Problem:** With the floating tab bar hidden in screenshot mode, there's no way to move between Home, Train, Community, Discover, and Profile.

**Solution:** While screenshot mode is on, a horizontal swipe anywhere on the screen moves to the next or previous tab.

**How it will feel**

- Swipe left → go to the next tab (Home → Train → Community → Discover → Profile)
- Swipe right → go to the previous tab
- Wraps around at the ends, so you can keep swiping in one direction to cycle through everything
- Tab change uses the same smooth spring animation already used elsewhere
- Only active when screenshot mode is on, so it never interferes with normal scrolling, lists, carousels, or buttons in regular use
- Requires a clear horizontal swipe (with a minimum distance) so vertical scrolling on the home feed still works as expected
- Completely invisible — nothing new appears on screen, keeping screenshots clean

