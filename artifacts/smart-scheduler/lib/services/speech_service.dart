import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/rounded_cupertino_sheet.dart';

// Offline-only speech-to-text service. Recognition is performed by the
// platform's native speech engine; no network or language-model API is used.
enum SttRequestResult { granted, denied, userCancelled }

class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  static const _methodChannel = MethodChannel('com.smartscheduler/stt');
  static const _eventChannel = EventChannel('com.smartscheduler/stt_events');
  StreamSubscription<dynamic>? _eventSubscription;
  bool _sessionActive = false;
  bool _available = false;
  bool _listening = false;
  bool _prePromptShown = false;
  static const _kMicPermissionPromptContinued =
      'skeddo_mic_permission_prompt_continued_v1';

  bool get isListening => _listening;
  bool get isAvailable => _available;

  Future<SttRequestResult> requestPermission(BuildContext context) async {
    if (_available) return SttRequestResult.granted;
    if (kIsWeb) return SttRequestResult.denied;

    if (!_prePromptShown) {
      var continuedPreviously = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        continuedPreviously =
            prefs.getBool(_kMicPermissionPromptContinued) ?? false;
      } catch (_) {}

      if (continuedPreviously) {
        _prePromptShown = true;
      } else {
        _prePromptShown = true;
        if (!context.mounted) {
          _prePromptShown = false;
          return SttRequestResult.userCancelled;
        }
        final proceed = await MicPermissionSheet.show(context);
        if (!proceed || !context.mounted) {
          _prePromptShown = false;
          return SttRequestResult.userCancelled;
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_kMicPermissionPromptContinued, true);
        } catch (_) {}
      }
    }

    try {
      final granted =
          await _methodChannel.invokeMethod<bool>('requestPermission') ?? false;
      _available =
          granted &&
          (await _methodChannel.invokeMethod<bool>('isAvailable') ?? false);
      return _available ? SttRequestResult.granted : SttRequestResult.denied;
    } on MissingPluginException {
      return SttRequestResult.denied;
    } on PlatformException {
      return SttRequestResult.denied;
    }
  }

  Future<bool> startListening({
    required void Function(String words) onPartial,
    required void Function(String words) onFinal,
    void Function()? onError,
  }) async {
    if (kIsWeb) return false;
    await cancel();
    _sessionActive = true;

    try {
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen((
        event,
      ) {
        if (!_sessionActive || event is! Map) return;
        final type = event['type']?.toString();
        final words = event['words']?.toString() ?? '';
        if (type == 'partial' && words.isNotEmpty) {
          onPartial(words);
        } else if (type == 'final') {
          _listening = false;
          onFinal(words);
        } else if (type == 'error') {
          _listening = false;
          onError?.call();
        }
      });
      final started = await _methodChannel.invokeMethod<bool>('start') ?? false;
      if (!started) {
        await _eventSubscription?.cancel();
        _eventSubscription = null;
        _sessionActive = false;
        return false;
      }
      _listening = true;
      return true;
    } on MissingPluginException {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _sessionActive = false;
      return false;
    } on PlatformException {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _sessionActive = false;
      _listening = false;
      return false;
    }
  }

  Future<void> stop() async {
    _sessionActive = false;
    _listening = false;
    await _methodChannel.invokeMethod<void>('stop').catchError((_) {});
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  Future<void> cancel() async {
    _sessionActive = false;
    _listening = false;
    await _methodChannel.invokeMethod<void>('cancel').catchError((_) {});
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}

class MicPermissionSheet {
  static Future<bool> show(BuildContext context) async {
    final result = await showSafeCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Microphone Access'),
        message: const Text(
          'Smart Scheduler needs microphone access to transcribe your voice into text.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),
      ),
    );
    return result ?? false;
  }
}
