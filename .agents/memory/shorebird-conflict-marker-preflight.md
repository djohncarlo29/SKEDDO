---
name: Shorebird conflict-marker preflight
description: Merge conflict markers in Dart source cause Shorebird to emit misleading cascades such as "'double' isn't a type".
---

Before pushing a Shorebird patch, scan Dart and native project sources for `<<<<<<<`, `=======`, and `>>>>>>>`. These markers can be committed accidentally and make the compiler report unrelated built-in types as invalid.

**Why:** Shorebird's release compiler reports the first malformed declaration and then cascades through nearly every Dart type, obscuring the real source problem.

**How to apply:** Keep the patch script's preflight check ahead of the Shorebird command and fail with the offending file and marker lines. Resolve the merge before attempting `--allow-native-diffs` or changing dependencies.