---
name: Year View fit spacing
description: Portrait Year View spacing when all month groups fit or overflow the viewport.
---

When all portrait Year View month groups fit, keep the first group's 16pt title gap and the last group's 16pt tab-bar gap, distributing any remaining height evenly across the three inter-group gaps. If the content overflows, each inter-group gap stays at the 16pt minimum.

**Why:** A fixed 16pt gap leaves unused space at the bottom on fitting layouts, while increasing the first or last gap would break the user's requested anchors.

**How to apply:** Keep this behavior portrait-only. Preserve measured row positions for Year↔Month morphs; landscape keeps its existing spacing.
