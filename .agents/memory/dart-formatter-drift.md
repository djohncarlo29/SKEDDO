---
name: Dart formatter drift
description: The installed Dart formatter can rewrite large portions of this project’s legacy Flutter files.
---

The workspace contains legacy Dart formatting that is not stable under every installed formatter version; a whole-file format can create broad unrelated diffs.

**Why:** A routine format pass on a large tab file changed many unrelated line breaks and indentation patterns, obscuring the functional diff.

**How to apply:** Prefer targeted syntax checks and diff checks. Only format a narrowly scoped file when the resulting formatting churn is acceptable, and inspect the diff immediately afterward.