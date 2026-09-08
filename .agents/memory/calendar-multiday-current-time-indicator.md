---
name: Multi-Day current-time indicator
description: Product geometry and swipe behavior for the current-time indicator in Calendar Multi-Day view.
---

In Multi-Day view, the left-side current day keeps the existing full-width current-time line. When today is the right-side day, the indicator follows that day’s column from the center divider toward the right edge, so only the right-side line is visible.

The indicator’s horizontal anchor must follow the live day-column position: the shared day moves at half speed, while entering and exiting days move at full speed and leave the viewport. The dot is painted after the vertical separators so it visibly sits on top of the divider.

**Why:** The current-time marker represents the day containing today, not a permanently fixed Multi-Day slot. Treating it as a fixed left anchor makes it incorrect when today is displayed on the right or while the day columns slide.

**How to apply:** Derive the indicator translation from the same column-position formulas used by `_DayTimelineMulti`; keep the line full-width and let the viewport clip it after the indicator moves to the right.