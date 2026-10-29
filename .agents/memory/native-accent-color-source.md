---
name: Native accent source limits
description: Platform behavior when mirroring the operating system's accent color.
---

Android 12+ exposes a wallpaper-derived dynamic palette. On iOS, `system_theme` reads SwiftUI `Color.accentColor`; iOS does not provide a user-configurable, global accent-color preference.

System accent APIs provide color values, not canonical human-readable names. Never assign the nearest app-swatch name to a system color; use “System Setting” when the platform supplies no name.

**Why:** Reusing an app swatch name can imply the system color has that swatch's exact color value, even when it does not.

**How to apply:** Use Android's dynamic palette when available, use the native iOS accent as a seed, refresh after resume, and keep the app's brand color as the unsupported-platform fallback. Do not infer a semantic name from RGB proximity.
