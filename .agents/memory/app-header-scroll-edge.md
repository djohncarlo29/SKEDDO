---
name: App header scroll-edge behavior
description: Shared pinned header glass edge and large-title movement across app pages.
---

## Rule
The large title follows the active scrollable's actual position without a fixed maximum. Clamp only the glass-edge progress to the title-slot length, and keep offsets scoped to the page/view whose scroll controller owns them. App-shell and Settings headers use the content background across the top safe area and both header levels; do not add a separate card fill or shadow.

**Why:** Clamping the title itself leaves it stuck beneath the pinned toolbar instead of allowing it to scroll away; summing gesture deltas can diverge from ballistic or restored positions. A card-colored or shadowed first level creates a visible band against the content surface even while idle.

**How to apply:** Derive title translation from `pixels - minScrollExtent`; normalize and clamp that value only when driving the edge effect. Use distinct scopes for calendar views and day submodes. Keep `LiquidGlassScrollEdge` as the scroll-reactive treatment, with its surface color matching the content background.
