---
name: Floating bar rim compositing
description: Layer ordering for the Floating Tab Bar hairline and lifted glass pill
---

The Floating Tab Bar’s 0.5px rim must be part of the bar capsule lens, not a
separate full-bar sibling. The lifted active pill then captures the capsule
output and refracts the rim using the active pill’s smaller animated envelope.

**Why:** A separate full-bar rim keeps its own geometry even when the active
selection lens contracts, lifts, or squashes. Moving it behind the overlay only
changes paint order; it does not make the rim part of the pill’s captured bar.

**How to apply:** Use the bar capsule’s optical shape border for the hairline,
give it an explicit low-alpha light tint so it remains visible, and do not add a
duplicate DecoratedBox rim in the live shell or visual preview. Keep shadows
separate from this rim; they have different capture and Dark Mode behavior.