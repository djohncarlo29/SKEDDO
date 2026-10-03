---
name: Modal scroll-edge extent and clipping
description: The top scroll-under effect's extent and sheet-boundary clipping.
---

For modal scroll-under effects, derive both the top fade and blur extent from the scroll view's actual resting top content inset. They must both reach zero exactly at the first content card's top edge; do not use a fixed transition tail. Clip the effect with the containing sheet's actual top shape, including transparent corner cutouts. Popup sheets with a different radius must pass their own shape. On Android's shaderless fallback, use one modest top blur with a continuous smoothstep-like opacity mask instead of separately clipped sigma bands; visible band seams are worse than a gradual fade of one blur radius. Keep the peak top sigma slightly below the shared maximum.

**Why:** A short or independently tuned fade/blur stops before the first card, while an unclipped backdrop filter can paint into the transparent rounded corners. Android's separate blur bands showed visible horizontal seams even at high counts; a continuous mask avoids those seams and provides a smooth visual transition, though it fades one radius rather than varying the kernel per pixel. On Android, keep the scroller outside the effect clip so the blur can sample its content.

**How to apply:** Keep the measured first-content position as the single source for both fade and blur. Put only the full-size edge-effect overlay inside a `ClipPath` using the parent sheet's `ShapeBorder`; pass a custom shape for popups with a different radius. If Android later supports a reliable spatial image-filter shader, it can replace the masked fallback without changing the shared extent.