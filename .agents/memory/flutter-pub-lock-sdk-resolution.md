---
name: Pinned Flutter dependency resolution
description: How the managed Flutter preview's pinned SDK affects transitive lockfile versions
---

The managed Flutter preview runs dependency resolution with the pinned Flutter 3.44.2 / Dart 3.12.2 toolchain before compiling. A lockfile produced by a different Dart SDK can be rewritten to compatible transitive versions and SDK metadata.

**Why:** The preview's actual dependency resolution depends on its pinned SDK, so restoring newer locked transitive packages can make the workspace inconsistent with the toolchain.

**How to apply:** After restarting the Flutter preview, inspect any `pubspec.lock` changes in the context of the pinned SDK. Keep the solver-produced lock when it resolves cleanly; do not hand-edit package hashes.

For Drift code generation on this toolchain, Flutter pins `meta` at 1.18.0 while newer `build_runner` releases pull analyzer/build versions requiring newer `meta`. Keep `build_runner` within the solver-compatible range (currently `^2.15.1`) unless Flutter is upgraded as a coordinated toolchain change.

**Why:** The solver rejects the newer builder/analyzer chain even though the Dart SDK constraint alone appears compatible.

**How to apply:** When adding code generators, resolve against the project's pinned Flutter SDK first; lower only the generator version needed to satisfy the SDK's pinned transitive packages.
