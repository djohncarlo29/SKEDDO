---
name: Modal sheet drag scope
description: Sheet dismissal should track native-style down-drags while protecting editable controls.
---

Modal sheet down-drag dismissal is admitted across the sheet surface, but the
route recognizer must not be attached when the initial pointer hit-test lands on
a RenderEditable. The dedicated header marker remains useful for identifying
headers, but is not required for the route gesture.

**Why:** the prior header-only gate left valid drags that began on cards,
pickers, or blank sheet space inert. A direct editable-target guard preserves
text selection without leaving the sheet stuck open.

**How to apply:** keep the route controller's delta math unchanged for 1:1
movement, guard editable targets at pointer-down, and let content widgets keep
their own scrolling and selection recognizers.