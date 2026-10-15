---
name: Liquid Glass platform compatibility
description: Combined index of package-version, local-fork, and platform-routing constraints.
---

Keep the app-specific Liquid Glass fork intact, verify package compatibility against the pinned Flutter toolchain, and use native iOS switch controls only on native iOS; retain the Flutter switch elsewhere.

**Why:** Broad upstream upgrades can remove APIs used by existing controls, and unsupported shader or platform paths can break otherwise valid UI.

**How to apply:** Check the focused notes for [native switch routing](cupertino-native-switch-package.md), [Flutter/package version compatibility](liquid-glass-widgets-compatibility.md), and [local fork compatibility](liquid-glass-easy-fork-compatibility.md) before changing dependencies or platform branches.
