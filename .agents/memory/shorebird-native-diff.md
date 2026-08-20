---
name: Shorebird native diff safety check
description: Why an Android Shorebird patch pauses with DEX field and method differences.
---

Shorebird patches can replace Dart code only. If its DEX comparison reports removed or added Android fields and methods, the patch build no longer matches the native baseline of the installed release.

**Why:** Native plugin changes, generated Android registrant changes, Gradle/Flutter changes, dependency changes, or a release built from an earlier commit cannot be safely delivered as a Dart-only patch.

**How to apply:** Do not pass `--allow-native-diffs` for a normal patch. Rebuild and publish a new Shorebird release from the current native baseline, then patch that new release; alternatively restore the exact source, lockfile, Flutter SDK, and native generated files used by the existing release.