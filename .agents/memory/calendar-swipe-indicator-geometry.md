---
name: Calendar swipe indicator geometry
description: Fixed-size selected and today indicators during Calendar swipes, including the separate blob deformation layer.
---

The selected and current-day indicators must never exceed the shared text-scale-aware static diameter. Preserve swipe feedback by applying horizontal-only blob deformation to the selected overlay; in Multi-Day mode, apply the same deformation to the translucent pill, anchored at its left edge.

**Why:** The animated bloom overshoot is visually read as a changing indicator size during both Single Day and Multi-Day swipes. Removing the selected overlay's blob wrapper also makes Single Day swipes lose the intended squish effect.

**How to apply:** Keep the painted circle's scale capped at 1.0 for every day mode, and keep the swipe overlay's `scaleY` at 1.0 while allowing `scaleX` to respond to drag velocity. Do not use a full-ancestor scale for this interaction.