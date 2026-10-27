---
name: Toolbar state-route hit testing
description: Keep screen input working when transparent routes are used only to register pinned toolbar states.
---

A non-opaque `PageRoute` still creates a modal barrier, and a transparent barrier with `dismissible: false` consumes pointer events. If a route exists only to register toolbar chrome over the current screen, override its barrier with an `IgnorePointer` so content beneath remains interactive; leave hit testing enabled only for the actual toolbar.

**Why:** Ignoring the route's full-screen page child does not bypass the separate modal-barrier overlay entry. The screen can look normal while all its controls and tabs stop receiving taps.

**How to apply:** Add a widget test that pushes the toolbar-registration route and taps a control on the underlying screen.
