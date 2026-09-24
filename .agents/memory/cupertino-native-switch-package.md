---
name: Native iOS switch routing
description: Route app-owned switches through the native iOS switch while preserving Liquid Glass on other platforms.
---

Use `CNSwitch` from `cupertino_native` only when `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`. This package's iOS implementation hosts a SwiftUI `Toggle`, which renders Apple's native switch. Keep the existing `LiquidGlassSwitch` for web, Android, macOS, and other non-iOS platforms.

**Why:** The app's established appearance outside iOS is Liquid Glass, and web can report an iOS target platform while running in a browser. The web guard prevents the native platform view from being selected there.

**How to apply:** Keep all app-owned switches on the shared wrapper. Verify the wrapper's native iOS branch and retain the non-iOS fallback; browser builds validate compilation and fallback behavior, not native iOS rendering.