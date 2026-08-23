import '../../ai/ai_services.dart';
import '../../ai/interfaces.dart';
import '../../ai/parsed_date.dart';
import '../../ai/date_parser/rule_based_date_parser.dart';
import 'package:flutter/foundation.dart' show compute;
import 'contracts.dart';
import 'models.dart';

class DefaultEventAnalyzer implements EventAnalyzer {
  final DateParser parser;

  DefaultEventAnalyzer({DateParser? parser})
    : parser = parser ?? RuleBasedDateParser();

  @override
  Future<List<ExtractedEvent>> analyze(
    ExtractedContent content, {
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  }) async {
    if (content.detectedType == DetectedFileType.ics ||
        content.detectedType == DetectedFileType.vcs) {
      return _calendarEvents(content, cancellation, onProgress);
    }
    final events = <ExtractedEvent>[];
    final sourceBlocks = <ContentBlock>[
      if (content.blocks.isEmpty)
        ContentBlock(
          kind: ContentBlockKind.paragraph,
          text: content.plainText,
          order: 0,
        )
      else
        ...content.blocks,
    ];
    // OCR engines normally return one block per line. Dates and times are
    // often split across multiple lines on invitations and screenshots, so
    // also analyze the reconstructed document text as one candidate. The
    // final dedupe pass prevents this combined candidate from duplicating an
    // event already found in an individual block.
    final combinedText = content.plainText.trim();
    if (content.blocks.length > 1 && combinedText.isNotEmpty) {
      sourceBlocks.add(
        ContentBlock(
          kind: ContentBlockKind.paragraph,
          text: combinedText,
          order: content.blocks.length,
          metadata: const {'combinedSource': true},
        ),
      );
    }
    final chunkInputs = sourceBlocks
        .map(
          (block) => <String, Object?>{
            'text': block.text,
            'pageIndex': block.pageIndex,
            'sectionIndex': block.sectionIndex,
            'order': block.order,
            'metadata': block.metadata,
          },
        )
        .toList();
    final chunkMaps = await compute(_boundedTextChunks, chunkInputs);
    final total = chunkMaps.isEmpty ? 1 : chunkMaps.length;

    for (var index = 0; index < chunkMaps.length; index++) {
      cancellation?.throwIfCancelled();
      final raw = chunkMaps[index];
      final block = ContentBlock(
        kind: ContentBlockKind.paragraph,
        text: raw['text'] as String,
        pageIndex: raw['pageIndex'] as int?,
        sectionIndex: raw['sectionIndex'] as int?,
        order: raw['order'] as int? ?? index,
        metadata:
            (raw['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final text = block.text.trim();
      if (text.isEmpty) continue;
      final temporal = _temporalFragment(text);
      if (temporal == null) continue;
      final parsed = parser.parse(temporal);
      if (!parsed.isScheduled &&
          parsed.canonicalTime == null &&
          !parsed.isRecurring) {
        continue;
      }

      final title = _title(text, temporal);
      final vectorAvailable = AIServices.embedding.dimensions > 0;
      double? semanticRelevance;
      if (vectorAvailable) {
        try {
          // MiniLM receives normalized extracted text only. It never receives
          // raw document bytes. The vector is intentionally not inserted into
          // the event index because imported candidates are not saved events.
          final vector = await AIServices.embedding.embed(text);
          semanticRelevance = vector.any((value) => value != 0) ? 1 : 0;
        } catch (_) {
          semanticRelevance = null;
        }
      }

      events.add(
        ExtractedEvent(
          title: title,
          subtitle: _labelValue(text, 'subtitle'),
          date: parsed.canonicalDate,
          time: parsed.canonicalTime,
          endDate: parsed.endDateTime == null
              ? null
              : _date(parsed.endDateTime!),
          endTime: parsed.canonicalEndTime,
          isAllDay: parsed.canonicalTime == null && parsed.isScheduled,
          location: _labelValue(text, 'location'),
          destination: _labelValue(text, 'destination'),
          travelTime: _labelValue(text, 'travel time'),
          travelMode: _labelValue(text, 'travel mode'),
          repeat: parsed.recurrence,
          repeatEndType: _labelValue(text, 'repeat ends') == null
              ? null
              : 'On Date',
          repeatEndDate: _labelValue(text, 'repeat ends'),
          alert: _labelValue(text, 'alert'),
          secondAlert: _labelValue(text, 'second alert'),
          url: _url(text),
          notes: _labelValue(text, 'notes'),
          recurrence: parsed.recurrence,
          timeZone: parsed.timezone,
          originalDateText: temporal,
          originalTimeText: parsed.rawInput,
          sourceFile: content.sourceName,
          sourcePage: block.pageIndex,
          sourceSection: _sourceSection(block),
          sourceText: block.metadata['sourceText'] as String? ?? text,
          sourceSpanStart: block.metadata['sourceSpanStart'] as int? ?? 0,
          sourceSpanEnd: block.metadata['sourceSpanEnd'] as int? ?? text.length,
          boundingBox: block.boundingBox,
          extractionMethod: 'deterministic+minilm',
          extractionConfidence: content.extractionConfidence,
          interpretationConfidence: _interpretationConfidence(parsed, title),
          warnings: content.warnings,
          semanticRelevance: semanticRelevance,
        ),
      );
      onProgress?.call(
        'Checking event relevance',
        .65 + .3 * ((index + 1) / total),
      );
    }
    return _dedupe(events);
  }

  List<ExtractedEvent> _calendarEvents(
    ExtractedContent content,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  ) {
    final lines = _unfold(content.plainText);
    final events = <ExtractedEvent>[];
    Map<String, String> fields = {};
    final attendees = <String>[];
    final alarms = <String>[];

    void flush() {
      if (fields.isEmpty) return;
      final summary = fields['SUMMARY']?.trim();
      final start = _calendarDate(fields['DTSTART']);
      if (summary == null || summary.isEmpty || start == null) {
        fields = {};
        attendees.clear();
        alarms.clear();
        return;
      }
      final end = _calendarDate(fields['DTEND']);
      final startRaw = fields['DTSTART'] ?? '';
      final endRaw = fields['DTEND'];
      final zone = _parameter(
        fields.keys.firstWhere(
          (key) => key.startsWith('DTSTART;'),
          orElse: () => 'DTSTART',
        ),
        'TZID',
      );
      events.add(
        ExtractedEvent(
          title: summary,
          date: _date(start),
          time: startRaw.contains('VALUE=DATE') ? null : _time(start),
          endDate: end == null ? null : _date(end),
          endTime: end == null || startRaw.contains('VALUE=DATE')
              ? null
              : _time(end),
          isAllDay: startRaw.contains('VALUE=DATE'),
          location: fields['LOCATION'],
          repeat: fields['RRULE'],
          url: fields['URL'],
          notes: fields['DESCRIPTION'],
          alert: alarms.isEmpty ? null : alarms.first,
          secondAlert: alarms.length < 2 ? null : alarms[1],
          recurrence: fields['RRULE'],
          timeZone: zone ?? fields['X-WR-TIMEZONE'],
          originalDateText: startRaw,
          originalTimeText: endRaw,
          sourceFile: content.sourceName,
          sourceText: fields.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n'),
          extractionMethod: 'ics-deterministic',
          extractionConfidence: 1,
          interpretationConfidence: 1,
          uid: fields['UID'],
          organizer: fields['ORGANIZER'],
          attendees: List.unmodifiable(attendees),
          alarms: List.unmodifiable(alarms),
        ),
      );
      fields = {};
      attendees.clear();
      alarms.clear();
    }

    for (final raw in lines) {
      cancellation?.throwIfCancelled();
      final line = raw.trim();
      if (line == 'BEGIN:VEVENT') {
        fields = {};
        attendees.clear();
        alarms.clear();
        continue;
      }
      if (line == 'END:VEVENT') {
        flush();
        continue;
      }
      if (line.startsWith('ATTENDEE')) {
        attendees.add(_value(line));
      } else if (line.startsWith('TRIGGER')) {
        alarms.add(_value(line));
      } else {
        final separator = line.indexOf(':');
        if (separator > 0) {
          final key = line.substring(0, separator);
          fields[key.split(';').first] = line.substring(separator + 1);
          fields[key] = line.substring(separator + 1);
        }
      }
    }
    onProgress?.call('Extracting calendar events', .85);
    return events;
  }

  List<String> _unfold(String text) {
    final output = <String>[];
    for (final line in text.split(RegExp(r'\r?\n'))) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          output.isNotEmpty) {
        output[output.length - 1] += line.substring(1);
      } else {
        output.add(line);
      }
    }
    return output;
  }

  DateTime? _calendarDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final raw = value.startsWith('VALUE=DATE:') ? value.substring(11) : value;
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?',
    ).firstMatch(raw);
    if (match == null) return DateTime.tryParse(raw);
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.tryParse(match.group(4) ?? '0') ?? 0,
      int.tryParse(match.group(5) ?? '0') ?? 0,
      int.tryParse(match.group(6) ?? '0') ?? 0,
    );
  }

  String? _parameter(String key, String name) {
    final match = RegExp(
      ';$name=([^;:]+)',
      caseSensitive: false,
    ).firstMatch(key);
    return match?.group(1);
  }

  String _value(String line) {
    final index = line.indexOf(':');
    return index < 0 ? line : line.substring(index + 1);
  }

  String? _temporalFragment(String text) {
    final match = RegExp(
      r'((?:today|tomorrow|yesterday|next|this|last)?\s*'
      r'(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
      r'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
      r'jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|'
      r'nov(?:ember)?|dec(?:ember)?|\d{1,4}[/-]\d{1,2}(?:[/-]\d{2,4})?)'
      r'(?:[^.!?]{0,40})?'
      r'(?:\d{1,2}(?::\d{2})?\s*(?:am|pm)|\d{1,2}:\d{2}|noon|midnight))',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) return match.group(1);
    final recurring = RegExp(
      r'\b(?:every|each)\s+(?:day|week|month|year|monday|tuesday|wednesday|'
      r'thursday|friday|saturday|sunday)\b[^.!?]{0,60}',
      caseSensitive: false,
    ).firstMatch(text);
    return recurring?.group(0);
  }

  String _title(String text, String temporal) {
    final without = text
        .replaceFirst(temporal, '')
        .replaceAll(RegExp(r'^[\s,:;-]+|[\s,:;-]+$'), '');
    return without.isEmpty ? text : without;
  }

  double _interpretationConfidence(ParsedDate parsed, String title) {
    var score = .55;
    if (parsed.isScheduled) score += .2;
    if (parsed.canonicalTime != null) score += .15;
    if (title.length >= 3) score += .1;
    return score.clamp(0, 1);
  }

  String? _sourceSection(ContentBlock block) {
    final metadata = block.metadata;
    final worksheet = metadata['worksheetName']?.toString();
    if (worksheet != null && worksheet.isNotEmpty) {
      return 'sheet $worksheet';
    }
    final slide = metadata['slideNumber']?.toString();
    if (slide != null && slide.isNotEmpty) return 'slide $slide';
    final part = metadata['part']?.toString();
    if (part != null && part.isNotEmpty) return part;
    return block.sectionIndex?.toString();
  }

  String? _labelValue(String text, String label) {
    final match = RegExp(
      '^\\s*${RegExp.escape(label)}\\s*:\\s*(.+)\$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  String? _url(String text) {
    final labeled = _labelValue(text, 'url');
    if (labeled != null) return labeled;
    return RegExp(
      r'https?://[^\\s<>()]+',
      caseSensitive: false,
    ).firstMatch(text)?.group(0);
  }

  List<ExtractedEvent> _dedupe(List<ExtractedEvent> input) {
    final seen = <String>{};
    return input.where((event) {
      final key = '${event.title.toLowerCase()}|${event.date}|${event.time}';
      return seen.add(key);
    }).toList();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

List<Map<String, Object?>> _boundedTextChunks(
  List<Map<String, Object?>> inputs,
) {
  const maxChars = 1200;
  const overlap = 120;
  final output = <Map<String, Object?>>[];
  for (final input in inputs) {
    final text = (input['text'] as String? ?? '').trim();
    if (text.isEmpty) continue;
    if (text.length <= maxChars) {
      output.add({
        ...input,
        'text': text,
        'metadata': {
          ...(((input['metadata'] as Map?) ?? {}).cast<String, dynamic>()),
          'sourceSpanStart': 0,
          'sourceSpanEnd': text.length,
          'chunkIndex': 0,
          'chunkLength': text.length,
          'sourceText': text,
        },
      });
      continue;
    }
    var start = 0;
    var chunkIndex = 0;
    while (start < text.length) {
      final end = (start + maxChars).clamp(0, text.length);
      final chunk = text.substring(start, end).trim();
      if (chunk.isNotEmpty) {
        final metadata = ((input['metadata'] as Map?) ?? {})
            .cast<String, dynamic>();
        output.add({
          ...input,
          'text': chunk,
          'order': (input['order'] as int? ?? 0) + chunkIndex,
          'metadata': {
            ...metadata,
            'sourceSpanStart': start,
            'sourceSpanEnd': end,
            'chunkIndex': chunkIndex,
            'chunkLength': text.length,
          },
        });
      }
      if (end == text.length) break;
      start = end - overlap;
      chunkIndex++;
    }
  }
  return output;
}
