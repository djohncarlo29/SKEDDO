#!/bin/bash
set -e

# Post-merge setup — runs automatically after every task merge.
# Must be idempotent and non-interactive (stdin is closed).

# Use the project's own Flutter toolchain (Dart 3.9.2), not the system one.
FLUTTER=/home/runner/workspace/.cache/flutter-3.35.7/bin/flutter

cd artifacts/smart-scheduler
$FLUTTER pub get --no-example
