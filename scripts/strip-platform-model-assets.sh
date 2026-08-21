#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?usage: strip-platform-model-assets.sh <android|apple|web> [root]}"
ROOT="${2:-.}"

case "$MODE" in
  android)
    # Android uses tflite_flutter and the TFLite model only.
    REMOVE="all-MiniLM-L6-v2.onnx"
    ;;
  apple)
    # iOS/macOS use flutter_onnxruntime and the ONNX model only. The
    # tflite_flutter dependency remains in pubspec.yaml for Android, but its
    # plugin metadata does not select an Apple native implementation.
    REMOVE="all-MiniLM-L6-v2.tflite"
    ;;
  web)
    # Web uses the no-op embedding service and receives neither model.
    REMOVE="all-MiniLM-L6-v2.onnx all-MiniLM-L6-v2.tflite"
    ;;
  *)
    echo "Unknown platform mode: $MODE" >&2
    exit 2
    ;;
esac

for filename in $REMOVE; do
  while IFS= read -r -d '' asset; do
    rm -f "$asset"
    echo "strip-platform-model-assets: removed $asset"
  done < <(find "$ROOT" -type f -path "*/assets/models/$filename" -print0 2>/dev/null)
done