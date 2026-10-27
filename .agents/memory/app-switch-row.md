---
name: Full-row switch interaction
description: Shared pattern for making rows containing LiquidGlassSwitch controls tappable across their full width.
---

Use `AppSwitchRow` around any new row that contains an `AppSwitch`/`LiquidGlassSwitch`. It expands the row to the available width, toggles by inverting the current value, and respects the row's enabled state.

For stateful rows with dependent UI, pass the switch's requested `bool` through to the state handler instead of ignoring it and blindly toggling. Make the handler a no-op when the requested value already matches state, so repeated row/switch callbacks cannot undo each other.

**Why:** The switch maintains its own gesture state while the parent owns the value, and a row target can otherwise require precise taps. Explicit, idempotent updates keep the full row interactive without letting overlapping callbacks undo dependent state.

**How to apply:** Keep the complete row layout in the wrapper's `child`, pass the same `value` and `onChanged` used by the switch, and set `enabled: false` when the row should not respond. For event-style side effects, run them only when the requested value differs from the current state.

For rows containing the package's raw-gesture `LiquidGlassSwitch`, keep the row tap target out of the switch's hit region. Use a sibling tap target for the label and remaining row space, with the switch rendered beside it.

**Why:** A parent tap recognizer spanning the package control can compete with its eager press/drag recognizer and interfere with the switch's own release-and-settle lifecycle.

**How to apply:** In this case, do not wrap the entire row around `AppSwitch`; let the switch own its pointer stream and keep row-level activation on the non-switch area. Continue passing the requested boolean to the idempotent state handler.