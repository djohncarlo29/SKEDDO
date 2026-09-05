---
name: Full-row switch interaction
description: Shared pattern for making rows containing LiquidGlassSwitch controls tappable across their full width.
---

Use `AppSwitchRow` around any new row that contains an `AppSwitch`/`LiquidGlassSwitch`. It expands the row to the available width, toggles by inverting the current value, and respects the row's enabled state.

**Why:** A switch control's own hit area only covers the control, so new rows can otherwise regress to requiring a precise tap on the switch.

**How to apply:** Keep the complete row layout in the wrapper's `child`, pass the same `value` and `onChanged` used by the switch, and set `enabled: false` when the row should not respond.