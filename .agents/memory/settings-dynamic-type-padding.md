---
name: Settings Dynamic Type padding
description: Settings rows must own fixed 16px vertical insets outside their content so text scaling grows the row instead of consuming its breathing room.
---

Settings rows and controls should use content-driven sizing with 16px vertical padding applied by the row wrapper. Avoid fixed heights on the row itself when the child can scale with Dynamic Type.

**Why:** a fixed row height can force larger labels or controls to compete with the intended top and bottom breathing room, especially in option and color-picker screens.

**How to apply:** keep a minimum baseline only where needed, wrap fixed-size controls with the same 16px insets, and use the shared `BoundedSquircleStadiumBorder` for settings cards.