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
        return _ooxml(sourceName, bytes, type, 'word/document.xml', 'w:t');
      case DetectedFileType.xlsx:
        return _ooxml(sourceName, bytes, type, 'xl/workbook.xml', 't');
      case DetectedFileType.pptx:
        return _ooxml(sourceName, bytes, type, 'ppt/presentation.xml', 'a:t');
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
          warnings: const ['Image content requires the offline OCR capability.'],
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
            .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
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

  ExtractedContent _ooxml(
    String sourceName,
    Uint8List bytes,
    DetectedFileType type,
    String primaryPart,
    String textTag,
  ) {
    final archive = _decodeZip(bytes);
    final textParts = <String>[];
    final blocks = <ContentBlock>[];
    final tables = <ExtractedTable>[];
    var order = 0;

    for (final entry in archive) {
      if (!entry.isFile || !entry.name.endsWith('.xml')) continue;
      final name = entry.name;
      if (name == '[Content_Types].xml' ||
          name.contains('/_rels/') ||
          name.endsWith('.rels')) {
        continue;
      }
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) continue;
      final values = xml
          .findAllElements(textTag.contains(':') ? textTag.split(':').last : textTag)
          .map((e) => e.innerText.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      if (values.isEmpty) continue;
      final partText = values.join(' ');
      textParts.add(partText);
      blocks.add(ContentBlock(
        kind: type == DetectedFileType.pptx
            ? ContentBlockKind.slide
            : ContentBlockKind.paragraph,
        text: partText,
        sectionIndex: order,
        order: order++,
        metadata: {'part': name, 'primaryPart': name == primaryPart},
      ));
      if (type == DetectedFileType.xlsx && name.contains('sheet')) {
        tables.add(ExtractedTable(
          name: name,
          rows: [values],
          sectionIndex: order - 1,
        ));
      }
    }

    if (textParts.isEmpty) {
      throw const OfflineExtractionException(
        AnalysisStatus.corruptFile,
        'The Office document did not contain readable text parts.',
      );
    }
    return _content(
      sourceName,
      type,
      bytes.length,
      textParts.join('\n'),
      blocks,
      tables: tables,
      warnings: [
        if (type == DetectedFileType.xlsx)
          'Spreadsheet structure is preserved conservatively; formulas are not recalculated.',
      ],
      confidence: .82,
    );
  }

  ExtractedContent _pdfText(String sourceName, Uint8List bytes) {
    // This deliberately handles common simple text PDFs only. It never claims
    // that arbitrary PDF layout extraction is complete; poor output gets an
    // explicit OCR-required warning for the coordinator.
    final raw = latin1.decode(bytes, allowInvalid: true);
    final matches = RegExp(r'\(([^()]*)\)\s*Tj').allMatches(raw);
    final values = matches
        .map((m) => m.group(1)!)
        .map(_unescapePdfText)
        .where((v) => v.trim().isNotEmpty)
        .toList();
    final text = values.join(' ');
    final quality = _pdfQuality(text, bytes.length);
    return _content(
      sourceName,
      DetectedFileType.pdf,
      bytes.length,
      text,
      _lines(text),
      warnings: quality < .55
          ? const ['PDF text layer is incomplete or low quality; OCR is required for affected pages.']
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
      final type = FileTypeDetector.detect(filename: name, bytes: Uint8List.fromList(data)).type;
      if (!_isTextLike(type)) continue;
      final text = utf8.decode(data, allowMalformed: true);
      if (text.trim().isEmpty) continue;
      blocks.add(ContentBlock(
        kind: ContentBlockKind.paragraph,
        text: text,
        sectionIndex: order,
        order: order++,
        metadata: {'archiveEntry': name, 'detectedType': type.name},
      ));
      onProgress?.call('Reading archive entry $name', .2 + .6 * (order / archive.length));
    }
    final text = blocks.map((b) => b.text).join('\n');
    return _content(
      sourceName,
      DetectedFileType.zipArchive,
      bytes.length,
      text,
      blocks,
      warnings: const ['Only supported text-like archive entries were analyzed.'],
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
        .map((e) => ContentBlock(
              kind: ContentBlockKind.paragraph,
              text: e.value,
              order: e.key,
            ))
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