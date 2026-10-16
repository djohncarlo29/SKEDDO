---
name: Floating bar clearance math
description: How to keep Floating Tab Bar content clearance from compounding existing control spacing
---

The Floating Tab Bar’s safety margin is a final-content buffer, not a replacement for or reuse of a component’s visual layout gap. When a control already has trailing padding, subtract that padding from the added scroll clearance so the visible gap is counted once. The pill itself stays at the authored 16 px bottom offset on Android landscape; gesture insets still contribute to scroll-content clearance.

**Why:** Reusing the Events category-to-button gap as the pill safety margin made the Add Category tail visibly larger, while the default 12 px final safety buffer made its actual visible gap too small after existing padding was accounted for. Android's invisible landscape gesture inset also raised the pill above its intended screen-edge position when navigation mode changed.

**How to apply:** Keep `kFloatingTabBarVisualGap` and `kFloatingTabBarSafetyMargin` independent. Pass existing trailing content padding to the shared clearance helper when the final control already includes it, and use the visual-gap override for Add Category. For event-tile search lists, add clearance only for non-empty tile lists; centered no-results widgets already own their clearance. Use the 16 px pill offset on Android landscape, but continue comparing persistent safe-area and system-gesture bottom insets for scroll clearance; never sum them.