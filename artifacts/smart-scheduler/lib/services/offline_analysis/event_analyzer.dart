import '../../ai/ai_services.dart';
import '../../ai/interfaces.dart';
import '../../ai/parsed_date.dart';
import '../../ai/date_parser/rule_based_date_parser.dart';
import 'contracts.dart';
import 'models.dart';

class DefaultEventAnalyzer implements EventAnalyzer {
  final DateParser parser;

  DefaultEventAnalyzer({DateParser? parser}) : parser = parser ?? RuleBasedDateParser();

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
    final sourceBlocks = content.blocks.isEmpty
        ? [
            ContentBlock(
              kind: ContentBlockKind.paragraph,
              text: content.plainText,
              order: 0,
            ),
          ]
        : content.blocks;
    final total = sourceBlocks.isEmpty ? 1 : sourceBlocks.length;

    for (var index = 0; index < sourceBlocks.length; index++) {
      cancellation?.throwIfCancelled();
      final block = sourceBlocks[index];
      final text = block.text.trim();
      if (text.isEmpty) continue;
      final temporal = _temporalFragment(text);
      if (temporal == null) continue;
      final parsed = parser.parse(temporal);
      if (!parsed.isScheduled && parsed.canonicalTime == null && !parsed.isRecurring) {
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

      events.add(ExtractedEvent(
        title: title,
        date: parsed.canonicalDate,
        time: parsed.canonicalTime,
        endDate: parsed.endDateTime == null ? null : _date(parsed.endDateTime!),
        endTime: parsed.canonicalEndTime,
        recurrence: parsed.recurrence,
        timeZone: parsed.timezone,
        originalDateText: temporal,
        originalTimeText: parsed.rawInput,
        sourceFile: content.sourceName,
        sourcePage: block.pageIndex,
        sourceSection: block.sectionIndex?.toString(),
        sourceText: text,
        boundingBox: block.boundingBox,
        extractionMethod: 'deterministic+minilm',
        extractionConfidence: content.extractionConfidence,
        interpretationConfidence: _interpretationConfidence(parsed, title),
        warnings: content.warnings,
        semanticRelevance: semanticRelevance,
      ));
      onProgress?.call('Checking event relevance', .65 + .3 * ((index + 1) / total));
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
      final zone = _parameter(fields.keys.firstWhere(
        (key) => key.startsWith('DTSTART;'),
        orElse: () => 'DTSTART',
      ), 'TZID');
      events.add(ExtractedEvent(
        title: summary,
        date: _date(start),
        time: _time(start),
        endDate: end == null ? null : _date(end),
        endTime: end == null ? null : _time(end),
        location: fields['LOCATION'],
        recurrence: fields['RRULE'],
        timeZone: zone ?? fields['X-WR-TIMEZONE'],
        originalDateText: startRaw,
        originalTimeText: endRaw,
        sourceFile: content.sourceName,
        sourceText: fields.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        extractionMethod: 'ics-deterministic',
        extractionConfidence: 1,
        interpretationConfidence: 1,
        uid: fields['UID'],
        organizer: fields['ORGANIZER'],
        attendees: List.unmodifiable(attendees),
        alarms: List.unmodifiable(alarms),
      ));
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
      if ((line.startsWith(' ') || line.startsWith('\t')) && output.isNotEmpty) {
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
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?')
        .firstMatch(raw);
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
    final match = RegExp(';$name=([^;:]+)', caseSensitive: false).firstMatch(key);
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
    final without = text.replaceFirst(temporal, '').replaceAll(RegExp(r'^[\s,:;-]+|[\s,:;-]+$'), '');
    return without.isEmpty ? text : without;
  }

  double _interpretationConfidence(ParsedDate parsed, String title) {
    var score = .55;
    if (parsed.isScheduled) score += .2;
    if (parsed.canonicalTime != null) score += .15;
    if (title.length >= 3) score += .1;
    return score.clamp(0, 1);
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