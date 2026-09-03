---
name: Flutter preview build directory
description: Native Flutter builds can remove the web preview bundle while its static server remains running.
---

When building the native APK, a Flutter clean can delete `build/web` while the
preview server is still listening on its port. The server then returns 404 or
an apparently blank page until the managed preview workflow rebuilds the web
bundle.

**Why:** The native and web workflows share the same Flutter project and build
directory, so cleaning one target invalidates the other target's served files.

**How to apply:** After any native clean/build, restart the managed web preview
before debugging routing or application code. Avoid running the native build
workflow while the web preview is the only required deliverable.