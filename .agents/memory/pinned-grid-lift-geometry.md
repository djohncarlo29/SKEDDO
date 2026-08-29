---
name: Pinned grid lift geometry
description: Grid tiles can be half-width or full-width at lift time and must keep that exact geometry throughout a reorder gesture.
---

## Rule
Capture the dragged tile’s rendered width, height, top-left, and grab offset from the current grid geometry on pointer-down. Keep those dimensions and the raw finger-relative position fixed throughout the gesture; only the normal post-release layout may apply the destination slot’s dimensions.

**Why:** Recomputing width from the live target slot makes a full-width tile collapse into a half-width ghost while the finger is still down, which breaks the visual identity of the lifted card.

**How to apply:** Use the actual `_GridItemGeometry` for both the in-grid placeholder and global overlay. Use half-width column pitch only for target-slot detection, never as the lifted card’s fallback geometry.