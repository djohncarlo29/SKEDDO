---
name: AppShell floating overlays
description: Parent-data constraints for shell-level floating controls in Flutter
---

Shell-level floating controls that use `Positioned` must be inserted directly
into the AppShell's outer `Stack`, not into a `Column` that happens to be
inside that stack.

**Why:** Flutter web can fail with an opaque runtime type-cast exception and
blank the app when `Positioned` receives `FlexParentData` from a `Column`.

**How to apply:** Keep the content/header `Column` as one Stack child, then add
floating controls as sibling Stack children in their intended z-order before
scrims and panels.