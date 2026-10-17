---
name: App header scroll-edge behavior
description: Shared pinned header glass edge and large-title movement across app pages.
---

## Rule
The large title follows the active scrollable's actual position without a fixed positive maximum. Floor negative elastic overscroll at zero, clamp glass-edge progress to the title-slot length, and keep offsets scoped to the page/view whose scroll controller owns them. Calendar Day timeline scrolling does not own the app header; exclude its notifications. App-shell and Settings headers use the content background across the top safe area and both header levels; do not add a separate card fill or shadow.

**Why:** Clamping the title itself leaves it stuck beneath the pinned toolbar instead of allowing it to scroll away; summing gesture deltas can diverge from ballistic or restored positions. Flutter's bouncing physics can report pixels below the minimum extent, which otherwise translates the title back down behind the toolbar. A global notification listener also sees Day timeline scrolling, so using it as header input moves the entire title group once per hour. A card-colored or shadowed first level creates a visible band against the content surface even while idle.

**How to apply:** Derive title translation from `pixels - minScrollExtent`, flooring at zero but leaving positive movement unbounded; normalize and clamp that value only when driving the edge effect. Filter notifications to scrollables that actually own the header, and use distinct scopes for calendar views and day submodes. Keep `LiquidGlassScrollEdge` as the scroll-reactive treatment, with its surface color matching the content background.
