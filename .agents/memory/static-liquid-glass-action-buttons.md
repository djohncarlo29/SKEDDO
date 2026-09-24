---
name: Static Liquid Glass controls
description: Rendering boundary for fixed-color action circles and simple non-interactive cards.
---

Fixed-color action circles and simple non-interactive cards do not need live backdrop capture, blur, magnification, refraction, or chromatic aberration. Keep their Liquid Glass identity with a bounded translucent directional fill, rim, highlight, and contact treatment. Action circles retain their existing bloom and tap timing; cards have no gesture or tap layer.

**Why:** These controls never need to reveal moving content behind them, so the full optical lens pipeline spends rendering work on effects users cannot meaningfully observe.

**How to apply:** Use the static action-button component for xmark, checkmark, and chevron circles, and the static surface component for simple cards. Keep the full dynamic glass pipeline for the Floating Tab Bar, LiquidGlassSwitch, LiquidGlassSlider, and any future control whose purpose depends on live backdrop optics.