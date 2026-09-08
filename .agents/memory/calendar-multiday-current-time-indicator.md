---
name: Multi-Day current-time indicator
description: Product geometry and swipe behavior for the current-time indicator in Calendar Multi-Day view.
---

In Multi-Day view, the time pill stays in the left label-column placement for shared or entering days. When today is the left-side day and that column exits left, the pill, circle, and line translate together as one clipped element. When today is the right-side day, only the circle and line follow that day’s column from the center divider toward the right edge.

The circle/line marker’s horizontal anchor must follow the live day-column position: the shared day moves at half speed, while entering and exiting days move at full speed and leave the viewport. The dot is painted after the vertical separators so it visibly sits on top of the divider.

**Why:** The pill normally belongs to the global hour-label column, while the circle/line marker represents the day containing today. The left-side exit is the exception: keeping the pill fixed there detaches it from the marker as the day leaves the viewport.

**How to apply:** Derive translations from the same column-position formulas used by `_DayTimelineMulti`. Use a whole-indicator translation only for the left-side exiting-today case; otherwise keep the pill anchored and translate only the marker. Keep the line full-width and let the viewport clip the indicator as it leaves.