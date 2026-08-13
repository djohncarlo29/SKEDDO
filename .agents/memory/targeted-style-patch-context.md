---
name: Targeted style patch context
description: Avoid applying repeated style changes to the wrong nearby widget.
---

When changing repeated style properties such as `fontSize`, anchor the edit with a unique nearby widget label or enclosing component rather than a generic property line.

**Why:** Repeated values in a large Dart file can cause a context-light patch to modify an adjacent, unrelated widget while leaving the intended occurrence untouched.

**How to apply:** After any repeated-style edit, inspect `git diff`, run an occurrence-aware search, and confirm the surrounding widget identity for every intended change.