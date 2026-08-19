---
name: Liquid Glass environmental shadows
description: Independent Light Mode shadows for translucent controls
---

Liquid Glass controls should disable the package's appearance-attached shadow and place a separate parent-level `LiquidGlassShadow` layer before the glass. This keeps the ring in the surrounding scene instead of letting the glass capture/refraction make it look like a dark tint inside the material. Use a broad low-opacity bar shadow plus a tighter active-lens shadow; the package's multiply compositing adapts naturally to the background.

**Why:** Shadows stored in a glass appearance are part of the captured material stack, which muddies transparency and makes the shadow appear seen through the glass rather than cast by it.

**How to apply:** Preserve the existing appearance color, blur, and refraction; remove only `appearance.shadow`, then size independent shadow parents to the visible control silhouette and place them below the glass in a local `Stack`. Suppress them in Dark Mode through the app's established brightness policy.