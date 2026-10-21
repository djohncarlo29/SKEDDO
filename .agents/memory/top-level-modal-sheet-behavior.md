---
name: Top-level modal sheet behavior
description: Product decision for how standalone sheets and nested subsheets stack over the Smart Scheduler app.
---

Top-level modal sheets leave the AppShell at full size and in its original position. In Light Mode, a single open parent sheet dims only the AppShell with ARGB `0x80A8A8A3` using `BlendMode.multiply`; do not apply that tint to the sheet. Nested subsheets continue to dim and stack their parent sheet. Parent sheets and nested subsheets both rest exactly 10px below the top safe-area inset.

**Why:** The user requires the specified Multiply tint on the AppShell behind a single Light Mode parent sheet, while keeping the sheet itself untinted and preserving a consistent physical top gap for every sheet.

**How to apply:** Keep the top-level AppShell’s delegated dim transition separate from the parent sheet’s nested secondary transition. Preserve the AppShell’s size and position; use the exact tint and Multiply mode only in Light Mode, and retain existing Dark Mode and nested-sheet dim behavior. Compute both route top offsets from `viewPadding.top + 10px`.
