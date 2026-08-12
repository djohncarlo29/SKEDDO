import 'package:flutter/foundation.dart';
import '../ai/ai_services.dart';
import '../ai/parsed_date.dart';
import 'event_model.dart';
import 'local_storage.dart';
import 'recurrence_expander.dart';

// Re-export ScheduledEvent so all existing `import 'event_store.dart'` callers
// continue to see it without any import changes.
export 'event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EventStore — app-wide in-memory event store with persistence.
//
// Both the Notes tab (writes) and Events tab (reads) access this singleton.
// ValueNotifier lets any widget rebuild reactively when events change.
//
// The AI pipeline is decoupled via static callback hooks so EventStore does
// not import EventPipeline (breaking the circular dependency).  EventPipeline
// registers its hooks via [setPipelineHooks] at app startup.
// ─────────────────────────────────────────────────────────────────────────────
class EventStore {
  EventStore._();
  static final EventStore instance = EventStore._();

  final events = ValueNotifier<List<ScheduledEvent>>([]);

  int _nextId = 1;

  // ── Pipeline hooks (set by EventPipeline.init()) ───────────────────────────
  // Using bare Function types so EventStore does not import EventPipeline.
  static Future<void> Function(ScheduledEvent, List<ScheduledEvent>)? _onAdded;
  // onRemoved receives the removed event's id, its attachment paths (so the
  // pipeline can clean up files on disk), and the remaining event list.
  static Future<void> Function(
    String id,
    List<String> attachmentPaths,
    List<ScheduledEvent> allEvents,
  )?
  _onRemoved;
  // onUpdated receives only the changed event — persistence is the caller's
  // responsibility so the pipeline just re-embeds without double-saving.
  static Future<void> Function(ScheduledEvent)? _onUpdated;
  // onCleared receives the flat list of all attachment paths that were on the
  // events that just got wiped, so the pipeline can delete the files from disk.
  static Future<void> Function(List<String> allAttachmentPaths)? _onCleared;

  static void setPipelineHooks({
    required Future<void> Function(ScheduledEvent, List<ScheduledEvent>)
    onAdded,
    required Future<void> Function(
      String id,
      List<String> attachmentPaths,
      List<ScheduledEvent> allEvents,
    )
    onRemoved,
    required Future<void> Function(ScheduledEvent) onUpdated,
    Future<void> Function(List<String> allAttachmentPaths)? onCleared,
  }) {
    _onAdded = onAdded;
    _onRemoved = onRemoved;
    _onUpdated = onUpdated;
    _onCleared = onCleared;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Load persisted events from local storage.  Call once at app startup
  /// (before runApp) so the initial state is correct on first build.
  ///
  /// Migration note: any event whose [ScheduledEvent.time] or
  /// [ScheduledEvent.endTime] was stored in 24-hour format (e.g. "14:30")
  /// is silently upgraded to 12-hour AM/PM (e.g. "2:30 PM") as it is read.
  /// This is a one-way, idempotent migration — events already in 12-hour
  /// format pass through [_normalizeTime] unchanged, so it is safe to apply
  /// on every startup regardless of whether the on-device data was already
  /// upgraded.  Events imported via ICS, CSV, or paste that bypass
  /// [create()] / [update()] are therefore normalised here as a last
  /// defensive gate.
  Future<void> loadFromStorage() async {
    final saved = await LocalStorage.instance.loadEvents();
    if (saved.isNotEmpty) {
      // Advance the ID counter past all existing IDs to prevent collisions.
      _nextId = saved.fold(1, (max, e) {
        final n = int.tryParse(e.id) ?? 0;
        return n >= max ? n + 1 : max;
      });
      // Upgrade any legacy 24-hour time strings to 12-hour AM/PM.
      var anyChanged = false;
      final normalised = saved.map((e) {
        final normTime = _normalizeTime(e.time);
        final normEndTime = _normalizeTime(e.endTime);
        if (normTime == e.time && normEndTime == e.endTime) return e;
        anyChanged = true;
        return ScheduledEvent(
          id: e.id,
          title: e.title,
          subtitle: e.subtitle,
          date: e.date,
          time: normTime,
          endDate: e.endDate,
          endTime: normEndTime,
          isAllDay: e.isAllDay,
          location: e.location,
          destination: e.destination,
          travelTime: e.travelTime,
          travelMode: e.travelMode,
          repeat: e.repeat,
          repeatEndType: e.repeatEndType,
          repeatEndDate: e.repeatEndDate,
          customRepeatConfig: e.customRepeatConfig,
          alert: e.alert,
          secondAlert: e.secondAlert,
          url: e.url,
          notes: e.notes,
          attachmentPaths: e.attachmentPaths,
          parsedDate: e.parsedDate,
          categoryId: e.categoryId,
          reminderOption: e.reminderOption,
          reminderDateTime: e.reminderDateTime,
          reminderRepeat: e.reminderRepeat,
          reminderCustomRepeatConfig: e.reminderCustomRepeatConfig,
          createdAt: e.createdAt,
          priority: e.priority,
        );
      }).toList();
      events.value = normalised;
      // Write the upgraded data back so subsequent launches load cleanly
      // without needing to re-normalise the same events.
      if (anyChanged) {
        final saved = await LocalStorage.instance.saveEvents(normalised);
        if (!saved) {
          debugPrint(
            'EventStore.loadFromStorage: WARNING — time-format migration '
            'write-back failed. On-disk data still contains 24-hour time '
            'strings; migration will re-run on next launch.',
          );
        }
      }
    }
  }

  // ── Time normalisation ─────────────────────────────────────────────────────

  /// Converts any recognized time string to 12-hour AM/PM format.
  ///
  /// Accepts:
  ///   • Already-normalised 12-hour strings ("9:30 AM", "2:00 PM") — returned
  ///     with any leading zero on the hour removed and AM/PM uppercased.
  ///   • 24-hour strings ("09:00", "14:30", "20:00") — converted to 12-hour.
  ///
  /// Returns [raw] unchanged when the value is null, empty, or in an
  /// unrecognised format (so we never silently discard user data).
  static String? _normalizeTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return raw;
    final trimmed = raw.trim();

    // Use the shared temporal normalizer first so imported and conversational
    // values ("8 PM", "20:00", "2000", "around 8") are stored in the same
    // display format as picker-created values.
    final parsed = AIServices.dateParser.parse(trimmed);
    final canonical = parsed.canonicalTime;
    if (canonical != null) {
      final parts = canonical.split(':');
      var hour = int.tryParse(parts.first);
      final minute = parts.length > 1 ? parts[1] : '00';
      if (hour != null && hour >= 0 && hour <= 23) {
        final isPm = hour >= 12;
        final ampm = isPm ? 'PM' : 'AM';
        if (hour == 0) {
          hour = 12;
        } else if (hour > 12) {
          hour -= 12;
        }
        return '$hour:$minute $ampm';
      }
    }

    // ── 12-hour: "9:30 AM" / "02:00 pm" ──────────────────────────────────
    final m12 = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (m12 != null) {
      final hour = int.parse(m12.group(1)!);
      final min = m12.group(2)!;
      final ampm = m12.group(3)!.toUpperCase();
      // Remove any leading zero from hour (matches DateFormat('h:mm a') output).
      return '$hour:$min $ampm';
    }

    // ── 24-hour: "09:00" / "14:30" / "20:00" ─────────────────────────────
    final m24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (m24 != null) {
      var hour = int.parse(m24.group(1)!);
      final min = m24.group(2)!;
      if (hour < 0 || hour > 23) return raw; // guard against garbage input
      final isPm = hour >= 12;
      final ampm = isPm ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12; // midnight → 12:xx AM
      } else if (hour > 12) {
        hour -= 12;
      }
      return '$hour:$min $ampm';
    }

    // Unknown format — return as-is so no data is lost.
    return raw;
  }

  /// Build a local start/end value from the parser's canonical time.  A
  /// time-only ParsedDate intentionally has no startDateTime, so consumers
  /// must use canonicalTime when a separate event date is available.
  static DateTime? _combineCanonicalTime(
    DateTime? date,
    String? canonicalTime,
  ) {
    if (date == null || canonicalTime == null) return null;
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(canonicalTime);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static ParsedDate? _parseEventTemporal({
    required String? date,
    required String? time,
    required String? endDate,
    required String? endTime,
  }) {
    final dateText = date?.trim() ?? '';
    final endDateText = endDate?.trim() ?? '';
    final start = dateText.isEmpty ? null : AIServices.dateParser.parse(dateText);
    final startTime =
        time == null ? null : AIServices.dateParser.parse(time);
    final end =
        endDateText.isEmpty ? null : AIServices.dateParser.parse(endDateText);
    final parsedEndTime =
        endTime == null ? null : AIServices.dateParser.parse(endTime);

    final startDate = start?.absoluteDate;
    final canonicalStartTime = startTime?.canonicalTime ?? start?.canonicalTime;
    final combinedStart = _combineCanonicalTime(
      startDate,
      canonicalStartTime,
    );
    final endDateValue = end?.absoluteDate ?? startDate;
    final canonicalEndTime =
        parsedEndTime?.canonicalTime ?? end?.canonicalTime;
    final combinedEnd = _combineCanonicalTime(
      endDateValue,
      canonicalEndTime,
    );
    final parsedSource = start ?? startTime ?? end ?? parsedEndTime;
    if (parsedSource == null) return null;

    return ParsedDate(
      absoluteDate: startDate ?? parsedSource.absoluteDate,
      startDateTime: combinedStart ?? parsedSource.startDateTime,
      endDateTime: combinedEnd ?? end?.startDateTime ?? end?.absoluteDate,
      deadlineDateTime: parsedSource.deadlineDateTime,
      canonicalTime: canonicalStartTime,
      canonicalEndTime: canonicalEndTime,
      datePrecision: start?.datePrecision ?? parsedSource.datePrecision,
      timePrecision: startTime?.timePrecision ??
          start?.timePrecision ??
          parsedSource.timePrecision,
      alternateDates: start?.alternateDates ?? parsedSource.alternateDates,
      recurrence: start?.recurrence ?? parsedSource.recurrence,
      recurrenceInterval:
          start?.recurrenceInterval ?? parsedSource.recurrenceInterval,
      recurrenceWeekdays:
          start?.recurrenceWeekdays ?? parsedSource.recurrenceWeekdays,
      recurrenceOrdinal:
          start?.recurrenceOrdinal ?? parsedSource.recurrenceOrdinal,
      isRecurring: start?.isRecurring ?? parsedSource.isRecurring,
      recurrenceType: start?.recurrenceType ?? parsedSource.recurrenceType,
      recurrenceWeekday:
          start?.recurrenceWeekday ?? parsedSource.recurrenceWeekday,
      rawInput: [
        if (dateText.isNotEmpty) dateText,
        if (time != null && time.trim().isNotEmpty) time.trim(),
      ].join(' '),
    );
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  void add(ScheduledEvent event) {
    events.value = [...events.value, event];
    _onAdded?.call(event, events.value); // fire-and-forget
  }

  ScheduledEvent create({
    required String title,
    String? subtitle,
    String? date,
    String? time,
    String? endDate,
    String? endTime,
    bool isAllDay = false,
    String? location,
    String? destination,
    String? travelTime,
    String? travelMode,
    String? repeat,
    String? repeatEndType,
    String? repeatEndDate,
    Map<String, dynamic>? customRepeatConfig,
    String? alert,
    String? secondAlert,
    String? reminderOption,
    String? reminderDateTime,
    String? reminderRepeat,
    Map<String, dynamic>? reminderCustomRepeatConfig,
    String? url,
    String? notes,
    List<String>? attachmentPaths,
    String categoryId = 'sys-uncategorized',
  }) {
    // Normalise time strings to 12-hour AM/PM before storing so all events
    // have a consistent format regardless of their origin (UI, tests, imports).
    final normTime = _normalizeTime(time);
    final normEndTime = _normalizeTime(endTime);

    final parsed = _parseEventTemporal(
      date: date,
      time: normTime,
      endDate: endDate,
      endTime: normEndTime,
    );

    final e = ScheduledEvent(
      id: '${_nextId++}',
      title: title,
      subtitle: subtitle,
      date: date,
      time: normTime,
      endDate: endDate,
      endTime: normEndTime,
      isAllDay: isAllDay,
      location: location,
      destination: destination,
      travelTime: travelTime,
      travelMode: travelMode,
      repeat: repeat,
      repeatEndType: repeatEndType,
      repeatEndDate: repeatEndDate,
      customRepeatConfig: customRepeatConfig,
      alert: alert,
      secondAlert: secondAlert,
      reminderOption: reminderOption,
      reminderDateTime: reminderDateTime,
      reminderRepeat: reminderRepeat,
      reminderCustomRepeatConfig: reminderCustomRepeatConfig,
      url: url,
      notes: notes,
      attachmentPaths: attachmentPaths,
      parsedDate: parsed,
      categoryId: categoryId,
      createdAt: DateTime.now().toIso8601String(),
    );
    add(e);
    return e;
  }

  /// Replace an event by id in-place, persist, and re-embed so Smart Category
  /// matching reflects the new content immediately.
  void update(ScheduledEvent updated) {
    // Normalise time strings to 12-hour AM/PM before persisting, for the same
    // reason as create(): callers may supply 24-hour strings or mixed casing.
    final normTime = _normalizeTime(updated.time);
    final normEndTime = _normalizeTime(updated.endTime);
    final parsedDate = _parseEventTemporal(
      date: updated.date,
      time: normTime,
      endDate: updated.endDate,
      endTime: normEndTime,
    );
    final toStore = (normTime == updated.time && normEndTime == updated.endTime)
        ? updated.withParsedDate(parsedDate)
        : ScheduledEvent(
            id: updated.id,
            title: updated.title,
            subtitle: updated.subtitle,
            date: updated.date,
            time: normTime,
            endDate: updated.endDate,
            endTime: normEndTime,
            isAllDay: updated.isAllDay,
            location: updated.location,
            destination: updated.destination,
            travelTime: updated.travelTime,
            travelMode: updated.travelMode,
            repeat: updated.repeat,
            repeatEndType: updated.repeatEndType,
            repeatEndDate: updated.repeatEndDate,
            customRepeatConfig: updated.customRepeatConfig,
            alert: updated.alert,
            secondAlert: updated.secondAlert,
            url: updated.url,
            notes: updated.notes,
            attachmentPaths: updated.attachmentPaths,
            parsedDate: parsedDate,
            categoryId: updated.categoryId,
            reminderOption: updated.reminderOption,
            reminderDateTime: updated.reminderDateTime,
            reminderRepeat: updated.reminderRepeat,
            reminderCustomRepeatConfig: updated.reminderCustomRepeatConfig,
            createdAt: updated.createdAt,
            priority: updated.priority,
          );
    events.value = [
      for (final e in events.value) e.id == toStore.id ? toStore : e,
    ];
    LocalStorage.instance.saveEvents(events.value).then((ok) {
      if (!ok) {
        debugPrint(
          '[EventStore] WARNING: saveEvents returned false in update() — '
          'event list not persisted to disk; in-memory state and disk are now diverged.',
        );
      }
    }); // unawaited
    _onUpdated?.call(toStore); // fire-and-forget re-embed
  }

  /// Apply the category's new preset values to every event that belongs to
  /// [categoryId].  Fields that are null/None/Never are cleared on the event.
  /// Call this whenever a user edits a category so existing events stay in sync.
  void updateCategoryPresets({
    required String categoryId,
    String? location,
    String? destination,
    String? travelTime,
    String? travelMode,
    String? repeat,
    String? repeatEndType,
    String? repeatEndDate,
    Map<String, dynamic>? customRepeatConfig,
    String? alert,
    String? secondAlert,
  }) {
    final updated = [
      for (final e in events.value)
        e.categoryId == categoryId
            ? e.copyWithPreset(
                location: location,
                destination: destination,
                travelTime: travelTime,
                travelMode: travelMode,
                repeat: repeat,
                repeatEndType: repeatEndType,
                repeatEndDate: repeatEndDate,
                customRepeatConfig: customRepeatConfig,
                alert: alert,
                secondAlert: secondAlert,
              )
            : e,
    ];
    events.value = updated;
    LocalStorage.instance.saveEvents(updated).then((ok) {
      if (!ok) {
        debugPrint(
          '[EventStore] WARNING: saveEvents returned false in updateCategoryPresets() — '
          'event list not persisted to disk; in-memory state and disk are now diverged.',
        );
      }
    }); // unawaited
    // Re-embed all affected events so their location/destination vectors stay
    // current for Smart Category matching. Location and destination are both
    // included in the embedding text, so a preset change can shift which
    // categories an event matches.
    for (final e in updated) {
      if (e.categoryId == categoryId) _onUpdated?.call(e); // fire-and-forget
    }
  }

  /// Update only the [priority] field for [id] without firing pipeline hooks.
  /// Called exclusively by EventPipeline after AI classification to avoid
  /// triggering a re-embed loop.
  void setPriority(String id, int priority) {
    final idx = events.value.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final old = events.value[idx];
    if (old.priority == priority) return;
    final next = List<ScheduledEvent>.of(events.value);
    next[idx] = old.copyWithPriority(priority);
    events.value = next;
    LocalStorage.instance.saveEvents(next); // fire-and-forget
  }

  void remove(String id) {
    // Capture the event's attachment paths before removing it so the pipeline
    // can delete the files from disk after the event is gone from memory.
    final removed = events.value.firstWhere(
      (e) => e.id == id,
      orElse: () => ScheduledEvent(id: id, title: ''),
    );
    final attachmentPaths = removed.attachmentPaths ?? const [];
    events.value = events.value.where((e) => e.id != id).toList();
    _onRemoved?.call(id, attachmentPaths, events.value); // fire-and-forget
  }

  void clear() {
    // Collect every attachment path before wiping the list so the pipeline
    // can delete the files from disk after the events are gone from memory.
    final allPaths = events.value
        .expand((e) => e.attachmentPaths ?? const <String>[])
        .toList();
    events.value = [];
    // Persist the empty state.
    LocalStorage.instance.saveEvents([]).then((ok) {
      if (!ok) {
        debugPrint(
          '[EventStore] WARNING: saveEvents returned false in clear() — '
          'empty event list not persisted to disk; in-memory state and disk are now diverged.',
        );
      }
    }); // unawaited
    if (allPaths.isNotEmpty) {
      _onCleared?.call(allPaths); // fire-and-forget
    }
  }

  // ── Recurring expansion ────────────────────────────────────────────────────

  /// Returns all events with recurring events expanded into concrete dated
  /// instances within [[from], [to]].
  ///
  /// Non-recurring events and events with no date are always included as-is.
  /// Recurring events are replaced by their expanded occurrences; if no
  /// occurrences fall in the window the base event is kept so it is not lost.
  ///
  /// Defaults to today → 365 days from today when called with no arguments.
  /// This rolling window is wide enough for Smart Category matching and
  /// built-in smart tiles without generating an unbounded number of instances.
  List<ScheduledEvent> expandedEvents({DateTime? from, DateTime? to}) {
    final now = DateTime.now();
    final f = from ?? DateTime(now.year, now.month, now.day);
    final t = to ?? f.add(const Duration(days: 365));

    final result = <ScheduledEvent>[];
    for (final e in events.value) {
      final isRecurring = e.repeat != null && e.repeat != 'Never';
      if (!isRecurring) {
        result.add(e);
      } else {
        final occurrences = RecurrenceExpander.expand(e, f, t);
        if (occurrences.isEmpty) {
          result.add(e); // keep base so it isn't silently dropped
        } else {
          result.addAll(occurrences);
        }
      }
    }
    return result;
  }
}
