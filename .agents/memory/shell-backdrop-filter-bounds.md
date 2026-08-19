---
name: Shell backdrop filter bounds
description: Android constraints for always-mounted frosted-glass controls in the app shell
---

Permanent shell controls should not use `BackdropFilter`; use a clipped
translucent surface instead. Even with an apparently bounded clip, a backdrop
filter in the floating shell can render as a slightly opaque rectangular halo
in the preview or a grey veil over the entire app on Android.

Full-screen shell surfaces positioned off-screen with a transform should also
be taken offstage after their close animation. Android can retain the
transformed layer's paint or hit-test participation even when its offset places
it outside the viewport.

**Why:** The floating navigation bar remains mounted in the root Stack,
unlike transient Action Panels. Android and the web renderer can expand or
mis-handle that backdrop layer even when the visual control is small.

**How to apply:** Set `enableBackdropFilter: false` for permanently mounted
shell controls and keep the shared frosted material reusable for transient
panels with their existing sampling behavior. Full-screen transformed panels
must also be taken offstage after their close animation so they cannot paint or
hit-test while closed.