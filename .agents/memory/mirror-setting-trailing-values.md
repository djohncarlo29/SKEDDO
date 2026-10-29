---
name: Mirror-setting trailing values
description: Consistent trailing values for settings that can mirror the operating system.
---

For a setting with Mirror System Setting and App Only sections, show the canonical `System` trailing value when the system row has no detail, or `System (detail)` when it does. App Only mode continues to show its selected app value.

**Why:** A system-derived detail should be available from the same native state shown in the system row; guessing or omitting an available detail makes similar settings inconsistent.

**How to apply:** Use the shared trailing-value formatter and pass only the detail displayed by that setting's Mirror System Setting row. Never infer labels from unrelated app options or nearest swatches.
