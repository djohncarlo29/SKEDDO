---
name: Overlay dismissal confirmation ownership
description: Back handling for unsaved-change confirmation overlays layered above editor routes.
---

An unsaved-change confirmation rendered as an `OverlayEntry` must own outside-tap and system-Back dismissal while visible. The underlying editor's `PopScope` must return without starting another confirmation, and both callbacks need a short-lived same-event consumption guard because one Back event can reach both scopes.

**Why:** An overlay is not a separate Navigator route, so the editor route can still receive the same OS Back event. Without explicit ownership, the editor opens a centered confirmation while the existing Xmark-triggered confirmation is still visible.

**How to apply:** Register one active dismiss callback for the discard overlay, wrap the overlay in `PopScope(canPop: false)`, clear the active callback on every close path, and make each editor dismissal handler consume/return when an active discard overlay exists.