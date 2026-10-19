---
name: Calendar midpoint view handoff
description: Calendar hierarchy view ownership and title painting during Year↔Month handoffs.
---

The Calendar Year, Month, and Day hierarchy treats 50% of the transition as the ownership boundary. Before that point, headers, controls, markers, and view-specific content belong to the outgoing view; after it, they belong to the incoming view. This applies in both directions, including the accelerated two-leg Year↔Day shortcut.

**Why:** A late or early handoff makes the header, navigation controls, and markers disagree with the view that is visually arriving. The midpoint matches the intended Detailed Category View behavior.

**How to apply:** Keep the morph/layout animation continuous, but commit the logical view and notify shared header owners only when the relevant transition controller crosses 0.5. Any dependent adornment must use the same threshold rather than its own endpoint or near-start gate.

During the Year↔Month zoom, the shell owns title-row painting while the scroll-content title stays mounted Offstage in its real fixed-size slot. Do not replace that slot with top padding during the morph. At the midpoint view handoff, carry the current shell header offset into the destination scope instead of restoring that scope's saved offset.

**Why:** Replacing the title slot with padding changes the measured Month endpoint from its settled layout. Restoring the destination's saved header offset at 50% also translates the shell title mid-morph, causing a visible vertical snap.

**How to apply:** Keep the shared title builder active during the portrait Year↔Month morph and let its Offstage state listen to the morph lifecycle, so only the shell paints the chevrons. Preserve the current header offset at the midpoint and copy it to the incoming view scope. Keep the Month↔Day collapse path unchanged.

Keep the shell-owned Calendar title row in the same complete fixed 57px slot as the scroll-content row. The shell slot starts at `topInset + toolbarHeight`, matching the scroll title's `leadingInset`, and its bottom inset stays inside the slot. Do not place that inset around the taller toolbar-plus-title wrapper.

**Why:** Matching only the slot height is insufficient. Different parent padding and origins can give HeaderTitleScroller different cross-axis constraints, shifting the title and navigation chevrons when ownership switches.

**How to apply:** Share one title-slot builder between shell and scroll-content owners across Year, Month, and Day navigation. Keep the outer header and toolbar geometry unchanged, and leave the title handoff and chevron painting logic intact.