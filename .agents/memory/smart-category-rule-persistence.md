---
name: Smart Category rule persistence
description: Data-model boundary for user-created Smart Category descriptions.
---

The text describing what belongs in a user-created Smart Category is a matching
rule, not the category's ordinary subtitle. It should be stored separately so
editing the rule never overwrites the subtitle shown in the category list.

**Why:** The modal has an existing subtitle field, while the new Smart Category
row represents a distinct filtering rule that must survive closing and reopening
the Edit Category sheet.

**How to apply:** Persist the rule with the category record and restore it when
opening the sheet. The row's checkmark confirms the current input; the sheet's
main save commits it to the category. For user-created Smart Categories, keep
the Category Type and rule row visible but hide Location, Repeat, and Alerts;
restore those cards immediately when another category type is selected.