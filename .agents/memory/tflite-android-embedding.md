---
name: TFLite Android embedding (all-MiniLM-L6-v2)
description: How TFLite offline vector similarity is wired on Android as a replacement for ONNX, including the model source, tensor layout, and Gradle fix.
---

## Why TFLite instead of ONNX
`flutter_onnxruntime`'s JNI layer causes an unrecoverable SIGSEGV on Android during `session.run()`. TFLite (via `tflite_flutter`) has a Google-maintained Android runtime that is stable.

## Model
- **File:** `assets/models/all-MiniLM-L6-v2.tflite` (22MB)
- **Source:** `https://huggingface.co/Madhur-Prakash-Mangal/all-MiniLM-L6-v2-tflite/resolve/main/sentence_transformer.tflite`
- **Verified** via ai-edge-litert Python inspection + test inference (L2 norm = 1.000000)

## Tensor layout (critical — don't guess)
| Idx | Name | Shape | dtype |
|-----|------|-------|-------|
| 0 (input) | `serving_default_attention_mask:0` | [1, 128] | int32 |
| 1 (input) | `serving_default_input_ids:0` | [1, 128] | int32 |
| 0 (output) | `StatefulPartitionedCall:0` | [1, 384] | float32 |

Output is **already L2-normalized and mean-pooled** — no post-processing needed in Dart.

## Service
`lib/ai/embedding/tflite_embedding_service.dart` — implements `EmbeddingService`, reuses the existing `WordPieceTokenizer`. Wired in `lib/ai/ai_services.dart` via `Platform.isAndroid` guard.

## Gradle fix required (KGP 2.1 + Flutter 3.44.9)
KGP 2.1 turned the JVM-target mismatch into a build error. Plugin packages (`flutter_onnxruntime`, `tflite_flutter`) declare Kotlin JVM 17 but Java 11. Fix: add to `android/gradle.properties`:
```
kotlin.jvm.target.validation.mode=WARNING
```
**Why:** `subprojects` task overrides in root `build.gradle.kts` don't reach the plugin modules in time (Flutter's plugin-loader applies them independently). The gradle.properties flag is the only approach that reliably works.

**How to apply:** This is already set in the project. If it breaks again after a toolchain update, check this flag first.
