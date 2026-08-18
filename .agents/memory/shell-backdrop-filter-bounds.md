---
name: Shell backdrop filter bounds
description: Android constraints for always-mounted frosted-glass controls in the app shell
---

Permanent shell controls that use `BackdropFilter` must have an explicit finite
clip matching the control's bounds, and should use clamped blur sampling. An
unbounded or decal-sampled filter in the shell overlay can render as a
slightly opaque grey veil over the entire app on Android even when the visual
control itself is small.

**Why:** The floating navigation bar remains mounted in the root Stack,
unlike transient Action Panels. Android can expand or mis-handle that
backdrop layer when its bounds are not enforced.

**How to apply:** Wrap always-on glass shell controls in a finite `ClipRect`
and opt them into `TileMode.clamp`; keep the shared frosted material reusable
for transient panels with their existing sampling behavior.