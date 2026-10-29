---
name: Intrinsic placeholder rendering
description: Shared behavior for one-line placeholders that overflow or rubberband at text-field edges.
---

AppSearchBar's one-line placeholder belongs in HorizontalEdgeFade's Flutter overlay, with NativeTextInput.placeholder empty. Set placeholderInChild=false and track focus in a listenable; the overlay and input then move together through HorizontalEdgeFade's fitting-content rubberband transform and alpha fade. Keep the wrapper Listener translucent so the placeholder's ignored hit target does not remove it from the pointer path. On web, the DOM input can keep an empty placeholder while its pointer handler publishes rubberband metrics that move the same Flutter overlay.

**Why:** NativeTextInputMobile paints its placeholder as an IgnorePointer sibling outside CupertinoTextField's editable scroll viewport, so it does not naturally follow the caret/text scroll. Putting that hint in the edge-fade layer makes it share the explicit drag offset and fade behavior; a unit test should also verify the hint is outside NativeTextInput rather than only checking that the whole widget moved.

**How to apply:** For AppSearchBar, keep the hint in HorizontalEdgeFade, the native hint empty, and the wrapper's translucent listener and alpha mask active. On web, verify pointer events on the HtmlElementView publish metrics and move the Flutter overlay; avoid depending on a CSS `::placeholder` pseudo-element for its gesture.