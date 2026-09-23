---
name: Android glass interaction performance
description: Performance rule for shader-backed glass, blur, and delayed actions on Android.
---

On Android, frequent interactive controls should not depend on shader-backed backdrop captures or large animated blur radii. Prefer a bounded solid/translucent fallback for repeated controls, reduce backdrop sampling for larger surfaces, and fire the user action immediately rather than waiting for a decorative bloom.

**Why:** Android raster work from repeated glass captures, clipping, shadows, and animated blur can make taps feel ignored and gestures drop frames even in a release APK.

**How to apply:** Preserve the richer glass path for iOS, but give Android controls a low-cost path. Update periodic clocks only at the precision the UI displays; do not wake or rebuild a whole tab more often than necessary.