---
name: Static Liquid Glass controls
description: Rendering boundary for fixed-color action circles and simple non-interactive cards.
---

Fixed-color action circles and simple non-interactive cards have separate rendering policies. Action circles use the historical app-owned LiquidGlassView + LiquidGlassLens composition when visual fidelity is the priority; cards remain non-interactive and use the cheaper live-backdrop surface path. Action circles retain their existing bloom and tap timing.

**Why:** The action-circle reference depends on app-specific capture, squircle, rim, shadow, and clipping values that package defaults do not reproduce. A frosted fallback or package-default button is visibly different and is not an acceptable substitute when the original appearance is required.

**How to apply:** Start from the historical action-button block in git when changing its optics; remove only explicitly requested effects and preserve its capture/view, squircle, optical border, shadow, hairline, and clip structure. Keep the full dynamic glass pipeline for the Floating Tab Bar, LiquidGlassSwitch, LiquidGlassSlider, and other controls whose appearance depends on live optical rendering; use the hybrid surface only for simple cards.