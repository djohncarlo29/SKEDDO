import '../ai/parsed_date.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScheduledEvent — the core event data class.
//
// Kept in its own file to break the circular-import chain that would arise if
// EventStore (which imports AIServices) and DeterministicMatcher (which uses
// ScheduledEvent) were both in event_store.dart.
//
// All existing code that imports event_store.dart continues to see
// ScheduledEvent because event_store.dart re-exports this file.
// ─────────────────────────────────────────────────────────────────────────────
class ScheduledEvent {
  final String id;
  final String title;

  /// Optional subtitle / notes shown below the title.
  final String? subtitle;

  /// Start date as a human-readable string (e.g. "August 8, 2026").
  /// Null for unscheduled events.
  final String? date;

  /// Start time as a human-readable string (e.g. "3:00 PM").
  /// Null for all-day or unscheduled events.
  final String? time;

  /// End date (all-day multi-day or timed spanning events).
  /// Null when not set or when the event is unscheduled.
  final String? endDate;

  /// End time. Null for all-day or unscheduled events.
  final String? endTime;

  /// True when the event occupies full day(s) with no specific time.
  final bool isAllDay;

  final String? location;

  /// Destination (future Google Maps integration).
  final String? destination;

  /// User's travel-time estimate, e.g. "1 hour", "30 minutes", "None".
  final String? travelTime;

  /// Travel mode, e.g. "Car", "Walking", "Transit". "None" when unset.
  final String? travelMode;

  /// Repeat rule label, e.g. "Every Week", "Every Day", or a custom label.
  /// "Never" (or null) means no recurrence.
  final String? repeat;

  /// When the repeat ends: "Never" or "On Date".
  final String? repeatEndType;

  /// The end date for "On Date" repeat, formatted as a human-readable string.
  final String? repeatEndDate;

  /// Serialised custom repeat config (frequency, selectedDays, etc.).
  /// Non-null only when [repeat] is a custom label.
  final Map<String, dynamic>? customRepeatConfig;

  /// First alert rule, e.g. "At time of event", "20 minutes before".
  final String? alert;

  /// Second alert rule, e.g. "None", "30 minutes before travel time".
  final String? secondAlert;

  /// URL attached to the event (saved as plain text; UI renders as hyperlink).
  final String? url;

  /// Free-form notes the user added.
  final String? notes;

  /// Absolute file-system paths to persisted attachment files.
  /// Each file is stored in the app's documents directory under skeddo_attachments/.
  final List<String>? attachmentPaths;

  /// Structured date/time metadata populated by the AI pipeline.
  /// Null when the event has no date/time, or before the pipeline has run.
  final ParsedDate? parsedDate;

  /// The ID of the standard category this event belongs to.
  /// Defaults to 'sys-uncategorized' for events with no explicit assignment.
  final String categoryId;

  // ── Unscheduled-event reminder ──────────────────────────────────────────────

  /// Reminder option for unscheduled events: null / 'Never' means no reminder;
  /// 'On Date' means a notification fires at [reminderDateTime].
  final String? reminderOption;

  /// ISO 8601 datetime string for the unscheduled-event reminder.
  /// Non-null only when [reminderOption] is 'On Date'.
  final String? reminderDateTime;

  /// Repeat cadence for the reminder.
  /// One of the built-in cadence labels or a custom recurrence label.
  final String? reminderRepeat;

  /// Serialised custom repeat config when [reminderRepeat] is custom.
  final Map<String, dynamic>? reminderCustomRepeatConfig;

  /// ISO 8601 timestamp set once at creation time.
  /// Null for events created before this field was introduced.
  final String? createdAt;

  /// AI-assigned priority level.
  ///   0 = None  1 = Low  2 = Medium  3 = High
  /// Set automatically by EventPipeline after embedding; defaults to 0.
  final int priority;

  const ScheduledEvent({
    required this.id,
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
    this.url,
    this.notes,
    this.attachmentPaths,
    this.parsedDate,
    this.categoryId = 'sys-uncategorized',
    this.reminderOption,
    this.reminderDateTime,
    this.reminderRepeat,
    this.reminderCustomRepeatConfig,
    this.createdAt,
    this.priority = 0,
  });

  /// Return a copy with the category-preset fields replaced.
  /// All other fields (title, date/time, url, notes, attachments, etc.)
  /// are preserved unchanged.  Pass null to clear an optional field.
  ScheduledEvent copyWithPreset({
    required String? location,
    required String? destination,
    required String? travelTime,
    required String? travelMode,
    required String? repeat,
    required String? repeatEndType,
    required String? repeatEndDate,
    required Map<String, dynamic>? customRepeatConfig,
    required String? alert,
    required String? secondAlert,
  }) => ScheduledEvent(
    id: id,
    title: title,
    subtitle: subtitle,
    date: date,
    time: time,
    endDate: endDate,
    endTime: endTime,
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
    url: url,
    notes: notes,
    attachmentPaths: attachmentPaths,
    parsedDate: parsedDate,
    categoryId: categoryId,
    reminderOption: reminderOption,
    reminderDateTime: reminderDateTime,
    reminderRepeat: reminderRepeat,
    reminderCustomRepeatConfig: reminderCustomRepeatConfig,
    createdAt: createdAt,
    priority: priority,
  );

  /// Return a copy assigned to a different standard category.
  ///
  /// Category reassignment is intentionally isolated from the other event
  /// fields so deleting a category can move its events to Uncategorized
  /// without changing any event content or scheduling data.
  ScheduledEvent copyWithCategory(String newCategoryId) => ScheduledEvent(
    id: id,
    title: title,
    subtitle: subtitle,
    date: date,
    time: time,
    endDate: endDate,
    endTime: endTime,
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
    url: url,
    notes: notes,
    attachmentPaths: attachmentPaths,
    parsedDate: parsedDate,
    categoryId: newCategoryId,
    reminderOption: reminderOption,
    reminderDateTime: reminderDateTime,
    reminderRepeat: reminderRepeat,
    reminderCustomRepeatConfig: reminderCustomRepeatConfig,
    createdAt: createdAt,
    priority: priority,
  );

  /// Return a copy with [parsedDate] updated (used by the EventPipeline).
  ScheduledEvent withParsedDate(ParsedDate? pd) => ScheduledEvent(
    id: id,
    title: title,
    subtitle: subtitle,
    date: date,
    time: time,
    endDate: endDate,
    endTime: endTime,
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
    url: url,
    notes: notes,
    attachmentPaths: attachmentPaths,
    parsedDate: pd,
    categoryId: categoryId,
    reminderOption: reminderOption,
    reminderDateTime: reminderDateTime,
    reminderRepeat: reminderRepeat,
    reminderCustomRepeatConfig: reminderCustomRepeatConfig,
    createdAt: createdAt,
    priority: priority,
  );

  /// Return a copy with [priority] updated by the AI pipeline.
  ScheduledEvent copyWithPriority(int newPriority) => ScheduledEvent(
    id: id,
    title: title,
    subtitle: subtitle,
    date: date,
    time: time,
    endDate: endDate,
    endTime: endTime,
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
    url: url,
    notes: notes,
    attachmentPaths: attachmentPaths,
    parsedDate: parsedDate,
    categoryId: categoryId,
    reminderOption: reminderOption,
    reminderDateTime: reminderDateTime,
    reminderRepeat: reminderRepeat,
    reminderCustomRepeatConfig: reminderCustomRepeatConfig,
    createdAt: createdAt,
    priority: newPriority,
  );

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (subtitle != null && subtitle!.isNotEmpty) 'subtitle': subtitle,
    if (date != null) 'date': date,
    if (time != null) 'time': time,
    if (endDate != null) 'endDate': endDate,
    if (endTime != null) 'endTime': endTime,
    if (isAllDay) 'isAllDay': isAllDay,
    if (location != null && location!.isNotEmpty) 'location': location,
    if (destination != null && destination!.isNotEmpty)
      'destination': destination,
    if (travelTime != null && travelTime != 'None') 'travelTime': travelTime,
    if (travelMode != null && travelMode != 'None') 'travelMode': travelMode,
    if (repeat != null && repeat != 'Never') 'repeat': repeat,
    if (repeatEndType != null && repeatEndType != 'Never')
      'repeatEndType': repeatEndType,
    if (repeatEndDate != null) 'repeatEndDate': repeatEndDate,
    if (customRepeatConfig != null) 'customRepeatConfig': customRepeatConfig,
    if (alert != null && alert != 'None') 'alert': alert,
    if (secondAlert != null && secondAlert != 'None')
      'secondAlert': secondAlert,
    if (reminderOption != null && reminderOption != 'Never')
      'reminderOption': reminderOption,
    if (reminderDateTime != null) 'reminderDateTime': reminderDateTime,
    if (reminderRepeat != null && reminderRepeat != 'Never')
      'reminderRepeat': reminderRepeat,
    if (reminderCustomRepeatConfig != null)
      'reminderCustomRepeatConfig': reminderCustomRepeatConfig,
    if (url != null && url!.isNotEmpty) 'url': url,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (attachmentPaths != null && attachmentPaths!.isNotEmpty)
      'attachmentPaths': attachmentPaths,
    if (parsedDate != null) 'parsedDate': parsedDate!.toJson(),
    'categoryId': categoryId,
    if (createdAt != null) 'createdAt': createdAt,
    if (priority != 0) 'priority': priority,
  };

  factory ScheduledEvent.fromJson(Map<String, dynamic> j) {
    final pdMap = j['parsedDate'];
    final rawAttachments = j['attachmentPaths'];
    final rawCustomConfig = j['customRepeatConfig'];
    final rawReminderCustomConfig = j['reminderCustomRepeatConfig'];
    return ScheduledEvent(
      id: (j['id'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      subtitle: j['subtitle'] as String?,
      date: j['date'] as String?,
      time: j['time'] as String?,
      endDate: j['endDate'] as String?,
      endTime: j['endTime'] as String?,
      isAllDay: (j['isAllDay'] as bool?) ?? false,
      location: j['location'] as String?,
      destination: j['destination'] as String?,
      travelTime: j['travelTime'] as String?,
      travelMode: j['travelMode'] as String?,
      repeat: j['repeat'] as String?,
      repeatEndType: j['repeatEndType'] as String?,
      repeatEndDate: j['repeatEndDate'] as String?,
      customRepeatConfig: rawCustomConfig is Map<String, dynamic>
          ? rawCustomConfig
          : null,
      alert: j['alert'] as String?,
      secondAlert: j['secondAlert'] as String?,
      reminderOption: j['reminderOption'] as String?,
      reminderDateTime: j['reminderDateTime'] as String?,
      reminderRepeat: j['reminderRepeat'] as String?,
      reminderCustomRepeatConfig:
          rawReminderCustomConfig is Map<String, dynamic>
          ? rawReminderCustomConfig
          : null,
      url: j['url'] as String?,
      notes: j['notes'] as String?,
      attachmentPaths: rawAttachments is List
          ? rawAttachments.cast<String>()
          : null,
      parsedDate: pdMap is Map<String, dynamic>
          ? ParsedDate.fromJson(pdMap)
          : null,
      // Legacy events saved before this field existed default to Uncategorized.
      categoryId: (j['categoryId'] as String?)?.isNotEmpty == true
          ? j['categoryId'] as String
          : 'sys-uncategorized',
      // Null for events created before this field was introduced.
      createdAt: j['createdAt'] as String?,
      priority: (j['priority'] as int?) ?? 0,
    );
  }
}
