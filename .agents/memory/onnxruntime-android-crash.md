---
name: flutter_onnxruntime Android crash
description: ONNX session.run() causes an unrecoverable JNI SIGSEGV on Android; also covers the earlier UnsatisfiedLinkError fix and plugin registration patch.
---

## JNI SIGSEGV from session.run() (primary crash — confirmed)

`OrtSession.run()` on Android crashes the process with a native SIGSEGV that bypasses all Dart error handlers (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, try/catch). The crash manifests as "UI shows for a few seconds then dies" because `AIServices.embedCategory()` warms up every saved Smart Category embedding right after the first frame renders — calling `session.run()` once per category.

**Fix:** Guard `OnnxEmbeddingService` init with `!Platform.isAndroid` in `AIServices.init()` in `lib/ai/ai_services.dart`. Android falls back silently to `NullEmbeddingService`; keyword matching in `HybridMatcher` still works correctly.

**Why:** The JNI crash is not catchable from Dart. Wrapping the Dart MethodChannel call in try/catch does nothing — the SIGSEGV kills the OS process from the C++ ONNX Runtime inference thread.

**How to apply:** Do not re-enable ONNX on Android until a stable path is confirmed (e.g., background isolate with crash boundaries, or a different provider). The guard is already in place.

## Earlier crash: UnsatisfiedLinkError (secondary — already fixed in APK)

`UnsatisfiedLinkError` is a `java.lang.Error`, not an `Exception`. `GeneratedPluginRegistrant` was patched via a Gradle task (`patchGeneratedPluginRegistrant`) to catch `Throwable` instead of `Exception` so the library-load failure degrades gracefully. Jetifier was also disabled (`enableJetifier=false`) to fix a `libs.jar` transform error that appeared alongside it.
