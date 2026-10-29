---
name: Search empty-state viewport geometry
description: Keep the No Results placeholder centered when search viewports have different tab-bar and keyboard boundaries.
---

Offscreen search uses the full screen-height viewport, with the floating tab bar painted above the search results so content can scroll beneath its glass surface. Center empty states above the tab bar by reserving its full bottom clearance inside the results viewport; use no viewport-bottom offset because the search viewport itself reaches the window bottom. Non-empty results need bottom content padding equal to the tab-bar clearance plus a 16px gap. Inline search retains its own existing viewport geometry.

**Why:** Ending the offscreen overlay at the tab bar's top left a solid blank strip and stopped result content from moving behind the translucent bar. Full-height content preserves the intended scroll surface, while a single explicit clearance keeps the empty state centered in the usable area.

**How to apply:** For every offscreen tab search overlay, extend the overlay to the window bottom and paint the tab bar after it. Set `viewportBottomOffset` to zero, center the empty state with `floatingTabBarContentBottomClearance(..., finalContentGap: 0)`, and give populated results 16px beyond the bar's top edge. For keyboard overlap, compare the full window-relative inset with the tab-bar clearance. Keep inline search geometry separate.
