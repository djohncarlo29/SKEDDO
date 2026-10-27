#!/bin/sh
set -e

# Kill anything holding the port
python3 - <<'PYEOF'
import os, signal, glob, time

def kill_port(hex_port):
    for _ in range(10):
        killed = False
        for tcp_file in ['/proc/net/tcp', '/proc/net/tcp6']:
            try:
                with open(tcp_file) as f:
                    for line in f:
                        p = line.strip().split()
                        if len(p) >= 10 and p[1].upper().endswith(':' + hex_port) and p[3] == '0A':
                            inode = p[9]
                            for fd in glob.glob('/proc/*/fd/*'):
                                try:
                                    if 'socket:[' + inode + ']' in os.readlink(fd):
                                        pid = int(fd.split('/')[2])
                                        if pid != os.getpid():
                                            os.kill(pid, signal.SIGKILL)
                                            killed = True
                                except Exception:
                                    pass
            except Exception:
                pass
        if not killed:
            break
        time.sleep(0.5)

kill_port('5F23')
PYEOF

sleep 1

cd /home/runner/workspace/artifacts/smart-scheduler
export PUB_CACHE="${PUB_CACHE:-/home/runner/workspace/.cache/pub-cache}"
export TMPDIR="${TMPDIR:-/home/runner/workspace/.cache/flutter-tmp}"
mkdir -p "$TMPDIR"
FLUTTER_BIN="/home/runner/workspace/.cache/flutter-3.44.2/bin/flutter"
if [ ! -x "$FLUTTER_BIN" ]; then
  echo "Flutter 3.44.2 SDK not found at $FLUTTER_BIN." >&2
  echo "The app requires Flutter 3.44.2 or newer; install the pinned workspace toolchain." >&2
  exit 1
fi
export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
echo "→ Using Flutter: $("$FLUTTER_BIN" --version | sed -n '1p')"

# sqlite3's web dependency graph requires both Flutter asset build features.
"$FLUTTER_BIN" config --enable-native-assets >/dev/null
"$FLUTTER_BIN" config --enable-dart-data-assets >/dev/null
"$FLUTTER_BIN" pub get 2>&1

# Reuse the compiled CanvasKit bundle on unchanged restarts. Hash all files
# that affect the web build plus the shared model-stripping step; source edits
# still force a rebuild, while restarting an unchanged app avoids a full Dart
# web compilation.
BUILD_STAMP="build/.smart-scheduler-web-fingerprint"
BUILD_FINGERPRINT=$(
  {
    find lib assets web packages -type f -print0 |
      LC_ALL=C sort -z |
      xargs -0 sha256sum
    sha256sum \
      pubspec.yaml \
      pubspec.lock \
      start.sh \
      /home/runner/workspace/scripts/strip-platform-model-assets.sh
    "$FLUTTER_BIN" --version | sed -n '1p'
    printf '%s\n' \
      'flutter build web --no-pub --no-tree-shake-icons --no-wasm-dry-run'
  } | sha256sum | awk '{print $1}'
)

if [ -f build/web/index.html ] &&
  [ -f "$BUILD_STAMP" ] &&
  [ "$(cat "$BUILD_STAMP")" = "$BUILD_FINGERPRINT" ]; then
  echo "→ Flutter web bundle is unchanged; reusing the last successful build."
else
  # Use the standard CanvasKit JS renderer; Wasm requires COOP/COEP headers
  # that prevent this app from loading inside the Replit preview iframe.
  "$FLUTTER_BIN" build web --no-pub --no-tree-shake-icons --no-wasm-dry-run 2>&1
  bash /home/runner/workspace/scripts/strip-platform-model-assets.sh web \
    /home/runner/workspace/artifacts/smart-scheduler/build/web
  printf '%s\n' "$BUILD_FINGERPRINT" > "$BUILD_STAMP"
fi

# Start the offline Node.js static file server.
exec node /home/runner/workspace/server/index.js
