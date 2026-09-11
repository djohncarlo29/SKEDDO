---
name: Smart Category lifecycle
description: Product rules for user-created Smart Category sections, colors, and utility confirmations.
---

User-created Smart Categories are matching views, not storage categories. They
do not own manual sections or section membership; archive/delete changes only
the saved rule, while matching events remain in their storage categories.

Their active archive and delete confirmations use destructive-red actions,
including archive. In Archived Items and Recently Deleted, the utility action
sheet uses explicit Smart Category labels and is followed by one
Smart-Category-specific confirmation, without a duplicate generic category
confirmation.

**Why:** Smart Categories organize a rule over existing events rather than
holding events themselves, so category-with-contents and section language is
misleading and the archive action is still intentionally destructive in this
product flow.

**How to apply:** Keep Smart Category lifecycle copy separate from standard
category copy, suppress section controls for user-created Smart Category DCVs,
and preserve explicit archive/delete labels in utility sheets.