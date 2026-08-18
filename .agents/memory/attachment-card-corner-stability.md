---
name: Attachment card corner stability
description: Stable corner treatment for the attachment list card while rows are inserted or removed.
---

The attachment card should keep one fixed-radius outer shape in both empty and populated states. Let AnimatedList and each row's SizeTransition own insertion/removal motion; do not wrap the card in AnimatedSize or switch the outer shape to a stadium when empty.

**Why:** AnimatedSize plus the empty/populated shape switch makes the card corners visibly morph as its height changes.

**How to apply:** When changing attachment-list animation, preserve the fixed outer card geometry and animate only the list contents.