---
name: Cupertino sheet gesture lifecycle
description: The route-owned down-drag dismissal path must follow Flutter's private Cupertino sheet lifecycle.
---

The sheet's down-drag recognizer should be added on pointer-down, allowed to compete in Flutter's gesture arena, and create the route pop controller only after `onStart` wins. Each `onUpdate` subtracts the pointer delta divided by the visible sheet height directly from the route animation controller, preserving 1:1 movement. `onEnd`/`onCancel` settle or pop through the controller while keeping `didStartUserGesture`/`didStopUserGesture` balanced.

**Why:** pre-filtering pointer hits through a full render-tree `Listener` made sheet drags fragile across cards, scroll views, transformed content, and editable controls; Flutter's own `showCupertinoSheet` does not use that gate.

**How to apply:** when changing `RoundedCupertinoSheetRoute`, compare the gesture detector and controller against the Flutter SDK's `cupertino/sheet.dart`; do not reintroduce header-only or synchronous render-tree ownership decisions.

Custom transition state must create any animation derived from inherited Cupertino theme data in `didChangeDependencies`, not `initState`.

**Why:** resolving theme brightness while the transition state is mounting triggers Flutter's inherited-dependency assertion and prevents the sheet route from building at all.

When a sheet page uses `PopScope` to protect unsaved edits, the custom drag controller must request dismissal with `Navigator.maybePop()` rather than `Navigator.pop()`.

**Why:** direct navigator pops bypass the descendant pop disposition, so a downward drag can close a dirty editor without giving its centered discard confirmation a chance to appear.