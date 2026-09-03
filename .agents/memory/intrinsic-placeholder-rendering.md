---
name: Intrinsic placeholder rendering
description: Shared behavior for one-line placeholders that overflow or rubberband at text-field edges.
---

One-line placeholders are rendered at their intrinsic width inside the field viewport. They must use clipping rather than ellipsis, show the matching edge fade when clipped, and translate with the field's horizontal rubberband offset. Multiline placeholders are top-aligned, normally wrapped, and participate in the vertical rubberband/fade wrapper.

**Why:** Native placeholder ellipsizing hides the actual product copy and does not participate in the same edge treatment or rubberband motion as normal text.

**How to apply:** Route visible one-line placeholders through the shared horizontal edge-fade wrapper and visible multiline placeholders through the vertical wrapper; keep the native field placeholder empty and resolve the fade surface from the exact card/sheet behind the field.