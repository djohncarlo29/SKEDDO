---
name: Smart category circle numbers
description: Scope of the Events smart-category number alignment adjustment.
---

The Today, Tomorrow, This Week, and Next Week date numbers stay proportional
without vertical stretching in both the Events-tab grid circles and the Edit
Category Card 1 preview. Keep the modal's centered, slight size reduction.

**Why:** The date should read as a normal numeral rather than an elongated
glyph; the modal preview is intentionally a little smaller than the grid.

**How to apply:** Keep the shared calendar helper's default vertical scale at
1.0 for the grid tile and drag ghost. Pass the same slight reduction on both
axes only from the modal preview. Do not infer this sizing choice for separate
empty-state icons.

The calendar frame and day badge must be composed at authored coordinates and
fitted together as one final-sized visual unit. Keep the normal Text renderer;
the fitting boundary is the important part.

**Why:** A shared Transform around a child with default-size layout bounds did
not reliably produce the same final coordinate space as the scaled tile.

**How to apply:** Share the authored calendar composition between the in-grid
tile, lifted-card renderer, and modal preview; keep the badge on
TextScaler.noScaling, then fit the complete composition to its scaled bounds.