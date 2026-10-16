---
name: Shorebird patch and release workflow
description: Combined index of the project's Shorebird patch constraints and release checks.
---

Before patching, use workspace temporary storage, scan for committed merge markers, and enforce the app and cached dependency SDK constraints. The installed CLI accepts targets through `shorebird patch --platforms <target>`, not as a positional argument. A native DEX/API difference means the patch no longer matches the installed baseline; publish a full release instead. Verify the generated APK and release handoff separately from build success.

**Why:** A patch can fail for invalid CLI syntax, environmental, source-preflight, SDK, or native-baseline reasons even when the Flutter build itself succeeds.

**How to apply:** Pass the target with `--platforms`, and consult the focused notes for [temporary storage](shorebird-patch-env.md), [conflict-marker preflight](shorebird-conflict-marker-preflight.md), [SDK constraints](shorebird-sdk-constraint.md), [native diffs](shorebird-native-diff.md), and [release verification](shorebird-release-build-verification.md).
