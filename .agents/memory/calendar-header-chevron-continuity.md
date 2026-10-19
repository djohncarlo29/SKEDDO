---
name: Calendar header chevron continuity
description: How controls should behave on inactive adjacent Calendar title panels during horizontal page navigation.
---

Calendar's three-panel title transition must paint navigation chevrons on inactive neighboring panels while preventing those controls from receiving input. Do not hide them with `Visibility` during a page slide.

**Why:** The outgoing active panel carries its controls away; if incoming preview panels hide theirs, the chevrons disappear during the handoff and only return after navigation commits.

**How to apply:** When changing Calendar title panels, keep inactive controls visible and visually disabled, with pointer input ignored. Check both shell-owned and scrollable title builders, including compact and noncompact layouts.
