---
name: Modal keyboard focus behavior
description: Which modal sheets autofocus and how other app interactions dismiss keyboard focus.
---

Only the **new Event**, **new Group**, and **new standard Category** sheets should request keyboard focus on open. Editing existing items and editing smart categories should not autofocus. Request focus on those routes so their explicitly focused title/name fields can take focus; route focus alone must not make every sheet open the keyboard.

Once a text field has focus, any completed pointer interaction outside an editable text field dismisses it, including actions in root modal sheets. Capture the focused field at pointer-down and blur only that same field after the action; never blur a destination field that gained focus while the interaction opened a route. Taps within editable fields are exempt.

For the three autofocus sheets, request the field focus after the modal route's enter animation completes. Requesting focus during the opening tap can race both route ownership and the root interaction dismissal.

**Why:** Root-level sheet routes need an active focus scope for their designated autofocus fields. A root tap handler can otherwise mistake a newly focused destination field for the source field that should be dismissed.

**How to apply:** Keep autofocus opt-in on the three create flows and pass the explicit route focus flag only for those routes. Defer their field focus until route entry completes. Global interaction dismissal should target the field captured at pointer-down, not whichever field is focused after the callback.
