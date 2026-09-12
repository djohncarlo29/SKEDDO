---
name: Sheet scroll indicator anchoring
description: Overlay-sheet scroll pills must be anchored to the sheet surface, not the padded content viewport.
---

For shared overlay sheets, keep the sheet's authored content padding unchanged but place that padding inside the scrollable child. The scroll-pill Stack can then use `clipBehavior: Clip.none` with fixed 8 px top, bottom, and right insets against the sheet surface.

**Why:** Positioning the pill inside the padded viewport makes it look too far inward and prevents consistent sheet-edge alignment. Clipping the viewport also cuts off the requested edge clearance.

**How to apply:** Preserve the existing padding values inside `ActionPanelScrollView`, keep its overlay Stack unclipped, and anchor the pill with explicit 8 px edge positions.