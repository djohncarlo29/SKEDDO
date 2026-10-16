---
name: Impeller screen-space glass geometry
description: Keep Impeller glass shader resolution aligned with FlutterView coordinates when app content MediaQuery is narrowed
---

Impeller liquid-glass shaders use full-window `FlutterFragCoord` values. Their
resolution uniforms must therefore use the actual FlutterView's full logical
size, even when a descendant `MediaQuery.size` has been narrowed to a landscape
safe-content rectangle. Preserve the live Impeller path; correct its coordinate
space instead of replacing the renderer.

**Why:** Mixing global lens positions with a narrower content resolution makes
the sampled backdrop shift or run out at a screen edge, which can also misalign
the selected glyph layer. Dark surfaces make the incorrect sample especially
visible against black.

**How to apply:** Read full-view dimensions from `MediaQueryData.fromView(View.of(context))`
for Impeller shader resolution. Keep captured Skia surfaces in their capture
view's local coordinate space.
