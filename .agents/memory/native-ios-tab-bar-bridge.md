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

On Flutter-rendered Android/web, landscape navigation is intentionally wider than portrait. Give landscape tabs equal fixed-width slots sized for inline icon-and-label content, clamp the pill to available space, and keep portrait sizing unchanged.

**Why:** The user clarified that landscape should be a longer horizontal version of the portrait bar, not the same-width portrait control with the labels rearranged.

**How to apply:** Keep the four landscape tab slots equal in width even when labels have different lengths. Use the fixed landscape width where it fits; allow the package bar to clamp all slots equally on narrow screens.

On the Flutter-rendered bar, landscape destinations use similar-sized inline icons and labels; portrait keeps the existing larger-icon/smaller-label stack. Preserve `GlassTabBar.bottom`, the selected indicator, selection routing, and the separate create button.

**Why:** The reference uses balanced icon and label sizes and equal-width destinations rather than carrying portrait proportions into landscape.

**How to apply:** Compose horizontal item content inside the package tab configuration, with equal tab slots and a wider landscape pill; do not replace the glass bar or move its actions.

Landscape inline item typography uses a 16pt SF icon beside a 12pt label.

**Why:** The user clarified that the icon and text should have balanced visual
weight, rather than simply inheriting the larger icon and tiny caption used by
the portrait stacked layout.

**How to apply:** Keep these base sizes specific to the landscape inline item;
portrait icon and label sizing remains unchanged.