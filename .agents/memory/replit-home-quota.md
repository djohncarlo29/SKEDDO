---
name: Replit temporary storage limits
description: Keep Flutter and Android caches and temporary build files on the workspace partition, not quota-limited home or tmpfs.
---

## The Rule
Never let Shorebird, Gradle, pub-cache, or Flutter temporary build files grow on `/home/runner` or `/tmp`. Keep them under `/home/runner/workspace/.cache/`; `~/.pub-cache` should resolve to the workspace cache and Flutter commands should set `TMPDIR` there.

**Why:** `/home/runner` has a per-user quota, and `/tmp` is a 4GB tmpfs that can fill during Flutter builds. The workspace can also hit its own quota even when `df` reports ample physical space; Gradle and Shorebird then fail while writing outputs or logs.

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

**How to apply:** Check `readlink -f ~/.pub-cache` and verify package roots before diagnosing dependency or source errors. Set `TMPDIR=/home/runner/workspace/.cache/flutter-tmp` for Flutter tests/builds, preserve existing cache contents when reconnecting symlinks, and treat explicit `Disk quota exceeded` from Gradle/Shorebird as authoritative despite `df` free-space readings.
