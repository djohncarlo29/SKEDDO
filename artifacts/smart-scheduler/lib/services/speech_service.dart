import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket; // Gemini Live WebSocket (mobile/desktop only)
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
// OLD (native STT bridge — MethodChannel / EventChannel):
// import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// OLD (Gemini REST punctuation / capitalisation pass):
// import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart';
import '../app_theme.dart';

// ── Permission request outcome ─────────────────────────────────────────────────
enum SttRequestResult { granted, denied, userCancelled }

// ── SpeechService ──────────────────────────────────────────────────────────────
//
// Connection-aware hybrid STT engine.
//
// ── Online path (Gemini Live WebSocket): ──────────────────────────────────────
//   When the device has an internet connection, opens a persistent WebSocket
//   to the Gemini Live API and streams raw 16-kHz PCM audio from the mic.
//   Gemini returns smart-formatted text tokens in real-time, piped directly
//   into the caller's TextEditingController via the onPartial callback.
//   No post-processing step: punctuation and capitalisation are handled by the
//   model in-stream, so there is no "AI glow / waiting" phase at all.
//
// ── Offline path (speech_to_text): ────────────────────────────────────────────
//   When the device is offline (or the WebSocket fails to open), falls back
//   silently to the device's built-in native speech recogniser via the
//   speech_to_text package.  Raw words appear without AI formatting.
//   No error is thrown; the mic just works with native recognition.
//
// ── OLD native platform-channel bridge (commented out): ───────────────────────
//   Was: MethodChannel  "com.smartscheduler/stt"
//          → requestPermission, isAvailable, start, stop, cancel
//        EventChannel   "com.smartscheduler/stt_events"
//          ← { "type": "partial" | "final" | "error",  "words": String }
//   Native side: iOS SFSpeechRecognizer + AVAudioEngine;
//                Android SpeechRecognizer with free-form language model.
//   Preserved as comments so it can be restored if needed.

class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  // OLD: native channel declarations
  // static const _method = MethodChannel('com.smartscheduler/stt');
  // static const _events = EventChannel('com.smartscheduler/stt_events');

  // ── New: hybrid engine state ───────────────────────────────────────────────
  final stt.SpeechToText _sttEngine = stt.SpeechToText();
  bool _sttInitialized = false;

  AudioRecorder? _activeRecorder;
  StreamSubscription<Uint8List>? _audioSub;
  WebSocket? _activeWs;

  // Session-active flag: set to false on cancel/stop so stale async callbacks
  // from a previous session don't fire after the user has stopped.
  bool _sessionActive = false;

  // Set to true when Gemini returns a 429 / RESOURCE_EXHAUSTED error.
  // While true, startListening skips the online path and goes straight to the
  // offline speech_to_text engine so the mic keeps working under quota.
  // Reset each time startListening is called so a fresh session can retry
  // Gemini after the quota window rolls over.
  bool _geminiQuotaExceeded = false;

  bool _available = false;
  bool _listening = false;
  bool _prePromptShown = false;

  // OLD: EventChannel subscription
  // StreamSubscription<dynamic>? _eventSub;

  bool get isListening => _listening;
  bool get isAvailable => _available;

  // ── Permission + availability ─────────────────────────────────────────────────
  Future<SttRequestResult> requestPermission(BuildContext context) async {
    // Fast path — already granted.
    if (_available) return SttRequestResult.granted;

    // Web: native channels are not available.
    if (kIsWeb) return SttRequestResult.denied;

    // First launch: show rationale sheet before triggering the OS dialog.
    if (!_prePromptShown) {
      _prePromptShown = true;
      if (!context.mounted) return SttRequestResult.userCancelled;
      final proceed = await MicPermissionSheet.show(context);
      if (!proceed || !context.mounted) return SttRequestResult.userCancelled;
    }

    // NEW: use the record package to check / request microphone permission.
    // Triggers the OS system dialog on the first call.
    try {
      final recorder = AudioRecorder();
      final granted = await recorder.hasPermission();
      await recorder.dispose();
      _available = granted;
      return granted ? SttRequestResult.granted : SttRequestResult.denied;
    } catch (_) {
      return SttRequestResult.denied;
    }

    // OLD: native channel permission request
    // try {
    //   final granted =
    //       await _method.invokeMethod<bool>('requestPermission') ?? false;
    //   _available = granted;
    //   return granted ? SttRequestResult.granted : SttRequestResult.denied;
    // } catch (_) {
    //   return SttRequestResult.denied;
    // }
  }

  // ── Connectivity check ─────────────────────────────────────────────────────
  //
  // Returns true when the device has a usable network connection (WiFi or
  // mobile data).  Called before every startListening to pick the right engine.
  Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ── Listening (hybrid dispatcher) ──────────────────────────────────────────
  //
  // Returns true if recognition started, false if the engine could not start.
  // The caller is responsible for resetting its UI when false is returned.
  Future<bool> startListening({
    required void Function(String words) onPartial,
    required void Function(String words) onFinal,
    // Fires when the recognizer stops/dies WITHOUT ever sending a 'final'
    // event — e.g. Android "no match"/"speech timeout" after silence.
    // Without this the caller's "listening" UI has no way to learn the
    // session ended and gets stuck showing the pulsing mic forever.
    void Function()? onError,
  }) async {
    if (kIsWeb) return false;

    // Cancel any lingering session before starting a fresh one.
    await cancel();

    _sessionActive = true;

    // Reset the quota flag so each fresh tap retries Gemini — the quota
    // window may have rolled over since the last session.
    _geminiQuotaExceeded = false;

    // Choose engine based on current connectivity.
    final online = await isOnline();
    if (online) {
      final started = await _startOnlineSession(
        onPartial: onPartial,
        onFinal: onFinal,
        onError: onError,
      );
      if (started) return true;
      // Online session failed to open — fall back to offline engine silently.
    }

    return _startOfflineSession(
      onPartial: onPartial,
      onFinal: onFinal,
      onError: onError,
    );

    // OLD: EventChannel + MethodChannel start logic
    // _eventSub = _events.receiveBroadcastStream().listen(
    //   (dynamic event) {
    //     if (event is! Map) return;
    //     final type  = event['type']  as String?;
    //     final words = (event['words'] as String?) ?? '';
    //     switch (type) {
    //       case 'partial':
    //         onPartial(words);
    //       case 'final':
    //         _listening = false;
    //         onFinal(words);
    //       case 'error':
    //         _listening = false;
    //         onError?.call();
    //     }
    //   },
    //   onError: (_) {
    //     _listening = false;
    //     onError?.call();
    //   },
    // );
    // try {
    //   final started =
    //       await _method.invokeMethod<bool>('start') ?? false;
    //   if (started) {
    //     _listening = true;
    //   } else {
    //     await _eventSub?.cancel();
    //     _eventSub = null;
    //   }
    //   return started;
    // } catch (_) {
    //   await _eventSub?.cancel();
    //   _eventSub = null;
    //   return false;
    // }
  }

  // ── Online session: Gemini Live WebSocket ──────────────────────────────────
  //
  // Streams raw 16 kHz / 16-bit PCM audio to the Gemini Live API over a
  // persistent WebSocket.  Text tokens are returned in real-time and piped
  // directly to the caller via onPartial; no post-processing is required.
  Future<bool> _startOnlineSession({
    required void Function(String) onPartial,
    required void Function(String) onFinal,
    void Function()? onError,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) return false;

    // Gemini Live WebSocket endpoint (Multimodal Live API).
    const wsBase =
        'wss://generativelanguage.googleapis.com/ws/'
        'google.ai.generativelanguage.v1beta.GenerativeService'
        '.BidiGenerateContent';
    final wsUri = '$wsBase?key=$apiKey';

    // ── Open WebSocket ────────────────────────────────────────────────────────
    WebSocket ws;
    try {
      ws = await WebSocket.connect(wsUri).timeout(const Duration(seconds: 10));
    } catch (_) {
      return false; // no connection — caller will try offline fallback
    }
    _activeWs = ws;

    // ── Send setup message ────────────────────────────────────────────────────
    // Model: gemini-2.0-flash-live-001 (stable GA live model).
    // To try the 2.5 preview, replace the model string with:
    //   'models/gemini-live-2.5-flash-preview'
    final setupMsg = jsonEncode({
      'setup': {
        'model': 'models/gemini-2.0-flash-live-001',
        'generation_config': {
          'response_modalities': ['TEXT'],
        },
        'system_instruction': {
          'parts': [
            {
              'text':
                  'You are a real-time speech-to-text transcription engine. '
                  'Your ONLY task is to transcribe exactly what the user says, '
                  'word for word, with correct punctuation and capitalisation. '
                  'Do not comment on the content, do not answer questions, '
                  'do not add anything. Return only the transcribed text.',
            },
          ],
        },
      },
    });
    try {
      ws.add(setupMsg);
    } catch (_) {
      await _cleanupWs();
      return false;
    }

    // ── Accumulated transcript ────────────────────────────────────────────────
    final transcript = StringBuffer();

    // ── Listen for server text tokens ─────────────────────────────────────────
    ws.listen(
      (dynamic raw) {
        if (!_sessionActive) return;
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;

          // ── Quota / rate-limit error ──────────────────────────────────────
          // Gemini sends { "error": { "code": 429, "status":
          // "RESOURCE_EXHAUSTED", "message": "..." } } then closes the socket.
          // When this arrives, mark the quota flag and seamlessly hand off to
          // the offline speech_to_text engine with the same callbacks so the
          // user's mic session continues without interruption.
          final errorBlock = msg['error'] as Map<String, dynamic>?;
          if (errorBlock != null) {
            final code = errorBlock['code'] as int?;
            final status = errorBlock['status'] as String?;
            if (code == 429 || status == 'RESOURCE_EXHAUSTED') {
              _geminiQuotaExceeded = true;
              _sessionActive = false;
              _listening = false;
              _fallbackToOffline(
                onPartial: onPartial,
                onFinal: onFinal,
                onError: onError,
              );
              return;
            }
          }

          // Primary: inputTranscription — direct STT transcript of user audio.
          final inputTx =
              msg['serverContent']?['inputTranscription']?['text'] as String?;
          if (inputTx != null && inputTx.isNotEmpty) {
            transcript.write(inputTx);
            onPartial(transcript.toString());
            return;
          }

          // Fallback: modelTurn text parts (model's formatted text response).
          final parts =
              msg['serverContent']?['modelTurn']?['parts'] as List<dynamic>?;
          if (parts != null) {
            for (final part in parts) {
              final text = (part as Map<String, dynamic>)['text'] as String?;
              if (text != null && text.isNotEmpty) {
                transcript.write(text);
              }
            }
            if (transcript.isNotEmpty) {
              onPartial(transcript.toString());
            }
          }
        } catch (_) {} // malformed server message — ignore
      },
      onError: (_) {
        // WS transport error (not a Gemini JSON error — those are handled
        // above in the data handler).  Treat as a Gemini failure and hand
        // off to the offline engine so the mic keeps working.
        if (!_sessionActive) return;
        _sessionActive = false;
        _listening = false;
        _fallbackToOffline(
          onPartial: onPartial,
          onFinal: onFinal,
          onError: onError,
        );
      },
      onDone: () {
        // Socket closed.  Two cases:
        //   1. We got transcription → deliver it as the final result.
        //   2. Empty transcript (server rejected / immediately closed,
        //      e.g. key lacks Live API access, quota error already handled,
        //      network drop) → fall back to offline so the mic keeps working.
        //
        // If _sessionActive is false the close was triggered by stop() or
        // cancel() — return early; the caller already handled cleanup.
        if (!_sessionActive) return;
        _sessionActive = false;
        _listening = false;
        _activeWs = null;
        if (transcript.isNotEmpty) {
          // Successfully received transcription — clean up recorder then deliver.
          () async {
            await _audioSub?.cancel();
            _audioSub = null;
            try {
              await _activeRecorder?.stop();
            } catch (_) {}
            _activeRecorder = null;
            onFinal(transcript.toString());
          }();
        } else {
          // No transcription received — Gemini rejected / gave up.
          // Fall back to the device's built-in STT engine.
          _fallbackToOffline(
            onPartial: onPartial,
            onFinal: onFinal,
            onError: onError,
          );
        }
      },
    );

    // ── Start audio recorder and pipe chunks to WebSocket ─────────────────────
    AudioRecorder? recorder;
    try {
      recorder = AudioRecorder();
      _activeRecorder = recorder;

      final audioStream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioSub = audioStream.listen(
        (Uint8List chunk) {
          if (!_sessionActive) return;
          if (ws.closeCode != null) return; // WebSocket already closed
          try {
            ws.add(
              jsonEncode({
                'realtime_input': {
                  'media_chunks': [
                    {
                      'mime_type': 'audio/pcm;rate=16000',
                      'data': base64.encode(chunk),
                    },
                  ],
                },
              }),
            );
          } catch (_) {}
        },
        onError: (_) {
          if (_sessionActive) onError?.call();
        },
      );

      _listening = true;
      return true;
    } catch (_) {
      await _cleanupWs();
      try {
        await recorder?.dispose();
      } catch (_) {}
      _activeRecorder = null;
      return false;
    }
  }

  // ── Offline session: speech_to_text ───────────────────────────────────────
  //
  // Uses the device's built-in native speech recogniser via the
  // speech_to_text package.  Raw words are surfaced without AI formatting.
  // Fires onPartial for intermediate results and onFinal on the last result.
  Future<bool> _startOfflineSession({
    required void Function(String) onPartial,
    required void Function(String) onFinal,
    void Function()? onError,
  }) async {
    // Initialise the engine (requests OS permission if not already granted).
    if (!_sttInitialized) {
      try {
        _sttInitialized = await _sttEngine.initialize(
          onError: (_) {},
          onStatus: (_) {},
        );
      } catch (_) {
        return false;
      }
    }
    if (!_sttInitialized) return false;

    try {
      await _sttEngine.listen(
        onResult: (result) {
          if (!_sessionActive) return;
          final words = result.recognizedWords;
          if (words.isEmpty) return;
          if (result.finalResult) {
            _listening = false;
            onFinal(words);
          } else {
            onPartial(words);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      _listening = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Stop gracefully — delivers last in-progress transcription as final ─────
  Future<void> stop() async {
    _sessionActive = false;
    _listening = false;
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _activeRecorder?.stop();
    } catch (_) {}
    _activeRecorder = null;
    try {
      await _activeWs?.close();
    } catch (_) {}
    _activeWs = null;
    if (_sttInitialized) {
      try {
        await _sttEngine.stop();
      } catch (_) {}
    }

    // OLD: native channel stop
    // _listening = false;
    // if (!kIsWeb) {
    //   try { await _method.invokeMethod<void>('stop'); } catch (_) {}
    // }
    // await _eventSub?.cancel();
    // _eventSub = null;
  }

  // ── Cancel — discards any in-progress transcription ────────────────────────
  Future<void> cancel() async {
    _sessionActive = false;
    _listening = false;
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _activeRecorder?.stop();
    } catch (_) {}
    _activeRecorder = null;
    try {
      await _activeWs?.close();
    } catch (_) {}
    _activeWs = null;
    if (_sttInitialized) {
      try {
        await _sttEngine.cancel();
      } catch (_) {}
    }

    // OLD: native channel cancel
    // _listening = false;
    // if (!kIsWeb) {
    //   try { await _method.invokeMethod<void>('cancel'); } catch (_) {}
    // }
    // await _eventSub?.cancel();
    // _eventSub = null;
  }

  // ── Gemini failure → offline fallback ────────────────────────────────────
  //
  // Called from any Gemini Live failure path (transport error, silent close
  // with no transcript, 429 quota).  Properly awaits mic release before
  // handing the same callbacks to the offline speech_to_text engine.
  // Fire-and-forget: the caller does NOT await this.
  void _fallbackToOffline({
    required void Function(String) onPartial,
    required void Function(String) onFinal,
    void Function()? onError,
  }) {
    () async {
      // Release the PCM recorder before the offline engine claims the mic.
      // On Android both engines share the hardware mic — skipping this await
      // causes the offline engine to silently fail to open the audio device.
      await _audioSub?.cancel();
      _audioSub = null;
      try {
        await _activeRecorder?.stop();
      } catch (_) {}
      _activeRecorder = null;
      await _cleanupWs();

      // Re-activate the session for the offline engine and start it.
      _sessionActive = true;
      final ok = await _startOfflineSession(
        onPartial: onPartial,
        onFinal: onFinal,
        onError: onError,
      );
      if (!ok) {
        _sessionActive = false;
        _listening = false;
        onError?.call();
      }
    }();
  }

  // ── Internal WebSocket cleanup helper ─────────────────────────────────────
  Future<void> _cleanupWs() async {
    try {
      await _activeWs?.close();
    } catch (_) {}
    _activeWs = null;
  }

  // ── OLD: Gemini REST punctuation / capitalisation cleanup (commented out) ───
  //
  // This two-step approach (speak → stop → send raw text to Gemini REST →
  // wait for formatted text) produced the "AI glow" animation while the
  // network call was in flight.  Replaced by the Gemini Live in-stream path
  // above, which applies formatting in real-time with no post-processing delay.
  // Preserved here so it can be restored if needed.
  //
  // static const _geminiModel = 'gemini-2.5-flash';
  // static const _geminiHost  =
  //     'https://generativelanguage.googleapis.com/v1beta/models';
  // static const Duration correctionTimeout = Duration(seconds: 6);
  // static String get _proxyBase    => dotenv.env['PROXY_BASE_URL'] ?? '';
  // static String get _directKey    => dotenv.env['GEMINI_API_KEY'] ?? '';
  // static bool   get _hasProxy     => kIsWeb || _proxyBase.isNotEmpty;
  // static bool   get _hasDirectKey => !kIsWeb && _directKey.isNotEmpty;
  // static bool   get _enabled      => _hasProxy || _hasDirectKey;
  //
  // Future<String> applySmartPunctuation(String raw) async {
  //   if (raw.trim().isEmpty) return raw;
  //   if (!_enabled) return raw;
  //   try {
  //     if (_hasProxy) {
  //       final base     = kIsWeb ? '' : _proxyBase;
  //       final response = await http
  //           .post(
  //             Uri.parse('$base/api/gemini/punctuate'),
  //             headers: {'Content-Type': 'application/json'},
  //             body: jsonEncode({'text': raw}),
  //           )
  //           .timeout(correctionTimeout);
  //       if (response.statusCode != 200) return raw;
  //       final data = jsonDecode(response.body) as Map<String, dynamic>;
  //       final text = data['result'] as String?;
  //       return (text?.isNotEmpty == true) ? text! : raw;
  //     } else {
  //       return _directPunctuate(raw);
  //     }
  //   } catch (_) {
  //     return raw;
  //   }
  // }
  //
  // Future<String> _directPunctuate(String raw) async {
  //   final prompt =
  //       'Add correct punctuation, sentence capitalisation, and '
  //       'paragraph breaks to this speech transcription. Do not '
  //       'change, add, or remove any words — only fix punctuation '
  //       'and capitalisation. Return ONLY the corrected text with '
  //       'no explanation or extra text.\n\n$raw';
  //   final body = jsonEncode({
  //     'contents': [
  //       {'parts': [{'text': prompt}]},
  //     ],
  //     'generationConfig': {'maxOutputTokens': 1024},
  //   });
  //   final uri = Uri.parse(
  //     '$_geminiHost/$_geminiModel:generateContent?key=$_directKey',
  //   );
  //   final response = await http
  //       .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
  //       .timeout(correctionTimeout);
  //   if (response.statusCode != 200) return raw;
  //   final data      = jsonDecode(response.body) as Map<String, dynamic>;
  //   final result    = (data['candidates']?[0]?['content']?['parts']?[0]
  //                         ?['text'] as String?)
  //                       ?.trim() ??
  //                     '';
  //   return result.isNotEmpty ? result : raw;
  // }
}

// ══════════════════════════════════════════════════════════════════════════════
// MicPermissionSheet
// ══════════════════════════════════════════════════════════════════════════════
//
// Why Overlay instead of showCupertinoModalPopup:
//
//   showCupertinoModalPopup pushes a new Navigator route, which means:
//   1. It runs its own slide-up transition that completely overrides our
//      GelBloomCard spring-bloom — the user sees the OS animation, not ours.
//   2. BackdropFilter inside a route cannot blur content from the previous
//      route (they're on separate compositing layers), so the frosted glass
//      has nothing to blur and looks like a plain solid card.
//
//   Inserting directly into the Overlay (the same technique ActionPanel uses)
//   keeps the sheet in the SAME compositing layer tree as the rest of the app,
//   so BackdropFilter blurs the real content behind it, and GelBloomCard's
//   spring-bloom is the only entry animation — there is no OS slide.
class MicPermissionSheet {
  static Future<bool> show(BuildContext context) async {
    final completer = Completer<bool>();
    late final OverlayEntry entry;
    final overlay = Overlay.of(context, rootOverlay: true);

    void close(bool result) {
      if (!completer.isCompleted) {
        entry.remove();
        completer.complete(result);
      }
    }

    entry = OverlayEntry(
      builder: (_) => _MicPermissionSheetOverlay(onResult: close),
    );

    overlay.insert(entry);
    return completer.future;
  }
}

// ── Sheet overlay widget ───────────────────────────────────────────────────────
//
// Stack layout:
//   [0] Full-screen scrim GestureDetector — absorbs taps outside the card.
//       (opaque hit test so any miss-through from the card lands here)
//   [1] Align(bottomCenter) card — tested first in the Stack hit-test order
//       (last child = top of visual stack = first in hit testing), so card
//       taps are consumed before the scrim sees them.
class _MicPermissionSheetOverlay extends StatelessWidget {
  final void Function(bool) onResult;
  const _MicPermissionSheetOverlay({required this.onResult});

  @override
  Widget build(BuildContext context) {
    final accent = resolveAccentColor(context);
    final primary = resolveThemeColor(kPrimaryLabel, context);
    final secondary = resolveThemeColor(kSecondaryLabel, context);
    final micCircle = resolveThemeColor(kMicPermissionCircle, context);
    final sheetBorder = CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? BorderSide(
            color: resolveThemeColor(kTertiaryLabel, context),
            width: 0.5,
          )
        : null;
    final buttonDecor = ShapeDecoration(
      color: resolveThemeColor(kModalButtonBackground, context),
      shape: const SquircleStadiumBorder(),
      shadows: resolveThemeShadows(kCardShadow, context),
    );
    const buttonPadding = EdgeInsets.symmetric(vertical: 16);

    return Stack(
      children: [
        // ── Scrim ────────────────────────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onResult(false),
          child: const ColoredBox(
            color: Color(0x44000000),
            child: SizedBox.expand(),
          ),
        ),

        // ── Card (tested before scrim in hit-test order) ─────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              // GelBloomCard: spring-bloom entry + frosted glass — no OS
              // slide transition fighting against it.
              child: GelBloomCard(
                scaleOrigin: Alignment.bottomCenter,
                fillOpacity: 0.82,
                shadowOpacity: 0.26,
                border: sheetBorder,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Mic icon circle ────────────────────────────────────
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: micCircle,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.mic_fill,
                          size: 28,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Title ──────────────────────────────────────────────
                      Text(
                        'Microphone Access',
                        style: TextStyle(
                          inherit: false,
                          fontSize: 18,
                          fontFamily: 'SFProDisplay',
                          fontWeight: FontWeight.w600,
                          color: primary,
                          letterSpacing: kTracking16,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Body ───────────────────────────────────────────────
                      Text(
                        'Smart Scheduler needs microphone access to transcribe your voice into text.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          inherit: false,
                          fontSize: 15,
                          fontFamily: 'SFProText',
                          fontWeight: FontWeight.w400,
                          color: secondary,
                          height: 1.5,
                          letterSpacing: kTracking16,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Continue ───────────────────────────────────────────
                      GelBloomButton(
                        peakScale: 1.06,
                        tapDelay: const Duration(milliseconds: 120),
                        onTap: () => onResult(true),
                        child: Container(
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: buttonDecor,
                          child: Padding(
                            padding: buttonPadding,
                            child: Center(
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  inherit: false,
                                  fontSize: 17,
                                  fontFamily: 'SFProDisplay',
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                  letterSpacing: kTracking17,
                                  height: kLineHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Not Now ────────────────────────────────────────────
                      GelBloomButton(
                        peakScale: 1.06,
                        tapDelay: const Duration(milliseconds: 120),
                        onTap: () => onResult(false),
                        child: Container(
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: buttonDecor,
                          child: Padding(
                            padding: buttonPadding,
                            child: Center(
                              child: Text(
                                'Not Now',
                                style: TextStyle(
                                  inherit: false,
                                  fontSize: 17,
                                  fontFamily: 'SFProDisplay',
                                  fontWeight: FontWeight.w500,
                                  color: secondary,
                                  letterSpacing: kTracking17,
                                  height: kLineHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
