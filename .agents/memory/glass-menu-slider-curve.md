---
name: GlassMenu slider curve
description: Keep pinned menu optics tied to the popover curve, not the shared renderer curve or menu radius
---

## Rule
In Smart Scheduler, `GlassPopover`, `GlassBarItem.menu`, and modal picker `GlassMenu` surfaces share one slider-position remap for all their popover-curve values: the new 50% position uses the current 25% values, with endpoints preserved. Menus use standard quality. Do not alter the toolbar/tab-bar shared curve or the separate settled active-tab indicator curve.

**Why:** The user wants the three popover/menu APIs to stay in lockstep for opacity, blur, and related values while delaying the current 25% optics until the new midpoint.

**How to apply:** Use one piecewise slider-position mapping for the popover opacity and blur helpers. Preserve the independent toolbar/tab-bar and active-tab helpers; leave menu geometry and radius alone.
