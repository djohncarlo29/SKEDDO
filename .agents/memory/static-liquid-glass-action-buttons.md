---
name: Static Liquid Glass controls
description: Rendering boundary for fixed-color action circles and simple non-interactive cards.
---

Fixed-color action circles and simple non-interactive cards have separate rendering policies. Action circles use the original LiquidGlassButton/LiquidGlassLens Impeller path when visual fidelity is the priority; cards remain non-interactive and use the cheaper live-backdrop surface path. Action circles retain their existing bloom and tap timing.

**Why:** The action-circle reference depends on the original optical rim and lens response, which the package’s Impeller path supplies. A frosted fallback is cheaper but visibly changes the material and is not an acceptable substitute when the original appearance is required.

**How to apply:** Use the package-backed action-button component for xmark, checkmark, and chevron circles. Keep the full dynamic glass pipeline for the Floating Tab Bar, LiquidGlassSwitch, LiquidGlassSlider, and other controls whose appearance depends on live optical rendering; use the hybrid surface only for simple cards.