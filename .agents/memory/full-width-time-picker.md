---
name: Full-width time picker selection
description: Shared event time-picker spacing and selection-bar behavior.
---

Use three equal-width columns across the available picker width so the hour, minute, and day-period values retain their established layout and the connected selection bar fills the row in both portrait and landscape. Right-align the hour with 12dp trailing padding, center the minutes, and left-align AM/PM with 12dp leading padding. Render these labels with plain `Text`, not `WheelOptionText`; its extra 8dp edge inset shifts the values away from the established positions. Preserve the off-axis barrel curvature.

The first selection-bar tap can enter numeric-entry mode and open the keypad. After a text field has focus, interacting with a non-editable picker control dismisses that focus under the app-wide keyboard interaction rule. Taps inside the actual editable field remain focused.

**Why:** The established picker uses evenly spaced columns and the full-width connected selection bar. A later `WheelOptionText` wrapper added an 8dp inset on top of the existing 12dp label padding, moving the hour and period away from their prior positions. The September 30 reference screenshot shows the original three-column arrangement.

**Why:** The OS can dismiss a software keypad without clearing the picker’s entry-mode or focus state; requesting focus on an already-focused field then does not show it again. The user later clarified that non-editable control interactions should dismiss keyboard focus, including when it was opened by an entry-mode picker.

**Why:** A post-frame focus callback alone may never run after a tap that schedules no frame, leaving an already-mounted but unfocused input unreachable.

**How to apply:** This rule applies to every shared event time picker instance, including start, end, and reminder times. Keep the three Expanded columns and the `-0.60 / 0 / +0.45` off-axis values for hour, minutes, and period respectively. A request to change barrel curvature does not authorize changing the column layout or replacing the plain time-label widgets with edge-inset wheel text. Selection-band taps may enter numeric mode when no field was focused before the interaction; do not reclaim focus after an interaction has completed outside the editable field.

**Why:** The app-wide focus-dismissal rule takes precedence over the earlier behavior that preserved the keypad during hour/minute selection.

**How to apply:** Keep the invisible field mounted while picker values update. Its in-progress gesture guard may protect focus during pointer-down, but the global pointer-up dismissal must be allowed to blur it after the interaction ends.