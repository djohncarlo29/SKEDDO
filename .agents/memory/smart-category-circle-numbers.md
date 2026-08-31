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
fitted together as one final-sized visual unit. A separately laid-out Text
widget inside a transformed box can still rasterize its baseline lower at
non-default text sizes.

**Why:** Flutter paragraph layout and the SVG can land on different fractional
coordinates when the OS text scaler changes, even when both are wrapped in a
shared Transform.scale.

**How to apply:** Share the authored calendar composition between the in-grid
tile, lifted-card renderer, and modal preview; paint the no-scaling badge at
authored coordinates, then fit the complete composition to its scaled bounds.