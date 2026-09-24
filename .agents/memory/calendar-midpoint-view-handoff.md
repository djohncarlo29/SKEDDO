---
name: Calendar midpoint view handoff
description: The Calendar hierarchy transition changes its committed view and dependent UI at the visual midpoint.
---

The Calendar Year, Month, and Day hierarchy treats 50% of the transition as the ownership boundary. Before that point, headers, controls, markers, and view-specific content belong to the outgoing view; after it, they belong to the incoming view. This applies in both directions, including the accelerated two-leg Year↔Day shortcut.

**Why:** A late or early handoff makes the header, navigation controls, and markers disagree with the view that is visually arriving. The midpoint matches the intended Detailed Category View behavior.

**How to apply:** Keep the morph/layout animation continuous, but commit the logical view and notify shared header owners only when the relevant transition controller crosses 0.5. Any dependent adornment must use the same threshold rather than its own endpoint or near-start gate.