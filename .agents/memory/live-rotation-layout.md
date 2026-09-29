---
name: Live rotation layout
description: The app must let adaptive layout receive intermediate window sizes during the native rotation animation.
---

Keep the root widget tree attached to Flutter's live window constraints while orientation changes. Do not replace the active MediaQuery size with the last settled portrait or landscape size, and do not defer the layout switch until the metrics stream becomes quiet. Descendant LayoutBuilders should see each intermediate width and height so wrapping, picker capacity, container widths, and trailing alignment adapt during the stretch/squish portion of rotation.

**Why:** Freezing the last settled size makes the entire app retain its old composition until rotation finishes, which produces a visible late snap instead of adapting during the transition.

**How to apply:** When changing orientation or window-metrics handling, preserve live MediaQuery propagation and validate both phone-sized and landscape-sized previews after the web bundle rebuilds.