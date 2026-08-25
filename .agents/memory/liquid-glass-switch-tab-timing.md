---
name: Liquid Glass switch/tab timing
description: Shared lift and landing timing between the web-preview switch thumb and active tab pill
---

The LiquidGlassSwitch is the reference interaction for lift/landing timing: stiffness 826 with damping 34.5 while lifting, stiffness 270 with damping 23 while landing, and settle position error < 0.001 with velocity < 0.01. The active tab pill follows these values for its geometry and material morph.

**Why:** The switch is the established interaction standard; making the selected tab conform to it keeps the product’s glass controls consistent.

**How to apply:** If the switch tuning changes, update the active tab’s lift/landing constants and settle gate together. Keep the switch’s positional travel spring separate because it governs thumb travel, not lift/landing.