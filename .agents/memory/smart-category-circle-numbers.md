---
name: Smart category circle numbers
description: Scope of the Events smart-category number alignment adjustment.
---

The Today, Tomorrow, This Week, and Next Week numbers are adjusted only inside
their small Events-tab smart-category circles. Larger smart-category previews
and detail/empty-state icons retain their existing number placement.

**Why:** The user clarified that the movement is intended for the numbers in the
smart-category icon circles, and there alone.

**How to apply:** When tuning these numbers, change the main smart tile and its
matching drag ghost together, but leave the add/edit preview and detail
placeholder layouts unchanged.

The calendar frame and day badge must be composed at authored coordinates and
fitted together as one final-sized visual unit. Keep the normal Text renderer;
the fitting boundary is the important part.

**Why:** A shared Transform around a child with default-size layout bounds did
not reliably produce the same final coordinate space as the scaled tile.

**How to apply:** Share the authored calendar composition between the in-grid
tile, lifted-card renderer, and modal preview; keep the badge on
TextScaler.noScaling, then fit the complete composition to its scaled bounds.