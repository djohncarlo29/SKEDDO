---
name: Search empty-state viewport geometry
description: Keep the No Results placeholder centered when search viewports have different tab-bar and keyboard boundaries.
---

Offscreen search uses the full screen-height viewport, with the floating tab bar painted above the search results so content can scroll beneath its glass surface. DCV must not shorten its whole empty-results scroll viewport by the tab-bar clearance: reserve that clearance inside the empty-state sliver instead. When the keyboard is open, shorten the viewport only by the keyboard overlap and subtract that overlap from the remaining tab-bar clearance. Non-empty results need bottom content padding equal to the tab-bar clearance plus a 16px gap. Inline search retains its own existing viewport geometry.

**Why:** Ending the offscreen overlay at the tab bar's top left a solid blank strip and stopped result content from moving behind the translucent bar. Full-height content preserves the intended scroll surface, while a single explicit clearance keeps the empty state centered in the usable area.

**How to apply:** For every offscreen tab search overlay, extend the overlay to the window bottom and paint the tab bar after it. Set `viewportBottomOffset` to zero. For DCV empty results, keep CustomScrollView full-height and apply `max(tabBarClearance - keyboardOverlap, 0)` to the placeholder's inner centering only. Give populated results 16px beyond the bar's top edge. Keep inline search geometry separate.
