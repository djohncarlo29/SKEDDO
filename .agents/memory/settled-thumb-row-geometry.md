---
name: Settled thumb row geometry
description: LiquidGlassSlider row sizing, full-track progress and ticks, and continuous-track caps.
---

Slider row height must be `16px + settled thumb height + 16px`. Keep the larger lifted/deformation viewport as an unpainted centered overflow area inside that settled-thumb slot.

**Why:** The slider's capture viewport is sized for animation and deformation, so using it as the row height makes settings rows visibly too tall and violates the intended resting geometry.

**How to apply:** Separate the settled content slot from the slider viewport; use overflow constraints for the latter and never use its height as the settings row's authored height.

## Track endpoints and continuous caps

The painted track spans the resting thumb's outer left and right edges. Progress maps the thumb's center travel across that full track, reaching the outer endpoints at minimum and maximum. Discrete tick bars are evenly distributed across the full track, with their outer bounds flush to the line endpoints; the opaque resting thumb covers the track at either endpoint. Sliders without divisions use a single capsule with rounded ends and no endpoint tick.

**Why:** The user requires endpoint lines and progress to reach the thumb's outer bounds without peeking through at rest, discrete tick bars to reach those same track edges, and the continuous Liquid Glass setting slider to have no endpoint tick or hard cap.

**How to apply:** Map normalized thumb-center travel onto the whole painted track instead of using the center coordinate as a fill endpoint. Change shared track painting rather than thumb travel or row bounds; preserve the thumb-over-track layer order, distribute discrete tick bars edge-to-edge, and round both outer caps only for sliders without divisions.