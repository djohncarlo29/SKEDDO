---
name: OOXML attribute case handling
description: OOXML local attribute names such as Id, Target, and r require case-insensitive matching when parsing namespace-aware XML.
---

OOXML attribute lookup by local name must be case-insensitive because relationship and worksheet metadata commonly use capitalized forms such as Id, Target, and Ref.

**Why:** Namespace-aware XML parsing preserves attribute spelling, and a lowercase-only lookup silently drops hyperlinks and relationship metadata.

**How to apply:** Centralize local-attribute lookup and compare `name.local.toLowerCase()` with the requested name before adding new Office extractors.