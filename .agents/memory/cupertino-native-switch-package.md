---
name: Cupertino native switch package
description: The iOS-native CNSwitch implementation uses cupertino_native, not cupertino_native_plus, with an iOS 14 Podfile target.
---

For the native UISwitch-backed CNSwitch, use the `cupertino_native` package and import `package:cupertino_native/cupertino_native.dart`. Keep the iOS Podfile and Xcode deployment target at 14.0 or higher. Wrap it in the app's shared switch widget so Android and web use a CupertinoSwitch fallback instead of the package's Material Switch.

**Why:** `cupertino_native_plus` exposes a similarly named CNSwitch but does not provide the same package/API/platform implementation the iOS 26 examples refer to.

**How to apply:** When adding or reviewing switch controls, verify the dependency/import and remember that browser preview validates compilation and fallback behavior, not native iOS rendering.