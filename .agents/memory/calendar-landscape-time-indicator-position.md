---
name: Landscape current-time positioning
description: Initial scroll position for Calendar Day timelines in landscape.
---

In landscape, center the current-time indicator within the timeline viewport after subtracting the shared Floating Tab Bar bottom clearance. Use the mounted scroll viewport's actual height, clamp the target offset to the scroll extents, and recalculate when the landscape window size or bottom clearance changes. Apply the same positioning to Single Day and Multi Day; leave the existing portrait starting offset unchanged.

**Why:** The landscape timeline below the calendar headers is short, so a fixed two-hour initial offset can place the current-time indicator behind the floating tab bar. Portrait already presents the current time at a useful height and should not be shifted by this correction.

**How to apply:** Measure `ScrollPosition.viewportDimension` after layout and subtract `floatingTabBarContentBottomClearance` once. Do not estimate timeline height from the full screen or duplicate the calendar-header geometry.