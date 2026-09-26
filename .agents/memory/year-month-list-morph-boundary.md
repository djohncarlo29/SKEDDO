---
name: Year↔Month List morph boundary
description: Keep Calendar List transition content positioned by the morph overlay and size its opacity boundary to actual list content.
---

The Calendar List branch of the Year↔Month morph must be a content-sized child of the overlay's `Positioned`. Do not put an unconstrained `Align` or viewport-sized transform inside the child before `Opacity`; Flutter can expand that layer to the full calendar viewport and produce a grey scrim over the outgoing Year View.

**Why:** The List transition embeds a DCV that can accept loose height constraints. A full-height alignment layer turns the List fade into a full-screen compositing layer, unlike Compact, Stacked, and Details.

**How to apply:** Compute the month-grid content origin in `_MorphOverlay`, pass the viewport/origin into the List morph widget for empty-state sizing, and keep `Opacity` directly around the intrinsic list/placeholder viewport.