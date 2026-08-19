---
name: Liquid Glass optical input field
description: How the floating tab bar should combine nearby-content capture with its existing glass response
---

The floating tab bar's optical source region may be larger than the visible pill in both axes, but the registered glass shape and final mask must remain the original pill. The expanded backdrop group must not be clipped before `BackdropFilter` samples it; the shader's shape SDF is the final mask. Nearby content should enter the same shader input field as a low-frequency ambient contribution; it must not be rendered as a second overlay or recognizable transformed image.

**Why:** Weakening the refracted sample to make expanded capture less recognizable removes the defining liquid-glass behavior, while vertical-only expansion cannot capture content beside the bar. A pre-filter clip makes the expanded source region ineffective even if the render object is larger.

**How to apply:** Preserve the established refraction/distortion strengths, expand the group render field horizontally and vertically, and average nearby samples before blending them subtly into the single glass-material result.