---
name: Flutter web preview rebuilds
description: How Dart changes reach the compiled Flutter web preview in this workspace
---

The Smart Scheduler preview workflow serves a compiled Flutter web build rather than an active Flutter hot-reload session. Dart file timestamp changes do not reliably update the visible preview; restart the managed preview workflow after Dart edits when visual verification matters.

**Why:** Repeated icon adjustments appeared unchanged because the preview was still serving the previous compiled bundle. A workflow restart rebuilt and served the latest source.

**How to apply:** After Dart UI changes, use the existing `artifacts/smart-scheduler: expo` workflow restart before judging the rendered result; a cold rebuild can exceed the workflow's readiness window even when `flutter build web` succeeds; do not build an APK unless explicitly requested.