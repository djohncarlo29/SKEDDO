---
name: GlassMenu slider curve
description: Keep pinned menu optics tied to the popover curve, not the shared renderer curve or menu radius
---

## Rule
In Smart Scheduler, expanded `GlassBarItem.menu` surfaces follow the Liquid Glass setting's GlassPopover slider curve. “Curve” refers to the slider-driven glass optics, not the menu's corner radius. Keep the menu radius at its existing 32px default unless the user separately asks to change it.

**Why:** The user corrected an earlier radius change: they meant the popover's slider-dependent optics, and specifically asked to restore the previous radius.

**How to apply:** Pass the popover-specific settings to the expanded menu surface independently of the toolbar capsule's shared renderer settings. When adjusting the Liquid Glass slider, preserve the separate popover opacity/blur anchors and leave menu geometry alone.
