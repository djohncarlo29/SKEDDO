---
name: Modal scroll-edge extent and clipping
description: The top scroll-under effect's extent and sheet-boundary clipping.
---

For modal scroll-under effects, derive both the top fade and blur extent from the scroll view's actual resting top content inset. They must both reach zero exactly at the first content card's top edge; do not use a fixed transition tail. Clip the effect with the containing sheet's actual top shape, including transparent corner cutouts. Popup sheets with a different radius must pass their own shape. On Android's shaderless fallback, do not use one constant-sigma blur under a gradient mask: that fades the blur but does not reduce its strength toward the first-card edge. Approximate the spatial ramp with enough thin clipped blur zones that the individual strength steps are visually indistinct.

**Why:** A short or independently tuned fade/blur stops before the first card, while an unclipped backdrop filter can paint into the transparent rounded corners. A single native backdrop filter has one sigma per region, so its mask cannot create a gradual change in blur strength; coarse bands look stepped. On Android, keep the scroller outside the effect clip so the blur can sample its content.

**How to apply:** Keep the measured first-content position as the single source for both fade and blur. Put only the full-size edge-effect overlay inside a `ClipPath` using the parent sheet's `ShapeBorder`; pass a custom shape for popups with a different radius.