---
name: GlassMenu scroll preservation
description: Per-level scrolling and multi-position ScrollController behavior during menu morphs
---

## Rule
Keep a separate `ScrollController` for every menu level and leave covered parent lists mounted at their current offset. During a menu morph, one controller can temporarily report multiple attached positions; do not use the single-client `position` or `offset` getters in that frame.

**Why:** The submenu transition keeps the parent panel visible while its child panel arrives. Flutter's single-position getters assert when a controller is briefly attached to more than one scrollable, which can break the transition and scroll indicator.

**How to apply:** Read the relevant entry from `controller.positions` while rendering transition frames, and verify after the morph settles that each level has its own controller, the parent offset is unchanged, and all temporary positions have detached.
