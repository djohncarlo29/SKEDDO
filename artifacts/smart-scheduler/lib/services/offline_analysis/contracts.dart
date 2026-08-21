import 'dart:typed_data';

import 'models.dart';

class AnalysisCancelled implements Exception {
  const AnalysisCancelled();
}

class AnalysisCancellationToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void throwIfCancelled() {
    if (_cancelled) throw const AnalysisCancelled();
  }
}

typedef AnalysisProgress = void Function(String stage, double progress);

abstract class ContentExtractor {
  bool supports(DetectedFileType type);

  Future<ExtractedContent> extract({
    required String sourceName,
    required Uint8List bytes,
    required DetectedFileType type,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  });
}

abstract class ContentPreprocessor {
  Future<ExtractedContent> preprocess(
    ExtractedContent content, {
    Uint8List? sourceBytes,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  });
}

abstract class EventAnalyzer {
  Future<List<ExtractedEvent>> analyze(
    ExtractedContent content, {
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  });
}

abstract class LocalGenerativeAnalyzer {
  Future<List<ExtractedEvent>> analyzeAmbiguous(
    ExtractedContent content, {
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  });
}

/// OCR is intentionally an injectable capability. The current project does
/// not bundle an OCR model, so the default implementation reports a precise
/// unsupported result instead of silently falling back to Gemini.
abstract class OfflineOcrService {
  bool get isAvailable;

  Future<ExtractedContent> recognize({
    required String sourceName,
    required Uint8List bytes,
    required DetectedFileType sourceType,
    List<int>? pageIndices,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  });
}
