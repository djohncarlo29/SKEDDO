---
name: Android model asset stripping
description: Platform-specific Flutter asset exclusion during Android release packaging
---

Android Flutter assets declared from a shared directory can be copied again by
Flutter and AGP after an ordinary Gradle dependency-based cleanup task. A
platform-excluded model must be removed in the final action of the relevant
asset-copy/merge task, and release verification must use a clean build.

**Why:** An incremental APK can retain an older archive even when current
intermediate directories no longer contain the excluded asset, and a later
asset-copy task can repopulate it.

**How to apply:** For Android-only model exclusion, keep the shared declaration
for other platforms but remove the excluded file in the final asset merge path;
inspect the final APK ZIP, not only build intermediates.