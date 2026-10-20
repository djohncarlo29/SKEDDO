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
- During Year → Month, every non-selected Year element—including same-row day cells—must zoom toward the measured Month weekday-row top. Painter canvas y=0 is above the Month content because the second-level title occupies space before that row.
- Freeze both snapshots for the full animation. Do not recompute them after the view handoff, from a new scroll offset, or by adding viewport/header offsets to coordinates already measured from rendered widgets.
- If either endpoint cannot be measured, do not run the morph with estimated geometry; settle directly into the real destination layout.

**Why:** The prior capture used CalendarTab-local coordinates while the painter used its overlay's coordinate space; the midpoint handoff could shift their relationship. Reverse motion could also target an old Year snapshot. Adding the content-area raise to measured Month coordinates duplicated an inset.

Non-selected same-row day cells must use the same target formula as the other non-selected elements: `monthFocalY + sFinal * (yearY - focalY)`. Omitting `monthFocalY` sends those still-visible cells above the title until the live Month view replaces the painter.

**How to apply:** Keep capture helpers tied to the painter's keyed coordinate-space box. Re-measure the destination on every transition, keep the snapshots immutable while animating, anchor every non-selected Month-target branch to its measured destination origin, and clear `_zoomMorphActive` only after the simulation completes.

## Remaining derived geometry

The selected mini-month's actual week-row bounds are measured. Its day slots are evenly sized children of those rows, so cell centers/sizes derive exactly from the measured row bounds. Formula-based scaling and row positions are only fallbacks/decorative motion for non-selected months; never use them as the selected endpoint.

## Handoff

The view/header handoff occurs at the transition midpoint. It may change ownership of the surrounding layout, but must not mutate or remeasure the morph endpoint snapshots.

Keep the measured destination `Scrollable` mounted through the painter's final release, and preserve its keyed parent slot as surrounding preview panels are added. A `ScrollController`'s `initialScrollOffset` seeds a new position; it does not track later live pixels.

**Why:** Replacing the hidden destination immediately before reveal can reattach a new `ScrollPosition` from a stale initial offset. The painter can reach the right measured endpoint while the live view appears at a different scroll position.

**How to apply:** Reconcile the destination as the same keyed child from capture through settled display. If adding sibling panels changes child order, key the direct Stack slots so the center destination is moved rather than remounted. Verify non-zero scroll offsets as well as viewport origin.

## Shell title slot

Hiding the duplicate scrollable title during a Year↔Month morph must not remove its 57px layout slot. `Offstage` reports zero size, so keep the fixed-height slot outside it; otherwise both captured endpoints sit 57px too high and snap when the live title returns.

**Why:** The Year and Month targets are measured while the shell owns the title. A zero-sized hidden child makes the scroll view believe the title is present while contributing no height.

**How to apply:** Preserve the title slot's full height while hiding only its contents, and verify capture geometry against settled geometry in the real AppShell.

## Morph text metrics

Canvas `TextPainter` does not inherit the ambient OS `TextScaler`. Resolve Month endpoint sizes with `TextScaler.scale()` at each label's authored font size, then interpolate those sizes through the morph. Keep Year-side text under its existing `maxScaleFactor: 1.0` cap and retain the current transition duration.

**Why:** Fixed painter font sizes render as system-default during the animation, then change abruptly when the scaled live Month view appears. The OS scaler can be nonlinear, so a ratio derived from another font size is not a reliable substitute.

**How to apply:** Derive DOW and week-number endpoint sizes from their own widget font sizes; include them in painter invalidation, and keep source/target weight and spacing aligned with the rendered endpoint styles.

## Key dependency

`lerpDouble` requires `import 'dart:ui' show lerpDouble;` — flutter/cupertino.dart alone does NOT expose it as a free function inside StatelessWidget.build.
