import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../interfaces.dart';
import 'wordpiece_tokenizer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TFLiteEmbeddingService — on-device sentence embeddings via all-MiniLM-L6-v2
// running on TensorFlow Lite.
//
// Produces 384-dimensional L2-normalised vectors (normalisation is baked into
// the TFLite model, so no post-processing is needed).
//
// Model tensor layout (verified via ai-edge-litert Python inspection):
//   Input  0: serving_default_attention_mask:0  [1, 128]  int32
//   Input  1: serving_default_input_ids:0       [1, 128]  int32
//   Output 0: StatefulPartitionedCall:0          [1, 384]  float32
//
// Use this on Android in place of OnnxEmbeddingService — the ONNX runtime's
// JNI layer causes an unrecoverable SIGSEGV on Android; TFLite is stable.
//
// Lifecycle:
//   final svc = TFLiteEmbeddingService();
//   await svc.init();                      // loads vocab + model (~1-2 s)
//   final vec = await svc.embed('text');   // sync inference, ~20-60 ms
// ─────────────────────────────────────────────────────────────────────────────

class TFLiteEmbeddingService implements EmbeddingService {
  static const _modelAsset = 'assets/models/all-MiniLM-L6-v2.tflite';
  static const _vocabAsset = 'assets/models/vocab.txt';
  static const _seqLen = 128;
  static const _hiddenSize = 384;

  Interpreter? _interpreter;
  WordPieceTokenizer? _tokenizer;

  @override
  int get dimensions => _hiddenSize;

  /// Load vocab and TFLite model. Must be called before [embed].
  Future<void> init() async {
    // Load WordPiece vocabulary bundled as an asset (shared with ONNX service).
    final vocabRaw = await rootBundle.loadString(_vocabAsset);
    _tokenizer = WordPieceTokenizer.fromVocabLines(
      vocabRaw.split('\n'),
      maxLen: _seqLen,
    );

    // Load TFLite model from assets. The interpreter is thread-safe for reads
    // but we always call from the same isolate so no locking is needed.
    _interpreter = await Interpreter.fromAsset(_modelAsset);
  }

  @override
  Future<List<double>> embed(String text) async {
    final interpreter = _interpreter;
    final tokenizer = _tokenizer;
    if (interpreter == null || tokenizer == null) {
      return List.filled(_hiddenSize, 0.0);
    }

    final tokens = tokenizer.encode(text);

    // Wrap in outer list to form [1, 128] shape required by the model.
    final inputIdsTensor  = [tokens.inputIds];       // List<List<int>>
    final attMaskTensor   = [tokens.attentionMask];  // List<List<int>>

    // Output buffer: [1, 384] float32.
    final outputBuffer = [List<double>.filled(_hiddenSize, 0.0)];

    // Inputs ordered by tensor index:
    //   [0] attention_mask, [1] input_ids
    interpreter.runForMultipleInputs(
      [attMaskTensor, inputIdsTensor],
      {0: outputBuffer},
    );

    // outputBuffer[0] is the 384-dim L2-normalised embedding vector.
    return List<double>.from(outputBuffer[0]);
  }
}
