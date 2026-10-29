---
name: Native accent source limits
description: Platform behavior when mirroring the operating system's accent color.
---

Android 12+ exposes a wallpaper-derived dynamic palette. On iOS, `system_theme` reads SwiftUI `Color.accentColor`; iOS does not provide a user-configurable, global accent-color preference.

**Why:** The iOS value is a native accent seed, typically the standard system blue, and should not be described as a user's global Settings choice.

**How to apply:** Use Android's dynamic palette when available, use the native iOS accent as a seed, refresh after resume, and keep the app's brand color as the unsupported-platform fallback.
