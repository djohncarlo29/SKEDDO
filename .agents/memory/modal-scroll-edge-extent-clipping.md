---
name: Modal scroll-edge extent and clipping
description: The top scroll-under effect's extent and sheet-boundary clipping.
---

For modal scroll-under effects, derive both the top fade and blur extent from the scroll view's actual resting top content inset. They must both reach zero exactly at the first content card's top edge; do not use a fixed transition tail. Clip the effect with the containing sheet's actual top shape, including transparent corner cutouts. Popup sheets with a different radius must pass their own shape. The current shader path uses a smooth per-pixel falloff; the fallback used by Android and web keeps the top blur unmasked with a separate surface gradient, while the bottom blur uses a ShaderMask.

**Why:** A short or independently tuned fade/blur stops before the first card, while an unclipped backdrop filter can paint into the transparent rounded corners. Android's per-pixel shader path is disabled because it can render no visible effect on supported devices; the widget test also treats the unmasked top blur and full-strength top gradient as the fallback contract. Keep platform differences explicit rather than assuming the shader and fallback produce identical pixels.

**How to apply:** Keep the measured first-content position as the single source for both fade and blur. Put only the full-size edge-effect overlay inside a `ClipPath` using the parent sheet's `ShapeBorder`; pass a custom shape for popups with a different radius. Keep the scroller outside that clip so fallback BackdropFilters can sample its content. Any change to Android's top mask, opacity, or blur should be checked on-device and against the widget test.