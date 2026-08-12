---
name: Shorebird patch environment
description: Environment requirements for shorebird-push.sh to succeed reliably in this Replit container.
---

Two things must be in place before every `shorebird patch` run:

1. **TMPDIR must point to the workspace volume.** The `/tmp` overlayfs filesystem cannot handle large sequential writes — Shorebird's ~100 MB AAB download fails mid-write with `FileSystemException: writeFrom failed (OS Error:)`. Fix: `export TMPDIR=/home/runner/workspace/.cache/shorebird-tmp`.

2. **Home-partition symlinks must be intact.** `~/.gradle`, `~/.pub-cache`, and `~/.shorebird` can silently become real directories after Replit restarts, consuming the per-user home quota and causing `Disk quota exceeded` mid-build. `shorebird-push.sh` now auto-detects and restores these symlinks before every push.

**Why:** Both failure modes are environment-level, not code-level. They produce confusing error messages that look like Gradle or Dart failures.

**How to apply:** Both fixes are already baked into `shorebird-push.sh`. Re-run the script to push any future patch — no manual setup needed as long as the workspace caches exist.
