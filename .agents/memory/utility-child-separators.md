---
name: Utility child separators
description: Separator ownership for category blocks and child events in Archived Items and Recently Deleted.
---

In utility category blocks with child events, the final child event owns the separator before the next utility item. The category wrapper must not add another separator at that boundary. The wrapper still owns the boundary when the category has no children.

**Why:** Both the grouped event card and the utility category wrapper previously painted the same 0.5px line, making the boundary appear darker and doubled.

**How to apply:** When changing `_DcvUtilityContent` row composition, keep exactly one separator owner for each boundary: child cards for child-to-child and final-child boundaries, wrapper rows for standalone category boundaries.