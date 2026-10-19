---
name: Calendar midpoint view handoff
description: Calendar hierarchy view ownership and title painting during Year↔Month handoffs.
---

The Calendar Year, Month, and Day hierarchy treats 50% of the transition as the ownership boundary. Before that point, headers, controls, markers, and view-specific content belong to the outgoing view; after it, they belong to the incoming view. This applies in both directions, including the accelerated two-leg Year↔Day shortcut.

**Why:** A late or early handoff makes the header, navigation controls, and markers disagree with the view that is visually arriving. The midpoint matches the intended Detailed Category View behavior.

**How to apply:** Keep the morph/layout animation continuous, but commit the logical view and notify shared header owners only when the relevant transition controller crosses 0.5. Any dependent adornment must use the same threshold rather than its own endpoint or near-start gate.

During the Year↔Month zoom, the shell takes title-row paint ownership as soon as the morph begins, while the outgoing scroll-content title must remain laid out for stable geometry. Make the content title's Offstage state listen to the morph lifecycle; a one-time bool can remain stale in a cached scroll panel. Do not gate it on the generic title-in-scroll-content state, because Month↔Day has separate ownership.

**Why:** Cached scroll panels can retain their old title widget through the handoff. A snapshot Offstage value does not update when the shell takes ownership, so both locations paint the same custom up/down chevrons and the fixed stroke appears heavier.

**How to apply:** Listen to the Year↔Month morph state, preserve the outgoing title slot's size, and suppress its paint only during that zoom. Keep the Month↔Day collapse path unchanged.

Keep the shell-owned Calendar title row constrained to the same fixed 57px title slot as the scroll-content row. The toolbar-plus-title wrapper is taller, so allowing the shell row to expand through it changes the vertical center of the trailing up/down controls when ownership switches.

**Why:** HeaderTitleScroller expands to its available cross-axis constraints, and the navigation chevrons align to that row. The shell and scroll-content parents otherwise provide different heights.

**How to apply:** Constrain only the Calendar title row inside the shell; keep the outer header and toolbar geometry unchanged.