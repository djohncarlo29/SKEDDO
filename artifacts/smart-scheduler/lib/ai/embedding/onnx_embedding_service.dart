import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import '../interfaces.dart';
import 'wordpiece_tokenizer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OnnxEmbeddingService — on-device sentence embeddings via all-MiniLM-L6-v2.
//
// Produces 384-dimensional L2-normalised vectors using the bundled ONNX model.
// Mean pooling is applied over token embeddings (attention-mask weighted).
//
// Lifecycle:
//   final svc = OnnxEmbeddingService();
//   await svc.init();                      // loads vocab + model (~1-3 s first run)
//   final vec = await svc.embed('text');   // ~20-50 ms per call on-device
//
// Web: not supported — use NullEmbeddingService on kIsWeb.
// ─────────────────────────────────────────────────────────────────────────────

class OnnxEmbeddingService implements EmbeddingService {
  static const _modelAsset = 'assets/models/all-MiniLM-L6-v2.onnx';
  static const _vocabAsset = 'assets/models/vocab.txt';
  static const _seqLen = 128;
  static const _hiddenSize = 384;

  OrtSession? _session;
  WordPieceTokenizer? _tokenizer;

  @override
  int get dimensions => _hiddenSize;

  /// Load vocab and ONNX model. Must be called before [embed].
  Future<void> init() async {
    // Load WordPiece vocabulary bundled as an asset.
    final vocabRaw = await rootBundle.loadString(_vocabAsset);
    _tokenizer = WordPieceTokenizer.fromVocabLines(
      vocabRaw.split('\n'),
      maxLen: _seqLen,
    );

    // Extract model asset to the temp directory (cached after first run)
    // and create the ONNX Runtime session.
    _session = await OnnxRuntime().createSessionFromAsset(
      _modelAsset,
      options: OrtSessionOptions(intraOpNumThreads: 2),
    );
  }

  @override
  Future<List<double>> embed(String text) async {
    final session = _session;
    final tokenizer = _tokenizer;
    if (session == null || tokenizer == null) {
      return List.filled(_hiddenSize, 0.0);
    }

    final tokens = tokenizer.encode(text);

    // Build Int64 input tensors — shape [1, seqLen].
    final inputIds = await OrtValue.fromList(
      Int64List.fromList(tokens.inputIds),
      [1, _seqLen],
    );
    final attentionMask = await OrtValue.fromList(
      Int64List.fromList(tokens.attentionMask),
      [1, _seqLen],
    );
    final tokenTypeIds = await OrtValue.fromList(
      Int64List.fromList(tokens.tokenTypeIds),
      [1, _seqLen],
    );

    try {
      final outputs = await session.run({
        'input_ids': inputIds,
        'attention_mask': attentionMask,
        'token_type_ids': tokenTypeIds,
      });

      // last_hidden_state: shape [1, seqLen, hiddenSize], flattened.
      final hiddenState = outputs['last_hidden_state'];
      if (hiddenState == null) return List.filled(_hiddenSize, 0.0);

      final flat = await hiddenState.asFlattenedList();
      await hiddenState.dispose();

      // Mean pooling — average token vectors weighted by attention mask.
      final mask = tokens.attentionMask;
      final embedding = List<double>.filled(_hiddenSize, 0.0);
      var tokenCount = 0;
      for (var t = 0; t < _seqLen; t++) {
        if (mask[t] == 0) continue;
        tokenCount++;
        for (var h = 0; h < _hiddenSize; h++) {
          embedding[h] += (flat[t * _hiddenSize + h] as num).toDouble();
        }
      }
      if (tokenCount > 0) {
        for (var h = 0; h < _hiddenSize; h++) {
          embedding[h] /= tokenCount;
        }
      }

      // L2 normalise so cosine similarity == dot product.
      var norm = 0.0;
      for (final v in embedding) norm += v * v;
      norm = norm > 0 ? math.sqrt(norm) : 1.0;
      return embedding.map((v) => v / norm).toList();
    } finally {
      await inputIds.dispose();
      await attentionMask.dispose();
      await tokenTypeIds.dispose();
    }
  }
}
