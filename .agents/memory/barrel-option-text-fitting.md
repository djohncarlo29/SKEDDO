---
name: Barrel option text fitting
description: Project-wide scope and sizing rule for custom barrel-wheel option labels.
---

Apply shrink-to-fit behavior to every option in every app-authored barrel-wheel picker, not only the ordinal/day pickers. Keep at least 8 logical pixels of inset at both selection-bar edges (preserving any larger existing inset), use the actual wheel-column width, and preserve the active OS text scaler while shrinking labels to fit.

**Why:** The user explicitly requires this for all barrel-wheel options: labels must not approach or cross either selection-bar edge, and must stay inside a fixed 8dp safe inset.

**How to apply:** Keep `WheelOptionText` as the shared rendering primitive and enforce the 8dp minimum inset there, taking the larger of 8dp and any caller-provided inset on each side. Pass each wheel's measured column width as its fallback wherever wheel-child constraints are unbounded; preserve magnification, column spacing, and native picker behavior.