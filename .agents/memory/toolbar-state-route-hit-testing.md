---
name: Toolbar state-route hit testing
description: Give pinned toolbar routes real morph timing without covering the app body or disabling changed controls.
---

Keep toolbar-only transition routes in a sibling nested `Navigator` above the indexed app body. Use opaque routes there so `GlassNavigationShell` receives real secondary-animation progress, while the route page itself stays transparent and ignores pointer input. A synthetic non-opaque route in the root navigator can leave progress at zero, keeping the outgoing toolbar controls visible or disabling the incoming ones.

Keep the primary `GlassBarItem` ID and icon-content identity stable across destinations when only its glyph changes. Render the current glyph inside a stable `Icon` wrapper so the package morphs the glass group rather than crossfading a different toolbar item.

**Why:** The navigation package derives morph progress from route coverage and matches persistent items by identity/content. A transparent root route can remain at zero progress, leaving outgoing controls on top and non-interactive. Separately, a non-opaque route's modal barrier can consume taps even if its page widget ignores pointers.

**How to apply:** Put only toolbar-state routes in the sibling navigator, keep the main tab subtree alive underneath, and test physical taps on both the changing leading item and the pass-through app body.
