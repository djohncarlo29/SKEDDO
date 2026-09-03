---
name: Emoji category selection repaint
description: Selection rendering for variation-selector emoji in the category strip.
---

Category-tab selection must keep the scroll target separate from the painted
emoji subtree. Variation-selector color emoji such as the heart need a real
Opacity layer for dimming, but that painted subtree must be replaced as a whole
when selection changes.

**Why:** The picker could switch its grid data correctly while one or more old
tab layers continued to look selected after navigating away from them.

**How to apply:** Use a stable, non-painted GlobalKey target for
ensureVisible, and put a selection-dependent key around the complete painted
tab. Keep Opacity around the emoji text because platform color emoji may ignore
alpha in TextStyle.color.