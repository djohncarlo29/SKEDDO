import 'dart:typed_data';

import 'contracts.dart';
import 'event_analyzer.dart';
import 'extractors.dart';
import 'file_type_detector.dart';
import 'models.dart';
import 'preprocessor.dart';

class FileAnalysisCoordinator {
  final ContentExtractor extractor;
  final ContentPreprocessor preprocessor;
  final EventAnalyzer analyzer;

  FileAnalysisCoordinator({
    ContentExtractor? extractor,
    ContentPreprocessor? preprocessor,
    EventAnalyzer? analyzer,
  }) : extractor = extractor ?? LocalContentExtractor(),
       preprocessor = preprocessor ?? const DefaultContentPreprocessor(),
       analyzer = analyzer ?? DefaultEventAnalyzer();

  Future<AnalysisResult> analyzeOffline({
    required String sourceName,
    required Uint8List bytes,
    String? mimeType,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  }) async {
    try {
      cancellation?.throwIfCancelled();
      onProgress?.call('Detecting file type', .05);
      final detected = FileTypeDetector.detect(
        filename: sourceName,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (detected.isEncrypted) {
        return const AnalysisResult(status: AnalysisStatus.encryptedFile);
      }
      if (!extractor.supports(detected.type)) {
        return AnalysisResult(
          status: AnalysisStatus.unsupportedFormat,
          failure: AnalysisFailure(
            AnalysisStatus.unsupportedFormat,
            'Offline extraction is not available for ${detected.type.name}.',
          ),
        );
      }

      final extracted = await extractor.extract(
        sourceName: sourceName,
        bytes: bytes,
        type: detected.type,
        cancellation: cancellation,
        onProgress: onProgress,
      );
      final prepared = await preprocessor.preprocess(
        extracted,
        sourceBytes: bytes,
        cancellation: cancellation,
        onProgress: onProgress,
      );
      final events = await analyzer.analyze(
        prepared,
        cancellation: cancellation,
        onProgress: onProgress,
      );
      onProgress?.call('Preparing results', 1);
      final warnings = [...prepared.warnings];
      final status = events.isEmpty
          ? AnalysisStatus.noEventsFound
          : warnings.isEmpty
          ? AnalysisStatus.success
          : AnalysisStatus.successWithWarnings;
      return AnalysisResult(
        status: status,
        content: prepared,
        events: events,
        warnings: warnings,
      );
    } on AnalysisCancelled {
      return const AnalysisResult(status: AnalysisStatus.cancelled);
    } on OfflineExtractionException catch (error) {
      return AnalysisResult(
        status: error.status,
        failure: AnalysisFailure(error.status, error.message, cause: error),
      );
    } catch (error) {
      return AnalysisResult(
        status: AnalysisStatus.extractionFailed,
        failure: AnalysisFailure(
          AnalysisStatus.extractionFailed,
          'The file could not be analyzed offline.',
          cause: error,
        ),
      );
    }
  }
}
