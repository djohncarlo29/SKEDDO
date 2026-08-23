import 'dart:async';
import 'dart:typed_data';

import 'contracts.dart';
import 'event_analyzer.dart';
import 'extractors.dart';
import 'file_type_detector.dart';
import 'models.dart';
import 'preprocessor.dart';
import 'package:flutter/foundation.dart' show compute;

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
    return _analyzeWithTimeout(
      sourceName: sourceName,
      bytes: bytes,
      mimeType: mimeType,
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }

  Future<AnalysisResult> _analyzeWithTimeout({
    required String sourceName,
    required Uint8List bytes,
    String? mimeType,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  }) async {
    try {
      return await _analyzeInternal(
        sourceName: sourceName,
        bytes: bytes,
        mimeType: mimeType,
        cancellation: cancellation,
        onProgress: onProgress,
      ).timeout(const Duration(seconds: 90));
    } on TimeoutException {
      cancellation?.cancel();
      return const AnalysisResult(
        status: AnalysisStatus.timedOut,
        failure: AnalysisFailure(
          AnalysisStatus.timedOut,
          'Offline analysis took too long and was stopped safely.',
        ),
      );
    }
  }

  Future<AnalysisResult> _analyzeInternal({
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

      final extracted = await _extract(
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
    } on TimeoutException {
      cancellation?.cancel();
      return const AnalysisResult(
        status: AnalysisStatus.timedOut,
        failure: AnalysisFailure(
          AnalysisStatus.timedOut,
          'This document took too long to process safely.',
        ),
      );
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

  Future<ExtractedContent> _extract({
    required String sourceName,
    required Uint8List bytes,
    required DetectedFileType type,
    required AnalysisCancellationToken? cancellation,
    required AnalysisProgress? onProgress,
  }) async {
    // Native OCR must stay on the platform isolate. Pure parsing is moved off
    // the UI isolate so large Office/text/archive inputs cannot monopolize it.
    if (type == DetectedFileType.image || extractor is! LocalContentExtractor) {
      return extractor.extract(
        sourceName: sourceName,
        bytes: bytes,
        type: type,
        cancellation: cancellation,
        onProgress: onProgress,
      );
    }
    cancellation?.throwIfCancelled();
    onProgress?.call('Processing document in background', .2);
    final extracted = await compute(_extractInBackground, {
      'sourceName': sourceName,
      'bytes': bytes,
      'type': type.name,
    }).timeout(const Duration(seconds: 45));
    cancellation?.throwIfCancelled();
    onProgress?.call('Document processed', .4);
    return extracted;
  }
}

Future<ExtractedContent> _extractInBackground(Map<String, Object?> input) {
  final typeName = input['type'] as String;
  final type = DetectedFileType.values.firstWhere(
    (value) => value.name == typeName,
  );
  return LocalContentExtractor().extract(
    sourceName: input['sourceName'] as String,
    bytes: input['bytes'] as Uint8List,
    type: type,
  );
}
