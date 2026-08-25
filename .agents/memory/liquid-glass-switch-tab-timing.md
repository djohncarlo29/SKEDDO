---
name: Liquid Glass switch/tab timing
description: Shared lift and landing timing between the web-preview switch thumb and active tab pill
---

The LiquidGlassSwitch morph should use the active tab pill's lift/landing spring family: stiffness 250, damping 19.0 while lifting and 22.1 while landing. Its settle gate is position error < 0.0008 with velocity < 0.01.

**Why:** The switch and selected tab are the same interaction language; separate spring timings make the switch feel noticeably slower and make its clear/rest handoff occur at a different point.

**How to apply:** If active tab motion tuning changes, update the switch morph constants and settle gate together. Keep the switch's positional travel spring separate because it governs thumb travel, not lift/landing.