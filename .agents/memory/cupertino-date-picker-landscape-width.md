---
name: Landscape date picker width
description: Keep landscape date wheels compact and behaviorally consistent with portrait, including disabled dates and OS text scaling.
---

Landscape date-picker wheels stay as a centered, narrow group sized to their localized labels. Preserve the existing spacing between month, day, and year columns; do not spread them across the full selection-bar width. Portrait stays on the native Cupertino picker.

Landscape must also preserve the native picker’s disabled-date behavior: disabled entries can pass through the selection bar while scrolling, do not update the date, and move back to a valid date after scrolling stops.

**Why:** The user explicitly clarified that only clipping should change: the landscape columns must keep the same compact, label-sized spacing as the reference, even though the selection overlay spans the sheet. Clipping comes from the option text not keeping its 8dp safe inset after picker magnification; widening the group is not an acceptable fix.

**How to apply:** Size each landscape column from its widest localized label at the active text scale plus the magnification-adjusted 8dp insets, then center the compact group. Keep labels inside each column using the shared `WheelOptionText` fit region; do not change group spacing to solve clipping. Keep each wheel’s temporary selection state current during scrolling, then validate and correct the combined date when all wheels stop.