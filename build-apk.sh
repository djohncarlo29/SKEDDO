#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Self-configure JDK and Android SDK if not already set ─────────────────────
if [[ -z "${JAVA_HOME:-}" ]]; then
  _JDK_PATH="/nix/store/xad649j61kwkh0id5wvyiab5rliprp4d-openjdk-17.0.15+6/lib/openjdk"
  if [[ -d "$_JDK_PATH" ]]; then
    export JAVA_HOME="$_JDK_PATH"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi
if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
  _SDK_PATH="$ROOT_DIR/.cache/android-sdk"
  if [[ -d "$_SDK_PATH" ]]; then
    export ANDROID_HOME="$_SDK_PATH"
    export ANDROID_SDK_ROOT="$_SDK_PATH"
  fi
fi

APP_DIR="$ROOT_DIR/artifacts/smart-scheduler"
OUTPUT_APK="$ROOT_DIR/SKEDDO.apk"
FLUTTER_BIN="${FLUTTER_BIN:-$ROOT_DIR/.cache/flutter-3.35.7/bin/flutter}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT_DIR/.cache/gradle}"
KEYSTORE_FILE="$APP_DIR/android/app/smart-scheduler-release.jks"
KEY_PROPERTIES_FILE="$APP_DIR/android/key.properties"

STORE_PASSWORD="${SMART_SCHEDULER_KEYSTORE_PASSWORD:-smart-scheduler-local-release}"
KEY_PASSWORD="${SMART_SCHEDULER_KEY_PASSWORD:-smart-scheduler-local-release}"
KEY_ALIAS="${SMART_SCHEDULER_KEY_ALIAS:-smart-scheduler}"

if [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "ERROR: Flutter 3.35.7 SDK not found at $FLUTTER_BIN." >&2
  echo "SKEDDO requires Dart 3.9.x; refusing to fall back to another Flutter installation." >&2
  exit 1
fi

# ── Restore cache symlinks (Replit wipes HOME on container restart) ───────────
for _pair in \
  "shorebird:$ROOT_DIR/.cache/shorebird" \
  "gradle:$ROOT_DIR/.cache/gradle-home" \
  "pub-cache:$ROOT_DIR/.cache/pub-cache"; do
  _name="${_pair%%:*}"; _target="${_pair#*:}"; _link="$HOME/.$_name"
  if [[ ! -L "$_link" ]] && [[ -d "$_target" ]]; then
    rsync -a --remove-source-files "$_link/" "$_target/" 2>/dev/null || true
    find "$_link" -type d -empty -delete 2>/dev/null || true; rm -rf "$_link"
    ln -sf "$_target" "$_link"
  elif [[ ! -e "$_link" ]] && [[ -d "$_target" ]]; then
    ln -sf "$_target" "$_link"
  fi
done

# ── Locate Shorebird (optional) ───────────────────────────────────────────────
# When SHOREBIRD_TOKEN is set, builds use `shorebird release android` so that
# the installed APK can receive over-the-air patches via `./shorebird-push.sh`.
# When the token is absent the script falls back to a plain Flutter release build.
SHOREBIRD_BIN=""
if [[ -n "${SHOREBIRD_TOKEN:-}" ]]; then
  if [[ -x "$HOME/.shorebird/bin/shorebird" ]]; then
    SHOREBIRD_BIN="$HOME/.shorebird/bin/shorebird"
  elif command -v shorebird &>/dev/null; then
    SHOREBIRD_BIN="$(command -v shorebird)"
  else
    echo "WARNING: SHOREBIRD_TOKEN is set but shorebird CLI was not found — falling back to Flutter build." >&2
  fi
  if [[ -n "$SHOREBIRD_BIN" ]]; then
    export PATH="$(dirname "$SHOREBIRD_BIN"):$PATH"
    export SHOREBIRD_TOKEN
    echo "→ Shorebird mode: patches will be deliverable to installed APKs."
  fi
else
  echo "→ Standard Flutter build (no SHOREBIRD_TOKEN — OTA patches not available)."
  echo "  Add SHOREBIRD_TOKEN to Replit Secrets to enable Shorebird code push."
fi

# ── Flutter binary ─────────────────────────────────────────────────────────────
if [[ ! -x "$FLUTTER_BIN" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(command -v flutter)"
  else
    echo "Flutter SDK not found. Set FLUTTER_BIN or install Flutter, then run this again." >&2
    exit 1
  fi
fi
export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
echo "→ Using Flutter: $("$FLUTTER_BIN" --version | sed -n '1p')"

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
  echo "Android SDK is not configured. Set ANDROID_HOME or ANDROID_SDK_ROOT, then run this again." >&2
  exit 1
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool is not installed or not on PATH. Install a JDK, then run this again." >&2
  exit 1
fi

# ── Keystore ───────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$KEYSTORE_FILE")"
if [[ ! -f "$KEYSTORE_FILE" ]]; then
  keytool -genkeypair \
    -v \
    -storetype JKS \
    -keystore "$KEYSTORE_FILE" \
    -storepass "$STORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=SKEDDO, OU=SKEDDO, O=SKEDDO, L=Local, S=Local, C=US"
fi

cat > "$KEY_PROPERTIES_FILE" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=app/smart-scheduler-release.jks
EOF

rm -f "$OUTPUT_APK"

# ── Inject secrets ─────────────────────────────────────────────────────────────
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > "$APP_DIR/.env"
  echo "→ GEMINI_API_KEY injected from Replit secret."
else
  echo "WARNING: GEMINI_API_KEY not set — using existing .env value."
fi

if [[ -z "${PROXY_BASE_URL:-}" ]]; then
  echo "WARNING: PROXY_BASE_URL is not set — AI features will be disabled in this APK."
  echo "         Set it to your deployed server URL and rebuild to enable them."
else
  echo "→ PROXY_BASE_URL=${PROXY_BASE_URL} — AI features will be enabled."
fi

# ── Clean ──────────────────────────────────────────────────────────────────────
echo "→ Cleaning previous build artifacts…"
(cd "$APP_DIR" && "$FLUTTER_BIN" clean)

# ── Build ──────────────────────────────────────────────────────────────────────
(
  cd "$APP_DIR"

  if [[ -n "$SHOREBIRD_BIN" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🐦 shorebird release android"
    echo "  This APK will receive OTA patches via ./shorebird-push.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    "$SHOREBIRD_BIN" release android \
      --artifact apk \
      -- \
      --no-tree-shake-icons \
      --dart-define=PROXY_BASE_URL="${PROXY_BASE_URL:-}"
  else
    echo "→ Building release APK (Flutter)…"
    "$FLUTTER_BIN" build apk --release \
      --no-tree-shake-icons \
      --dart-define=PROXY_BASE_URL="${PROXY_BASE_URL:-}"
  fi
)

cp "$APP_DIR/build/app/outputs/flutter-apk/app-release.apk" "$OUTPUT_APK"
echo ""
echo "✅  Created $OUTPUT_APK"
if [[ -n "$SHOREBIRD_BIN" ]]; then
  echo "    This APK is Shorebird-enabled. Push updates anytime with:"
  echo "    ./shorebird-push.sh"
fi
