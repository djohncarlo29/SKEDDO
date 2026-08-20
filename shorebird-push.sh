#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# shorebird-push.sh  —  Push a Shorebird patch to all devices running SKEDDO
#
# Usage:
#   ./shorebird-push.sh                     # patch to all platforms
#   ./shorebird-push.sh android             # Android only
#
# Requirements:
#   • SHOREBIRD_TOKEN env var (or Replit secret) must be set.
#     Get it by running:  shorebird login:ci
#     Then add it in Replit → Secrets → SHOREBIRD_TOKEN
#
# What it does:
#   1. Runs `shorebird patch android --release-version <current>` which
#      compiles just the changed Dart code into a binary diff.
#   2. Uploads the diff to Shorebird's CDN.
#   3. Every installed APK built with `shorebird release android` checks for
#      updates on launch and applies the patch silently in the background.
#      The update is active on the NEXT restart of the app.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/artifacts/smart-scheduler"

# ── Locate shorebird ──────────────────────────────────────────────────────────
SHOREBIRD_BIN=""
if [[ -x "$HOME/.shorebird/bin/shorebird" ]]; then
  SHOREBIRD_BIN="$HOME/.shorebird/bin/shorebird"
elif [[ -x "$ROOT_DIR/.cache/shorebird/bin/shorebird" ]]; then
  SHOREBIRD_BIN="$ROOT_DIR/.cache/shorebird/bin/shorebird"
elif command -v shorebird &>/dev/null; then
  SHOREBIRD_BIN="$(command -v shorebird)"
else
  echo "❌  shorebird not found. Run the build-apk.sh first (it installs shorebird)." >&2
  exit 1
fi
export PATH="$(dirname "$SHOREBIRD_BIN"):$PATH"

# ── Auth ──────────────────────────────────────────────────────────────────────
if [[ -z "${SHOREBIRD_TOKEN:-}" ]]; then
  echo "❌  SHOREBIRD_TOKEN is not set."
  echo "    Get it by running:  shorebird login:ci"
  echo "    Then add it in Replit → Secrets → SHOREBIRD_TOKEN"
  exit 1
fi
export SHOREBIRD_TOKEN

# ── Environment ───────────────────────────────────────────────────────────────
if [[ -z "${JAVA_HOME:-}" ]]; then
  _JDK="/nix/store/xad649j61kwkh0id5wvyiab5rliprp4d-openjdk-17.0.15+6/lib/openjdk"
  [[ -d "$_JDK" ]] && export JAVA_HOME="$_JDK" && export PATH="$JAVA_HOME/bin:$PATH"
fi
if [[ -z "${ANDROID_HOME:-}" ]]; then
  _SDK="$ROOT_DIR/.cache/android-sdk"
  [[ -d "$_SDK" ]] && export ANDROID_HOME="$_SDK" && export ANDROID_SDK_ROOT="$_SDK"
fi

# Redirect TMPDIR to the workspace volume. The /tmp overlayfs filesystem in
# this environment cannot handle large sequential writes (Shorebird's ~100 MB
# AAB download fails mid-write). Workspace has no such limit.
mkdir -p "$ROOT_DIR/.cache/shorebird-tmp"
export TMPDIR="$ROOT_DIR/.cache/shorebird-tmp"
# Shorebird leaves large AAB/download staging directories behind after a
# patch attempt. Clear only this disposable temp area so repeated pushes do
# not exhaust Replit's per-user home quota.
find "$TMPDIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

# Ensure per-session cache symlinks are intact.  They can be reset between
# restarts (the home partition has a per-user quota far below its apparent
# 32 GB size).
for _pair in \
    "shorebird:$ROOT_DIR/.cache/shorebird" \
    "gradle:$ROOT_DIR/.cache/gradle-home" \
    "pub-cache:$ROOT_DIR/.cache/pub-cache"; do
  _name="${_pair%%:*}"; _target="${_pair#*:}"
  _link="$HOME/.$_name"
  if [[ ! -L "$_link" ]] && [[ -d "$_target" ]]; then
    # Real directory exists — move its contents then replace with symlink.
    rsync -a --remove-source-files "$_link/" "$_target/" 2>/dev/null || true
    find "$_link" -type d -empty -delete 2>/dev/null || true
    rm -rf "$_link" 2>/dev/null || true
    ln -sf "$_target" "$_link"
    echo "→ Restored symlink: ~/$_link → $_target"
  elif [[ ! -e "$_link" ]] && [[ -d "$_target" ]]; then
    ln -sf "$_target" "$_link"
    echo "→ Created symlink: ~/$_link → $_target"
  fi
done

# Inject GEMINI_API_KEY into the bundled .env so the patched APK can reach AI
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > "$APP_DIR/.env"
  echo "→ GEMINI_API_KEY injected."
fi

PLATFORM="${1:-android}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🐦 Shorebird patch → $PLATFORM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

(
  cd "$APP_DIR"

  # Pull the version from pubspec so shorebird knows which release to patch
  VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
  echo "→ App version: $VERSION"

  # Shorebird runs dependency resolution with its bundled Flutter SDK. Repair
  # a stale/malformed lock file first so one bad indentation cannot abort the
  # patch before compilation starts.
  FLUTTER_BIN="$(find "$(dirname "$SHOREBIRD_BIN")/cache/flutter" \
    -mindepth 3 -maxdepth 3 -type f -path '*/bin/flutter' -print -quit 2>/dev/null || true)"
  if [[ -z "$FLUTTER_BIN" || ! -x "$FLUTTER_BIN" ]]; then
    echo "❌  Shorebird's bundled Flutter SDK was not found." >&2
    exit 1
  fi
  echo "→ Resolving dependencies..."
  "$FLUTTER_BIN" pub get

  # Pass --release-version explicitly so shorebird doesn't prompt interactively.
  "$SHOREBIRD_BIN" patch "$PLATFORM" \
    --release-version "$VERSION" \
    --dart-define=PROXY_BASE_URL="${PROXY_BASE_URL:-}" \
    -- --no-tree-shake-icons
)

echo ""
echo "✅  Patch pushed! Devices running this version will update on next app restart."
