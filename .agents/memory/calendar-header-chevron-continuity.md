---
name: Calendar header chevron continuity
description: How controls should behave on inactive adjacent Calendar title panels during horizontal page navigation.
---

Calendar's three-panel title transition must paint navigation chevrons on inactive neighboring panels while preventing those controls from receiving input. Do not hide them with `Visibility` during a page slide.

**Why:** The outgoing active panel carries its controls away; if incoming preview panels hide theirs, the chevrons disappear during the handoff and only return after navigation commits.

**How to apply:** When changing Calendar title panels, keep inactive controls visible and visually disabled, with pointer input ignored. Check both shell-owned and scrollable title builders, including compact and noncompact layouts.

Compact landscape period chevrons are nested inside `HeaderTitleScroller`, whose
parent tap returns a Day View title to Month View. `AnimatedTapIcon` handles raw
pointer events but does not install a tap recognizer, so its callback can run alongside
the enclosing title callback. Keep a child tap recognizer in the compact chevron hit
target to consume the tap before it reaches the title.

**Why:** Without the child recognizer, tapping a left/right Day View navigation arrow
can both change the selected day and invoke the title's “return to Month” action.
Swipes do not have this conflict.

**How to apply:** Keep compact left/right period navigation separate from the split
hierarchy chevron, and verify the Day View remains open after tapping either arrow.

Hierarchy navigation availability must be refreshed again after a Day View
collapse finishes. The view handoff can happen at the animation midpoint, before
the controller stops; a parent toolbar that disables chevrons while animating
will otherwise stay stale-disabled.

**Why:** A midpoint-only callback updates the displayed view while the collapse
controller is still active, and no later parent rebuild may occur to restore the
chevrons.

**How to apply:** Notify the AppShell after the Day-entry animation settles, even
if the midpoint already committed and cleared the target view.
