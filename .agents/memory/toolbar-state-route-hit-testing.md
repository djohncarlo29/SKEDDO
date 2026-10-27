---
name: Toolbar state-route hit testing
description: Separate app-shell screen navigation from root modal presentation so pinned chrome stays under the sheet.
---

Keep toolbar destinations and Settings/subscreens in the AppShell-owned Navigator. Keep global modal sheets and dialogs on the root Navigator so they cover the entire AppShell route, including Settings and the pinned toolbar.

Place `GlassNavigationShell` inside the AppShell page around the tab body and its toolbar Navigator, not outside the root Navigator in `CupertinoApp.builder`. The root route's delegated modal transition then dims the body and pinned chrome together, and the root sheet is above both. Do not apply an inverse scale to the toolbar for these root-level sheets; the shell remains at its settled geometry.

Keep stable `GlassBarItem` IDs and icon-content identity when destinations reuse an item with a different glyph. Refresh local toolbar route state after its own screen route finishes popping; root modal dismissal does not change the local toolbar route stack.

Key toolbar routes by their visible glyph/action configuration, not by the destination screen. Tabs with the same toolbar should keep the same route. When the configuration changes, push the incoming toolbar route so both registrations participate in the package morph; prune the previous toolbar-only routes once the incoming transition settles.

**Why:** The package renders pinned chrome above the Navigator it encloses and ranks registrations using route coverage within that Navigator. `pushReplacement` can deactivate the outgoing registration before it is available as the morph source; replacing routes for content-only tab changes also needlessly restarts chrome. A sheet pushed only into the AppShell Navigator cannot cover sibling tab bodies, and the root AppShell route cannot dim a shell hosted outside its subtree.

**How to apply:** Use the nested AppShell Navigator for tab/Settings route changes and the root Navigator for app-wide presentations. Test that unchanged configurations stay settled, changed configurations morph without an empty frame, and both body and toolbar share the root route's dim filter.
