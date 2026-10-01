---
name: Multi-Day current-time indicator
description: Product geometry and swipe behavior for the current-time indicator in Calendar Multi-Day view.
---

In Multi-Day view, the time pill stays in the left label-column placement for shared or entering days. The circle and line follow today's live day-column position, and the line ends at that column's moving right edge: the center divider when today is on the left, and the right edge when today is on the right.

During Multi-Day entrance, tie the line to the animated center separator: a left-side today line retracts from full width to the moving divider, while a right-side today dot follows that divider and its line grows toward the right edge. After entrance, return to the live day-column geometry.

The shared day moves at half speed, while entering and exiting days move at full speed. For left-edge entering/exiting cases, the pill, circle, and line may still translate together with the full panel offset. The line width must compensate for that indicator offset so its endpoint remains aligned to the actual day's right edge. Paint the dot after the vertical separators so it visibly sits on top of the divider.

**Why:** A full-width line crosses into the adjacent day when today is in the left column. The pill belongs to the global hour-label column, while the marker and line represent only the day containing today.

**How to apply:** In `_DayTimelineMulti`, use the live animated center-separator position while the entrance controller is running. For settled/swiping states, compute the line length from today's column right edge and the marker's live origin shift, subtracting the gap and dot width before the line begins. Preserve existing whole-indicator swipe rules; do not use viewport clipping as a substitute for the per-column endpoint.