---
name: Toolbar state-route hit testing
description: Keep pinned toolbar ownership, route transitions, and modal handoffs on one coherent navigation stack.
---

`GlassNavigationShell` orders pinned toolbar registrations from route coverage and current ownership. Keep toolbar destinations and every app-level route that covers or presents over them—Settings, subscreens, dialogs, and modal sheets—on the same Navigator. Splitting toolbar registrations from real screen and sheet routes can leave stale actions, invisible hit targets, or chrome above a sheet.

The indexed tab bodies may stay mounted beside that Navigator. Toolbar-state routes can be opaque to provide real transition progress while their transparent, pointer-ignoring page lets the body continue receiving taps.

After a modal route is popped, refresh the covered toolbar registration only after that route's exit has completed. Refreshing at presentation or pop start can re-register the bar during the transition and make it overlap the sheet.

Keep the primary `GlassBarItem` ID and icon-content identity stable across destinations when only its glyph changes.

**Why:** The package ranks routes using the Navigator's transition coverage. Separate stacks do not provide one reliable ordering, while early handoff refreshes can race the modal's exit animation.

**How to apply:** Use the same Navigator for app toolbar state, Settings routes, and modal presentation/dismissal. Verify body taps pass through toolbar-state routes and that the registered toolbar returns after a sheet fully closes.
