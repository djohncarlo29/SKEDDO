---
name: Replit home partition quota
description: /home/runner has a per-user disk quota far below its filesystem size; large tool caches must live on the workspace partition instead.
---

## The Rule
Never let Shorebird, Gradle, or pub-cache grow large on `/home/runner`. Keep them under `/home/runner/workspace/.cache/`; `~/.pub-cache` should resolve to the workspace cache.

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

Before relying on Flutter analysis or builds, verify that `~/.pub-cache` is still a symlink to the workspace cache and that package roots referenced by `.dart_tool/package_config.json` exist. If the home path has become a separate directory, preserve and merge its contents into the workspace cache before restoring the symlink; do not discard the old cache.

**Why:** Flutter's package configuration stores absolute cache paths. A stale path can make installed packages appear missing, while an unlinked home cache can grow against the smaller user quota.

**How to apply:** Check `readlink -f ~/.pub-cache` and verify package roots before diagnosing dependency or source errors. Merge and preserve any existing cache before reconnecting the workspace cache.
