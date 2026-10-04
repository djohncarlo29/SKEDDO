---
name: Modal scroll-edge extent and clipping
description: The top scroll-under effect's extent, sheet clipping, and transition compositing.
---

For modal scroll-under effects, derive both the top fade and blur extent from the scroll view's actual resting top content inset. They must both reach zero exactly at the first content card's top edge; do not use a fixed transition tail. Clip the effect with the containing sheet's actual top shape, including transparent corner cutouts. Popup sheets with a different radius must pass their own shape. Keep the scroller outside that clip so the backdrop filter can sample its content.

Keep `LiquidGlassScrollEdge` on its default `srcOver` composition. A transition-level `ColorFiltered` layer can make its backdrop blur disappear or render incorrectly. Use a sibling dim overlay only when one rounded modal sheet covers another. Keep the top-level app-page dim alpha-aware (`srcATop`) so it does not tint transparent status-bar gaps.

**Why:** A short or independently tuned fade/blur stops before the first card, while an unclipped backdrop filter can paint into transparent rounded corners. The edge blur is sensitive to ancestor compositing, but a normal sibling scrim over a full-screen app page also paints into transparent gaps.

**How to apply:** Use the measured first-content position as the single source for both fade and blur. Put only the full-size edge-effect overlay inside a `ClipPath` using the parent sheet's `ShapeBorder`; pass a custom shape for popups with a different radius. Keep the scroll-edge widget outside any transition `ColorFiltered` ancestor. Test a real nested-sheet push and verify the backdrop filter remains `srcOver`, has no `ColorFiltered` ancestor, and the top-level app dim path remains alpha-aware.