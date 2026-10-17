---
name: App header scroll-edge behavior
description: Shared pinned header glass edge and large-title movement across app pages.
---

## Rule
The large title follows the active scrollable's actual position without a fixed maximum. Clamp only the glass-edge progress to the title-slot length, and keep offsets scoped to the page/view whose scroll controller owns them. Landscape compact headers remain unchanged.

**Why:** Clamping the title itself leaves it stuck beneath the pinned toolbar instead of allowing it to scroll away; summing gesture deltas can diverge from ballistic or restored positions.

**How to apply:** Derive title translation from `pixels - minScrollExtent`; normalize and clamp that value only when driving the edge effect. Use distinct scopes for calendar views and day submodes.
