---
name: Category preview ball gradient
description: Soccerball category previews must match the Card 1 circle's per-swatch additive highlight.
---

The large Card 1 soccerball preview uses the same top-to-bottom `BlendMode.plus`
highlight profile as its surrounding category circle. Yellow, Teal, and Sand use
the reduced lift; all other category swatches use the standard lift, including
both light and dark resolved ARGB values.

**Why:** A flat soccerball fill looks inconsistent with the gradient visible on
the preview circle, while one generic opacity makes bright swatches too white.

**How to apply:** Keep the per-swatch highlight lookup shared by the circle
painter and soccerball mask. The soccerball shader must use the full preview
circle as its coordinate extent, sampling the circle's middle segment at the
icon's centered bounds. Preserve the soccerball's transparent detail areas and
outline color; only its category-colored artwork receives the gradient.