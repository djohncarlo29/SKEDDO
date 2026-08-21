import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'contracts.dart';
import 'file_type_detector.dart';
import 'models.dart';

class OfflineExtractionException implements Exception {
  final AnalysisStatus status;
  final String message;

  const OfflineExtractionException(this.status, this.message);

  @override
  String toString() => message;
}

class LocalContentExtractor implements ContentExtractor {
  static const maxBytes = 50 * 1024 * 1024;
  static const maxArchiveEntries = 200;
  static const maxArchiveExpandedBytes = 100 * 1024 * 1024;

  @override
  bool supports(DetectedFileType type) => true;

  @override
  Future<ExtractedContent> extract({
    required String sourceName,
    required Uint8List bytes,
    required DetectedFileType type,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    if (bytes.length > maxBytes) {
      throw const OfflineExtractionException(
        AnalysisStatus.fileTooLarge,
        'This file is larger than the offline analysis limit.',
      );
    }
    onProgress?.call('Reading document', .2);

    switch (type) {
      case DetectedFileType.plainText:
      case DetectedFileType.markdown:
      case DetectedFileType.json:
      case DetectedFileType.xml:
      case DetectedFileType.csv:
      case DetectedFileType.html:
      case DetectedFileType.log:
      case DetectedFileType.ics:
      case DetectedFileType.vcs:
      case DetectedFileType.rtf:
        return _text(sourceName, bytes, type);
      case DetectedFileType.docx:
        return _docx(sourceName, bytes);
      case DetectedFileType.xlsx:
        return _xlsx(sourceName, bytes);
      case DetectedFileType.pptx:
        return _pptx(sourceName, bytes);
      case DetectedFileType.pdf:
        return _pdfText(sourceName, bytes);
      case DetectedFileType.zipArchive:
        return _zip(sourceName, bytes, cancellation, onProgress);
      case DetectedFileType.legacyOffice:
        throw const OfflineExtractionException(
          AnalysisStatus.unsupportedFormat,
          'Legacy Office binaries are not supported offline yet.',
        );
      case DetectedFileType.image:
        return _content(
          sourceName,
          type,
          bytes.length,
          '',
          const [],
          warnings: const [
            'Image content requires the offline OCR capability.',
          ],
          confidence: 0,
        );
      case DetectedFileType.unsupported:
      case DetectedFileType.encrypted:
      case DetectedFileType.corrupt:
        throw const OfflineExtractionException(
          AnalysisStatus.unsupportedFormat,
          'This file type is not supported for offline analysis.',
        );
    }
  }

  ExtractedContent _text(
    String sourceName,
    Uint8List bytes,
    DetectedFileType type,
  ) {
    final raw = utf8.decode(bytes, allowMalformed: true);
    final text = type == DetectedFileType.html
        ? raw
              .replaceAll(
                RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
                ' ',
              )
              .replaceAll(
                RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
                ' ',
              )
              .replaceAll(RegExp(r'<[^>]+>'), ' ')
        : type == DetectedFileType.rtf
        ? _stripRtf(raw)
        : raw;
    final lines = _lines(text);
    return _content(
      sourceName,
      type,
      bytes.length,
      text,
      lines,
      confidence: text.trim().isEmpty ? .1 : .98,
    );
  }

  ExtractedContent _docx(String sourceName, Uint8List bytes) {
    final archive = _decodeZip(bytes);
    final blocks = <ContentBlock>[];
    final tables = <ExtractedTable>[];
    var order = 0;

    for (final entry in archive) {
      if (!entry.isFile ||
          (!entry.name.endsWith('word/document.xml') &&
              !entry.name.startsWith('word/header') &&
              !entry.name.startsWith('word/footer'))) {
        continue;
      }
      final name = entry.name;
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) continue;

      for (final paragraph in _elements(xml, 'p')) {
        if (paragraph.ancestors.any(
          (ancestor) => ancestor is XmlElement && ancestor.name.local == 'tbl',
        )) {
          continue;
        }
        final text = paragraph.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 't')
            .map((e) => e.innerText)
            .join()
            .trim();
        if (text.isEmpty) continue;
        final styleElements = _elements(paragraph, 'pStyle').toList();
        final style = styleElements.isEmpty
            ? null
            : _attributeLocal(styleElements.first, 'val');
        final isList = _elements(paragraph, 'numPr').isNotEmpty;
        blocks.add(
          ContentBlock(
            kind: style?.toLowerCase().startsWith('heading') == true
                ? ContentBlockKind.heading
                : ContentBlockKind.paragraph,
            text: text,
            sectionIndex: order,
            order: order++,
            metadata: {
              'part': name,
              if (style != null) 'style': style,
              if (isList) 'list': 'true',
            },
          ),
        );
      }

      for (final table in _elements(xml, 'tbl')) {
        final rows = <List<String>>[];
        for (final row in _elements(table, 'tr')) {
          final cells = _elements(row, 'tc')
              .map(
                (cell) => cell.descendants
                    .whereType<XmlElement>()
                    .where((element) => element.name.local == 't')
                    .map((e) => e.innerText)
                    .join()
                    .trim(),
              )
              .toList();
          if (cells.any((cell) => cell.isNotEmpty)) rows.add(cells);
        }
        if (rows.isEmpty) continue;
        tables.add(
          ExtractedTable(name: name, rows: rows, sectionIndex: order - 1),
        );
      }
    }

    if (blocks.isEmpty && tables.isEmpty) {
      throw const OfflineExtractionException(
        AnalysisStatus.corruptFile,
        'The Office document did not contain readable text parts.',
      );
    }
    return _content(
      sourceName,
      DetectedFileType.docx,
      bytes.length,
      blocks.map((block) => block.text).join('\n'),
      blocks,
      tables: tables,
      metadata: {'sourceName': sourceName, 'format': 'docx'},
      warnings: const [],
      confidence: .9,
    );
  }

  ExtractedContent _xlsx(String sourceName, Uint8List bytes) {
    final archive = _decodeZip(bytes);
    final sharedStrings = <String>[];
    final worksheetNames = <String>[];
    ArchiveFile? sharedEntry;
    for (final candidate in archive) {
      if (candidate.name == 'xl/sharedStrings.xml') {
        sharedEntry = candidate;
        break;
      }
    }
    for (final entry in archive) {
      if (entry.name != 'xl/workbook.xml') continue;
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) continue;
      worksheetNames.addAll(
        _elements(
          xml,
          'sheet',
        ).map((sheet) => sheet.getAttribute('name') ?? 'Sheet').toList(),
      );
    }
    if (sharedEntry != null) {
      final xml = _safeXml(sharedEntry.readBytes() ?? const <int>[]);
      if (xml != null) {
        for (final item in _elements(xml, 'si')) {
          sharedStrings.add(
            _elements(item, 't').map((e) => e.innerText).join(),
          );
        }
      }
    }

    final blocks = <ContentBlock>[];
    final tables = <ExtractedTable>[];
    var order = 0;
    for (final entry in archive.where(
      (entry) =>
          entry.isFile &&
          RegExp(r'xl/worksheets/sheet\d+\.xml$').hasMatch(entry.name),
    )) {
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) continue;
      final rows = <List<String>>[];
      final coordinates = <String>[];
      for (final row in _elements(xml, 'row')) {
        final cells = <String>[];
        for (final cell in _elements(row, 'c')) {
          final coordinate = cell.getAttribute('r');
          if (coordinate != null) coordinates.add(coordinate);
          final type = cell.getAttribute('t');
          final value = _elements(cell, 'v').map((e) => e.innerText).join();
          final inline = _elements(cell, 'is')
              .expand((inlineString) => _elements(inlineString, 't'))
              .map((e) => e.innerText)
              .join();
          var resolved = inline.isNotEmpty ? inline : value;
          if (type == 's') {
            final index = int.tryParse(value);
            resolved =
                index != null && index >= 0 && index < sharedStrings.length
                ? sharedStrings[index]
                : resolved;
          } else if (type == 'b') {
            resolved = value == '1' ? 'TRUE' : 'FALSE';
          }
          cells.add(resolved.trim());
        }
        if (cells.any((cell) => cell.isNotEmpty)) rows.add(cells);
      }
      if (rows.isEmpty) continue;
      final worksheetIndex = order;
      final worksheetName = worksheetNames.length > worksheetIndex
          ? worksheetNames[worksheetIndex]
          : 'Sheet${worksheetIndex + 1}';
      final text = rows.map((row) => row.join(' | ')).join('\n');
      blocks.add(
        ContentBlock(
          kind: ContentBlockKind.table,
          text: text,
          sectionIndex: order,
          order: order++,
          metadata: {
            'part': entry.name,
            'worksheetName': worksheetName,
            'cellCoordinates': coordinates,
          },
        ),
      );
      tables.add(
        ExtractedTable(
          name: worksheetName,
          rows: rows,
          sectionIndex: order - 1,
        ),
      );
    }
    if (blocks.isEmpty) {
      throw const OfflineExtractionException(
        AnalysisStatus.corruptFile,
        'The spreadsheet did not contain readable worksheet data.',
      );
    }
    return _content(
      sourceName,
      DetectedFileType.xlsx,
      bytes.length,
      blocks.map((block) => block.text).join('\n'),
      blocks,
      tables: tables,
      metadata: {'sourceName': sourceName, 'format': 'xlsx'},
      warnings: const [
        'Formulas are read from cached values and are not recalculated.',
      ],
      confidence: .88,
    );
  }

  ExtractedContent _pptx(String sourceName, Uint8List bytes) {
    final archive = _decodeZip(bytes);
    final blocks = <ContentBlock>[];
    var order = 0;
    final slides =
        archive
            .where(
              (entry) =>
                  entry.isFile &&
                  RegExp(r'ppt/slides/slide\d+\.xml$').hasMatch(entry.name),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    for (final entry in slides) {
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) continue;
      final text = xml.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 't')
          .map((e) => e.innerText)
          .join(' ')
          .trim();
      if (text.isEmpty) continue;
      final slideNumber = int.tryParse(
        RegExp(r'slide(\d+)\.xml$').firstMatch(entry.name)?.group(1) ?? '',
      );
      blocks.add(
        ContentBlock(
          kind: ContentBlockKind.slide,
          text: text,
          pageIndex: slideNumber == null ? null : slideNumber - 1,
          sectionIndex: order,
          order: order++,
          metadata: {
            'part': entry.name,
            'slideNumber': '${slideNumber ?? order}',
          },
        ),
      );
    }
    if (blocks.isEmpty) {
      throw const OfflineExtractionException(
        AnalysisStatus.corruptFile,
        'The presentation did not contain readable slide text.',
      );
    }
    return _content(
      sourceName,
      DetectedFileType.pptx,
      bytes.length,
      blocks.map((block) => block.text).join('\n'),
      blocks,
      metadata: {'sourceName': sourceName, 'format': 'pptx'},
      confidence: .88,
    );
  }

  ExtractedContent _pdfText(String sourceName, Uint8List bytes) {
    // This deliberately handles common simple text PDFs only. It never claims
    // that arbitrary PDF layout extraction is complete; poor output gets an
    // explicit OCR-required warning for the coordinator.
    final raw = latin1.decode(bytes, allowInvalid: true);
    final values = <String>[];
    values.addAll(
      RegExp(
        r'\(([^()]*)\)\s*Tj',
      ).allMatches(raw).map((m) => _unescapePdfText(m.group(1)!)),
    );
    values.addAll(
      RegExp(
        r'<([0-9A-Fa-f\s]+)>\s*Tj',
      ).allMatches(raw).map((m) => _decodePdfHex(m.group(1)!)),
    );
    for (final match in RegExp(r'\[((?:.|\n)*?)\]\s*TJ').allMatches(raw)) {
      values.addAll(
        RegExp(r'\(([^()]*)\)|<([0-9A-Fa-f\s]+)>')
            .allMatches(match.group(1)!)
            .map(
              (part) => part.group(1) != null
                  ? _unescapePdfText(part.group(1)!)
                  : _decodePdfHex(part.group(2)!),
            ),
      );
    }
    values.removeWhere((value) => value.trim().isEmpty);
    final text = values.join(' ');
    final quality = _pdfQuality(text, bytes.length);
    return _content(
      sourceName,
      DetectedFileType.pdf,
      bytes.length,
      text,
      _lines(text),
      metadata: {'sourceName': sourceName, 'format': 'pdf'},
      warnings: quality < .55
          ? const [
              'PDF text layer is incomplete or low quality; OCR is required for affected pages.',
            ]
          : const [],
      confidence: quality,
    );
  }

  ExtractedContent _zip(
    String sourceName,
    Uint8List bytes,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  ) {
    final archive = _decodeZip(bytes);
    if (archive.length > maxArchiveEntries) {
      throw const OfflineExtractionException(
        AnalysisStatus.fileTooLarge,
        'The archive contains too many files for safe offline analysis.',
      );
    }
    var expanded = 0;
    final blocks = <ContentBlock>[];
    var order = 0;
    for (final entry in archive) {
      cancellation?.throwIfCancelled();
      if (!entry.isFile) continue;
      final name = entry.name;
      if (_unsafeArchiveName(name)) {
        throw const OfflineExtractionException(
          AnalysisStatus.corruptFile,
          'The archive contains an unsafe path.',
        );
      }
      final data = entry.readBytes() ?? const <int>[];
      expanded += data.length;
      if (expanded > maxArchiveExpandedBytes) {
        throw const OfflineExtractionException(
          AnalysisStatus.fileTooLarge,
          'The archive expands beyond the offline safety limit.',
        );
      }
      final type = FileTypeDetector.detect(
        filename: name,
        bytes: Uint8List.fromList(data),
      ).type;
      if (!_isTextLike(type)) continue;
      final text = utf8.decode(data, allowMalformed: true);
      if (text.trim().isEmpty) continue;
      blocks.add(
        ContentBlock(
          kind: ContentBlockKind.paragraph,
          text: text,
          sectionIndex: order,
          order: order++,
          metadata: {'archiveEntry': name, 'detectedType': type.name},
        ),
      );
      onProgress?.call(
        'Reading archive entry $name',
        .2 + .6 * (order / archive.length),
      );
    }
    final text = blocks.map((b) => b.text).join('\n');
    return _content(
      sourceName,
      DetectedFileType.zipArchive,
      bytes.length,
      text,
      blocks,
      warnings: const [
        'Only supported text-like archive entries were analyzed.',
      ],
      confidence: blocks.isEmpty ? .1 : .76,
    );
  }

  Archive _decodeZip(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw OfflineExtractionException(
        AnalysisStatus.corruptFile,
        'The ZIP container could not be read: $e',
      );
    }
  }

  static ExtractedContent _content(
    String sourceName,
    DetectedFileType type,
    int byteSize,
    String text,
    List<ContentBlock> blocks, {
    List<ExtractedTable> tables = const [],
    Map<String, String> metadata = const {},
    List<String> warnings = const [],
    double confidence = 0,
  }) {
    return ExtractedContent(
      sourceName: sourceName,
      detectedType: type,
      byteSize: byteSize,
      plainText: text,
      blocks: blocks,
      sections: blocks,
      tables: tables,
      metadata: metadata,
      warnings: warnings,
      extractionConfidence: confidence,
    );
  }

  static List<ContentBlock> _lines(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (e) => ContentBlock(
            kind: ContentBlockKind.paragraph,
            text: e.value,
            order: e.key,
          ),
        )
        .toList();
  }

  static XmlDocument? _safeXml(List<int> bytes) {
    if (bytes.length > 10 * 1024 * 1024) return null;
    final input = utf8.decode(bytes, allowMalformed: true);
    if (input.contains('<!ENTITY') || input.contains('<!DOCTYPE')) return null;
    try {
      return XmlDocument.parse(input);
    } catch (_) {
      return null;
    }
  }

  static Iterable<XmlElement> _elements(XmlNode node, String localName) => node
      .descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == localName);

  static String? _attributeLocal(XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value;
    }
    return null;
  }

  static bool _isTextLike(DetectedFileType type) =>
      type == DetectedFileType.plainText ||
      type == DetectedFileType.markdown ||
      type == DetectedFileType.json ||
      type == DetectedFileType.xml ||
      type == DetectedFileType.csv ||
      type == DetectedFileType.html ||
      type == DetectedFileType.log ||
      type == DetectedFileType.ics ||
      type == DetectedFileType.vcs ||
      type == DetectedFileType.rtf;

  static bool _unsafeArchiveName(String name) {
    final normalized = name.replaceAll('\\', '/');
    return normalized.startsWith('/') ||
        normalized.split('/').contains('..') ||
        name.contains('\u0000');
  }

  static String _stripRtf(String value) => value
      .replaceAll(RegExp(r'\\[a-z]+\d* ?', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'[{}]'), '')
      .replaceAll(RegExp(r'\\[^a-z]'), '')
      .trim();

  static String _unescapePdfText(String value) => value
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll(r'\\', r'\')
      .replaceAll(RegExp(r'\\[0-7]{1,3}'), ' ');

  static String _decodePdfHex(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    final padded = compact.length.isOdd ? '${compact}0' : compact;
    final bytes = <int>[];
    for (var i = 0; i < padded.length; i += 2) {
      bytes.add(int.tryParse(padded.substring(i, i + 2), radix: 16) ?? 32);
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  static double _pdfQuality(String text, int bytes) {
    if (text.trim().length < 20) return .15;
    final printable = text.runes.where((r) => r >= 32 && r < 127).length;
    final ratio = printable / text.runes.length;
    if (ratio < .8) return .3;
    if (text.length < bytes ~/ 500) return .45;
    return .78;
  }
}

class UnavailableOfflineOcrService implements OfflineOcrService {
  const UnavailableOfflineOcrService();

  @override
  bool get isAvailable => false;

  @override
  Future<ExtractedContent> recognize({
    required String sourceName,
    required Uint8List bytes,
    required DetectedFileType sourceType,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  }) {
    throw const OfflineExtractionException(
      AnalysisStatus.ocrFailed,
      'Offline OCR is not available on this build.',
    );
  }
}
