---
name: Liquid Glass Easy fork compatibility
description: Compatibility constraints for upgrading the app's customized liquid_glass_easy dependency.
---

Keep the local `liquid_glass_easy` fork unless existing app integrations are deliberately migrated with it. When an upstream widget is needed, prefer porting that isolated component into the fork over replacing the dependency wholesale.

**Why:** Moving the app to upstream 4.3.4 caused compile errors in existing app-specific glass slider, switch, and navigation APIs.

**How to apply:** Before upgrading the dependency, compare the fork's public exports and constructor signatures with the target release, then migrate or preserve every app call site and verify the full Flutter build.