---
name: Static Liquid Glass action buttons
description: Rendering boundary for fixed-color xmark, checkmark, and chevron circle controls.
---

Fixed-color action circles do not need live backdrop capture, blur, magnification, refraction, or chromatic aberration. Keep their Liquid Glass identity with a bounded translucent directional fill, rim, highlight, and contact treatment while preserving the existing bloom and tap timing.

**Why:** These controls never need to reveal moving content behind them, so the full optical lens pipeline spends rendering work on effects users cannot meaningfully observe.

**How to apply:** Use the static circle renderer for xmark, checkmark, and chevron action buttons only. Keep the full dynamic glass pipeline for the Floating Tab Bar, LiquidGlassSwitch, LiquidGlassSlider, and any future control whose purpose depends on live backdrop optics.