---
name: Liquid Glass color cache invalidation
description: Prevent stale optical rim colors when a cached Liquid Glass surface changes tint
---

One-shot `LiquidGlassView` captures must be invalidated when the resolved color of a small dynamic glass control changes. A tint rebuild alone updates the lens body but can leave the optical rim sampling the previous captured surface.

**Why:** Modal sheets can change category color while preserving the button widget state. With `realTimeCapture: false`, the old sheet/button color remains in the cached backdrop and appears as a colored artifact around the new checkmark button.

**How to apply:** Key the small `LiquidGlassView` by the resolved ARGB surface color so it remounts only on a color change; keep one-shot capture for unchanged controls instead of enabling continuous recapture globally.