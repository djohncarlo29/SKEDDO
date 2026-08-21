import 'dart:math' as math;
import 'dart:typed_data';

import 'contracts.dart';
import 'extractors.dart';
import 'models.dart';
import 'native_ocr.dart';

class DefaultContentPreprocessor implements ContentPreprocessor {
  final OfflineOcrService ocr;

  const DefaultContentPreprocessor({
    this.ocr = const NativeOfflineOcrService(),
  });

  @override
  Future<ExtractedContent> preprocess(
    ExtractedContent content, {
    Uint8List? sourceBytes,
    AnalysisCancellationToken? cancellation,
    AnalysisProgress? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    onProgress?.call('Normalizing content', .45);

    var normalized = _normalize(content);
    if (content.detectedType == DetectedFileType.image ||
        (content.detectedType == DetectedFileType.pdf &&
            content.extractionConfidence < .55)) {
      cancellation?.throwIfCancelled();
      onProgress?.call('Running OCR', .55);
      try {
        final pageIndices = content.detectedType == DetectedFileType.pdf
            ? _ocrPageIndices(content)
            : null;
        final ocrContent = await ocr.recognize(
          sourceName: content.sourceName,
          bytes: sourceBytes ?? Uint8List(0),
          sourceType: content.detectedType,
          pageIndices: pageIndices,
          cancellation: cancellation,
          onProgress: onProgress,
        );
        normalized = _merge(content, ocrContent);
      } on OfflineExtractionException {
        rethrow;
      }
    }
    return normalized;
  }

  List<int> _ocrPageIndices(ExtractedContent content) {
    final encoded = content.metadata['ocrPageIndices'];
    if (encoded == null || encoded.trim().isEmpty) return const [0];
    return encoded.split(',').map(int.tryParse).whereType<int>().toList();
  }

  ExtractedContent _normalize(ExtractedContent content) {
    final blocks = content.blocks
        .map(
          (block) => ContentBlock(
            kind: block.kind,
            text: _clean(block.text),
            pageIndex: block.pageIndex,
            sectionIndex: block.sectionIndex,
            boundingBox: block.boundingBox,
            order: block.order,
            metadata: block.metadata,
          ),
        )
        .where((block) => block.text.isNotEmpty)
        .toList();
    final plain = blocks.isEmpty
        ? _clean(content.plainText)
        : blocks.map((b) => b.text).join('\n');
    final deduped = <String>{};
    final filtered = blocks.where((b) => deduped.add(b.text)).toList();
    return content.copyWith(
      plainText: filtered.map((b) => b.text).join('\n').isEmpty
          ? plain
          : filtered.map((b) => b.text).join('\n'),
      blocks: filtered,
      sections: filtered,
      warnings: [
        ...content.warnings,
        if (filtered.length != blocks.length)
          'Repeated content was removed before analysis.',
      ],
    );
  }

  ExtractedContent _merge(
    ExtractedContent original,
    ExtractedContent ocrContent,
  ) {
    return original.copyWith(
      plainText: ocrContent.plainText,
      blocks: ocrContent.blocks,
      pages: ocrContent.pages,
      sections: ocrContent.sections,
      images: ocrContent.images,
      warnings: [...original.warnings, ...ocrContent.warnings],
      extractionConfidence: math.min(
        original.extractionConfidence + .2,
        ocrContent.extractionConfidence,
      ),
    );
  }

  String _clean(String text) => text
      .replaceAll('\u0000', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .trim();
}
