---
name: Multi-Day current-time indicator
description: Product geometry and swipe behavior for the current-time indicator in Calendar Multi-Day view.
---

In Multi-Day view, the time pill stays in the left label-column placement for shared or entering days. The circle and line follow today's live day-column position. In landscape, omit the outer right vertical divider in both the day banner and timeline, and extend the current-time line to the physical screen edge when today is in the right-hand column. In other positions, the line ends at today's moving column edge.

During Multi-Day entrance, tie the line to the animated center separator: a left-side today line retracts from full width to the moving divider, while a right-side today dot follows that divider and its line grows toward the right edge. After entrance, return to the live day-column geometry.

The shared day moves at half speed, while entering and exiting days move at full speed. For left-edge entering/exiting cases, the pill, circle, and line may still translate together with the full panel offset. Do not clip that translated indicator at the content inset; only the physical viewport edge should clip it. The line width must compensate for the indicator offset so its endpoint stays aligned to the intended edge. Paint the dot after the vertical separators so it visibly sits on top of the divider.

**Why:** A full-width line crosses into the adjacent day when today is in the left column. The pill belongs to the global hour-label column, while the marker and line represent only the day containing today. The user requested an edge-to-edge line and no outer divider for the right day in landscape, plus unclipped left-edge swipe-out behavior.

**How to apply:** In `_DayTimelineMulti`, use the live animated center-separator position while the entrance controller is running. For settled/swiping states, compute the line length from the intended endpoint and marker's live origin shift, subtracting the gap and dot width before the line begins. In landscape, use the physical right edge for right-column today and omit the outer right divider. Preserve whole-indicator swipe rules and avoid clipping at the content inset.