---
name: Full-width time picker selection
description: Shared event time-picker spacing and selection-bar behavior.
---

Use three equal-width columns across the available picker width so the hour, minute, and day-period values retain their established layout and the connected selection bar fills the row in both portrait and landscape. Right-align the hour with 12dp trailing padding, center the minutes, and left-align AM/PM with 12dp leading padding. Render these labels with plain `Text`, not `WheelOptionText`; its extra 8dp edge inset shifts the values away from the established positions. Preserve the off-axis barrel curvature.

The keypad must reopen whenever it is inactive and the selection bar is tapped, regardless of how it was dismissed. Do not infer keypad visibility from entry-mode or focus alone: the OS can hide the keypad while both remain active. When the keypad is already visible, tapping hour or minute changes the entry target without dismissing it.

**Why:** The established picker uses evenly spaced columns and the full-width connected selection bar. A later `WheelOptionText` wrapper added an 8dp inset on top of the existing 12dp label padding, moving the hour and period away from their prior positions. The September 30 reference screenshot shows the original three-column arrangement.

**Why:** The OS can dismiss a software keypad without clearing the picker’s entry-mode or focus state; requesting focus on an already-focused field then does not show it again.

**Why:** A post-frame focus callback alone may never run after a tap that schedules no frame, leaving an already-mounted but unfocused input unreachable.

**How to apply:** This rule applies to every shared event time picker instance, including start, end, and reminder times. Keep the three Expanded columns and the `-0.60 / 0 / +0.45` off-axis values for hour, minutes, and period respectively. A request to change barrel curvature does not authorize changing the column layout or replacing the plain time-label widgets with edge-inset wheel text. Selection-band taps must inspect actual keyboard visibility, refresh focus when the keypad is absent, and request focus immediately when the input is already mounted.