---
name: Landscape date picker width
description: Keep landscape date wheels full-width and behaviorally consistent with portrait, including disabled dates and OS text scaling.
---

Landscape date-picker wheels must span the full selection-bar width, with three equal-width columns. Each localized label uses the shared 8dp inset and shrinks to fit its own column after magnification; do not compact the group to intrinsic label widths. Portrait stays on the native Cupertino picker.

Landscape must also preserve the native picker’s disabled-date behavior: disabled entries can pass through the selection bar while scrolling, do not update the date, and move back to a valid date after scrolling stops.

**Why:** The compact intrinsic-width landscape group left too little room for off-axis barrel projection and clipped the month label even though the selection overlay was full-width. The user explicitly requires the wheels to use the full selection-bar area with only 8dp side insets and shrink-to-fit labels. The portrait layout is already correct.

**How to apply:** Split the available landscape selection-bar width evenly across the localized date-order columns and pass each actual wheel width to `WheelOptionText` as its fallback. Preserve the active OS text scaler, 8dp fixed insets, and shrink-to-fit behavior. Keep each wheel’s temporary selection state current during scrolling, then validate and correct the combined date when all wheels stop.