#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/artifacts/smart-scheduler"
OUTPUT_DIR="$ROOT_DIR"

# ── Pre-flight checks ──────────────────────────────────────────────────────────

if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: iOS builds require macOS. This script must be run on a Mac." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: Xcode is not installed. Install it from the App Store, then run:" >&2
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: Flutter is not installed or not on PATH." >&2
  echo "  Install it from https://docs.flutter.dev/get-started/install/macos" >&2
  exit 1
fi

# ── Clean ──────────────────────────────────────────────────────────────────────

echo "→ Cleaning previous build artifacts…"
(cd "$APP_DIR" && flutter clean)
(cd "$APP_DIR" && flutter pub get)

# ── Build IPA ─────────────────────────────────────────────────────────────────
#
# Requires code signing to be configured in Xcode first:
#   1. Open artifacts/smart-scheduler/ios/Runner.xcworkspace in Xcode
#   2. Select the Runner target → Signing & Capabilities
#   3. Choose your Apple Developer Team and set a Bundle ID
#   4. Then run this script
#
# The IPA will be placed in build/ios/ipa/ and copied to the project root.

echo "→ Building release IPA…"
(
  cd "$APP_DIR"
  flutter build ipa --release \
 
)

# ── Copy output ────────────────────────────────────────────────────────────────

IPA_FILE="$(find "$APP_DIR/build/ios/ipa" -name "*.ipa" | head -1)"

if [[ -z "$IPA_FILE" ]]; then
  echo "ERROR: IPA file not found in build/ios/ipa/ — check the build output above." >&2
  exit 1
fi

OUTPUT_IPA="$OUTPUT_DIR/SKEDDO.ipa"
cp "$IPA_FILE" "$OUTPUT_IPA"
echo "✓ Created $OUTPUT_IPA"
echo ""
echo "Install options:"
echo "  • TestFlight: upload via Xcode Organizer or Transporter"
echo "  • Ad Hoc / direct install: use Apple Configurator 2 or ideviceinstaller"
