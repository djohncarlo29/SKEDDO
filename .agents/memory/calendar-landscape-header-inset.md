---
name: Calendar landscape header and Year inset
description: Landscape safe-area treatment for Year View and shared fixed calendar header behavior during horizontal navigation.
---

In landscape, keep adjacent Calendar panels full-width and edge-to-edge. Apply the symmetric `AppWindowContentScope.horizontalInset` to Year View's grid geometry and scroll content padding, not to a narrower viewport or clipping boundary. The Year↔Month morph must use the same inset for its Year-side origin and grid dimensions.

Keep the complete compact header group—period title, previous/next arrows, and up/down view control—stationary while calendar content swipes. Put the group in one rubber-bandable `HeaderTitleScroller`, and switch its title to the incoming period at 50% of the content slide for Year, Month, and Day views. Match its fade color to the live header surface.

**Why:** A safe-area clip breaks the intended edge-to-edge panel transition, while translating the header with the calendar content makes the chrome move and delays the title change until navigation commits.

**How to apply:** Use the full physical viewport width for slide geometry and title handoff thresholds. Apply the safe inset only to Year View's content, and keep compact header layout independent from the slide offset except for midpoint title selection.