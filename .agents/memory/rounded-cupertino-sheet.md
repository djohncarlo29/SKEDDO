---
name: Custom-radius Cupertino sheet transition
description: Flutter's showCupertinoSheet hardcodes a 12px corner radius with no public override; how to reproduce the exact motion with a different radius.
---

Flutter's `showCupertinoSheet` / `CupertinoSheetRoute` (in
`packages/flutter/lib/src/cupertino/sheet.dart`) hardcodes `Radius.circular(12)`
for the sheet's rounded top corners and for the corners revealed on the
receding page behind it. There is no constructor parameter, theme property, or
public override point for this — the radius is a literal baked into a private
`CupertinoSheetTransition` widget and a private drag-to-dismiss controller.

To get a different radius while keeping the exact native motion (slide-up
curve, scale-down "stacking" of the previous page, drag-to-dismiss physics,
`delegatedTransition` wiring so the *previous* route's corners round off
too), the practical approach is to copy the entire implementation into an
app-owned file, replacing every `Radius.circular(12)` with the desired
constant. All the private helper classes (`_CupertinoDownGestureController`,
`_CupertinoSheetScope`, etc.) must be reimplemented under new names using only
public `ModalRoute`/`PageRoute` API (`route.controller`, `route.navigator`,
`route.popGestureInProgress`, the `delegatedTransition` getter) — they can't be
imported or subclassed since they're library-private.

**Why:** a user explicitly wanted the sheet's corners to match the app's
`kCornerRadius` design-system constant instead of iOS's native 12px, while
insisting the motion look "exact as Flutter's built-in showCupertinoSheet."
Patching Flutter's SDK source isn't viable in this environment, and wrapping
the sheet content in an inner `ClipRRect` with a larger radius has no visual
effect — the outer framework clip at 12px still bounds the shape.

**How to apply:** see `artifacts/smart-scheduler/lib/widgets/rounded_cupertino_sheet.dart`
for a working, drop-in `showRoundedCupertinoSheet` replacement. Reuse that
pattern (or that file directly) for any future sheet that needs a non-default
corner radius, rather than re-deriving the animation constants from scratch.
