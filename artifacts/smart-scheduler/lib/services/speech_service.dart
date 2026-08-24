import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onResult(false),
          child: const ColoredBox(
            color: Color(0x44000000),
            child: SizedBox.expand(),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                                  fontFamily: 'SFProText',
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
                                  fontFamily: 'SFProText',
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
