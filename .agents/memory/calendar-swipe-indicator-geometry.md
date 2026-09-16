---
name: Calendar swipe indicator geometry
description: Fixed-size selected and today indicators during Calendar swipes, including the separate blob deformation layer.
---

The selected and current-day indicators must never exceed the shared text-scale-aware static diameter. Preserve swipe feedback with a bounded blob clip path on the selected overlay; in Multi-Day mode, apply the same bounded deformation to the translucent pill, anchored toward its extension.

**Why:** The animated bloom overshoot is visually read as a changing indicator size during both Single Day and Multi-Day swipes. Removing the selected overlay's blob wrapper also makes Single Day swipes lose the intended squish effect.

**How to apply:** Keep the painted circle's scale capped at 1.0 for every day mode. Never use `Transform.scale` for the swipe indicators, including `scaleX`-only transforms; deform the path inside the original widget bounds so both visible width and height remain fixed.