---
name: Calendar landscape safe-area insets
description: Symmetric safe-area treatment for Year and Month content without narrowing edge-to-edge calendar swipe panels.
---

In landscape, keep adjacent Calendar panels full-width and edge-to-edge. Apply the symmetric `AppWindowContentScope.horizontalInset` to Year View's grid geometry and scroll content padding, not to a narrower viewport or clipping boundary. The Year↔Month morph must apply the inset to both endpoints: Year-side grid origin/dimensions and Month-side content origin/width/cell coordinates.

For Month View, inset the calendar content symmetrically inside each full-width swipe panel. Keep the panel width, clipping, and swipe distance physical-width-based. Week-row backgrounds and bottom separator lines remain edge-to-edge; inset only the week number, day cells, weekday labels, selection overlays, and Month List content. Interpolate the content inset to zero during Month→Day collapse so the Day View strip returns to its full-width geometry.

Keep the complete compact header group stationary while calendar content swipes, in this exact order: left chevron, period title, up/down view chevron, right chevron. Put the group in one rubber-bandable `HeaderTitleScroller`, and switch its title to the incoming period at 50% of the content slide for Year, Month, and Day views. Match its fade color to the live header surface.

**Why:** A safe-area clip breaks the intended edge-to-edge panel transition, while inset separator lines no longer match the screen-wide week-strip treatment. If only the Year endpoint uses the inset, the painter shifts or stretches cells at the Month endpoint. Translating the header with calendar content also makes the chrome move and delays the title change until navigation commits.

**How to apply:** Use the full physical viewport width for slide geometry and title handoff thresholds. Interpolate calendar content between symmetrically inset Year and Month geometry, preserve full-bleed Month row surfaces and separators, and keep compact header layout independent from the slide offset except for midpoint title selection.