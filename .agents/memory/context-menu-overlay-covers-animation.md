---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
Do not run a context-menu mutation callback until the closing animation is complete, and give package preview builders explicit dimensions when their source is a constraint-dependent card.

**Why:** SKEDDO's custom overlay keeps an opaque preview over the real row through its close animation. The package `showGlassContextMenu` route future completes as the pop starts, before its reverse morph finishes, and its action callback runs after `Navigator.pop()`. Also, a positioned-only `Stack` can measure at zero when the package builds a preview offstage without the grid's constraints.

**How to apply:** For custom overlays, defer callbacks until the overlay is removed. For `showGlassContextMenu`, keep the source hidden and pending action through the package's reverse transition duration before restoring the source or invoking the callback. Wrap constraint-dependent previews in a `SizedBox` using the source tile's measured size.
