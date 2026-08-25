---
name: Settled thumb row geometry
description: LiquidGlassSlider settings rows measure authored padding from the resting thumb, not the larger lifted capture viewport.
---

Slider row height must be `16px + settled thumb height + 16px`. Keep the larger lifted/deformation viewport as an unpainted centered overflow area inside that settled-thumb slot.

**Why:** The slider's capture viewport is sized for animation and deformation, so using it as the row height makes settings rows visibly too tall and violates the intended resting geometry.

**How to apply:** Separate the settled content slot from the slider viewport; use overflow constraints for the latter and never use its height as the settings row's authored height.