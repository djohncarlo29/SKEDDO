// Web stub — tflite_flutter uses dart:ffi which is incompatible with dart2js.
// This file satisfies the conditional import in ai_services.dart on web;
// TFLiteEmbeddingService is never instantiated on web (kIsWeb guard in
// AIServices.init()), so it can simply delegate to NullEmbeddingService.
import '../interfaces.dart';

class TFLiteEmbeddingService implements EmbeddingService {
  @override
  int get dimensions => 0;

  Future<void> init() async {}

  @override
  Future<List<double>> embed(String text) async => [];
}
