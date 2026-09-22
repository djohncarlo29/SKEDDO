---
name: Utility color provenance
description: Archived and deleted DCV tiles must render original category colors instead of utility accent colors.
---

Archived and Recently Deleted utility content uses the original category color
for event dots and category-circle backgrounds. Deleted category snapshots take
precedence over the live category registry; built-in Smart Category utility
rows use their persisted Smart Category swatches.

**Why:** Utility containers intentionally use slate or destructive-red accents,
but applying those colors to child content makes archived/deleted items look
like utility metadata rather than the categories users recognize.

**How to apply:** When adding utility renderers, pass persisted Smart Category
colors and resolve event colors from archived/deleted category snapshots before
using the live registry or utility fallback.