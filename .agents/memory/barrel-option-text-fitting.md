---
name: Barrel option text fitting
description: Project-wide scope and sizing rule for custom barrel-wheel option labels.
---

Apply shrink-to-fit behavior to every option in every app-authored barrel-wheel picker. Use exactly an 8 logical-pixel safe inset on both sides, with no caller-supplied larger inset or stacked horizontal padding. Measure against the actual wheel-column width, preserve the active OS text scaler, and shrink oversized labels instead of clipping them.

**Why:** The user explicitly corrected the earlier larger-inset behavior: labels should have only the fixed 8dp inset, and the previous accumulation of wheel-group narrowing, caller insets, and padding made labels too small and too far from the selection-bar edges. A width limit alone is insufficient: aligning the fit box to a wheel edge before magnification can place the rendered text outside that edge.

**How to apply:** Keep `WheelOptionText` as the shared rendering primitive and enforce the fixed 8dp inset there without an override parameter. Center the `(columnWidth - 16) / magnification` fit region before the wheel transform, then align text within that region; this keeps the rendered safe area inset on both sides. Pass each wheel's measured column width as its fallback wherever wheel-child constraints are unbounded. Remove extra horizontal padding and pill-edge clips that can shrink or cut the fitted text; preserve magnification, off-axis behavior, and native picker interactions.