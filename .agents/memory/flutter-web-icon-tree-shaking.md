---
name: Flutter web icon tree-shaking
description: The Smart Scheduler preview build must disable icon tree-shaking because user-persisted category icons use runtime IconData.
---

The preview launcher uses `flutter build web --no-tree-shake-icons`; keep that flag when validating or changing the web workflow.

**Why:** Category icons are reconstructed from persisted code points and font metadata, so Flutter cannot statically tree-shake every IconData instance. A plain release web build can fail even when the app source is otherwise valid.

**How to apply:** Treat a standalone build failure mentioning non-constant IconData as a command-flag mismatch first. Validate through the configured preview workflow, or pass `--no-tree-shake-icons`.