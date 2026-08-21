#!/bin/sh
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

# Inject the Replit GEMINI_API_KEY secret into the .env asset file so it is
# available to the Flutter app (via flutter_dotenv) and to the Node proxy
# server.  If the secret is not set, the existing file is left unchanged.
cd /home/runner/workspace/artifacts/smart-scheduler
FLUTTER_BIN="/home/runner/workspace/.cache/flutter-3.35.7/bin/flutter"
if [ ! -x "$FLUTTER_BIN" ]; then
  echo "Flutter 3.35.7 SDK not found at $FLUTTER_BIN." >&2
  echo "The app requires Dart 3.9.x; install the pinned workspace toolchain." >&2
  exit 1
fi
export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
echo "→ Using Flutter: $("$FLUTTER_BIN" --version | sed -n '1p')"
if [ -n "${GEMINI_API_KEY:-}" ]; then
  echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > .env
  echo "→ GEMINI_API_KEY injected from Replit secret."
else
  echo "WARNING: GEMINI_API_KEY secret not found — using existing .env value."
fi

# Build Flutter web app using the standard CanvasKit JS renderer (no WASM).
# The WASM renderer requires COOP/COEP headers (for SharedArrayBuffer) which
# block the app from being embedded in the Replit preview iframe.
"$FLUTTER_BIN" pub get 2>&1
"$FLUTTER_BIN" build web --no-tree-shake-icons 2>&1
bash /home/runner/workspace/scripts/strip-platform-model-assets.sh web \
  /home/runner/workspace/artifacts/smart-scheduler/build/web

# Start the Node.js proxy + static file server.
# It reads GEMINI_API_KEY from the environment (Replit secret) and serves
# both the Flutter web build and the /api/gemini/* proxy endpoints.
exec node /home/runner/workspace/server/index.js
