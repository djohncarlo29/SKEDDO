---
name: Temporal composition API compatibility
description: Shared event temporal composition must use the canonical model copy API and keep date/time precision enums distinct.
---

## Rule
When composing ParsedDate values for create and update, use the model's current parsed-date copy method and pass `TimePrecision` only to the time-precision field; `TemporalPrecision` is for calendar precision.

**Why:** The shared composition refactor exposed stale helper naming and an enum mismatch that static analysis caught; its parser migration also needed to preserve relative offsets and period expressions.

**How to apply:** Before compiling temporal changes, verify model helper names and enum parameter types, then run the focused Flutter analyzer and pure-Dart AI tests with the project-compatible Flutter SDK.