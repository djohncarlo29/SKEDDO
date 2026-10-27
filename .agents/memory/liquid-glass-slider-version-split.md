---
name: Liquid Glass slider v5 edge motion
description: Preserve the original bouncing thumb-edge icon motion while keeping the slider and other controls on liquid_glass_easy 5.0.0.
---

Keep the slider and all other controls on `liquid_glass_easy` 5.0.0. The app's local 5.0.0 package copy adds live visual-size reporting to the motion pill and moves edge icons from the actual thumb center and rendered envelope, preserving the active gap through rubberband overrun.

**Why:** The user specifically requires the slider to remain 5.0.0 and wants the original iOS-style edge-icon push and bounce restored; an older slider implementation or value-only wrapper is not acceptable.

**How to apply:** Keep the package version at 5.0.0 and preserve upstream behavior for unrelated controls. When rebasing the local patch, retain tests for both edges, rubberband motion, the maintained gap, and icon return after release.
