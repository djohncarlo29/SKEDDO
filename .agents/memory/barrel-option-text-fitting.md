---
name: Barrel option text fitting
description: Project-wide scope and sizing rule for custom barrel-wheel option labels.
---

Apply shrink-to-fit behavior to every option in every app-authored barrel-wheel picker, not only the ordinal/day pickers. Use the actual wheel-column width, preserve the active OS text scaler, and scale the rendered option down only when the magnified label would exceed its available selection-bar segment.

**Why:** The user explicitly corrected a narrow ordinal/day-only implementation; the requirement covers all options across the app's barrel-wheel picker families.

**How to apply:** Keep `WheelOptionText` as the shared rendering primitive. Pass each wheel's measured column width as its fallback wherever wheel-child constraints are unbounded; preserve existing edge insets, magnification, column spacing, and native picker behavior.