---
name: Native iOS tab bar bridge
description: How the Flutter shell uses classic native tabs on older iOS and floating native tabs on iOS 26+.
---

Use a native `UITabBarController` overlay on iOS versions supported by the app. UIKit supplies the classic bottom bar on versions before iOS 26 and the floating Liquid Glass presentation on iOS 26+. Keep the Flutter tab pill on web and Android, and keep Flutter responsible for the actual tab content and selected-index state.

**Why:** A SwiftUI `TabView` cannot replace one Flutter widget in place without moving the app’s tab content into native hosting controllers. The UIKit overlay can provide OS-appropriate native tab chrome while preserving Flutter’s existing content and navigation lifecycle. The classic bar is edge-anchored, so it needs different scroll clearance from the floating pill.

**How to apply:** Keep native child controllers transparent and pass hit testing through to Flutter outside the native tab-bar subtree. Bridge native selection to Flutter and programmatic selection back to native. Report whether UIKit is using the floating style so shared Flutter content padding reserves either the classic bar plus bottom safe area and at least a 16 px content gap, or the floating pill plus its offset and gap. Preserve any larger per-section gap. Browser previews cannot verify native UIKit rendering.

Keep tab colors synchronized from Flutter by sending both the resolved active accent and inactive theme color through the native bridge. The app's selected Light/Dark appearance can differ from UIKit's trait collection, so a native-only dynamic color may not match the Flutter pill.

**Why:** The app supports an appearance override independent of the device's system appearance; UIKit trait-based colors alone can therefore show the wrong inactive tint.

**How to apply:** Resolve both colors from the same Cupertino theme context used by the Flutter tab pill, send them together, and verify the light and dark pairs.

On web and Android, use `flutter_liquid_glass_widgets`' `GlassTabBar.bottom` for the Flutter-rendered floating bar. Its pill and separate trailing action use a 49 logical-pixel height. Size `FixedSFIcon` glyphs explicitly because `iconSize` only supplies an `IconTheme`; the extra button has independent glyph sizing. The package bar's private explicit preset bypasses `GlassTheme`.

**Why:** Theme-only dark overrides do not reach the bar because its explicit settings take precedence. Applying every field from the package's general dark theme weakens thickness and refraction while increasing blur, making the surface look like a frosted overlay. A high-opacity charcoal replacement also darkens content seen through the glass.

**How to apply:** Keep the UIKit overlay on native iOS. For web/Android, preserve AppShell positioning and navigation state around `GlassTabBar.bottom`, keep the pill and `extraButton` at 49 logical pixels, and size custom SF glyphs directly without changing the separate plus action. Merge only the package dark variant's tint and lighting into the bottom-bar preset; preserve its optical thickness, refraction, dispersion, saturation, and blur.

On Flutter-rendered Android/web, keep the navigation pill at its portrait width when rotating to landscape. Reposition it for the new viewport without resizing it; animate explicit horizontal pane offsets separately.

**Why:** Clamping the pill to landscape constraints and animating both left and right edges makes the whole control visibly shrink and expand during rotation, unlike the steady-width navigation the user expects.

**How to apply:** Use the cached portrait width (or the short screen edge minus the standard margins when launched in landscape) as the bar width in both orientations. Give the positioned bar an explicit fixed width and animate only `horizontalOffset`, never its width.

On the Flutter-rendered bar, landscape destinations use an inline icon-left/label-right layout; portrait keeps the existing icon-over-label layout. Preserve `GlassTabBar.bottom`, the selected indicator, selection routing, and the separate create button.

**Why:** The user requested the landscape arrangement to match the supplied reference without changing the portrait design or navigation behavior.

**How to apply:** Compose the horizontal item content inside the package tab configuration rather than replacing the glass bar or moving its actions.