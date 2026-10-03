---
name: Android performance visual fidelity
description: Product constraint for improving Android performance without removing designed visual treatments.
---

Performance work must preserve the app's full glass, bloom, motion, and interaction treatment across platforms. Optimize the amount and timing of work around those effects, and use measured profiling to find bottlenecks; do not replace them with Android-only solid fallbacks or remove intentional motion without explicit approval.

**Why:** The visual details are intentional product behavior, not optional decoration. A faster app that loses those details is not an acceptable result.

**How to apply:** Keep the existing rendering path as the baseline. Prefer reducing redundant rebuilds, bounding expensive work without changing appearance, caching safely, and tuning animation implementation only when the visual output remains equivalent.

For renderer-dependent Android effects such as the modal scroll-edge blur, widget tests and the Flutter web preview do not establish physical-device visual correctness. Do not call the effect visually verified until the user has tested the actual build on a physical Android device.

**Why:** Android Impeller can report shader-filter support while this app's prior runtime-shader path still rendered no visible effect on some devices.

**How to apply:** Keep code/test success separate from Android visual acceptance; require the user's physical-device test before reporting this effect as verified.