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

Keep Android `BackdropFilter` directly over the sharp scroll content; wrapping it in `ShaderMask` with `BlendMode.src` can isolate the backdrop in a temporary layer and erase the visible blur. `ImageFilter.isShaderFilterSupported` is a capability signal, not proof that this runtime shader renders correctly on a device.

**Why:** A high-opacity raster probe showed the direct filter blurring its source while the masked `src` composition left the source sharp; Android shader output has also varied by renderer.

**How to apply:** Prefer the direct clipped Android fallback, log the reported capability and selected path for diagnostics, and reserve visual acceptance for an actual Android-device check.