import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/services/offline_analysis.dart';

void main() {
  final coordinator = FileAnalysisCoordinator();

  Uint8List officeZip(Map<String, String> parts) {
    final archive = Archive();
    for (final part in parts.entries) {
      final bytes = Uint8List.fromList(part.value.codeUnits);
      archive.addFile(ArchiveFile(part.key, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

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

  test(
    'ICS uses deterministic parsing and preserves calendar fields',
    () async {
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
    },
  );

  test('images enter OCR and report the precise current capability', () async {
    final result = await coordinator.analyzeOffline(
      sourceName: 'invite.png',
      bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
    );
    expect(result.status, AnalysisStatus.ocrFailed);
    expect(result.failure?.message, contains('OCR'));
  });

  test(
    'legacy Office files are not reported as successfully analyzed',
    () async {
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
    },
  );

  test('cancellation is reported explicitly', () async {
    final token = AnalysisCancellationToken()..cancel();
    final result = await coordinator.analyzeOffline(
      sourceName: 'notes.txt',
      bytes: Uint8List.fromList('tomorrow at 9 AM'.codeUnits),
      cancellation: token,
    );
    expect(result.status, AnalysisStatus.cancelled);
  });

  test('DOCX preserves paragraphs and table rows', () async {
    final bytes = officeZip({
      'word/document.xml': '''
        <w:document xmlns:w="urn:word">
          <w:body>
            <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Design review August 28 at 9 AM</w:t></w:r></w:p>
            <w:tbl>
              <w:tr><w:tc><w:p><w:r><w:t>Owner</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Room A</w:t></w:r></w:p></w:tc></w:tr>
              <w:tr><w:tc><w:p><w:r><w:t>Time</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>09:00</w:t></w:r></w:p></w:tc></w:tr>
            </w:tbl>
          </w:body>
        </w:document>
      ''',
    });
    final result = await coordinator.analyzeOffline(
      sourceName: 'review.docx',
      bytes: bytes,
    );
    expect(result.status, AnalysisStatus.success);
    expect(result.content?.blocks, hasLength(1));
    expect(result.content?.blocks.single.kind, ContentBlockKind.heading);
    expect(result.content?.blocks.single.metadata['part'], 'word/document.xml');
    expect(result.content?.metadata['sourceName'], 'review.docx');
    expect(result.content?.tables.single.rows, [
      ['Owner', 'Room A'],
      ['Time', '09:00'],
    ]);
  });

  test('XLSX resolves shared strings and worksheet rows', () async {
    final bytes = officeZip({
      'xl/sharedStrings.xml': '''
        <sst xmlns="urn:sheet"><si><t>Design review</t></si><si><t>Room A</t></si></sst>
      ''',
      'xl/workbook.xml': '''
        <workbook xmlns="urn:sheet"><sheets><sheet name="Planning" r:id="rId1"/></sheets></workbook>
      ''',
      'xl/worksheets/sheet1.xml': '''
        <worksheet xmlns="urn:sheet"><sheetData>
          <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
          <row r="2"><c r="A2" t="inlineStr"><is><t>August 28</t></is></c><c r="B2"><v>9</v></c></row>
        </sheetData></worksheet>
      ''',
    });
    final result = await coordinator.analyzeOffline(
      sourceName: 'schedule.xlsx',
      bytes: bytes,
    );
    expect(result.content?.tables.single.rows, [
      ['Design review', 'Room A'],
      ['August 28', '9'],
    ]);
    expect(result.content?.tables.single.name, 'Planning');
    expect(result.content?.blocks.single.metadata['worksheetName'], 'Planning');
    expect(result.content?.blocks.single.metadata['cellCoordinates'], [
      'A1',
      'B1',
      'A2',
      'B2',
    ]);
    expect(result.content?.metadata['sourceName'], 'schedule.xlsx');
  });

  test('PPTX preserves slide boundaries and slide numbers', () async {
    final bytes = officeZip({
      'ppt/slides/slide1.xml': '''
        <p:sld xmlns:a="urn:drawing"><a:t>Design review August 28</a:t><a:t>Room A</a:t></p:sld>
      ''',
      'ppt/slides/slide2.xml': '''
        <p:sld xmlns:a="urn:drawing"><a:t>Follow-up</a:t></p:sld>
      ''',
    });
    final result = await coordinator.analyzeOffline(
      sourceName: 'deck.pptx',
      bytes: bytes,
    );
    expect(result.content?.blocks.map((block) => block.kind), [
      ContentBlockKind.slide,
      ContentBlockKind.slide,
    ]);
    expect(result.content?.blocks.first.pageIndex, 0);
    expect(result.content?.blocks.first.text, contains('Room A'));
    expect(result.content?.blocks.first.metadata['slideNumber'], '1');
    expect(result.content?.blocks[1].text, 'Follow-up');
    expect(result.content?.blocks[1].pageIndex, 1);
    expect(result.content?.metadata['sourceName'], 'deck.pptx');
  });

  test('PDF parser accepts hex text streams', () async {
    final pdf = Uint8List.fromList(
      '%PDF-1.7 stream <44657369676e2072657669657720417567757374203238> Tj endstream %%EOF'
          .codeUnits,
    );
    final result = await coordinator.analyzeOffline(
      sourceName: 'review.pdf',
      bytes: pdf,
    );
    expect(result.status, AnalysisStatus.noEventsFound);
    expect(result.content?.plainText, contains('Design review August 28'));
    expect(result.content?.extractionConfidence, greaterThan(.55));
    expect(result.content?.metadata['sourceName'], 'review.pdf');
  });

  test(
    'PDF poor text-layer extraction is identified as requiring OCR',
    () async {
      final result = await coordinator.analyzeOffline(
        sourceName: 'scanned.pdf',
        bytes: Uint8List.fromList('%PDF-1.7 %%EOF'.codeUnits),
      );
      expect(result.status, AnalysisStatus.ocrFailed);
      expect(result.failure?.message, contains('OCR'));
    },
  );
}
