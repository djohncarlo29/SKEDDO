---
name: Year↔Month List morph boundary
description: Keep Calendar List transition content positioned by the morph overlay and size its opacity boundary to actual list content.
---

The Calendar List branch of the Year↔Month morph must be a content-sized child of the overlay's `Positioned`, continuously translated and scaled from the selected mini-month's lower edge into the settled Month List position. Do not put an unconstrained `Align` or viewport-sized transform inside the child before `Opacity`; Flutter can expand that layer to the full calendar viewport and produce a grey scrim over the outgoing Year View.

**Why:** The List transition embeds a DCV that can accept loose height constraints. A full-height alignment layer turns the List fade into a full-screen compositing layer, unlike Compact, Stacked, and Details.

**How to apply:** Compute both the mini-month and settled content origins in `_MorphOverlay`, interpolate the child transform for the full `t=0..1` morph, pass the settled origin into the List widget for empty-state sizing, and keep `Opacity` directly around the intrinsic list/placeholder viewport.