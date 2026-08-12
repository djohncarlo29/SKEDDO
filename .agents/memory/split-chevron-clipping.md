---
name: Split Cupertino picker chevron clipping
description: How to separate the standard up/down picker glyph without changing its weight or footprint.
---

Picker chevrons must keep the original Cupertino glyph and render its upper and
lower halves in separate clipped viewports. The lower viewport needs the source
glyph translated by `-half + lowerOffset`; `lowerOffset` is then the visible
downward separation.

**Why:** translating the glyph directly inside the lower viewport exposes the
wrong half or moves the crop rather than the lower chevron itself.

**How to apply:** preserve the fixed glyph box and horizontal scale, clip each
half independently, and use a 1 logical-pixel `lowerOffset` for the app's
picker rows.