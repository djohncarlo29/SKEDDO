---
name: Overlay scroll view primary controller reset
description: CustomScrollView overlays inside CupertinoTabScaffold must use primary:false or they steal the tab scroll controller and snap the position to 0.
---

## Rule
Any `CustomScrollView` placed as a Stack overlay inside a `CupertinoTabScaffold` tab must explicitly set `primary: false`.

**Why:** `CupertinoTabScaffold` injects the tab's scroll controller as the `PrimaryScrollController` for each tab's subtree. A `CustomScrollView` with no explicit `controller` and no `primary: false` silently adopts that primary controller. When the overlay `CustomScrollView` is added to the tree it starts at offset 0, resetting the tab's visible scroll position to 0 instantly.

**How to apply:** Every time a `CustomScrollView` is created inside a Stack that sits inside a `CupertinoTabScaffold` tab, add `primary: false` even if an explicit controller is not needed. This forces Flutter to create a fresh internal `ScrollController` for that view rather than adopting the ambient primary.

```dart
CustomScrollView(
  primary: false,   // ← required for any overlay inside CupertinoTabScaffold
  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
  slivers: [...],
)
```
