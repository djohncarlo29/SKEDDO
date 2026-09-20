---
name: Independent Multi-Day circles
description: Keep today and adjacent Multi-Day markers visually identical to the selected circle while their centers move during horizontal drags.
---

Render the fixed today marker and moving adjacent Multi-Day marker as separate circles at the authored diameter, using the dedicated exact Light/Dark marker pair for the active accent swatch, and the selected circle’s text and shape styling. During a swipe, translate their centers only; never suppress either marker when their bounds overlap, paint them as one union shape, or apply a scale to their marker layer.

**Why:** Multi-Day today and adjacent markers are intentionally full-opacity peers of the selected circle with a separate contrast palette for each accent swatch, and must remain visible through overlap; a shared opaque union would still make them read as one wider shape as the moving marker approaches today, even when each mathematical radius is unchanged.

**How to apply:** Keep both markers in the normal day-circle render tree with fixed-size enabled and the exact selected-circle color/text treatment. The selected marker may translate independently, while today and the adjacent marker retain their own circle bounds.