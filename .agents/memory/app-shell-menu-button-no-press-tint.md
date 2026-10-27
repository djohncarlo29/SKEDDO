---
name: App-shell hamburger/X appearance
description: Geometry, settings response, and press feedback for the AppShell's LiquidGlassButton.
---

The AppShell toolbar stays free of tap-time darkening or lightening and follows
the shared Liquid Glass setting. Regular app screens use the hamburger with
their normal actions; Settings uses X with no search/create actions, and
portrait Settings sub-screens use a back chevron with no search/create actions.
Detailed Category View changes the hamburger to a back chevron.

Toolbar changes must use `GlassNavigationShell` route registrations with stable
item IDs. Morph the Liquid Glass group when its item set or destination changes;
do not tween the hamburger strokes into the X or chevron.

**Why:** The user means the package's physical toolbar morph, not a custom glyph
animation. Tab, search, Settings, and Detailed Category View are distinct
toolbar destinations even when the main screen content remains mounted.

**How to apply:** Keep transparent splash/highlight settings scoped to this
control. Use the shared settings-based Liquid Glass appearance; retain the
40px circle at safeTop + 10px and horizontalInset + 16px.
