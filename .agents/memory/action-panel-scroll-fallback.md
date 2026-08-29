---
name: Action-panel scroll fallback
description: Safe-area scrolling and live row anchoring for full-size action menus
---

## Rule
Every full-size action menu should use the shared ActionPanel overflow treatment: bounded content, edge fades, and a transient scroll indicator. Expandable menus must also position their connected sub-panel from the main panel's live scroll offset.

**Why:** A long menu can exceed the available safe-area height, and a user may scroll before opening an expandable row. A static row position makes the drill-down detach from the row that was tapped.

**How to apply:** Pass a max height derived from the chosen safe-area side into the main and sub ActionPanel instances. If the main panel can scroll, publish its offset and subtract that offset when positioning the expandable sub-panel and shared trigger row.

When an expandable sub-panel's maxHeight changes as its parent scrolls, resync
both fade flags from the current ScrollMetrics after layout. Do not infer the
bottom fade from overflow alone, because the sub-panel may already be settled
at its maximum offset.

**Why:** A dynamic viewport update can call didUpdateWidget without changing the
scroll offset, leaving a stale bottom fade visible after the nested panel has
reached its end.