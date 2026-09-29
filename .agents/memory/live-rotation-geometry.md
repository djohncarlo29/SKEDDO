---
name: Live rotation geometry
description: Cross-platform portrait↔landscape picker morphing must follow live Flutter window metrics.
---

Use the changing Flutter window size as the shared rotation progress signal. Anchor portrait and landscape endpoint geometry from the last settled window, derive progress by projecting the live size between those endpoints, and interpolate complete picker rect models per frame.

**Why:** Flutter does not provide a usable cross-platform fractional rotation callback to the layout tree, and timer-based 280ms transitions desynchronize parent heights, child slots, and glyph constraints.

**How to apply:** Keep rotation geometry separate from sheet routes and user gestures. During metrics transitions, render direct interpolated positions and sizes; reserve implicit/explicit reflow animations for non-rotation interactions.