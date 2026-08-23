import 'package:flutter/services.dart';

import 'contracts.dart';
import 'extractors.dart';
import 'models.dart';
import 'platform_support.dart';

class NativeOfflineOcrService implements OfflineOcrService {
  const NativeOfflineOcrService();

  static const _channel = MethodChannel('com.smartscheduler/offline_ocr');

  @override
  bool get isAvailable => nativeOcrPlatform;

  @override
  Future<ExtractedContent> recognize({
    required String sourceName,
    required Uint8List bytes,
    required DetectedFileType sourceType,
    List<int>? pageIndices,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    if (!nativeOcrPlatform) {
      throw const OfflineExtractionException(
        AnalysisStatus.ocrFailed,
        'Offline OCR is not available on the web build.',
      );
    }
    onProgress?.call('Preparing offline OCR', .58);
    Future<void> cancel() => _channel.invokeMethod<void>('cancel');
    cancellation?.addListener(cancel);
    try {
      final response = await _channel.invokeMethod<Object?>('recognize', {
        'sourceName': sourceName,
        'sourceType': sourceType.name,
        'bytes': bytes,
        if (pageIndices != null) 'pageIndices': pageIndices,
      });
      cancellation?.throwIfCancelled();
      if (response is! Map) {
        throw const OfflineExtractionException(
          AnalysisStatus.ocrFailed,
          'The native OCR service returned an invalid response.',
        );
      }
      final blocks = _blocks(response['blocks']);
      final metadata = <String, String>{
        'sourceName': sourceName,
        'sourceType': sourceType.name,
        'engine': '${response['engine'] ?? 'native'}',
        'offline': '${response['offline'] ?? true}',
        'confidenceSource': '${response['confidenceSource'] ?? 'engine'}',
        if (response['orientation'] != null)
          'orientation': '${response['orientation']}',
      };
      final warnings =
          (response['warnings'] as List?)
              ?.whereType<Object>()
              .map((warning) => '$warning')
              .toList() ??
          const <String>[];
      onProgress?.call('Recognizing text offline', .8);
      return ExtractedContent(
        sourceName: sourceName,
        detectedType: sourceType,
        byteSize: bytes.length,
        plainText: blocks.map((block) => block.text).join('\n'),
        blocks: blocks,
        pages: _groupPages(blocks),
        sections: _groupSections(blocks),
        metadata: metadata,
        warnings: warnings,
        extractionConfidence: _confidence(response['confidence'], blocks),
      );
    } on PlatformException catch (error) {
      if (cancellation?.isCancelled == true) {
        throw const OfflineExtractionException(
          AnalysisStatus.cancelled,
          'Offline OCR was cancelled.',
        );
      }
      throw OfflineExtractionException(
        AnalysisStatus.ocrFailed,
        error.message ?? 'Offline OCR failed.',
      );
    } on MissingPluginException {
      throw const OfflineExtractionException(
        AnalysisStatus.ocrFailed,
        'Offline OCR is not available on this platform build.',
      );
    } finally {
      cancellation?.removeListener(cancel);
    }
  }

  List<ContentBlock> _groupPages(List<ContentBlock> blocks) {
    final byPage = <int, List<ContentBlock>>{};
    for (final block in blocks) {
      byPage.putIfAbsent(block.pageIndex ?? 0, () => []).add(block);
    }
    return [
      for (final entry in byPage.entries)
        ContentBlock(
          kind: ContentBlockKind.page,
          text: entry.value.map((block) => block.text).join('\n'),
          pageIndex: entry.key,
          order: entry.key,
          metadata: {'sourcePage': entry.key},
        ),
    ];
  }

  List<ContentBlock> _groupSections(List<ContentBlock> blocks) => blocks
      .map(
        (block) => ContentBlock(
          kind: block.kind,
          text: block.text,
          pageIndex: block.pageIndex,
          sectionIndex: block.pageIndex,
          boundingBox: block.boundingBox,
          order: block.order,
          metadata: {...block.metadata, 'sourceSection': block.pageIndex},
        ),
      )
      .toList();

  List<ContentBlock> _blocks(Object? rawBlocks) {
    if (rawBlocks is! List) return const [];
    return rawBlocks
        .whereType<Map>()
        .map((raw) {
          final text = '${raw['text'] ?? ''}'.trim();
          final box = raw['boundingBox'];
          return ContentBlock(
            kind: ContentBlockKind.paragraph,
            text: text,
            pageIndex: (raw['pageIndex'] as num?)?.toInt(),
            order: (raw['order'] as num?)?.toInt() ?? 0,
            boundingBox: box is Map
                ? BoundingBox(
                    (box['left'] as num?)?.toDouble() ?? 0,
                    (box['top'] as num?)?.toDouble() ?? 0,
                    (box['width'] as num?)?.toDouble() ?? 0,
                    (box['height'] as num?)?.toDouble() ?? 0,
                  )
                : null,
            metadata: {
              'sourceFile': '${raw['sourceFile'] ?? ''}',
              'sourceType': '${raw['sourceType'] ?? ''}',
              if (raw['confidence'] != null) 'confidence': raw['confidence'],
              if (raw['orientation'] != null) 'orientation': raw['orientation'],
              if (raw['pageIndex'] != null) 'pageIndex': raw['pageIndex'],
            },
          );
        })
        .where((block) => block.text.isNotEmpty)
        .toList();
  }

  double _confidence(Object? raw, List<ContentBlock> blocks) {
    if (raw is num) return raw.toDouble();
    if (blocks.isEmpty) return 0;
    final values = blocks
        .map((block) => block.metadata['confidence'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
