---
name: Split-pane content sizing
description: Preserve portrait responsive spacing and row measurements when content is constrained to one side of a landscape split.
---

Responsive content in a split pane must use the pane's usable width for text wrapping, row heights, columns, and other width-derived geometry. Wrap that content in `AppWindowPaneContent`; `AppWindowContentPadding` intentionally keeps `MediaQuery.size` at app-window width for full-window transitions and overlays. Keep authored portrait gaps and insets unchanged.

**Why:** The landscape Events master pane was visually clipped to portrait width while its rows measured themselves against the full landscape MediaQuery width. Wrapped subtitles therefore occupied more lines than their fixed row heights reserved.

**How to apply:** Use `AppWindowPaneContent` inside a width-constrained pane, selecting the shared system insets that pane owns. Keep full-window transition layers under `AppWindowContentPadding` and use render-box measurements for drag geometry.
