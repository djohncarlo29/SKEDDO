---
name: GlassMenu slider curve
description: Keep pinned menu optics tied to the popover curve, not the shared renderer curve or menu radius
---

## Rule
In Smart Scheduler, `GlassPopover`, `GlassBarItem.menu`, and modal picker `GlassMenu` share base opacity anchors `.7464`, `.800`, `.8546`, `.9087`, `.9500` and blur anchors `1.744`, `3.808`, `5.872`, `7.936`, `10.000`. For their slider, remap `x≤.5` to `.8x` and `x>.5` to `.4+1.2(x-.5)`: the old 40% sample is now 50%, with endpoints fixed. The toolbar/tab-bar curve remains separate and unchanged. Calendar bar menus use premium quality; modal picker menus use standard quality and a plain text trigger morphing from its measured dimensions without a separate glass blob. Dark menu rims reduce `lightIntensity`, Fresnel, ambient rim, and glow independently of slider optics.

**Why:** The user wants the three menu surfaces to share the Popover curve and most recently moved the old 40% sample to the new midpoint while preserving endpoints. The toolbar/tab-bar curve has its own remap.

**How to apply:** Apply the Popover-only slider-position remap before interpolating both opacity and blur anchors; do not modify anchor values or the separate shared toolbar/tab-bar remap. Resolve menu brightness from the active `CupertinoTheme` appearance so Dark Mode edge reduction persists when the app overrides system appearance. For these menu surfaces, halve dark `lightIntensity`, `ambientRim`, `fresnelStrength`, and `glowIntensity` independently of slider optics. Preserve the active-tab lens's own blur and radius.
