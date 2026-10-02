---
name: Landscape date picker width
description: Keep landscape date wheels compact and behaviorally consistent with portrait, including disabled dates and OS text scaling.
---

Landscape date-picker wheels should remain a centered group sized around their localized labels rather than spreading across all available width. Portrait stays on the native Cupertino picker.

Landscape must also preserve the native picker’s disabled-date behavior: disabled entries can pass through the selection bar while scrolling, do not update the date, and move back to a valid date after scrolling stops.

**Why:** Full-width distribution leaves excessive space between date values and can push scaled labels to the screen edges, while the portrait layout is already correct. The landscape wheels are custom-built, so visual parity alone does not preserve the native scrolling contract.

**How to apply:** Size the landscape group from the widest localized month, day, and year labels using the same text style and ambient scaler as the rendered wheels. Expand into the viewport only when those intrinsic widths no longer fit. Keep each wheel’s temporary selection state current during scrolling, then validate and correct the combined date when all wheels stop.