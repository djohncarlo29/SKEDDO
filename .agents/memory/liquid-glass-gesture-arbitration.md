---
name: Liquid Glass gesture arbitration
description: Shared pointer ownership across glass menus, pickers, dialogs, and popovers.
---

All option-bearing Liquid Glass surfaces must route stretch, drag-selection, and scrolling through one shared per-surface gesture owner. Once the pointer resolves to an owner, it remains locked until release; touch glow and press scaling may continue independently as visual feedback. Coordinated lists disable competing native drag recognizers but keep wheel/trackpad scrolling and use normal scroll physics for the arbiter's explicit drag.

**Why:** Stacked pointer listeners and scroll recognizers caused the same movement to stretch the material, highlight crossed rows, and scroll at once, making taps and selection inconsistent.

**How to apply:** Reuse the shared controller for package menus, tile context panels, confirmation dialogs, and popovers. Keep drag selection available for short option-to-option movement; classify longer or fast movement at a scrollable boundary as scrolling, and never activate an option merely because a scroll passed over it.
