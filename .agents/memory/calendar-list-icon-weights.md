---
name: Calendar list icon weights
description: Weight and clipping rules for Calendar List mode icons.
---

The Calendar Month View List menu action and Month View header List icon use the
custom-painted ListViewIcon. The Calendar Day View List header icon remains an
SF Symbol at weight 500 and independent of the Multi-Day painter clipping.

**Why:** The custom Month List glyph matches the other view-mode artwork more
reliably than the SF Symbol, while the Day header remains a separate lighter
glyph; the Multi-Day icon's clip-through treatment is not appropriate for List.

**How to apply:** Use ListViewIcon for both Month List menu/header placements;
keep the Day List header in its own non-clipping wrapper with explicit w500.