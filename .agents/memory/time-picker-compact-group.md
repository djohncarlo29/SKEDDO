---
name: Compact time picker group
description: Layout and appearance rules for the shared event time picker.
---

Keep hour, minute, and day-period wheels together in a centered group sized from their actual rendered labels at the active text scale. Preserve the hour and period off-axis barrel curvature.

**Why:** Full-width columns spread the values too far apart, especially in landscape; the fixed-width layout also needs to respect larger text and localized label widths.

**How to apply:** Update the shared time-picker widget so starts, ends, and reminder times stay consistent. Recompute widths when text style, text scaler, or direction changes, and keep the group within its available width.