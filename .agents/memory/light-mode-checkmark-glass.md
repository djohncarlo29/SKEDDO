---
name: Light-mode attachment confirm surface
description: The attachment viewer confirm button must bypass the light liquid-glass lens
---

In Light Mode, the Notes attachment viewer's confirm control stays on the shared
liquid-glass button path, but its glass appearance base must be fully opaque and
accent-colored with a white checkmark. Dark Mode can retain the existing glass path.

**Why:** `liquid_glass_easy` normalizes a translucent saturated light surface toward
a white highlight, making the confirm action appear white instead of accent-colored.

**How to apply:** Keep `isCheckmark` as the semantic flag and use it to select an
opaque accent appearance only in Light Mode; leave dismiss/navigation controls and
the Dark Mode confirm control on their existing optical path.