---
name: Day View week-strip positioning
description: Align the selected Month row, DOW header, and Day Banner in expanded and compact Calendar Day View.
---

In settled Calendar Day View, the selected week strip must use the shell's shared header coordinates, not remain in the Month grid's nested scroll viewport. Keep the Month-owned row for the collapse animation, then hand off to one Day-owned strip directly below the DOW mask and above the Day Banner.

**Why:** The Month grid's nested title inset and viewport clip can leave its row at a stale vertical origin while the Day DOW and banner follow the shell's live expanded/compact state. Widget-box alignment alone did not prove that the date cells were painted.

**How to apply:** Preserve the in-grid row through Month↔Day animation; at the settled Day handoff, hide that copy and render the selected week in the Day header stack. Test both expanded and compact shell states and assert the rendered strip has no Month viewport clip ancestor.
