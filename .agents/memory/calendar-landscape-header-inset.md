---
name: Calendar landscape safe-area insets
description: Symmetric safe-area treatment for Year and Month content without narrowing edge-to-edge calendar swipe panels.
---

In landscape, keep adjacent Calendar panels full-width and edge-to-edge. Apply the symmetric `AppWindowContentScope.horizontalInset` to Year View's grid geometry and scroll content padding, not to a narrower viewport or clipping boundary. The Year↔Month morph must use the same inset for its Year-side origin and grid dimensions.

For Month View, inset the calendar content symmetrically inside each full-width swipe panel. Keep the panel width, clipping, and swipe distance physical-width-based. Week-row backgrounds and bottom separator lines remain edge-to-edge; inset only the week number, day cells, weekday labels, selection overlays, and Month List content. Interpolate the content inset to zero during Month→Day collapse so the Day View strip returns to its full-width geometry.

Keep the complete compact header group stationary while calendar content swipes, in this exact order: left chevron, period title, up/down view chevron, right chevron. Put the group in one rubber-bandable `HeaderTitleScroller`, and switch its title to the incoming period at 50% of the content slide for Year, Month, and Day views. Match its fade color to the live header surface.

**Why:** A safe-area clip breaks the intended edge-to-edge panel transition, while inset separator lines no longer match the screen-wide week-strip treatment. Translating the header with the calendar content makes the chrome move and delays the title change until navigation commits.

**How to apply:** Use the full physical viewport width for slide geometry and title handoff thresholds. Apply symmetric safe insets within Year and Month content, preserve full-bleed Month separators, and keep compact header layout independent from the slide offset except for midpoint title selection.