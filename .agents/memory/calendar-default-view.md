---
name: Calendar default destination
description: The saved Default View setting determines the Calendar hierarchy on launch and when changed in Settings.
---

Default View starts at Month on a fresh install and is persisted across launches. Day opens Day View in Single Day mode; Week opens Day View in Multi Day mode; Month and Year open their matching views. Changing the setting also updates the current app session.

**Why:** The user expects the Default View setting to determine the actual Calendar destination, not merely its displayed selection, including after restart.

**How to apply:** Keep the preference mapping consistent across Settings selection, startup initialization, and the Calendar tab’s live state. Preserve the independent Month density and unrelated day-mode preferences when the default is Month or Year.
