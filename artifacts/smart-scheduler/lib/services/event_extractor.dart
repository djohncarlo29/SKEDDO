import 'dart:convert';
import 'dart:typed_data';

import 'offline_analysis.dart' as offline;

// The attachment UI consumes this small presentation model. Keep the richer
// offline-analysis model inside the analysis service so the sheet remains
// independent from extraction details.
class ExtractedEvent {
  final String title;
  final String? date;
  final String? time;
  final String? location;

  const ExtractedEvent({
    required this.title,
    this.date,
    this.time,
    this.location,
  });
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
    String mimeType,
  ) => _analyze(
    sourceName: _sourceNameForMime(mimeType),
    bytes: bytes,
    mimeType: mimeType,
  );

  static Future<List<ExtractedEvent>> fromFile({
    required Uint8List bytes,
    required String filename,
    String? mimeType,
  }) => _analyze(
    sourceName: filename,
    bytes: bytes,
    mimeType: mimeType,
  );

  static Future<List<ExtractedEvent>> fromText(String text) => _analyze(
    sourceName: 'pasted.txt',
    bytes: Uint8List.fromList(utf8.encode(text)),
    mimeType: 'text/plain',
  );

  static Future<List<ExtractedEvent>> fromLegacyOffice(
    Uint8List bytes,
    String filename,
  ) => _analyze(sourceName: filename, bytes: bytes);

  static Future<List<ExtractedEvent>> _analyze({
    required String sourceName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final result = await _coordinator.analyzeOffline(
      sourceName: sourceName,
      bytes: bytes,
      mimeType: mimeType,
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
        date: event.date,
        time: event.time,
        location: event.location,
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