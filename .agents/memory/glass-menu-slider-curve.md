---
name: GlassMenu slider curve
description: Keep pinned menu optics tied to the popover curve, not the shared renderer curve or menu radius
---

## Rule
In Smart Scheduler, `GlassPopover`, `GlassBarItem.menu`, and modal picker `GlassMenu` surfaces share the popover opacity curve, and menus use standard quality. The existing opacity curve occupies slider positions 50–100%; positions 0–50% ramp linearly from transparent to the former 0% opacity. Keep the popover blur curve on its existing full slider range, and do not alter the shared-renderer or active-tab curves.

**Why:** The user wants a much lighter opacity floor while preserving the established upper-range opacity response and all blur behavior; premium rendering is reserved for persistent navigation surfaces, not these menus.

**How to apply:** Keep `skeddoPopoverOpacityForPosition` as the sole remapping point for all popover-curve consumers. Preserve `skeddoPopoverBlurForPosition`, `skeddoSharedGlassOpacityForPosition`, and `skeddoActiveTabIndicatorBlurForPosition`; leave menu geometry and radius alone.
