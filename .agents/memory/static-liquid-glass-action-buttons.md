---
name: Static Liquid Glass controls
description: Rendering boundary for fixed-color action circles and simple non-interactive cards.
---

Fixed-color action circles and simple non-interactive cards share the historical app-owned LiquidGlassView + LiquidGlassLens composition. Actions retain bloom and tap timing; surfaces omit touch, gestures, and bloom.

**Why:** The action-circle reference depends on app-specific capture, squircle, rim, shadow, and clipping values that package defaults do not reproduce. A frosted fallback or package-default button is visibly different and is not an acceptable substitute when the original appearance is required.

**How to apply:** Start from the historical action-button block in git when changing these optics; remove only explicitly requested effects and preserve its capture/view, squircle, optical border, shadow, hairline, and clip structure. Build the shared static lens style directly rather than copying `LiquidGlassButton.defaultStyle`, so action shadows cannot leak into surfaces; pass app-owned `BoxShadow` values outside the lens. Non-interactive surfaces using `LiquidGlassView` need intrinsic-height sizing when their parent gives loose height constraints, and should let the package choose its supported backend instead of forcing legacy capture. Keep the full dynamic glass pipeline for the Floating Tab Bar, LiquidGlassSwitch, LiquidGlassSlider, and other controls whose appearance depends on live optical rendering.