---
name: Modal scroll-edge extent and clipping
description: The top scroll-under effect's extent, sheet clipping, and transition compositing.
---

For modal scroll-under effects, derive both the top fade and blur extent from the scroll view's actual resting top content inset. They must both reach zero exactly at the first content card's top edge; do not use a fixed transition tail. Clip the effect with the containing sheet's actual top shape, including transparent corner cutouts. Popup sheets with a different radius must pass their own shape. Keep the scroller outside that clip so the backdrop filter can sample its content.

Keep `LiquidGlassScrollEdge` on its default `srcOver` composition. A transition-level `ColorFiltered` layer can make its backdrop blur disappear or render incorrectly. When one rounded modal sheet covers another, put the sibling dim overlay inside the sheet's primary slide and rounded clip. Do not put it beside an already-transitioned child: that makes its full-screen bounds start at viewport y=0 instead of at the sheet's visible top. Keep the top-level app-page dim alpha-aware (`srcATop`) so it does not tint transparent status-bar gaps.

**Why:** A short or independently tuned fade/blur stops before the first card, while an unclipped backdrop filter can paint into transparent rounded corners. The edge blur is sensitive to ancestor compositing, and route transitions have separate primary and secondary transforms; a sibling scrim outside the primary slide covers the status-bar gap above the sheet.

**How to apply:** Use the measured first-content position as the single source for both fade and blur. Put only the full-size edge-effect overlay inside a `ClipPath` using the parent sheet's `ShapeBorder`; pass a custom shape for popups with a different radius. Place covered-sheet dimming inside the primary slide and clip before applying the secondary transform. Keep the scroll-edge widget outside any transition `ColorFiltered` ancestor. Test a real nested-sheet push and verify the dim overlay top matches the sheet top, the backdrop filter remains `srcOver`, and the top-level app dim path remains alpha-aware.