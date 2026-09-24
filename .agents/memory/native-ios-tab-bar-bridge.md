---
name: Native iOS tab bar bridge
description: How the Flutter shell adopts Apple’s iOS 26 floating tab bar without rewriting tab content.
---

On iOS 26+, use a native `UITabBarController` overlay for the floating Liquid Glass tab bar and bridge selection through a Flutter method channel; keep the Flutter tab pill for web, Android, and older iOS.

**Why:** A SwiftUI `TabView` cannot replace one Flutter widget in place without moving the app’s tab content into native hosting controllers. UIKit’s system tab-bar controller provides the same Apple-owned iOS 26 presentation while preserving Flutter’s existing content and navigation lifecycle.

**How to apply:** Keep native child controllers transparent and pass hit testing through to Flutter outside the native tab-bar subtree. Flutter remains responsible for tab content, search cleanup, and selected-index state; native selection sends an event to Flutter, and Flutter can push programmatic selection back to native.