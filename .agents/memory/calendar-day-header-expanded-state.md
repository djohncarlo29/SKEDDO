---
name: Day View week-strip positioning
description: Align the selected Month row, DOW header, and Day Banner in expanded and compact Calendar Day View.
---

In settled Single/Multi Day View, the selected week strip must use the shell's shared header coordinates, not remain in the Month grid's nested scroll viewport. Keep Month panels through the Month↔Day animation so their rows share the collapse progress; once Day settles, remove the Month panel layer and leave one Day-owned DOW row and strip. On reverse, remount the Month layer as that same collapse progress starts.

**Why:** The Month grid's nested title inset and viewport clip can leave its row at a stale vertical origin while the Day DOW and banner follow the shell's live expanded/compact state. Leaving the Month layer under settled Day also leaks neighboring week rows and duplicates the DOW line.

**How to apply:** Apply this only to Single/Multi Day, not List Day. Preserve Month rows during the transition, then remove the full Month panel at settled Day; render the selected week in the Day header stack. Test expanded and compact headers, one DOW, absence of Month panels at rest, and Month-panel return during reverse.

## DOW baseline and Day Banner spacing

In Month, Single Day, and Multi Day views, anchor each DOW label's alphabetic baseline to the bottom of the 28pt DOW row. The date-circle indicator allowance begins 12pt below that baseline, while the DOW row and first date row remain adjacent. Single- and Multi-Day banners use 12pt vertical text clearance and derive their height from the scaled line count plus those insets.

**Why:** The user updated both requested clearances from 8pt to 12pt; keeping the circle offset and banner text insets synchronized preserves the intended layout.

**How to apply:** Keep the widget and Year↔Month morph-painter DOW positions in sync; preserve the separate title-baseline gap and existing circle diameter/bottom clearance. Use the same 12pt banner inset when changing either Day submode.

## Visible DOW top edge at the shared header

The 16pt gap from the expanded title baseline or settled toolbar circle is measured to the visible top of the DOW text, not the top of its fixed-height baseline row. In portrait Month, shift the whole active month document during shared header collapse so the DOW row and month grid retain their existing adjacency. Landscape remains unchanged.

**Why:** The 28pt baseline row includes font-metric space above the visible glyphs. Aligning the row box instead leaves the DOW text too low; moving only the DOW line would also create a new gap before the grid.

**How to apply:** Measure the text inset with the active OS text scaler. Use it for the Month title/compact corrections and Day fixed-header geometry, and keep the separate Year mini-month DOW-to-week-row gap at its authored value.
