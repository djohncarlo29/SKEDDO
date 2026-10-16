---
name: Android Freeform/Recents window band
description: Distinguish black bands in Android Recents cards from active Freeform window decoration.
---

The user first reported the black band in an Android Recents preview, then clarified that the current issue is also visible in an active Freeform window behind its system caption controls. Treat these as distinct system-owned layers and use the current screenshot to determine the target. The app's regular edge-to-edge layout is already enabled. Current remediation is native LaunchTheme/NormalTheme styling across resource variants; do not blindly hide the caption bar, since that removes live floating-window controls.

**Why:** The reported scope changed from a Recents thumbnail to the active floating window; those regions do not necessarily share the same owner or behavior.

**How to apply:** Confirm whether the current target is Recents or active Freeform before changing runtime inset flags. Keep transparent status-bar drawing and API-qualified cutout settings, preserve system controls, and verify on-device after a fresh install.
