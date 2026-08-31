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

The calendar frame and day badge must be composed at their authored circle size
and transformed once as a unified visual unit. Separately scaling the frame,
Positioned top, and font size causes the badge to drift inside the frame.

**Why:** The overlay inherits the device text scale independently of the
fixed-position badge geometry, which changes the measured glyph height and
shifts the day number inside the calendar circle.

**How to apply:** Share the unified calendar composition between the in-grid
tile and lifted-card renderer; keep the badge text on `TextScaler.noScaling`
inside that transformed unit.