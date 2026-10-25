---
name: Day View week-strip positioning
description: Align the selected Month row, DOW header, and Day Banner in expanded and compact Calendar Day View.
---

In settled Single/Multi Day View, the selected week strip must use the shell's shared header coordinates, not remain in the Month grid's nested scroll viewport. Keep Month panels through the Month↔Day animation so their rows share the collapse progress; once Day settles, remove the Month panel layer and leave one Day-owned DOW row and strip. On reverse, remount the Month layer as that same collapse progress starts.

**Why:** The Month grid's nested title inset and viewport clip can leave its row at a stale vertical origin while the Day DOW and banner follow the shell's live expanded/compact state. Leaving the Month layer under settled Day also leaks neighboring week rows and duplicates the DOW line.

**How to apply:** Apply this only to Single/Multi Day, not List Day. Preserve Month rows during the transition, then remove the full Month panel at settled Day; render the selected week in the Day header stack. Test expanded and compact headers, one DOW, absence of Month panels at rest, and Month-panel return during reverse.
