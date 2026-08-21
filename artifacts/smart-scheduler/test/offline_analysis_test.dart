import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/services/offline_analysis.dart';

void main() {
  final coordinator = FileAnalysisCoordinator();

  test('detects PDF by signature instead of extension', () {
    final detected = FileTypeDetector.detect(
      filename: 'calendar.bin',
      bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
    );
    expect(detected.type, DetectedFileType.pdf);
  });

  test('extracts local text and preserves source provenance', () async {
    final result = await coordinator.analyzeOffline(
      sourceName: 'notes.txt',
      bytes: Uint8List.fromList(
        'Design review on August 28 at 9:00 AM in Room A'.codeUnits,
      ),
    );
    expect(result.status, isNot(AnalysisStatus.extractionFailed));
    expect(result.content?.detectedType, DetectedFileType.plainText);
    expect(result.events, isNotEmpty);
    expect(result.events.single.sourceFile, 'notes.txt');
    expect(result.events.single.sourceText, contains('Design review'));
  });

  test('ICS uses deterministic parsing and preserves calendar fields', () async {
    final ics = [
      'BEGIN:VCALENDAR',
      'X-WR-TIMEZONE:Asia/Manila',
      'BEGIN:VEVENT',
      'UID:demo-1',
      'DTSTART;TZID=Asia/Manila:20260828T090000',
      'DTEND;TZID=Asia/Manila:20260828T100000',
      'SUMMARY:Design review',
      'LOCATION:Room A',
      'RRULE:FREQ=WEEKLY',
      'ORGANIZER:mailto:lead@example.com',
      'ATTENDEE:mailto:person@example.com',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
    final result = await coordinator.analyzeOffline(
      sourceName: 'calendar.ics',
      bytes: Uint8List.fromList(ics.codeUnits),
    );
    expect(result.status, AnalysisStatus.success);
    final event = result.events.single;
    expect(event.extractionMethod, 'ics-deterministic');
    expect(event.uid, 'demo-1');
    expect(event.timeZone, 'Asia/Manila');
    expect(event.recurrence, 'FREQ=WEEKLY');
    expect(event.location, 'Room A');
    expect(event.attendees, contains('mailto:person@example.com'));
  });

  test('images enter OCR and report the precise current capability', () async {
    final result = await coordinator.analyzeOffline(
      sourceName: 'invite.png',
      bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
    );
    expect(result.status, AnalysisStatus.ocrFailed);
    expect(result.failure?.message, contains('OCR'));
  });

  test('legacy Office files are not reported as successfully analyzed', () async {
    final result = await coordinator.analyzeOffline(
      sourceName: 'old.doc',
      bytes: Uint8List.fromList([
        0xd0,
        0xcf,
        0x11,
        0xe0,
        0xa1,
        0xb1,
        0x1a,
        0xe1,
      ]),
    );
    expect(result.status, AnalysisStatus.unsupportedFormat);
  });

  test('cancellation is reported explicitly', () async {
    final token = AnalysisCancellationToken()..cancel();
    final result = await coordinator.analyzeOffline(
      sourceName: 'notes.txt',
      bytes: Uint8List.fromList('tomorrow at 9 AM'.codeUnits),
      cancellation: token,
    );
    expect(result.status, AnalysisStatus.cancelled);
  });
}