---
name: Floating bar rim compositing
description: Layer ordering for the Floating Tab Bar hairline and lifted glass pill
---

The Floating Tab Bar’s custom 0.5px rim must be painted into the backdrop before
the bodyless Impeller glass bar overlay. The lifted active pill then captures and
refracts the rim underneath it, while the bar’s own edge treatment preserves the
visible outer silhouette.

**Why:** A rim painted after the glass overlay is a final composited layer, so it
stays perfectly crisp through the active pill and visibly ignores refraction.

**How to apply:** Keep the rim as a sibling below the `LiquidGlassTabBar` layer
in both the live shell and any matching visual preview. Keep shadows separate
from this rim; they have different capture and Dark Mode behavior.