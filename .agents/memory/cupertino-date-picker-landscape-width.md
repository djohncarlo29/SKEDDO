---
name: Landscape date picker width
description: Keep landscape date wheels compact while preserving portrait behavior and OS text scaling.
---

Landscape date-picker wheels should remain a centered group sized around their localized labels rather than spreading across all available width. Portrait stays on the native Cupertino picker.

**Why:** Full-width distribution leaves excessive space between date values and can push scaled labels to the screen edges, while the portrait layout is already correct.

**How to apply:** Size the landscape group from the widest localized month, day, and year labels using the same text style and ambient scaler as the rendered wheels. Expand into the viewport only when those intrinsic widths no longer fit.