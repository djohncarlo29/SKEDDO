---
name: Intrinsic placeholder rendering
description: Shared behavior for one-line placeholders that overflow or rubberband at text-field edges.
---

One-line placeholders need to follow the same editable surface gesture as typed text, not just share its paint transform. AppSearchBar keeps its placeholder inside NativeTextInput and sets HorizontalEdgeFade.placeholderInChild=true; the wrapper still supplies clipping and alpha fade. When the wrapper uses its manual fitting-content fallback, its Listener must be translucent so an ignored hint/platform child cannot remove the wrapper from the pointer path. On web, keep the DOM input placeholder populated so the platform input can measure it and apply its CSS alpha mask. Other fields, such as New Event Title, may use their established Flutter overlay pattern when their native editable scroll path is already working.

**Why:** A separate, ignored Flutter placeholder can appear to move in a widget test while failing to join the native/platform text input's real drag path. Keeping AppSearchBar's hint in the input makes the same editable surface own placeholder and typed-text gestures; web platform views still require CSS masking because Flutter shader masks cannot fade their DOM text.

**How to apply:** For AppSearchBar, keep `NativeTextInput.placeholder` set to the visible hint, use `placeholderInChild: true`, and retain the shared wrapper's alpha fade. Make the wrapper hit-test translucent while its manual drag fallback is enabled. Preserve web CSS masking for the DOM input and keep Flutter's alpha-mask subtree mounted with an opaque identity shader when fades are off.