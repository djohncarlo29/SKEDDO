---
name: Horizontal fade control gaps
description: Geometry rule for fades next to icons and action controls.
---

Horizontal text fades should begin/end 16px from the visible adjacent control, not blindly 16px from the wrapper boundary. Subtract any existing layout gap; when an icon overlays the same stack, include its visual width in the trailing inset.

**Why:** using the same raw inset everywhere produces inconsistent spacing because some controls are outside the text wrapper while others are positioned inside it.

**How to apply:** measure from the control's visible edge to the fade's opaque endpoint, preserve existing spacing, and keep the fade overlay non-interactive.