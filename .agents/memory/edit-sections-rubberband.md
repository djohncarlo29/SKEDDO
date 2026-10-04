---
name: Edit Sections rubberbanding
description: Desired scroll-edge behavior for the Edit Sections sheet's content area.
---

The Edit Sections sheet's content area should rubberband at its scroll edges, even when the current section list fits without scrolling. Keep this behavior scoped to the content area; fixed controls and reorder gestures should remain unchanged.

**Why:** The project owner requested the same native-style overscroll response used elsewhere in the app.

**How to apply:** Keep the outer vertical content list always scrollable with bouncing physics. Do not make the nested reorder list independently scrollable.