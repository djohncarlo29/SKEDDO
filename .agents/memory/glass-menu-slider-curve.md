---
name: GlassMenu slider curve
description: Keep pinned menu optics tied to the popover curve, not the shared renderer curve or menu radius
---

## Rule
In Smart Scheduler, `GlassPopover`, `GlassBarItem.menu`, and modal picker `GlassMenu` surfaces share one slider-position remap for opacity and blur: the new 50% point uses the pre-remap 40% values, with endpoints preserved. The toolbar/tab-bar opacity uses its former 45% value at new 0% and interpolates to its former 50% value at the new midpoint. Scale the active-tab lens tint with that shared opacity curve while preserving its former midpoint appearance; keep its independent blur curve unchanged. Menus use standard quality.

**Why:** The user wants the three popover/menu APIs to stay in lockstep while moving their slider midpoint to a specific prior point, and wants the active lens to follow the shell opacity adjustment without changing its normal midpoint appearance.

**How to apply:** Map popover slider positions piecewise through old 40% at new 50%. Use the shared opacity curve as a normalized multiplier for the active lens's existing tint; do not change active-lens blur, menu geometry, or radius.
