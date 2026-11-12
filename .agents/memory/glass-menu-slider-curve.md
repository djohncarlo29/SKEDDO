---
name: GlassMenu slider curve
description: Keep pinned menu optics tied to the popover curve, not the shared renderer curve or menu radius
---

## Rule
In Smart Scheduler, `GlassPopover`, `GlassBarItem.menu`, and modal picker `GlassMenu` surfaces share direct piecewise-linear opacity and blur anchors at 0%, 25%, 50%, 75%, and 100%: opacity `.7464`, `.800`, `.8546`, `.9087`, `.9500`; blur `1.744`, `3.808`, `5.872`, `7.936`, `10.000`. The toolbar/tab-bar opacity uses its former 45% value at new 0% and interpolates to its former 50% value at the new midpoint. Scale the active-tab lens tint with that shared opacity curve while preserving its former midpoint appearance; keep its independent blur curve unchanged. Menus use standard quality.

**Why:** The user wants identical interpolation for the three popover/menu APIs and explicitly set the five anchor values; the active lens should follow the shell opacity adjustment without changing its normal midpoint appearance.

**How to apply:** Interpolate popover/menu opacity and blur directly between the five specified anchors, without another position remap. Use the shared toolbar/tab-bar opacity curve as a normalized multiplier for the active lens's existing tint; do not change active-lens blur, menu geometry, or radius.
