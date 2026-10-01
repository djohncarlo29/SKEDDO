---
name: Calendar landscape safe-area insets
description: Symmetric safe-area treatment for Year, Month, and Day content while retaining full-width calendar panels and bleed rules.
---

In landscape, keep adjacent Calendar panels full physical width and edge-to-edge. Apply the symmetric `AppWindowContentScope.horizontalInset` to Year View's grid geometry and scroll content padding, not to a narrower viewport or clipping boundary. The Year↔Month morph must apply the inset to both endpoints: Year-side grid origin/dimensions and Month-side content origin/width/cell coordinates.

For Month View, inset calendar content symmetrically inside each full-width swipe panel. Keep panel width, clipping, and swipe distance physical-width-based. Week-row backgrounds and bottom separator lines remain edge-to-edge; inset only the week number, day cells, weekday labels, selection overlays, and Month List content.

Day View keeps the same symmetric inset for the week strip, weekday labels, day-banner labels, and timeline day columns. The panels, swipe distance, and viewport clipping remain full-width. Horizontal separators, the midnight rule, hourly rules, and the current-time rule extend to the physical right edge; multi-day vertical day-column dividers use the inset bounds. Preserve the inset throughout the Month↔Day collapse rather than fading it to zero, so the selected week strip meets the settled Day View geometry.

Keep the complete compact header group stationary while calendar content swipes, in this exact order: left chevron, period title, up/down view chevron, right chevron. Put the group in one rubber-bandable `HeaderTitleScroller`, and switch its title to the incoming period at 50% of the content slide for Year, Month, and Day views. Match its fade color to the live header surface.

**Why:** A safe-area clip breaks the intended edge-to-edge panel transition, while inset separator lines no longer match the screen-wide calendar treatment. If inset geometry changes during Month↔Day collapse, the week strip and Day View content do not align. If only the Year endpoint uses the inset, the painter shifts or stretches cells at the Month endpoint. Translating the header with calendar content also makes the chrome move and delays the title change until navigation commits.

**How to apply:** Use the full physical viewport width for slide geometry and title handoff thresholds. Apply a shared symmetric inset to Year, Month, and Day content; preserve full-bleed backgrounds and rules; keep the Month↔Day content inset stable through the morph; and keep compact header layout independent from slide offset except for midpoint title selection.