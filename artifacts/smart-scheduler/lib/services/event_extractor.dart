import 'dart:convert';
import 'dart:typed_data';

import 'offline_analysis.dart' as offline;
import 'alert_sequence.dart';

// The attachment UI consumes this small presentation model. Keep the richer
// offline-analysis model inside the analysis service so the sheet remains
// independent from extraction details.
class ExtractedEvent {
  final String title;
  final String? subtitle;
  final String? date;
  final String? time;
  final String? endDate;
  final String? endTime;
  final bool isAllDay;
  final String? location;
  final String? destination;
  final String? travelTime;
  final String? travelMode;
  final String? repeat;
  final String? repeatEndType;
  final String? repeatEndDate;
  final Map<String, dynamic>? customRepeatConfig;
  final String? alert;
  final String? secondAlert;
  final List<String>? alerts;
  final String? reminderOption;
  final String? reminderDateTime;
  final String? reminderRepeat;
  final Map<String, dynamic>? reminderCustomRepeatConfig;
  final String? url;
  final String? notes;
  final List<String>? attachmentPaths;
  final String? categoryId;
  final String? timeZone;
  final String? sourceFile;
  final int? sourcePage;
  final String? sourceSection;
  final String? sourceText;
  final int? sourceSpanStart;
  final int? sourceSpanEnd;
  final String? extractionMethod;
  final double extractionConfidence;
  final double interpretationConfidence;
  final List<String> warnings;
  final String? uid;

  const ExtractedEvent({
    required this.title,
    this.subtitle,
    this.date,
    this.time,
    this.endDate,
    this.endTime,
    this.isAllDay = false,
    this.location,
    this.destination,
    this.travelTime,
    this.travelMode,
    this.repeat,
    this.repeatEndType,
    this.repeatEndDate,
    this.customRepeatConfig,
    this.alert,
    this.secondAlert,
    this.alerts,
    this.reminderOption,
    this.reminderDateTime,
    this.reminderRepeat,
    this.reminderCustomRepeatConfig,
    this.url,
    this.notes,
    this.attachmentPaths,
    this.categoryId,
    this.timeZone,
    this.sourceFile,
    this.sourcePage,
    this.sourceSection,
    this.sourceText,
    this.sourceSpanStart,
    this.sourceSpanEnd,
    this.extractionMethod,
    this.extractionConfidence = 0,
    this.interpretationConfidence = 0,
    this.warnings = const [],
    this.uid,
  });

  List<String> get alertSequence =>
      AlertSequence.compact(alerts ?? [alert, secondAlert]);

  bool get needsReview => interpretationConfidence < .7;
}

/// Offline-only event extraction used by the Notes attachment flow.
///
/// File analysis must not depend on a network, proxy, or API key.
/// Native OCR is invoked by [FileAnalysisCoordinator] for images and PDFs
/// whose text layer is insufficient.
class EventExtractor {
  static final offline.FileAnalysisCoordinator _coordinator =
      offline.FileAnalysisCoordinator();

  static Future<List<ExtractedEvent>> fromImage(
    Uint8List bytes,
    String mimeType, {
    String? filename,
    offline.AnalysisCancellationToken? cancellation,
    offline.AnalysisProgress? onProgress,
  }) => _analyze(
    sourceName: filename ?? _sourceNameForMime(mimeType),
    bytes: bytes,
    mimeType: mimeType,
    cancellation: cancellation,
    onProgress: onProgress,
  );

  static Future<List<ExtractedEvent>> fromFile({
    required Uint8List bytes,
    required String filename,
    String? mimeType,
    offline.AnalysisCancellationToken? cancellation,
    offline.AnalysisProgress? onProgress,
  }) => _analyze(
    sourceName: filename,
    bytes: bytes,
    mimeType: mimeType,
    cancellation: cancellation,
    onProgress: onProgress,
  );

  static Future<List<ExtractedEvent>> fromText(
    String text, {
    offline.AnalysisCancellationToken? cancellation,
    offline.AnalysisProgress? onProgress,
  }) => _analyze(
    sourceName: 'pasted.txt',
    bytes: Uint8List.fromList(utf8.encode(text)),
    mimeType: 'text/plain',
    cancellation: cancellation,
    onProgress: onProgress,
  );

  static Future<List<ExtractedEvent>> fromLegacyOffice(
    Uint8List bytes,
    String filename,
  ) => _analyze(sourceName: filename, bytes: bytes);

  static Future<List<ExtractedEvent>> _analyze({
    required String sourceName,
    required Uint8List bytes,
    String? mimeType,
    offline.AnalysisCancellationToken? cancellation,
    offline.AnalysisProgress? onProgress,
  }) async {
    final result = await _coordinator.analyzeOffline(
      sourceName: sourceName,
      bytes: bytes,
      mimeType: mimeType,
      cancellation: cancellation,
      onProgress: onProgress,
    );
    if (!result.isSuccess) {
      throw ExtractionException(
        result.failure?.message ?? _statusMessage(result.status),
      );
    }
    return result.events.map(_fromOfflineEvent).toList(growable: false);
  }

  static ExtractedEvent _fromOfflineEvent(offline.ExtractedEvent event) =>
      ExtractedEvent(
        title: event.title,
        subtitle: event.subtitle,
        date: event.date,
        time: event.time,
        endDate: event.endDate,
        endTime: event.endTime,
        isAllDay: event.isAllDay,
        location: event.location,
        destination: event.destination,
        travelTime: event.travelTime,
        travelMode: event.travelMode,
        repeat: event.repeat,
        repeatEndType: event.repeatEndType,
        repeatEndDate: event.repeatEndDate,
        customRepeatConfig: event.customRepeatConfig,
        alert: event.alert,
        secondAlert: event.secondAlert,
        alerts: event.alerts,
        reminderOption: event.reminderOption,
        reminderDateTime: event.reminderDateTime,
        reminderRepeat: event.reminderRepeat,
        reminderCustomRepeatConfig: event.reminderCustomRepeatConfig,
        url: event.url,
        notes: event.notes,
        attachmentPaths: event.attachmentPaths,
        categoryId: event.categoryId,
        timeZone: event.timeZone,
        sourceFile: event.sourceFile,
        sourcePage: event.sourcePage,
        sourceSection: event.sourceSection,
        sourceText: event.sourceText,
        sourceSpanStart: event.sourceSpanStart,
        sourceSpanEnd: event.sourceSpanEnd,
        extractionMethod: event.extractionMethod,
        extractionConfidence: event.extractionConfidence,
        interpretationConfidence: event.interpretationConfidence,
        warnings: event.warnings,
        uid: event.uid,
      );

  static String _sourceNameForMime(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'application/pdf':
        return 'attachment.pdf';
      case 'image/png':
        return 'attachment.png';
      case 'image/webp':
        return 'attachment.webp';
      default:
        return 'attachment.jpg';
    }
  }

  static String _statusMessage(offline.AnalysisStatus status) {
    switch (status) {
      case offline.AnalysisStatus.noEventsFound:
        return 'No scheduled events were found in this file.';
      case offline.AnalysisStatus.unsupportedFormat:
        return 'This file format is not supported for offline analysis.';
      case offline.AnalysisStatus.encryptedFile:
        return 'This file is encrypted and cannot be analyzed offline.';
      case offline.AnalysisStatus.ocrFailed:
        return 'Offline OCR could not read this file.';
      case offline.AnalysisStatus.cancelled:
        return 'Offline analysis was cancelled.';
      default:
        return 'The file could not be analyzed offline.';
    }
  }
}

class ExtractionException implements Exception {
  final String message;
  const ExtractionException(this.message);

  @override
  String toString() => 'ExtractionException: $message';
}
