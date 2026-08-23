import 'dart:typed_data';

enum DetectedFileType {
  plainText,
  markdown,
  json,
  xml,
  csv,
  html,
  log,
  ics,
  vcs,
  pdf,
  image,
  docx,
  xlsx,
  pptx,
  legacyOffice,
  rtf,
  zipArchive,
  unsupported,
  encrypted,
  corrupt,
}

enum ContentBlockKind {
  paragraph,
  heading,
  table,
  page,
  slide,
  image,
  metadata,
  unknown,
}

enum AnalysisStatus {
  success,
  successWithWarnings,
  noEventsFound,
  unsupportedFormat,
  encryptedFile,
  corruptFile,
  extractionFailed,
  ocrFailed,
  offlineModelUnavailable,
  onlineUnavailable,
  rateLimited,
  timedOut,
  cancelled,
  fileTooLarge,
}

class BoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const BoundingBox(this.left, this.top, this.width, this.height);

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };
}

class ContentBlock {
  final ContentBlockKind kind;
  final String text;
  final int? pageIndex;
  final int? sectionIndex;
  final BoundingBox? boundingBox;
  final int order;
  final Map<String, dynamic> metadata;

  const ContentBlock({
    required this.kind,
    required this.text,
    this.pageIndex,
    this.sectionIndex,
    this.boundingBox,
    this.order = 0,
    this.metadata = const {},
  });
}

class ExtractedTable {
  final String? name;
  final List<List<String>> rows;
  final int? pageIndex;
  final int? sectionIndex;
  final Map<String, dynamic> metadata;

  const ExtractedTable({
    required this.rows,
    this.name,
    this.pageIndex,
    this.sectionIndex,
    this.metadata = const {},
  });
}

class ExtractedImage {
  final String? mimeType;
  final Uint8List? bytes;
  final int? pageIndex;
  final int? sectionIndex;

  const ExtractedImage({
    this.mimeType,
    this.bytes,
    this.pageIndex,
    this.sectionIndex,
  });
}

class ExtractedContent {
  final String sourceName;
  final DetectedFileType detectedType;
  final int byteSize;
  final String plainText;
  final List<ContentBlock> blocks;
  final List<ContentBlock> pages;
  final List<ContentBlock> sections;
  final List<ExtractedTable> tables;
  final List<ExtractedImage> images;
  final Map<String, String> metadata;
  final List<String> warnings;
  final double extractionConfidence;

  const ExtractedContent({
    required this.sourceName,
    required this.detectedType,
    required this.byteSize,
    this.plainText = '',
    this.blocks = const [],
    this.pages = const [],
    this.sections = const [],
    this.tables = const [],
    this.images = const [],
    this.metadata = const {},
    this.warnings = const [],
    this.extractionConfidence = 0,
  });

  bool get hasText =>
      plainText.trim().isNotEmpty ||
      blocks.any((b) => b.text.trim().isNotEmpty);

  ExtractedContent copyWith({
    String? plainText,
    List<ContentBlock>? blocks,
    List<ContentBlock>? pages,
    List<ContentBlock>? sections,
    List<ExtractedTable>? tables,
    List<ExtractedImage>? images,
    Map<String, String>? metadata,
    List<String>? warnings,
    double? extractionConfidence,
  }) => ExtractedContent(
    sourceName: sourceName,
    detectedType: detectedType,
    byteSize: byteSize,
    plainText: plainText ?? this.plainText,
    blocks: blocks ?? this.blocks,
    pages: pages ?? this.pages,
    sections: sections ?? this.sections,
    tables: tables ?? this.tables,
    images: images ?? this.images,
    metadata: metadata ?? this.metadata,
    warnings: warnings ?? this.warnings,
    extractionConfidence: extractionConfidence ?? this.extractionConfidence,
  );
}

class ExtractedEvent {
  final String title;
  final String? subtitle;
  final String? date;
  final String? time;
  final String? endDate;
  final String? endTime;
  final bool isAllDay;
  final String? location;
  final String? destination;
  final String? travelTime;
  final String? travelMode;
  final String? repeat;
  final String? repeatEndType;
  final String? repeatEndDate;
  final Map<String, dynamic>? customRepeatConfig;
  final String? alert;
  final String? secondAlert;
  final String? reminderOption;
  final String? reminderDateTime;
  final String? reminderRepeat;
  final Map<String, dynamic>? reminderCustomRepeatConfig;
  final String? url;
  final String? notes;
  final List<String>? attachmentPaths;
  final String? categoryId;
  final String? recurrence;
  final String? timeZone;
  final String? originalDateText;
  final String? originalTimeText;
  final String? sourceFile;
  final int? sourcePage;
  final String? sourceSection;
  final String? sourceText;
  final BoundingBox? boundingBox;
  final String extractionMethod;
  final double extractionConfidence;
  final double interpretationConfidence;
  final List<String> warnings;
  final String? uid;
  final String? organizer;
  final List<String> attendees;
  final List<String> alarms;
  final double? semanticRelevance;

  const ExtractedEvent({
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
    this.reminderOption,
    this.reminderDateTime,
    this.reminderRepeat,
    this.reminderCustomRepeatConfig,
    this.url,
    this.notes,
    this.attachmentPaths,
    this.categoryId,
    this.recurrence,
    this.timeZone,
    this.originalDateText,
    this.originalTimeText,
    this.sourceFile,
    this.sourcePage,
    this.sourceSection,
    this.sourceText,
    this.boundingBox,
    this.extractionMethod = 'deterministic',
    this.extractionConfidence = 0,
    this.interpretationConfidence = 0,
    this.warnings = const [],
    this.uid,
    this.organizer,
    this.attendees = const [],
    this.alarms = const [],
    this.semanticRelevance,
  });
}

class AnalysisFailure {
  final AnalysisStatus status;
  final String message;
  final Object? cause;

  const AnalysisFailure(this.status, this.message, {this.cause});
}

class AnalysisResult {
  final AnalysisStatus status;
  final ExtractedContent? content;
  final List<ExtractedEvent> events;
  final List<String> warnings;
  final AnalysisFailure? failure;
  final bool networkUsed;

  const AnalysisResult({
    required this.status,
    this.content,
    this.events = const [],
    this.warnings = const [],
    this.failure,
    this.networkUsed = false,
  });

  bool get isSuccess =>
      status == AnalysisStatus.success ||
      status == AnalysisStatus.successWithWarnings ||
      status == AnalysisStatus.noEventsFound;
}
