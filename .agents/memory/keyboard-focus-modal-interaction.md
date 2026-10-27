---
name: Modal keyboard focus behavior
description: Which modal sheets autofocus and how other app interactions dismiss keyboard focus.
---

Only the **new Event**, **new Group**, and **new standard Category** sheets should request keyboard focus on open. Editing existing items and editing smart categories should not autofocus. Request focus on those routes so their explicitly focused title/name fields can take focus; route focus alone must not make every sheet open the keyboard.

Once a text field has focus, any completed pointer interaction outside an editable text field dismisses it, including actions in root modal sheets. Taps within editable fields are exempt so users can continue typing or move to another field. Apply the rule at the root Navigator boundary and let it run after the interaction callback, so control handlers cannot accidentally reclaim focus.

**Why:** Root-level sheet routes need an active focus scope for their designated autofocus fields. At the same time, Flutter and native text inputs do not consistently resign focus when users select a picker row, action, or icon.

**How to apply:** Keep autofocus opt-in on the three create flows. When adding a new focused modal, pass the explicit route focus flag only for that flow. Do not replace global interaction dismissal with per-button unfocus calls or blur on taps inside editable text.
