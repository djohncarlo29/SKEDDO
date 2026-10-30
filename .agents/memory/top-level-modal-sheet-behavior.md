---
name: Top-level modal sheet behavior
description: Product decision for how standalone sheets and nested subsheets stack over the Smart Scheduler app.
---

Top-level modal sheets leave the AppShell at full size and in its original position. In Light Mode, a single open parent sheet dims only the AppShell with ARGB `0x80A8A8A3` using `BlendMode.multiply`; do not apply that tint to the sheet. Nested subsheets continue to dim and stack their parent sheet. Parent sheets and nested subsheets both rest exactly 10px below the top safe-area inset.

**Why:** The user requires the specified Multiply tint on the AppShell behind a single Light Mode parent sheet, while keeping the sheet itself untinted and preserving a consistent physical top gap for every sheet.

**How to apply:** Keep the top-level AppShell’s delegated dim transition separate from the parent sheet’s nested secondary transition. Preserve the AppShell’s size and position; use the exact tint and Multiply mode only in Light Mode, and retain existing Dark Mode and nested-sheet dim behavior. Compute both route top offsets from `viewPadding.top + 10px`.

## Stable AppShell dim layer

Keep top-level sheet dimming in a permanently mounted AppShell layer. Animate only its filter value; do not add and remove a `ColorFiltered` wrapper around the entire AppShell through a route delegated transition.

**Why:** Adding and removing that wrapper at sheet dismissal can detach and reparent the DCV scroll/render subtree, leaving its content blank or disturbing its scroll and header state.

**How to apply:** Let the sheet route publish its top-level dim progress to the AppShell's stable dimmer. Nested sheets continue to dim their parent sheet independently. Preserve the sheet tint and keep the parent screen's widget tree, header state, and scroll controllers mounted throughout presentation and dismissal.
