---
name: Static Liquid Glass controls
description: Rendering boundary for fixed-color action circles and simple non-interactive cards.
---

Fixed-color action circles and simple non-interactive cards do not need magnification, refraction, or chromatic aberration, but a completely opaque painted fallback loses the premium depth. Use one bounded low-sigma live backdrop blur plus translucent directional fill, rim, highlight, and contact treatment. Action circles retain their existing bloom and tap timing; cards have no gesture or tap layer.

**Why:** These controls benefit from live background depth, but the full optical lens pipeline spends rendering work on magnification, refraction, and chromatic effects users do not need to observe. The hybrid path preserves the material cue at lower cost.

**How to apply:** Use the hybrid action-button component for xmark, checkmark, and chevron circles, and the hybrid surface component for simple cards. Keep the full dynamic glass pipeline for the Floating Tab Bar, LiquidGlassSwitch, LiquidGlassSlider, and any future control whose purpose depends on magnified or refracted backdrop optics.