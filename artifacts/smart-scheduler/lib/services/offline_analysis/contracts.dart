import 'dart:typed_data';

import 'models.dart';

class AnalysisCancelled implements Exception {
  const AnalysisCancelled();
}

class AnalysisCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

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
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  });
}