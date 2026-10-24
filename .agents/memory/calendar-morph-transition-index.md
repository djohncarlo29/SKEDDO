---
name: Calendar morph transition index
description: Focused notes for Calendar hierarchy morphs, panel handoffs, and Day List header transitions.
---

Use the view-specific note that matches the transition being changed:

- [Midpoint view handoff](calendar-midpoint-view-handoff.md) — switch controls at 50%; keep shell and scroll-title painting exclusive during Year↔Month zoom.
- [Day List header transition](calendar-day-list-header-transition.md) — keep the weekday row, week strip, and day banner moving together.
- [Morph content bounds](calendar-morph-content-bounds.md) — keep positioned morph children content-sized.
- [Year-to-Month List boundary](year-month-list-morph-boundary.md) — keep the List handoff in the overlay with intrinsic event content.
- [Week-strip veil architecture](calendar-morph-week-strip-surfaces.md) — preserve fixed DOW chrome while complete week rows act as moving veils.
- [Year↔Month title geometry](calendar-year-zoom-transform.md) — freeze measured endpoints through the spring.
- [Three-panel swipe handoff](calendar-3panel-plusminus2-bug.md) — remap panel slots only after the transition completes.
- [Month panel clipping](calendar-month-panel-clipping.md) — clip each month panel before its vertical strip transform.
- [Swipe indicator geometry](calendar-swipe-indicator-geometry.md) — cap bloom overshoot and keep the overlay blob-wrapped.
- [Day banner swipe height](day-banner-swipe-height.md) — interpolate the banner toward the incoming view's label height.
- [Header chevron continuity](calendar-header-chevron-continuity.md) — keep inactive panels non-interactive and block title taps from chevrons.

**How to apply:** Read the directly relevant topic before changing Calendar view-transition ownership, clipping, or content bounds.
