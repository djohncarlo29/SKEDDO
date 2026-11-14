---
name: Glass menu selection behavior
description: Menu selection, scale, and rubberband interaction rules
---

`GlassBarItem.menu`, modal picker `GlassMenu`, and long-press context menu rows show a temporary active-row tint and 0.98× scale during touch or glide selection. Light Mode uses black at 8% opacity; Dark Mode uses white at 6%. Semantic selection remains separate from this transient state. All use the shared 2pt row gap; adaptive highlights clear immediately when the pointer moves to another row so only one pill is visible. Overflow scrolling clears the glide highlight when scrolling begins; fitting menus retain slide-to-select and highlight the row under the finger.

**Why:** The user explicitly changed the earlier no-pill behavior and requested one consistent selection highlight across these three menu paths.

**How to apply:** Keep the adaptive tint, 0.98× active-row scale, and shared row gap on the toolbar menu, modal picker menu, and long-press context menu. Clear the prior active pill immediately on row changes. Keep actual selected values independent, preserve normal taps and slide selection, and do not turn overflow scrolling into glide activation.
