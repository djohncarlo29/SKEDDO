---
name: Multi-Day current-time indicator
description: Product geometry and swipe behavior for the current-time indicator in Calendar Multi-Day view.
---

In Multi-Day view, the time pill always stays in the left label-column placement. The left-side current day keeps the existing full-width current-time line. When today is the right-side day, only the circle and line follow that day’s column from the center divider toward the right edge.

The circle/line marker’s horizontal anchor must follow the live day-column position: the shared day moves at half speed, while entering and exiting days move at full speed and leave the viewport. The dot is painted after the vertical separators so it visibly sits on top of the divider.

**Why:** The pill belongs to the global hour-label column, while the circle/line marker represents the day containing today. Translating the entire widget incorrectly moves the pill when today is displayed on the right.

**How to apply:** Keep the pill outside the translated marker subtree. Derive only the marker translation from the same column-position formulas used by `_DayTimelineMulti`; keep the line full-width and let the viewport clip it after the marker moves to the right.