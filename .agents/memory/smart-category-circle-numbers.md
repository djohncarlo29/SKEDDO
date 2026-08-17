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

The drag ghost is rendered in the global overlay, so its day-number Text must
also explicitly use `TextScaler.noScaling`; matching font size and position
alone is not enough when the device accessibility text scale is enlarged.

**Why:** The overlay inherits the device text scale independently of the
fixed-position badge geometry, which changes the measured glyph height and
shifts the day number inside the calendar circle.

**How to apply:** Any future change to the four calendar badge numbers must be
made in both the in-grid tile and the lifted-card renderer, including their
text-scaling policy.