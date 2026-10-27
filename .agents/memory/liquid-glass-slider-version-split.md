---
name: Liquid Glass slider version split
description: Preserve the original bouncing thumb-edge icon motion without downgrading the main liquid_glass_easy controls.
---

Keep the main app on hosted `liquid_glass_easy` 5.0.0 for switches and other controls. Flutter sliders use the slider-only `liquid_glass_easy_slider` companion built from the retained local v4 implementation. That implementation reports the live thumb center and rendered pill size, so the edge icons can follow the actual rubberbanded thumb and maintain the active gap.

**Why:** The hosted 5.0.0 slider does not expose the rendered-size/center callbacks needed for the original effect, and a value-only wrapper cannot reproduce its end bounce. The user also requires untouched hosted 5.0.0 switch defaults.

**How to apply:** Keep app slider imports on the companion's narrow slider barrel; keep switches on hosted `liquid_glass_easy`. Migrate only after a hosted API provides live thumb geometry and regression tests verify both ends, rubberband motion, gap, and release.
