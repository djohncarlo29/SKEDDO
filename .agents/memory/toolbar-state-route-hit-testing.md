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

## Pinned menus and anchors

Use `GlassBarItem.menu` when the shared toolbar capsule itself should morph into an action menu; the package owns the trigger geometry and morph. If a custom overlay menu is required instead, do not put a `GlobalKey` on an individual pinned action's icon subtree. Give each toolbar-route instance its own key at the route-level `AppShellPinnedToolbar`, then derive custom-menu anchors from that toolbar frame and the package's slot dimensions.

**Why:** The package menu already anchors and morphs the whole capsule. For custom overlays, the navigation shell paints a hoisted copy of pinned action icons as well as the in-route registration. A key inside an icon is therefore mounted twice and triggers a duplicate-key failure; a configuration-keyed frame key can also collide during fast overlapping route transitions.

**How to apply:** Prefer `GlassBarItem.menu` for capsule-to-menu transitions. For a custom overlay, keep action widgets keyless, capture a fresh frame key per toolbar route instance, and calculate the action rectangle from its measured frame, toolbar insets, and shared-slot extent.

## Dynamic menu contents

When a pinned menu's selected or conditional rows depend on state that can change while the visible toolbar configuration stays the same, rebuild the route-owned toolbar action list through a notifier included in that route's builder.

**Why:** The pinned toolbar lives in its own route registration; a parent `setState` does not guarantee that the active route rebuilds its menu item list.

**How to apply:** Increment the menu-content revision after changing menu state or changing the active DCV category, and listen to it from the toolbar route builder.

## Menu selection surface

The sliding row surface is presentation only. A menu can hide that pill while keeping the hovered/pressed row state that drives its press-scale feedback.

**Why:** Some toolbar menus should open visually neutral and show only the item's direct interaction response; turning off selection tracking would also remove useful press/slide behavior.

**How to apply:** Disable only the selection-pill rendering for those menus. Keep pointer and drag state active; leave the package default enabled for other `GlassMenu` callers.
