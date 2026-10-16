---
name: Landscape Events master-detail geometry
description: Keep the Events master pane portrait-width and animate the floating tab bar to its center only while its landscape DCV split is active.
---

The landscape Events master pane begins at the physical left edge, but its content receives the shared horizontal safe-area inset on the left. Set the pane width to the portrait short-edge content width plus exactly one shared inset, leaving the content itself equal to portrait width. Use that same pane width when calculating whether the detail pane fits.

While the landscape Events DCV split is active, offset the shared floating tab bar from the screen center to the actual master-pane center. Animate both the glass bar and its separate shadow together. Returning to another tab or leaving the split targets the normal screen center.

**Why:** The safe-area padding otherwise makes the visible master content narrower than the portrait layout. Centering navigation against the whole landscape screen also leaves it floating between the two panes instead of over the Events pane.

**How to apply:** Derive the inset from `AppWindowContentScope`; don't add both left and right insets to the master pane. Drive the tab-bar offset from the same split-active condition used by the Events layout so it returns automatically when the pane split is inactive.
