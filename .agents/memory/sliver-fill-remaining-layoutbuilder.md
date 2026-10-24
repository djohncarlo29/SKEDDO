---
name: SliverFillRemaining and LayoutBuilder
description: Prevent intrinsic-size assertions when a remaining sliver contains responsive LayoutBuilders.
---

`SliverFillRemaining(hasScrollBody: false)` probes its child's intrinsic height. A descendant `LayoutBuilder` cannot answer that query, so a full-screen sliver containing responsive flex content can assert during layout.

**Why:** The emoji picker’s responsive grid hit this Flutter assertion when rendered in the widget test, even though the release web build completed.

**How to apply:** Before placing responsive `LayoutBuilder` or flex content under a non-scroll-body `SliverFillRemaining`, provide an intrinsic sizing boundary that still expands to the remaining viewport. Verify the viewport fill and scrolling behavior after the change.
