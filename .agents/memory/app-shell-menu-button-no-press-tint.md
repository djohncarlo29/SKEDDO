---
name: App-shell hamburger/X appearance
description: Geometry, settings response, and press feedback for the AppShell's LiquidGlassButton.
---

The AppShell toolbar stays free of tap-time darkening or lightening and follows
the shared Liquid Glass setting. Regular app screens use the hamburger with
their normal actions; Settings uses X with no search/create actions, and
portrait Settings sub-screens use a back chevron with no search/create actions.
Settings sub-screen back returns to the main Settings panel; Settings-root X
returns to AppShell; Detailed Category View back returns to the Events tab.
Landscape Settings detail panes are in-place destinations and must expose the
same back action on the shared toolbar.

Reuse a `GlassBarItem` ID across destinations only while its glyph is unchanged.
Menu, close, and back glyph states need distinct IDs: matching IDs tell
`GlassNavigationShell` the item persists and skip the package's
materialize/blur choreography. Keep shared IDs for menu-to-menu transitions and
for action items that genuinely persist across screens. Set the shell's
`effectTransition` to `GlassEffectTransition.materialize`; do not custom-tween
the hamburger strokes into the X or chevron.

Search mode must remove the toolbar registration, not just make it transparent
or pass empty item lists. Also gate the outgoing toolbar route synchronously
when search begins: its route remains mounted during replacement, and its
invisible hit targets can block the search cancel control.

**Why:** The user means the package's physical toolbar morph, not a custom glyph
animation. A matched item ID explicitly suppresses the package's appearance
transition, while a hidden-but-mounted search toolbar still intercepts taps.
Tab, search, Settings, and Detailed Category View are distinct toolbar
destinations even when the main screen content remains mounted.

**How to apply:** Keep transparent splash/highlight settings scoped to this
control. Use the shared settings-based Liquid Glass appearance; retain the
40px circle at safeTop + 10px and horizontalInset + 16px. In search mode,
unregister both the current and outgoing toolbar before the cancel control
needs input.
