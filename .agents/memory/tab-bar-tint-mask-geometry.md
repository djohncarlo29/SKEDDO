---
name: Tab-bar tint mask geometry
description: Preserve indicator motion while keeping selected tab tint within the moving pill.
---

**Rule:** Keep indicator expansion and glass geometry unchanged when fixing selected-color bleed. The selected-color mask must follow the pill's exact moving bounds during rubber-band overdrag; do not clamp it back to the resting first or last tab slot.

**Why:** A mask clamped to a tab slot can leave neighboring icon or label pixels accented after the glass pill has moved away. The pill expansion itself is intentional and is not the cause of this bleed.

**How to apply:** Compare the color mask's geometry with the rendered indicator at both edge overdrags. Test that the mask moves past each edge and preserve the package's original expansion values.
