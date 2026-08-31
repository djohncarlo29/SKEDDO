---
name: Horizontal fade surface matching
description: Surface-color rule for horizontal text overflow fades.
---

The opaque end of a horizontal text fade must use the exact resolved color of the surface directly behind that text row. Generic app surfaces are not interchangeable with modal card surfaces, particularly in dark mode.

**Why:** a mismatched opaque gradient reads as a visible overlay instead of blending into the field or card.

**How to apply:** resolve the fade color at the row's build boundary from the same semantic surface used by the enclosing background; keep independent surfaces such as search bars on their own resolved color.