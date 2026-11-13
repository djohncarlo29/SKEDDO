---
name: Modal row Dynamic Type sizing
description: Fixed control slots inside modal sheets must not impose a fixed height on their text labels.
---

Modal-sheet labels beside fixed-size controls should keep their normal minimum row target while growing from the measured, text-scaled line height and any wrapping. Use the shared `ModalSheetRowLabel` for these mixed-content rows; scale fixed-height date/month grid cells with `modalSheetScaledRowExtent`; leave content-driven label/value rows untouched.

**Why:** A fixed-height label viewport can clip accessibility-sized text even when other rows in the same card grow naturally.

**How to apply:** When adding a modal switch or similarly fixed-size control row, constrain only the control slot. Give the label a measured text-driven minimum and allow it to wrap; preserve the base height at the default text scale. For selectable calendar-style cells, scale their minimum extent with the same OS `TextScaler` so the text remains inside the hit target.
