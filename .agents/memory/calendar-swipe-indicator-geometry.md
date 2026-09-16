---
name: Calendar swipe indicator geometry
description: Fixed-size selected and today indicators during Calendar swipes, including the separate blob deformation layer.
---

The selected and current-day indicators must never exceed the shared text-scale-aware static diameter. Preserve swipe and bloom feedback with bounded blob clip paths; every indicator layer must remain inside its authored rectangle.

**Why:** The animated bloom layer and the swipe overlay are separate render paths, and either one can make the circle appear larger if it uses a scale transform. Removing the selected overlay's blob wrapper also makes Single Day swipes lose the intended squish effect.

**How to apply:** Never use `Transform.scale` for any selected, today, or swipe indicator, including `scaleX`-only transforms. Deform paths inside the original widget bounds so both visible width and height remain fixed; keep the number label at scale 1.0. Keep the static bloom and swipe overlay in equally constrained rectangles; replacing one with a differently sized render path creates an apparent growth jump even when the drag deformation is bounded.