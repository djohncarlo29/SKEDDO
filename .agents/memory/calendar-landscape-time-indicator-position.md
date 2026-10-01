---
name: Landscape current-time positioning
description: Initial scroll position for Calendar Day timelines in landscape.
---

In landscape, center the current-time indicator within the timeline viewport after subtracting the shared Floating Tab Bar bottom clearance. Use the mounted scroll viewport's actual height and clamp the target offset to the scroll extents. Recenter at initial layout, after landscape geometry changes, and when navigation returns the current day to the center/visible pair; do not override ordinary manual scrolling. Apply the same behavior to Single Day and Multi Day while leaving portrait positioning unchanged.

**Why:** The landscape timeline below the calendar headers is short, so a fixed two-hour initial offset can place the current-time indicator behind the floating tab bar. Manual scrolling can also move it out of view; returning to today should restore it without making normal scrolling fight the app. Portrait already presents the current time at a useful height and should not be shifted.

**How to apply:** Measure `ScrollPosition.viewportDimension` after layout and subtract `floatingTabBarContentBottomClearance` once. Trigger date-return recentering from selected-date changes, not every rebuild or time tick. Do not estimate timeline height from the full screen or duplicate the calendar-header geometry.