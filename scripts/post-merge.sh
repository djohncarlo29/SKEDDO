#!/bin/bash
set -e

# Post-merge setup — runs automatically after every task merge.
# Must be idempotent and non-interactive (stdin is closed).

# Use the project's pinned Flutter toolchain, not the system one.
FLUTTER=/home/runner/workspace/.cache/flutter-3.44.2/bin/flutter
export PUB_CACHE="${PUB_CACHE:-/home/runner/workspace/.cache/pub-cache}"

cd artifacts/smart-scheduler
$FLUTTER pub get --no-example
