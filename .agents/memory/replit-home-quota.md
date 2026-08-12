---
name: Replit home partition quota
description: /home/runner has a per-user disk quota far below its filesystem size; large tool caches must live on the workspace partition instead.
---

## The Rule
Never let Shorebird, Gradle, or pub-cache grow large on `/home/runner`. Move them to `/home/runner/workspace/.cache/` and symlink.

**Why:** The `/home/runner` filesystem shows ~32GB but has a per-user quota that triggers `EDQUOT (errno=122)` well before that. The `/home/runner/workspace` partition (`/dev/vdf`, 256GB) has no such quota.

## How to Apply
If you see `Disk quota exceeded` during an APK build:
```bash
# Move caches to quota-free partition and symlink
mv ~/.shorebird /home/runner/workspace/.cache/shorebird && ln -s /home/runner/workspace/.cache/shorebird ~/.shorebird
mv ~/.pub-cache /home/runner/workspace/.cache/pub-cache && ln -s /home/runner/workspace/.cache/pub-cache ~/.pub-cache
mv ~/.gradle /home/runner/workspace/.cache/gradle-home && ln -s /home/runner/workspace/.cache/gradle-home ~/.gradle
```
These symlinks survive session restarts because the workspace is persistent.

## Known State (as of Aug 8 2026)
All three caches are already migrated. `/home/runner` is now only ~186MB.
The symlinks are:
- `~/.shorebird → /home/runner/workspace/.cache/shorebird`
- `~/.pub-cache  → /home/runner/workspace/.cache/pub-cache`
- `~/.gradle     → /home/runner/workspace/.cache/gradle-home`
