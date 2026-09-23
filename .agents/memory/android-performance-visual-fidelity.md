---
name: Android performance visual fidelity
description: Product constraint for improving Android performance without removing designed visual treatments.
---

Performance work must preserve the app's full glass, bloom, motion, and interaction treatment across platforms. Optimize the amount and timing of work around those effects, and use measured profiling to find bottlenecks; do not replace them with Android-only solid fallbacks or remove intentional motion without explicit approval.

**Why:** The visual details are intentional product behavior, not optional decoration. A faster app that loses those details is not an acceptable result.

**How to apply:** Keep the existing rendering path as the baseline. Prefer reducing redundant rebuilds, bounding expensive work without changing appearance, caching safely, and tuning animation implementation only when the visual output remains equivalent.