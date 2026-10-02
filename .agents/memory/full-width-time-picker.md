---
name: Full-width time picker selection
description: Shared event time-picker spacing and selection-bar behavior.
---

Use three equal-width columns across the available picker width so the hour, minute, and day-period values retain their established layout and the connected selection bar fills the row in both portrait and landscape. Preserve the 12dp inner padding on the hour and day-period labels, plus their off-axis barrel curvature.

**Why:** The compact measured-width group made the time values too close together and narrowed the selection bar compared with the surrounding pickers. Removing the 12dp inner padding also collapsed the established gaps between hour/minute/period labels.

**How to apply:** This rule applies to every shared event time picker instance, including start, end, and reminder times. A request to add or preserve off-axis curvature does not authorize changing the time picker's column layout or label spacing.