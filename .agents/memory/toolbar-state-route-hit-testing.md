---
name: Toolbar state-route hit testing
description: Separate app-shell screen navigation from root modal presentation so pinned chrome stays under the sheet.
---

Keep toolbar destinations and Settings/subscreens in the AppShell-owned Navigator. Keep global modal sheets and dialogs on the root Navigator so they cover the entire AppShell route, including Settings and the pinned toolbar.

Place `GlassNavigationShell` inside the AppShell page around the tab body and its toolbar Navigator, not outside the root Navigator in `CupertinoApp.builder`. The root route's delegated modal transition then dims the body and pinned chrome together, and the root sheet is above both. Do not apply an inverse scale to the toolbar for these root-level sheets; the shell remains at its settled geometry.

Keep stable `GlassBarItem` IDs and icon-content identity when destinations reuse an item with a different glyph. Refresh local toolbar route state after its own screen route finishes popping; root modal dismissal does not change the local toolbar route stack.

**Why:** The package renders pinned chrome above the Navigator it encloses and ranks registrations using route coverage within that Navigator. A sheet pushed only into the AppShell Navigator cannot cover sibling tab bodies, and the root AppShell route cannot dim a shell hosted outside its subtree.

**How to apply:** Use the nested AppShell Navigator for tab/Settings route changes and the root Navigator for app-wide presentations. Test that both body and toolbar share the root route's dim filter, the sheet blocks underlying taps, and toolbar bounds remain unchanged while it is open.
