---
name: Calendar year↔month shared-element morph
description: The Year↔Month morph uses measured endpoint snapshots in the painter's coordinate space and retains painter ownership until the spring completes.
---

## Morph ownership

`_MorphOverlay` renders per-element interpolation. `_zoomMorphActive` begins only after both endpoint snapshots are measured and remains true until the animation future completes. Do not let controller thresholds expose the static destination early: a bounded spring can touch its endpoint before it has settled.

**Why per-element instead of one Transform:** The Matrix4 approach is geometrically correct for preserving gaps, but it can't produce a true shared-element morph — individual cells can't converge on independent month-view positions. Per-element interpolation lets each cell reach its own measured settled position.

**Why keep painter ownership through completion:** A spring may reach the controller bound and move away from it before the simulation finishes. Swapping to the static layout at that temporary endpoint causes a visible flash or snap.

## Endpoint geometry

Measure both endpoints in the render box that owns the `Positioned.fill` painter. Convert measured render-box corners into that box's local coordinates, so source, destination, and canvas share one frame.

- Year → Month: capture the settled Year source, mount the real Month view invisibly, then measure its rows, cells, headers, and List content before motion starts.
- Month → Year: capture the current Month source, mount the real Year view invisibly, then freshly measure the destination instead of reusing the Year geometry from a previous visit.
- Freeze both snapshots for the full animation. Do not recompute them after the view handoff, from a new scroll offset, or by adding viewport/header offsets to coordinates already measured from rendered widgets.
- If either endpoint cannot be measured, do not run the morph with estimated geometry; settle directly into the real destination layout.

**Why:** The prior capture used CalendarTab-local coordinates while the painter used its overlay's coordinate space; the midpoint handoff could shift their relationship. Reverse motion could also target an old Year snapshot. Adding the content-area raise to measured Month coordinates duplicated an inset.

**How to apply:** Keep capture helpers tied to the painter's keyed coordinate-space box. Re-measure the destination on every transition, keep the snapshots immutable while animating, and clear `_zoomMorphActive` only after the simulation completes.

## Remaining derived geometry

The selected mini-month's actual week-row bounds are measured. Its day slots are evenly sized children of those rows, so cell centers/sizes derive exactly from the measured row bounds. Formula-based scaling and row positions are only fallbacks/decorative motion for non-selected months; never use them as the selected endpoint.

## Handoff

The view/header handoff occurs at the transition midpoint. It may change ownership of the surrounding layout, but must not mutate or remeasure the morph endpoint snapshots.

## Key dependency

`lerpDouble` requires `import 'dart:ui' show lerpDouble;` — flutter/cupertino.dart alone does NOT expose it as a free function inside StatelessWidget.build.
