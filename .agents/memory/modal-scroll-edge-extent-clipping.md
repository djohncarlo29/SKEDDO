---
name: Modal scroll-edge extent and clipping
description: The top scroll-under effect's extent, sheet clipping, and transition compositing.
---

For modal scroll-under effects, derive both the top fade and blur extent from the scroll view's actual resting top content inset. They must both reach zero exactly at the first content card's top edge; do not use a fixed transition tail. Clip the effect with the containing sheet's actual top shape, including transparent corner cutouts. Popup sheets with a different radius must pass their own shape. Keep the scroller outside that clip so the backdrop filter can sample its content. Because a covering rounded sheet applies `ColorFiltered` to its outgoing route, set the scroll-edge `BackdropFilter` blend mode to `BlendMode.src` in this modal context.

**Why:** A short or independently tuned fade/blur stops before the first card, while an unclipped backdrop filter can paint into the transparent rounded corners. Flutter documents that `srcOver` can produce surprising results when a parent creates a temporary compositing layer; the rounded-sheet cover transition uses such a `ColorFiltered` layer, and the edge blur can disappear or break without `src`.

**How to apply:** Keep the measured first-content position as the single source for both fade and blur. Put only the full-size edge-effect overlay inside a `ClipPath` using the parent sheet's `ShapeBorder`; pass a custom shape for popups with a different radius. Preserve `BlendMode.src` for edge blurs under sheet transitions and keep a regression test with an ancestor `ColorFiltered`.