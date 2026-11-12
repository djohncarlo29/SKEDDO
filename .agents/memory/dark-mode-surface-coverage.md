---
name: Smart Scheduler dark-mode surface coverage
description: Theme guidance for surfaces that bypass Cupertino's automatic dynamic-color resolution
---

Shared custom-painted and decorated surfaces must resolve their appearance at the
widget build boundary instead of relying on CupertinoDynamicColor to resolve
inside arbitrary `Color` or `BoxShadow` values. This includes frosted-glass fills,
attachment/document previews, import scrims, modal handles, action-menu press
states, and attachment card borders/shadows.

**Why:** These surfaces are frequently built with `ColoredBox`, `ShapeDecoration`,
`CustomPaint`, or custom overlays, where a raw light color can remain visible even
when the surrounding `CupertinoApp` is dark.

**How to apply:** Add a semantic dynamic color in `app_theme.dart`, resolve it
with `resolveThemeColor` or `CupertinoDynamicColor.resolve` in the build method,
and use the resolved value for custom painting. Resolve `TextStyle.color` before
passing styles to platform-backed inputs, picker text, SF Symbols, or other
widgets that may not resolve CupertinoDynamicColor themselves. Keep intentional
white-on-accent icons/text and image/export colors unchanged.

All app glass renderers share `kSkeddoSharedGlassRimStrength = 1.0`, matching
the brighter toolbar/tab-bar edge. Apply it to package `fresnelStrength` and
app-owned specular edges once; keep per-theme key lighting, tint, and blur
separate. Dark interaction glow remains an independent setting.

**Why:** Applying a 0.5 reduction through several renderer-specific inputs
made the Calendar menu rim noticeably weaker than the toolbar and tab bar.

**How to apply:** When adding an app glass surface, use the shared rim-strength
constant for its rim control and do not apply another Dark Mode multiplier.
The lightweight shader also uses `fresnelStrength` to scale its fixed
structural rim in Dark Mode.