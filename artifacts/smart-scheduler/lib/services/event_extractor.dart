import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class ExtractedEvent {
  final String title;
  final String? date;
  final String? time;
  final String? location;

  const ExtractedEvent({
    required this.title,
    this.date,
    this.time,
    this.location,
  });

  factory ExtractedEvent.fromJson(Map<String, dynamic> j) => ExtractedEvent(
    title: (j['title'] as String?)?.trim() ?? '',
    date: (j['date'] as String?)?.trim(),
    time: (j['time'] as String?)?.trim(),
    location: (j['location'] as String?)?.trim(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Extraction service
// ─────────────────────────────────────────────────────────────────────────────
//
// Routing logic:
//   Web               → same-origin proxy  /api/gemini/extract
//   Mobile + proxy    → PROXY_BASE_URL/api/gemini/extract
//   Mobile + key only → Gemini REST API directly (key from .env)
// ─────────────────────────────────────────────────────────────────────────────
class EventExtractor {
  static const _geminiModel = 'gemini-2.5-flash';
  static const _geminiHost =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _extractPrompt =
      'Look at this image and extract every event, meeting, appointment, '
      'reminder, deadline, or scheduled activity you can find. '
      'Return a JSON array of objects. Each object must have: '
      '"title" (string, required), '
      '"date" (string, optional — use natural language like "June 5" or "next Monday"), '
      '"time" (string, optional — use "3:00 PM" format), '
      '"location" (string, optional). '
      'Return ONLY the raw JSON array with no markdown fences or extra text. '
      'If there are no events, return [].';

  static String get _proxyBase => dotenv.env['PROXY_BASE_URL'] ?? '';
  static String get _directKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static bool get _hasProxy => kIsWeb || _proxyBase.isNotEmpty;
  static bool get _hasDirectKey => !kIsWeb && _directKey.isNotEmpty;
  static bool get _enabled => _hasProxy || _hasDirectKey;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Extract events from image bytes (multimodal Gemini call).
  static Future<List<ExtractedEvent>> fromImage(
    Uint8List bytes,
    String mimeType,
  ) async {
    _assertEnabled();
    if (_hasProxy) {
      final base = kIsWeb ? '' : _proxyBase;
      final response = await http
          .post(
            Uri.parse('$base/api/gemini/extract'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'imageBase64': base64Encode(bytes),
              'mimeType': mimeType,
            }),
          )
          .timeout(const Duration(seconds: 30));
      return _parseProxy(response);
    } else {
      return _directFromImage(bytes, mimeType);
    }
  }

  /// Extract events from plain text.
  static Future<List<ExtractedEvent>> fromText(String text) async {
    _assertEnabled();
    if (_hasProxy) {
      final base = kIsWeb ? '' : _proxyBase;
      final response = await http
          .post(
            Uri.parse('$base/api/gemini/extract'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 30));
      return _parseProxy(response);
    } else {
      return _directFromText(text);
    }
  }

  // ── Direct Gemini calls (mobile, no proxy) ──────────────────────────────────

  static Future<List<ExtractedEvent>> _directFromImage(
    Uint8List bytes,
    String mimeType,
  ) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(bytes),
              },
            },
            {'text': _extractPrompt},
          ],
        },
      ],
      'generationConfig': {'maxOutputTokens': 8192},
    });
    final raw = await _callGeminiDirect(body);
    return _parseGeminiText(raw);
  }

  static Future<List<ExtractedEvent>> _directFromText(String text) async {
    final prompt =
        'Extract events from the following text:\n\n$text\n\n$_extractPrompt';
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'maxOutputTokens': 8192},
    });
    final raw = await _callGeminiDirect(body);
    return _parseGeminiText(raw);
  }

  static Future<String> _callGeminiDirect(String body) async {
    final uri = Uri.parse(
      '$_geminiHost/$_geminiModel:generateContent?key=$_directKey',
    );
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw ExtractionException(
        'AI analysis failed (HTTP ${response.statusCode})',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['candidates']?[0]?['content']?['parts']?[0]?['text']
            as String?) ??
        '';
  }

  static List<ExtractedEvent> _parseGeminiText(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '')
        .replaceAll(RegExp(r'```$', multiLine: true), '')
        .trim();
    List<dynamic> events = [];
    try {
      events = jsonDecode(cleaned) as List;
    } catch (_) {}
    return events
        .whereType<Map<String, dynamic>>()
        .map(ExtractedEvent.fromJson)
        .where((e) => e.title.isNotEmpty)
        .toList();
  }

  // ── Proxy response parser ───────────────────────────────────────────────────

  static List<ExtractedEvent> _parseProxy(http.Response response) {
    if (response.statusCode != 200) {
      throw ExtractionException(
        'AI analysis failed (HTTP ${response.statusCode})',
      );
    }
    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('error')) {
      throw ExtractionException('AI analysis failed: ${data['error']}');
    }
    final raw = (data as Map<String, dynamic>)['events'] as List? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ExtractedEvent.fromJson)
        .where((e) => e.title.isNotEmpty)
        .toList();
  }

  static void _assertEnabled() {
    if (!_enabled) {
      throw ExtractionException(
        'AI service not configured — add GEMINI_API_KEY to your .env file.',
      );
    }
  }
}

class ExtractionException implements Exception {
  final String message;
  const ExtractionException(this.message);
  @override
  String toString() => 'ExtractionException: $message';
}
