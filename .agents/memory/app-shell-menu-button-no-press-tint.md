---
name: App-shell hamburger/X pressed appearance
description: Press feedback behavior for the AppShell's LiquidGlassButton.
---

The AppShell hamburger/X keeps the same glass brightness when tapped. Remove
only its Material splash and pressed highlight; keep its normal glass styling,
menu actions, and tap behavior unchanged.

**Why:** The user wants the button to respond to taps without a darkening or
lightening flash.

**How to apply:** Scope transparent splash/highlight settings to this control,
not the app-wide Material theme or other LiquidGlassButtons.
