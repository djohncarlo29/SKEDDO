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

The in-route pinned-bar placeholder must not intercept the empty center of the
header while the shell owns the real hit targets. In search mode, disable all
toolbar actions, slide the pinned toolbar and ordinary header content above the
viewport, then remove the registration after the slide. Restore the registration
before sliding it back down, and re-enable actions only after it settles.

**Why:** The transparent, full-width in-route app bar can intercept taps on
controls underneath it even when the pinned shell draws the visible buttons
separately. The search bar also needs a real unobstructed header after the
toolbar and normal header have moved out of view.

**How to apply:** Keep the toolbar's registration and button identities stable
through the exit motion, while ensuring the body remains stationary. The
hoisted shell owns toolbar taps; the in-route copy is only a placeholder while
pinning is active. Keep transparent splash/highlight settings scoped to this
control and preserve its existing placement and shared glass appearance.

## Two-action trailing toolbar order

When a trailing toolbar contains Search and one screen-specific action, place
Search first and the other action at the rightmost position. Solo Search
toolbars remain unchanged.

**Why:** The user wants Search to consistently occupy the left side of every
two-icon trailing toolbar.

**How to apply:** Preserve each item's stable ID and behavior; only reorder the
shared action list.

## Trailing action icon alignment

Pinned trailing toolbar icons other than Search share a 3.5px left visual
translation. Search retains its existing position. Do not apply the normal
calendar header's separate optical offsets to the other action icons.

**Why:** The user requested a consistent 3.5px left adjustment for screen-specific
trailing actions, while Search and in-content header alignment remain unchanged.

**How to apply:** Apply the translation in the pinned action icon wrapper so
screen-specific icons move together without changing their slots.

## Trailing action icon alignment

Pinned trailing action icons use their unshifted centered geometry. Optical
offsets used by the normal calendar header must not be applied to these action
icons.

**Why:** The user requested removing offsets from every icon in the trailing
toolbar without changing the separate in-content header icons.

**How to apply:** Build calendar action icons with `applyOpticalOffset: false`;
keep the default offset behavior for icons still used in the normal header.
