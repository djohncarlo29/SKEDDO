---
name: Package glass default-first rule
description: Start new flutter_liquid_glass_widgets surfaces with their defaults; reuse SKEDDO's shared optical settings only after a visual mismatch is reported.
---

For newly added `flutter_liquid_glass_widgets` components, use the package's
default glass behavior on the first pass. If the user says a component's glass
looks wrong, immediately apply the shared SKEDDO glass settings used by the
floating tab bar and modal toolbar buttons rather than inventing another
renderer or tuning a separate design.

**Why:** The user wants a clean first comparison against the package, followed
by a consistent correction path when its default optics do not fit SKEDDO.

**How to apply:** Do not automatically pass the shared settings to unrelated
new package widgets. After the user flags a mismatch, reuse the shared settings
source and preserve the package's rendering path.

For SKEDDO's shared glass renderer, preserve the white Light Mode tint and
`#3E3E40` Dark Mode tint. Its opacity and blur use slider curves; GlassPopover
has independent curves. Modal save checkmarks keep category/accent tint on the
glass while the checkmark glyph stays opaque white.

**Why:** The user wants mode-specific shared surfaces, with independently tuned
slider response for the renderer and GlassPopover. Tinted toolbar actions
should resemble iOS tinted glass without sacrificing refraction or white-glyph
contrast.

**How to apply:** Preserve the separate Light/Dark tint colors and keep
GlassPopover settings independent of the shared renderer curves. Keep modal
action tint on the material, not on the glyph.

All glass surfaces that follow the Liquid Glass slider should rebuild while the
slider is dragged, including shared toolbars and the discard popover. Active
category/accent checkmarks are the exception: their glass optics stay fixed at
the 50% slider reference.

**Why:** The user expects slider-driven glass to respond immediately, but
explicitly kept active checkmarks independent from the slider curves.

**How to apply:** Keep the slider notifier connected to shared surfaces,
toolbars, and popover settings; anchor active-checkmark optics to the fixed
reference even though their widget may rebuild.

For the Liquid Glass settings slider, map the new 50% position to the effects
formerly produced at 57%, while preserving the 0% and 100% endpoints. Apply
that coordinate remap to every slider-driven opacity and blur curve, including
the independent active-tab and popover curves. Its midpoint marker matches
Text Size ticks: 3×3 circle, tertiary-label color, 8px below the track center,
and below the thumb. It is a release-only detent: 48% through 52% settle to
50%, but dragging remains continuous.

**Why:** The user wants the prior 57% effect response centered at the slider's
50% position, with the midpoint marker helping users settle there without
introducing a drag-time stop.

**How to apply:** Keep the effect-coordinate remap centralized for all glass
curves; keep the stored slider coordinate unchanged and apply midpoint snapping
only at gesture completion. Preserve the shared tick geometry, color, and layer
order on Flutter and native iOS.
