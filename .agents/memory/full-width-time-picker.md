---
name: Full-width time picker selection
description: Shared event time-picker spacing and selection-bar behavior.
---

Use three equal-width columns across the available picker width so the hour, minute, and day-period values retain their established layout and the connected selection bar fills the row in both portrait and landscape. Right-align the hour with 12dp trailing padding, center the minutes, and left-align AM/PM with 12dp leading padding. Render these labels with plain `Text`, not `WheelOptionText`; its extra 8dp edge inset shifts the values away from the established positions. Preserve the off-axis barrel curvature.

**Why:** The established picker uses evenly spaced columns and the full-width connected selection bar. A later `WheelOptionText` wrapper added an 8dp inset on top of the existing 12dp label padding, moving the hour and period away from their prior positions. The September 30 reference screenshot shows the original three-column arrangement.

**How to apply:** This rule applies to every shared event time picker instance, including start, end, and reminder times. Keep the three Expanded columns and their `-0.45 / 0 / +0.45` off-axis values. A request to change barrel curvature does not authorize changing the column layout or replacing the plain time-label widgets with edge-inset wheel text.