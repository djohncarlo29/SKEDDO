---
name: Empty Month List scroll extent
description: Keep a fitting Month List grid at zero scroll offset when its selected day has no events.
---

In empty Month List mode, size the “No Events” placeholder from the viewport space remaining after the header and weekday/grid content. The placeholder should fill available space, not add scroll extent when the grid fits; only real grid overflow should make this empty state scrollable.

**Why:** Giving the empty placeholder a full viewport-sized box after header slivers made compact List mode appear scrolled despite a fitting month grid.

**How to apply:** When adjusting Month List slivers, derive the empty body height from `viewportMainAxisExtent - precedingScrollExtent`, and preserve scroll extent only when the calendar grid itself exceeds that available height.
