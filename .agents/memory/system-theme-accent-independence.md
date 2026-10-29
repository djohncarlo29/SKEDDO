---
name: System theme and accent independence
description: Keep system-accent selection independent from the app's current brightness.
---

Accent selection is color-only and must never change the app's selected theme. In System theme mode, the displayed system brightness and rendered brightness must come from the same operating-system snapshot.

**Why:** A root rebuild after selecting the system accent exposed a mismatch between the brightness shown by Settings and the brightness used by the rendered app theme.

**How to apply:** Resolve System-mode brightness from the platform brightness notifier and propagate that same value to CupertinoTheme and descendant MediaQuery. Keep accent palette updates independent of brightness state.
