---
name: Smart Scheduler theme constants — one constant per distinct usage
description: Naming/reuse convention for app_theme.dart color and icon constants after a user correction; don't collapse visually-similar-but-distinct surfaces into one shared constant.
---

In `artifacts/smart-scheduler/lib/app_theme.dart`, colors and icons that are
conceptually distinct get their own named constant even if an existing
constant happens to have the same value at the time. This came from a direct
user correction: an earlier fix reused `kBackgroundColor` for the color
painted behind the receding Navigator stack while a `CupertinoSheetRoute`
(e.g. the "Add Category" sheet) is open. The user wanted that surface
independently tunable, so it now has its own constant,
`kAddCategorySheetBackground` (light `#C7C6CB` / dark `#000000` — deliberately
different from `kBackgroundColor`'s light value), used only in the
`CupertinoApp.builder` in `main.dart`.

Similarly, the search bar's mic-icon-to-clear-button crossfade uses a "circle
x" icon (`CupertinoIcons.clear_circled_solid`) that's now named
`kSearchClearCircleIcon` in `app_theme.dart` rather than being an inline
literal in `search_bar_widget.dart`.

**Why:** the user explicitly flagged the reuse as "a mistake" — a shared
background constant made two independently-designed surfaces impossible to
theme separately. When adding theme values, default to a new named constant
per distinct UI surface/purpose, not reuse-by-coincidence-of-value.

**How to apply:** before wiring a color/icon literal into `app_theme.dart`,
check whether it represents a genuinely new surface (sheet backdrop, a
specific icon's identity, etc.) vs. truly the same design token — if in doubt,
 prefer a new constant.

Gel-bloom circular dismiss and back controls use the resolved card surface for
their circle container and the resolved primary label/accent color for the
X or chevron glyph. Controls on modal sheets use the modal card surface;
non-modal controls such as search exit use the regular card surface. Confirm
buttons remain accent-colored with white icons.

**Why:** this is the intended visual rule for the app's circular navigation
controls, so dark-mode surfaces and icon contrast stay consistent across tabs.

**How to apply:** shared non-modal circle-button defaults should use
`kCardColor`; modal-sheet button defaults should use `kModalCard`; dynamic icon
colors should be resolved at the widget build boundary.

Fixed vertical breathing room is a shared layout token, not a search-only
literal. Search bars use it for their inner top and bottom insets, while their
text line height is measured from the ambient OS text scaler; settings rows and
category/list rows that follow the same 16 pt rule should reuse the same token.

**Why:** a fixed outer control height makes text scaling collide with the
authored inset, and separate literals let pinned, overlay, and settings hosts
drift apart.

**How to apply:** keep the 16 pt token fixed, let only the text line grow, and
derive any pinned-header or off-screen placeholder extent from the scaled line
height rather than a hardcoded search-bar height.

Search-bar horizontal edge insets are also fixed at 16 pt: keep the leading
search-icon inset and the trailing mic/clear-icon inset outside the text scaler,
and let the trailing slot grow with the scaled icon instead of constraining it
to a fixed width.

**Why:** Dynamic Type should resize the text and icons without changing the
authored distance between either search-bar edge and its edge icon.

**How to apply:** use one shared horizontal inset token at the row edges and
inside the trailing icon slot; do not compensate with a text-scaled gap or a
fixed-width slot.

Clear-search glyphs outside the main search bar should follow the same ambient
text scaler; keep their containing row's authored right inset and grow the
action slot only when the scaled glyph needs more room.

**Why:** modal-sheet clear actions were still hard-coded at their compact icon
size, so they diverged from the main search control at larger OS text sizes.

**How to apply:** scale the glyph from its authored size at build time, remove
const wrappers that prevent that, and preserve the existing row-edge padding.
