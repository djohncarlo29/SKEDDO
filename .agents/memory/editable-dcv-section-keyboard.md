---
name: Editable DCV section keyboard reveal
description: Keyboard visibility behavior for inline-editable custom section headers in the Category Detail View.
---

## Rule

An inline section header that autofocuses inside the DCV's scrollable content must reveal itself after focus, after keyboard insets change, and after text edits that can add wrapped lines.

**Why:** Focus can happen before the keyboard resizes the viewport, and a title can become taller after the initial reveal. A single focus-time scroll leaves lower lines hidden on shorter screens.

**How to apply:** Keep the reveal scheduled post-frame, use `Scrollable.ensureVisible` on the editable header, and repeat it from the focus listener, `didChangeMetrics`, and the field's `onChanged` callback.