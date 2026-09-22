---
name: Smart category circle numbers
description: Scope of the Events smart-category number alignment adjustment.
---

The Today, Tomorrow, This Week, and Next Week numbers keep the original sizing
in the small Events-tab grid circles, while the Edit Category Card 1 preview
and Detailed Category View empty-state icon use a centered sub-1 px reduction.

**Why:** The grid badge is already visually calibrated, while the larger modal
preview and detail placeholder need the smaller centered number treatment.

**How to apply:** Keep the shared calendar helper's defaults for the grid tile
and drag ghost. Pass the reduced scale only from the modal preview, and mirror
it in the four date-based empty-state icons.

The calendar frame and day badge must be composed at authored coordinates and
fitted together as one final-sized visual unit. Keep the normal Text renderer;
the fitting boundary is the important part.

**Why:** A shared Transform around a child with default-size layout bounds did
not reliably produce the same final coordinate space as the scaled tile.

**How to apply:** Share the authored calendar composition between the in-grid
tile, lifted-card renderer, and modal preview; keep the badge on
TextScaler.noScaling, then fit the complete composition to its scaled bounds.