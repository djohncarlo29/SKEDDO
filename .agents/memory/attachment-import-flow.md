---
name: Attachment import flow
description: User-confirmed distinction between the pre-import confirmation overlay and the active importing progress sheet.
---

The attachment flow should go directly from file selection or drop into the existing Importing items sheet. Remove the separate pre-import confirmation controls (Add more, Import, and its Cancel), but preserve the active Importing sheet's layout and Cancel behavior. Its title/subtitle card and Cancel control explicitly use the shared 24px confirmation sheet/button geometry.

**Why:** The user explicitly corrected an over-broad interpretation: the progress sheet is part of the desired workflow and must not be changed.

**How to apply:** Future attachment UX changes should target only the transition into the Importing sheet or the attachment row’s drop feedback unless the user separately asks to change the Importing sheet. Keep its shared geometry explicit and do not alter its import/cancel flow.