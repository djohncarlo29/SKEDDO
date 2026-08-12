---
name: flutter_onnxruntime 1.8.3 API
description: Correct API for flutter_onnxruntime 1.8.3 — session creation, tensor construction, and output extraction.
---

## Correct API (1.8.3)

- Session creation from asset: `OnnxRuntime().createSessionFromAsset(assetKey, options: OrtSessionOptions())` — handles asset extraction to temp dir automatically; **do not** use `OrtEnvironment` or manual file copy.
- Session creation from file path: `OnnxRuntime().createSession(filePath)`
- Tensor construction: `await OrtValue.fromList(Int64List.fromList([...]), [1, seqLen])` — takes typed data + shape; **do not** use `OrtValueTensor`.
- Inference: `session.run(Map<String, OrtValue>)` → returns `Map<String, OrtValue>` (not a list).
- Getting output data: `await ortValue.asList()` → nested `List<dynamic>` for rank-3; `.asFlattenedList()` for flat.
- Cleanup: `await ortValue.dispose()` (not `.release()`).
- Int64List is NOT supported on Web; guard ONNX code with `kIsWeb`.

**Why:** flutter_onnxruntime 1.8.3 exports only `OnnxRuntime`, `OrtSession`, `OrtValue`, `OrtDataType`, `OrtProvider`, `OrtSessionOptions`, `OrtRunOptions`, `OrtModelMetadata`. The classes `OrtEnvironment` and `OrtValueTensor` do not exist in this version.

**How to apply:** Any time flutter_onnxruntime inference code is written or reviewed, verify against these exact class/method names. `flutter analyze` may not catch wrong class names if the package has any-type stubs.
