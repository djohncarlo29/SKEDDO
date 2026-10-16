---
name: Android dark landscape tab-bar fallback
description: Why the floating tab bar uses a single-lens renderer in Android landscape Dark Mode
---

On Android in landscape Dark Mode, render the floating tab bar with the regular
single-lens `LiquidGlassTabBar` path rather than the bodyless live-Impeller
two-layer path. Keep the current animated glass-pill renderer for other platform,
orientation, and theme combinations.

**Why:** The reported Android screenshots showed the active tab glyphs offset and
painted twice, along with a clipped trailing edge. The active icon shell is
painted in two coordinated layers for the live glass reveal, and this combination
can misalign those layers on the affected renderer/layout.

**How to apply:** Keep the fallback narrow to Android + landscape + Dark Mode.
The regular lens still preserves the glass bar and selected-tab styling; do not
replace the main bar with an opaque solid surface.
