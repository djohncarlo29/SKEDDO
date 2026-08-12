---
name: Events Tab keyboard dismissal root cause
description: Why the search keyboard dismissed on content-area interaction, and what actually fixed it.
---

## The rule — TWO layers, BOTH required

### Layer 1: Flutter gesture arena
When `_CategoryDetailView` has `label.isEmpty` (DCV not active/off-screen), return `SizedBox.expand` instead of `CustomScrollView`. Never keep a `CustomScrollView` alive in the tree for a widget that is off-screen and wrapped in `IgnorePointer`.

**Fix:** In `_CategoryDetailView.build()` (events_tab.dart):
```dart
if (kIsWeb || label.isEmpty) return SizedBox.expand(child: content);
return CustomScrollView(...);  // only when DCV is actually visible
```

### Layer 2: iOS UIKit implicit resign (lockFocus / unlockFocus)
The iOS native `UITextField` has `textFieldShouldEndEditing` returning `!isLocked`. Without `isLocked = true`, iOS UIKit can dismiss the keyboard on any implicit resign request (scroll, tap-outside, etc.) — even with `keyboardDismissBehavior: manual` on Flutter's `CustomScrollView`. Flutter's `keyboardDismissBehavior: manual` is purely a Dart-layer guard (prevents `primaryFocus?.unfocus()` call in Dart) — it does NOT prevent iOS UIKit from asking the native UITextField to resign first responder.

**Fix:** Call `NativeTextInput.lockFocus(controller)` after the native text field becomes first responder in search mode, and `NativeTextInput.unlockFocus(controller)` before explicit cancel/deactivate.

## Why both are needed
- `CustomScrollView` fix: removes Flutter-level `primaryFocus?.unfocus()` call from the gesture arena.
- `lockFocus`/`unlockFocus`: blocks iOS UIKit from dismissing the keyboard via `textFieldShouldEndEditing`.
Notes Tab is unaffected because (a) no DCV in its tree and (b) its search mode activates via direct tap (no remount race + programmatic scroll).

## activateSearchMode() bug also fixed
`_onSearchFocusChanged(true)` returns early in the `activateSearchMode()` path (guard `if (_searchFocused == focused) return` — both are already `true` by the time NativeTextInput fires). So `sbSearchModeActive = true` must be set directly in `activateSearchMode()`, not relied upon from the focus callback.

## Call sites in events_tab.dart
- `_onSearchFocusChanged(true)` post-frame cb: `focus()` then `lockFocus()`
- `activateSearchMode()`: set `sbSearchModeActive = true` immediately, then `focus()` + `lockFocus()` in the 300ms delay
- `_cancelSearch()`: `unlockFocus()` BEFORE `unfocusAll()`
- `deactivate()`: `unlockFocus()` BEFORE `unfocusAll()`

## What NOT to do
- Do not remove `lockFocus`/`unlockFocus` as "dead code" — the iOS native side actively uses `isLocked` in `textFieldShouldEndEditing`.
- Do not use `IgnorePointer` alone to suppress a `CustomScrollView`'s keyboard side-effects — it is insufficient for the Flutter layer and does nothing for the iOS UIKit layer.
