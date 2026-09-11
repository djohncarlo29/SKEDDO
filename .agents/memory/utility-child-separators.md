---
name: Utility child separators
description: Separator ownership for category blocks and child events in Archived Items and Recently Deleted.
---

In utility category blocks with child events, the utility wrapper emits every child boundary separator as a full-width row outside the child-event indentation. The category wrapper must not add a second separator after the final child. The wrapper also owns the boundary when the category has no children.

**Why:** Both the grouped event card and the utility category wrapper previously painted the same 0.5px line, making the boundary appear darker and doubled. Keeping separator rows outside the child inset prevents the line from becoming indented.

**How to apply:** When changing `_DcvUtilityContent` row composition, keep exactly one separator owner for each boundary, and render utility separator rows at the category card's full width. Only event content should be indented.