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
    final relationships = _docxRelationships(archive);
    var order = 0;
    var section = 0;

    final documentParts =
        archive
            .where(
              (entry) =>
                  entry.isFile &&
                  (entry.name == 'word/document.xml' ||
                      RegExp(
                        r'^word/(header|footer)\d+\.xml$',
                      ).hasMatch(entry.name)),
            )
            .toList()
          ..sort((a, b) {
            int rank(String name) {
              if (name == 'word/document.xml') return 0;
              if (name.startsWith('word/header')) return 1;
              return 2;
            }

            final rankCompare = rank(a.name).compareTo(rank(b.name));
            return rankCompare == 0 ? a.name.compareTo(b.name) : rankCompare;
          });

    for (final entry in documentParts) {
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
        final hyperlinkIds = _elements(
          paragraph,
          'hyperlink',
        ).map((element) => _attributeLocal(element, 'id')).whereType<String>();
        final hasSectionBreak = _elements(paragraph, 'sectPr').isNotEmpty;
        blocks.add(
          ContentBlock(
            kind: style?.toLowerCase().startsWith('heading') == true
                ? ContentBlockKind.heading
                : ContentBlockKind.paragraph,
            text: text,
            sectionIndex: section,
            order: order++,
            metadata: {
              'part': name,
              'sourceSection': section,
              if (style != null) 'style': style,
              if (isList) ...{
                'list': 'true',
                if (_elements(paragraph, 'ilvl').isNotEmpty)
                  'listLevel': _attributeLocal(
                    _elements(paragraph, 'ilvl').first,
                    'val',
                  ),
                if (_elements(paragraph, 'numId').isNotEmpty)
                  'numberingId': _attributeLocal(
                    _elements(paragraph, 'numId').first,
                    'val',
                  ),
              },
              if (hyperlinkIds.isNotEmpty)
                'hyperlinks': {
                  for (final id in hyperlinkIds)
                    if (relationships[id] != null) id: relationships[id],
                },
            },
          ),
        );
        if (hasSectionBreak) section++;
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
          ExtractedTable(
            name: name,
            rows: rows,
            sectionIndex: section,
            metadata: {'part': name, 'sourceSection': section},
          ),
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

  Map<String, String> _docxRelationships(Archive archive) {
    for (final entry in archive) {
      if (entry.name != 'word/_rels/document.xml.rels') continue;
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) return const {};
      return {
        for (final relationship in _elements(xml, 'Relationship'))
          if (_attributeLocal(relationship, 'id') != null &&
              _attributeLocal(relationship, 'target') != null)
            _attributeLocal(relationship, 'id')!: _attributeLocal(
              relationship,
              'target',
            )!,
      };
    }
    return const {};
  }

  ExtractedContent _xlsx(String sourceName, Uint8List bytes) {
    final archive = _decodeZip(bytes);
    final sharedStrings = <String>[];
    final worksheetNames = <String>[];
    final date1904 = _xlsxUses1904Calendar(archive);
    final numberFormats = _xlsxNumberFormats(archive);
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
      for (final sheet in _elements(xml, 'sheet')) {
        final name = sheet.getAttribute('name') ?? 'Sheet';
        worksheetNames.add(name);
      }
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
      final mergedRanges = _elements(xml, 'mergeCell')
          .map((element) => _attributeLocal(element, 'ref'))
          .whereType<String>()
          .toList();
      final hiddenRows = _elements(xml, 'row')
          .where((row) => _attributeLocal(row, 'hidden') == '1')
          .map((row) => _attributeLocal(row, 'r'))
          .whereType<String>()
          .toList();
      final hiddenColumns = _elements(xml, 'col')
          .where((column) => _attributeLocal(column, 'hidden') == '1')
          .map(
            (column) =>
                '${_attributeLocal(column, 'min') ?? ''}:${_attributeLocal(column, 'max') ?? _attributeLocal(column, 'min') ?? ''}',
          )
          .whereType<String>()
          .toList();
      final hyperlinkTargets = _xlsxHyperlinks(archive, entry.name);
      final cellFormats = <String, String>{};
      final dateValues = <String, String>{};
      for (final row in _elements(xml, 'row')) {
        final cells = <String>[];
        for (final cell in _elements(row, 'c')) {
          final coordinate = _attributeLocal(cell, 'r');
          if (coordinate != null) coordinates.add(coordinate);
          final type = _attributeLocal(cell, 't');
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
          final styleIndex = int.tryParse(_attributeLocal(cell, 's') ?? '');
          final format = styleIndex == null ? null : numberFormats[styleIndex];
          if (coordinate != null && format != null) {
            cellFormats[coordinate] = format;
          }
          if (coordinate != null &&
              format != null &&
              _looksLikeExcelDateFormat(format) &&
              double.tryParse(value) != null) {
            final parsedDate = _excelSerialDate(
              double.parse(value),
              date1904: date1904,
            );
            resolved = parsedDate;
            dateValues[coordinate] = parsedDate;
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
            'worksheetIndex': worksheetIndex,
            'cellCoordinates': coordinates,
            'mergedRanges': mergedRanges,
            'hiddenRows': hiddenRows,
            'hiddenColumns': hiddenColumns,
            'numberFormats': cellFormats,
            'hyperlinks': hyperlinkTargets,
            'dateValues': dateValues,
          },
        ),
      );
      tables.add(
        ExtractedTable(
          name: worksheetName,
          rows: rows,
          sectionIndex: order - 1,
          metadata: {
            'part': entry.name,
            'mergedRanges': mergedRanges,
            'hiddenRows': hiddenRows,
            'hiddenColumns': hiddenColumns,
            'numberFormats': cellFormats,
            'hyperlinks': hyperlinkTargets,
            'dateValues': dateValues,
          },
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

  bool _xlsxUses1904Calendar(Archive archive) {
    for (final entry in archive) {
      if (entry.name != 'xl/workbook.xml') continue;
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) return false;
      final workbookPr = _elements(xml, 'workbookPr').toList();
      return workbookPr.isNotEmpty &&
          _attributeLocal(workbookPr.first, 'date1904') == '1';
    }
    return false;
  }

  Map<int, String> _xlsxNumberFormats(Archive archive) {
    final builtIn = <int, String>{
      14: 'm/d/yy',
      15: 'd-mmm-yy',
      16: 'd-mmm',
      17: 'mmm-yy',
      18: 'h:mm AM/PM',
      19: 'h:mm:ss AM/PM',
      20: 'h:mm',
      21: 'h:mm:ss',
      22: 'm/d/yy h:mm',
    };
    final custom = <int, String>{};
    for (final entry in archive) {
      if (entry.name != 'xl/styles.xml') continue;
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) break;
      for (final format in _elements(xml, 'numFmt')) {
        final id = int.tryParse(_attributeLocal(format, 'numFmtId') ?? '');
        final code = _attributeLocal(format, 'formatCode');
        if (id != null && code != null) custom[id] = code;
      }
      final xfs = _elements(
        xml,
        'cellXfs',
      ).expand((element) => _elements(element, 'xf')).toList();
      return {
        for (var index = 0; index < xfs.length; index++)
          index:
              builtIn[int.tryParse(
                    _attributeLocal(xfs.elementAt(index), 'numFmtId') ?? '',
                  ) ??
                  -1] ??
              custom[int.tryParse(
                    _attributeLocal(xfs.elementAt(index), 'numFmtId') ?? '',
                  ) ??
                  -1] ??
              '',
      };
    }
    return const {};
  }

  Map<String, String> _xlsxHyperlinks(Archive archive, String sheetPath) {
    final slash = sheetPath.lastIndexOf('/');
    final directory = slash < 0 ? '' : sheetPath.substring(0, slash);
    final filename = slash < 0 ? sheetPath : sheetPath.substring(slash + 1);
    final relsPath = '$directory/_rels/$filename.rels';
    final relationships = <String, String>{};
    for (final entry in archive) {
      if (entry.name != relsPath) continue;
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) return const {};
      for (final relationship in _elements(xml, 'Relationship')) {
        final id = _attributeLocal(relationship, 'id');
        final target = _attributeLocal(relationship, 'target');
        if (id != null && target != null) relationships[id] = target;
      }
    }
    for (final entry in archive) {
      if (entry.name != sheetPath) continue;
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) return const {};
      return {
        for (final link in _elements(xml, 'hyperlink'))
          if (_attributeLocal(link, 'ref') != null &&
              (_attributeLocal(link, 'id') != null &&
                  relationships[_attributeLocal(link, 'id')] != null))
            _attributeLocal(link, 'ref')!:
                relationships[_attributeLocal(link, 'id')]!,
      };
    }
    return const {};
  }

  bool _looksLikeExcelDateFormat(String format) {
    final withoutLiterals = format
        .replaceAll(RegExp(r'"[^"]*"'), '')
        .replaceAll(RegExp(r'\[[^\]]+\]'), '')
        .toLowerCase();
    return RegExp(r'[ymd]').hasMatch(withoutLiterals) &&
        !RegExp(r'[^a-z]m(?![a-z])').hasMatch(withoutLiterals);
  }

  String _excelSerialDate(double serial, {required bool date1904}) {
    final epoch = date1904
        ? DateTime.utc(1904, 1, 1)
        : DateTime.utc(1899, 12, 30);
    final date = epoch.add(
      Duration(microseconds: (serial * 86400000000).round()),
    );
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  ExtractedContent _pptx(String sourceName, Uint8List bytes) {
    final archive = _decodeZip(bytes);
    final blocks = <ContentBlock>[];
    final tables = <ExtractedTable>[];
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
      final paragraphs = _elements(
        xml,
        'p',
      ).map(_elementText).where((value) => value.isNotEmpty).toList();
      final textBoxes = _elements(
        xml,
        'sp',
      ).map(_elementText).where((value) => value.isNotEmpty).toList();
      final slideNumber = int.tryParse(
        RegExp(r'slide(\d+)\.xml$').firstMatch(entry.name)?.group(1) ?? '',
      );
      final title = _elements(xml, 'sp')
          .where((shape) {
            return _elements(shape, 'ph').any(
              (placeholder) => _attributeLocal(placeholder, 'type') == 'title',
            );
          })
          .map(_elementText)
          .where((value) => value.isNotEmpty)
          .toList();
      final slideTitle = title.isEmpty ? null : title.first;
      for (final table in _elements(xml, 'tbl')) {
        final rows = <List<String>>[];
        for (final row in _elements(table, 'tr')) {
          final cells = _elements(row, 'tc').map(_elementText).toList();
          if (cells.any((cell) => cell.isNotEmpty)) rows.add(cells);
        }
        if (rows.isNotEmpty) {
          tables.add(
            ExtractedTable(
              name: 'Slide ${slideNumber ?? order + 1}',
              rows: rows,
              pageIndex: slideNumber == null ? null : slideNumber - 1,
              metadata: {'part': entry.name},
            ),
          );
        }
      }
      final notes = _pptxNotes(archive, slideNumber);
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
            'paragraphs': paragraphs,
            'textBoxes': textBoxes,
            if (slideTitle != null) 'title': slideTitle,
            if (notes != null) 'speakerNotes': notes,
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
      tables: tables,
      metadata: {'sourceName': sourceName, 'format': 'pptx'},
      confidence: .88,
    );
  }

  String? _pptxNotes(Archive archive, int? slideNumber) {
    if (slideNumber == null) return null;
    final noteName = 'ppt/notesSlides/notesSlide$slideNumber.xml';
    for (final entry in archive) {
      if (entry.name != noteName) continue;
      final xml = _safeXml(entry.readBytes() ?? const <int>[]);
      if (xml == null) return null;
      final text = _elementText(xml).trim();
      return text.isEmpty ? null : text;
    }
    return null;
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
    final pageCount = RegExp(
      r'/Type\s*/Page\b',
    ).allMatches(raw).length.clamp(1, 10000);
    final pageBlocks = _pdfPageBlocks(raw, pageCount);
    final poorPages = pageBlocks
        .where((page) => _pdfQuality(page.text, bytes.length) < .55)
        .map((page) => page.index)
        .toList();
    final quality = _pdfQuality(text, bytes.length);
    final classification = _pdfClassification(text, raw, quality);
    return _content(
      sourceName,
      DetectedFileType.pdf,
      bytes.length,
      text,
      _lines(text),
      metadata: {
        'sourceName': sourceName,
        'format': 'pdf',
        'quality': classification,
        'pageCount': '$pageCount',
        'ocrPageIndices': poorPages.join(','),
      },
      warnings: [
        if (classification != 'usable')
          'PDF text layer classification: $classification.',
        if (classification == 'partial' ||
            classification == 'scrambled' ||
            classification == 'image-only')
          'OCR is required for affected PDF pages.',
      ],
      confidence: quality,
    );
  }

  List<({int index, String text})> _pdfPageBlocks(String raw, int pageCount) {
    if (pageCount <= 1) return [(index: 0, text: raw)];
    final markers = RegExp(r'/Type\s*/Page\b').allMatches(raw).toList();
    return List.generate(pageCount, (index) {
      final start = index == 0 ? 0 : markers[index - 1].end;
      final end = index + 1 < markers.length
          ? markers[index].start
          : raw.length;
      final pageRaw = raw.substring(start, end);
      final pageText = [
        ...RegExp(
          r'\(([^()]*)\)\s*Tj',
        ).allMatches(pageRaw).map((m) => _unescapePdfText(m.group(1)!)),
        ...RegExp(
          r'<([0-9A-Fa-f\s]+)>\s*Tj',
        ).allMatches(pageRaw).map((m) => _decodePdfHex(m.group(1)!)),
        ...RegExp(r'\[((?:.|\n)*?)\]\s*TJ')
            .allMatches(pageRaw)
            .expand(
              (match) => RegExp(r'\(([^()]*)\)|<([0-9A-Fa-f\s]+)>')
                  .allMatches(match.group(1)!)
                  .map(
                    (part) => part.group(1) != null
                        ? _unescapePdfText(part.group(1)!)
                        : _decodePdfHex(part.group(2)!),
                  ),
            ),
      ].join(' ');
      return (index: index, text: pageText);
    });
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
      blocks: [
        for (final block in blocks)
          ContentBlock(
            kind: block.kind,
            text: block.text,
            pageIndex: block.pageIndex,
            sectionIndex: block.sectionIndex,
            boundingBox: block.boundingBox,
            order: block.order,
            metadata: {
              'sourceFile': sourceName,
              'sourceType': type.name,
              ...block.metadata,
            },
          ),
      ],
      sections: [
        for (final block in blocks)
          ContentBlock(
            kind: block.kind,
            text: block.text,
            pageIndex: block.pageIndex,
            sectionIndex: block.sectionIndex,
            boundingBox: block.boundingBox,
            order: block.order,
            metadata: {
              'sourceFile': sourceName,
              'sourceType': type.name,
              ...block.metadata,
            },
          ),
      ],
      tables: [
        for (final table in tables)
          ExtractedTable(
            name: table.name,
            rows: table.rows,
            pageIndex: table.pageIndex,
            sectionIndex: table.sectionIndex,
            metadata: {
              'sourceFile': sourceName,
              'sourceType': type.name,
              ...table.metadata,
            },
          ),
      ],
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

  static String _elementText(XmlNode node) => node.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 't')
      .map((element) => element.innerText)
      .join(' ')
      .trim();

  static String? _attributeLocal(XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local.toLowerCase() == localName.toLowerCase()) {
        return attribute.value;
      }
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
    // A text layer made only of repeated one-character fragments is usually
    // an unusable font-map extraction, not a meaningful document.
    final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final shortTokenRatio = tokens.isEmpty
        ? 1.0
        : tokens.where((token) => token.length <= 1).length / tokens.length;
    if (shortTokenRatio > .65) return .3;
    if (text.length < bytes ~/ 500) return .45;
    return .78;
  }

  static String _pdfClassification(String text, String raw, double quality) {
    final hasPdfHeader = raw.startsWith('%PDF-');
    final hasEof = raw.contains('%%EOF');
    final hasPageObject = RegExp(r'/Type\s*/Page\b').hasMatch(raw);
    if (!hasPdfHeader || !hasEof) return 'corrupt-or-unreadable';
    if (text.trim().isEmpty) {
      return hasPageObject ? 'image-only' : 'corrupt-or-unreadable';
    }
    if (quality < .35) return 'scrambled';
    if (quality < .55) return 'partial';
    return 'usable';
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
    List<int>? pageIndices,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  }) {
    throw const OfflineExtractionException(
      AnalysisStatus.ocrFailed,
      'Offline OCR is not available on this build.',
    );
  }
}
