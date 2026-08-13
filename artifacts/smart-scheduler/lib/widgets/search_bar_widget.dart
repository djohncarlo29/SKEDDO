import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show DeviceGestureSettings, kTouchSlop;
import 'squircle_glow.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import '../app_theme.dart';
import '../services/speech_service.dart';
import 'native_text_input.dart';
import 'fixed_size_icon.dart';

// ── Shared constants ──────────────────────────────────────────────────────────
// kSbCornerRadius is the shared 24 px card/section radius. The search bar's
// stadium geometry has its own explicit 20 px token below.
const double kSbCornerRadius = kCornerRadius;
const kSbCursorColor = kAccentColor;

/// The TapRegion group that covers every text input in the app.  A tap on any
/// widget in the group does NOT fire onTapOutside on other group members.
const String kSbGroupId = 'smart-scheduler-text-fields';

/// Stable Cupertino selection controls whose handles follow a live colour
/// notifier.  Keeping the controls instance stable is important: changing its
/// identity makes EditableText recreate the selection overlay and can disrupt
/// cursor/selection gestures mid-interaction.
class TintedCupertinoTextSelectionControls
    extends CupertinoTextSelectionControls
    with TextSelectionHandleControls {
  TintedCupertinoTextSelectionControls(this.colorNotifier);

  final ValueNotifier<Color> colorNotifier;

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    return ValueListenableBuilder<Color>(
      valueListenable: colorNotifier,
      builder: (_, color, __) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          gestureSettings: const DeviceGestureSettings(touchSlop: kTouchSlop),
        ),
        child: CupertinoTheme(
          data: CupertinoThemeData(primaryColor: color),
          child: Builder(
            builder: (ctx) => ColorFiltered(
              // CupertinoTextSelectionControls does not consistently use
              // CupertinoTheme.primaryColor for the handle asset on every
              // platform.  The category sheets explicitly tint the rendered
              // handle, so keep the shared search control visually identical
              // when a DCV supplies its category colour.
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              child: super.buildHandle(ctx, type, textLineHeight, onTap),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search-mode state (module-level so it survives widget rebuilds) ────────────
/// True while any search bar in the app is focused.  Used by
/// [sbDismissTextFieldFocus] to block accidental tap-outside dismissals while
/// the user is in "search mode".
bool sbSearchModeActive = false;

/// Fires true when a context-menu overlay is opening, false when it has fully
/// closed.  NativeTextInput listens to this and swaps out its platform view
/// for an empty SizedBox so the BackdropFilter can blur the area cleanly
/// (platform views are composited outside Flutter's layer and cannot be
/// blurred by BackdropFilter).
final ValueNotifier<bool> sbContextMenuActive = ValueNotifier(false);

/// Callback that dismisses the currently-open category long-press context menu.
/// Set to [_CategoryContextMenuState._hide] when a menu opens; cleared on close.
/// Allows AppShell's OS-back handler to dismiss the overlay without holding a
/// direct reference into the deep widget tree.
final ValueNotifier<VoidCallback?> sbContextMenuDismiss = ValueNotifier(null);

/// Dismisses both the native platform text input and the Flutter framework
/// focus, unless a search bar is currently active (in which case the
/// X-circle button is the only allowed exit).
void sbDismissTextFieldFocus() {
  if (sbSearchModeActive) return;
  NativeTextInput.unfocusAll();
  FocusManager.instance.primaryFocus?.unfocus();
}

/// Called by AppShell synchronously on every tab switch so the mode-gate is
/// always cleared even before the async platform-channel blur arrives.
void sbResetSearchMode() {
  sbSearchModeActive = false;
}

// ── SearchWeightedIcon ────────────────────────────────────────────────────────
/// Renders a Cupertino glyph with a faux-bold stroke via a same-coloured
/// shadow halo.  [weight] controls thickness (0.4 = original, 1.0 = bold).
class SearchWeightedIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final double weight;

  /// Extra space added on every side of the bounding box (default 0).
  /// Keeps [fontSize] at [size] while giving glyphs that draw near or
  /// beyond the em-square edge room to render without being clipped.
  final double boxPadding;
  final bool shadowsEnabled;

  const SearchWeightedIcon(
    this.icon, {
    super.key,
    required this.size,
    required this.color,
    this.weight = 0.4,
    this.boxPadding = 0,
    this.shadowsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fontFamily = icon.fontPackage != null
        ? 'packages/${icon.fontPackage}/${icon.fontFamily}'
        : (icon.fontFamily ?? '');
    final boxSize = size + boxPadding * 2;
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(
        child: RichText(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              inherit: false,
              color: color,
              fontSize: size,
              fontFamily: fontFamily,
              fontStyle: FontStyle.normal,
              shadows: shadowsEnabled
                  ? resolveThemeTextShadows([
                      Shadow(color: color, blurRadius: weight),
                    ], context)
                  : null,
            ),
          ),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

// ── AppSearchBar ──────────────────────────────────────────────────────────────
/// The functional search bar used in both NotesTab and EventsTab.
class AppSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool>? onFocusChanged;
  final String placeholder;

  /// Optional tint for caret, selection highlight, and selection handles.
  /// DCV search bars use the active category colour; regular search bars
  /// continue to use the app accent.
  final Color? selectionTint;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.onFocusChanged,
    this.placeholder = 'Search',
    this.selectionTint,
  });

  @override
  State<AppSearchBar> createState() => AppSearchBarState();
}

class AppSearchBarState extends State<AppSearchBar>
    with SingleTickerProviderStateMixin {
  bool _micPressed = false;
  bool _micListening = false;
  bool _micBusy = false; // guard: prevents AnimatedSwitcher ghost taps
  int _sttSession = 0;

  String _preListenText = '';
  Timer? _sttBoundaryTimer;
  // [GEMINI LIVE: glow state kept as inert variables so the SquircleGlowBorder
  //  widget in the build tree compiles and can be re-activated by un-commenting
  //  the mutation sites below.  Values are never set to true while the hybrid
  //  Gemini Live engine is active — formatting happens in-stream, no glow needed.]
  String _bgRaw = '';
  String _bgFormatted = '';
  bool _bgActive = false;
  bool _glowActive = false;
  int _bgLock = 0;

  late final AnimationController _pulseCtrl;
  late final ValueNotifier<Color> _selectionColorNotifier;
  late final TintedCupertinoTextSelectionControls _selectionControls;

  @override
  void initState() {
    super.initState();
    _selectionColorNotifier = ValueNotifier<Color>(
      widget.selectionTint ?? kAccentColor,
    );
    _selectionControls = TintedCupertinoTextSelectionControls(
      _selectionColorNotifier,
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.4,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _sttBoundaryTimer?.cancel();
    _pulseCtrl.dispose();
    _selectionColorNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSelectionColor();
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionTint != widget.selectionTint) {
      _syncSelectionColor();
    }
  }

  void _syncSelectionColor() {
    final color = widget.selectionTint ?? resolveAccentColor(context);
    if (_selectionColorNotifier.value != color) {
      _selectionColorNotifier.value = color;
    }
  }

  // ── Cancel mic from outside (called by parent's _cancelSearch) ────────────
  void cancelMic() {
    if (!_micListening && !_micBusy) return;
    _sttSession++;
    _sttBoundaryTimer?.cancel();
    // [GEMINI LIVE] _bgLock++;
    // [GEMINI LIVE] _bgRaw = ''; _bgFormatted = ''; _bgActive = false; _glowActive = false;
    _pulseCtrl.stop();
    _pulseCtrl.value = 1.0;
    setState(() {
      _micListening = false;
      _micBusy = false;
    });
    SpeechService.instance.cancel();
  }

  // ── [GEMINI LIVE] Gemini REST finalization — commented out, not deleted ──────
  // Replaced by the in-stream Gemini Live path in SpeechService.  Re-enable
  // these two methods (and the mutation sites in _onMicTap below) to restore
  // the old two-step REST correction + AI glow flow.
  //
  // Future<void> _finalizeDictation(String words, int sessionId) async {
  //   final rawTail = words.length > _bgRaw.length
  //       ? words.substring(_bgRaw.length).trim()
  //       : '';
  //   if (rawTail.isNotEmpty) {
  //     final lockId = ++_bgLock;
  //     if (mounted) setState(() { _bgActive = true; _glowActive = true; });
  //     final tailCorrected =
  //         await SpeechService.instance.applySmartPunctuation(rawTail);
  //     if (!mounted || _sttSession != sessionId || _bgLock != lockId) {
  //       if (mounted) setState(() { _bgActive = false; _glowActive = false; _micListening = false; _micBusy = false; });
  //       return;
  //     }
  //     final full = _bgFormatted.isNotEmpty
  //         ? '$_bgFormatted $tailCorrected'
  //         : tailCorrected;
  //     widget.controller.text = full;
  //   } else if (_bgFormatted.isNotEmpty) {
  //     widget.controller.text = _bgFormatted;
  //   }
  //   _bgRaw = ''; _bgFormatted = ''; _bgActive = false;
  //   if (mounted) setState(() { _micListening = false; _glowActive = false; });
  //   await Future.delayed(const Duration(milliseconds: 250));
  //   if (mounted) setState(() { _micBusy = false; });
  // }
  //
  // Future<void> _backgroundCorrect(String words, int sessionId) async {
  //   final newRaw = words.length > _bgRaw.length
  //       ? words.substring(_bgRaw.length).trim()
  //       : '';
  //   if (newRaw.isEmpty) return;
  //   final lockId = ++_bgLock;
  //   if (mounted) setState(() { _bgActive = true; _glowActive = true; });
  //   final corrected = await SpeechService.instance.applySmartPunctuation(newRaw);
  //   if (!mounted || _sttSession != sessionId || _bgLock != lockId) return;
  //   _bgRaw = words;
  //   _bgFormatted = _bgFormatted.isEmpty ? corrected : '$_bgFormatted $corrected';
  //   if (mounted) setState(() { _bgActive = false; });
  // }

  Future<void> _onMicTap() async {
    // Guard: prevents the AnimatedSwitcher fade-out ghost tap from re-firing.
    if (_micBusy) return;
    _micBusy = true;

    final svc = SpeechService.instance;

    if (_micListening) {
      _sttSession++;
      _sttBoundaryTimer?.cancel();
      // [GEMINI LIVE] _bgLock++;
      // [GEMINI LIVE] _bgRaw = ''; _bgFormatted = ''; _bgActive = false; _glowActive = false;
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
      // Keep _micBusy = true until AnimatedSwitcher fade-out finishes (200ms)
      // so any ghost tap on the outgoing widget is blocked.
      setState(() {
        _micListening = false;
      });
      await svc.cancel();
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted)
        setState(() {
          _micBusy = false;
        });
      return;
    }

    if (!mounted) {
      _micBusy = false;
      return;
    }
    final result = await svc.requestPermission(context);
    if (!mounted) {
      _micBusy = false;
      return;
    }

    if (result == SttRequestResult.denied) {
      _micBusy = false;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Microphone Access Denied'),
          content: const Text(
            'To use voice input, enable microphone access in your device Settings.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (result == SttRequestResult.userCancelled) {
      _micBusy = false;
      return;
    }

    // [GEMINI LIVE] _bgRaw = ''; _bgFormatted = ''; _bgActive = false; _glowActive = false; _bgLock++;
    _preListenText = widget.controller.text;
    final sessionId = ++_sttSession;

    // Focus the search field — this also triggers onFocusChanged → search mode.
    NativeTextInput.focus(widget.controller);

    // Show listening UI optimistically — reset below if the engine fails to start.
    setState(() => _micListening = true);
    _pulseCtrl.repeat(reverse: true);

    // Tracks the most recent raw dictation text so a native "error" event
    // (session died without a proper 'final') can still finalize gracefully
    // with whatever was already transcribed, instead of losing it.
    String lastWords = '';

    void endSession(String words) {
      if (!mounted || _sttSession != sessionId) return;
      _sttBoundaryTimer?.cancel();
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
      // Commit whatever was transcribed (already smart-formatted by Gemini Live
      // in-stream; no post-processing step needed).
      if (words.trim().isNotEmpty) {
        widget.controller.text = words.trim();
      }
      setState(() {
        _micListening = false;
      });
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted)
          setState(() {
            _micBusy = false;
          });
      });
      // [GEMINI LIVE] Old two-step REST correction path:
      // _bgRaw = ''; _bgFormatted = ''; _bgActive = false; _glowActive = false;
      // _finalizeDictation(words.trim(), sessionId);
    }

    final started = await svc.startListening(
      onPartial: (words) {
        if (!mounted || _sttSession != sessionId) return;
        lastWords = words;
        widget.controller.text = words;
        // [GEMINI LIVE] Background Gemini REST correction timer removed —
        // in-stream formatting from Gemini Live means no post-processing needed.
        // _sttBoundaryTimer?.cancel();
        // final rawNew = words.length > _bgRaw.length
        //     ? words.substring(_bgRaw.length).trim()
        //     : '';
        // if (rawNew.isNotEmpty) {
        //   _sttBoundaryTimer = Timer(
        //     const Duration(milliseconds: 1800),
        //     () => _backgroundCorrect(words, sessionId),
        //   );
        // }
      },
      onFinal: endSession,
      // Native recognizer stopped/errored without ever sending 'final' (e.g.
      // Android "no match"/"speech timeout" after a silence) — end the
      // session using whatever was last transcribed so the mic doesn't get
      // stuck showing the blue pulsing "listening" state forever.
      onError: () => endSession(lastWords),
    );

    // startListening() returned false — engine couldn't start.
    if (!mounted || _sttSession != sessionId) return;
    if (!started) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
      setState(() {
        _micListening = false;
        _micBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = resolveThemeColor(kSbSurface, context);
    final tertiaryLabel = resolveThemeColor(kTertiaryLabel, context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final emptyStateIcon = resolveThemeColor(kEmptyStateIcon, context);
    final selectionTint = widget.selectionTint ?? resolveAccentColor(context);
    return SizedBox(
      height: 40,
      child: Stack(
        // Clip.none allows the outer glow to bleed past the 40 px bounds.
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: surfaceColor,
              shape: const SquircleStadiumBorder(
                radius: kSearchBarCornerRadius,
              ),
              shadows: resolveThemeShadows(kCardShadow, context),
            ),
            child: Row(
              children: [
                SizedBox(width: 13),
                SearchWeightedIcon(
                  CupertinoIcons.search,
                  size: 17,
                  color: tertiaryLabel,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ClipRect(
                    child: TapRegion(
                      groupId: kSbGroupId,
                      child: CupertinoTheme(
                        data: CupertinoTheme.of(
                          context,
                        ).copyWith(primaryColor: selectionTint),
                        child: DefaultSelectionStyle(
                          selectionColor: selectionTint.withOpacity(0.20),
                          child: NativeTextInput(
                            controller: widget.controller,
                            onFocusChanged: widget.onFocusChanged,
                            placeholder: widget.placeholder,
                            placeholderStyle: TextStyle(
                              inherit: false,
                              color: secondaryLabel,
                              fontSize: 17,
                              fontFamily: kSFProText,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.normal,
                              letterSpacing: kTracking16,
                            ),
                            style: TextStyle(
                              inherit: false,
                              fontSize: 17,
                              color: primaryLabel,
                              fontFamily: kSFProText,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.normal,
                              letterSpacing: kTracking16,
                              height: kLineHeight,
                            ),
                            padding: const EdgeInsets.only(top: 0),
                            cursorColor: selectionTint,
                            selectionColor: selectionTint.withOpacity(0.20),
                            selectionControls: _selectionControls,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Mic icon (idle) ↔ clear-circle (has text) — animated switcher
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, child) {
                    final bool hasText = value.text.isNotEmpty;
                    return SizedBox(
                      width: 31,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          final scale = Tween<double>(begin: 0.5, end: 1.0)
                              .animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                ),
                              );
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: scale, child: child),
                          );
                        },
                        child: _micListening
                            // ── Listening: pulsing accent mic, tap to stop ──────────
                            ? GestureDetector(
                                key: const ValueKey('search-mic-listen'),
                                onTap: _onMicTap,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    5,
                                    8,
                                    10,
                                    8,
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _pulseCtrl,
                                    builder: (_, __) => Opacity(
                                      opacity: _pulseCtrl.value,
                                      child: FixedSFIcon(
                                        SFIcons.sf_microphone_fill,
                                        fontSize: 15,
                                        color: resolveAccentColor(context),
                                        shadows: resolveThemeTextShadows([
                                          Shadow(
                                            color: resolveAccentColor(context),
                                            blurRadius: 0.4,
                                          ),
                                        ], context),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            // ── Has text: clear button ──────────────────────────────
                            : hasText
                            ? GestureDetector(
                                key: const ValueKey('search-clear'),
                                onTap: () => widget.controller.clear(),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(5, 8, 10, 8),
                                  child: Icon(
                                    kSearchClearCircleIcon,
                                    size: 18,
                                    color: emptyStateIcon,
                                  ),
                                ),
                              )
                            // ── Empty + idle: dim mic, tap to start ────────────
                            : AnimatedTapIcon(
                                key: const ValueKey('search-mic'),
                                padding: const EdgeInsets.fromLTRB(5, 8, 10, 8),
                                onTap: _onMicTap,
                                onPressedChanged: (pressed) =>
                                    setState(() => _micPressed = pressed),
                                child: FixedSFIcon(
                                  SFIcons.sf_microphone_fill,
                                  fontSize: 15,
                                  color: _micPressed
                                      ? secondaryLabel
                                      : tertiaryLabel,
                                  shadows: resolveThemeTextShadows([
                                    Shadow(
                                      color: _micPressed
                                          ? secondaryLabel
                                          : tertiaryLabel,
                                      blurRadius: 0.4,
                                    ),
                                  ], context),
                                ),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 3),
              ],
            ),
          ), // Container
          // ── AI glow — outer-edge glow around the search bar pill ────────
          // Shown while Gemini is actively correcting (_bgActive).  Outer mode
          // inverts the clip so blur bleeds outward past the pill border.
          // Stack(clipBehavior: Clip.none) allows the overflow to paint.
          if (_glowActive)
            Positioned.fill(
              child: IgnorePointer(
                child: SquircleGlowBorder(
                  cornerRadius: kSearchBarCornerRadius,
                  stadium: true,
                  outer: true,
                  glowWidth: 5,
                  blurSigma: 6,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    ); // SizedBox + Stack
  }
}

// ── SearchCancelButton ────────────────────────────────────────────────────────
/// The X-circle button that appears to the right of the search bar when it
/// gains focus.  Driven by [animation] (AppShell's AnimationController) so it
/// advances frame-for-frame with the header collapse.
/// Tapping triggers a gel-bloom scale animation (same easeOutBack character
/// as the attachment-viewer circle buttons).
class SearchCancelButton extends StatefulWidget {
  final Animation<double>? animation;
  final bool searchFocused;
  final VoidCallback onTap;

  const SearchCancelButton({
    super.key,
    required this.searchFocused,
    required this.onTap,
    this.animation,
  });

  @override
  State<SearchCancelButton> createState() => _SearchCancelButtonState();
}

class _SearchCancelButtonState extends State<SearchCancelButton> {
  static const double _kFullWidth = 50.0;

  @override
  Widget build(BuildContext context) {
    final circle = _buildCircle(context);
    if (widget.animation != null) {
      return AnimatedBuilder(
        animation: widget.animation!,
        builder: (context, child) {
          final t = widget.animation!.value.clamp(0.0, 1.0);
          if (t < 0.005) return const SizedBox(height: 40);
          return SizedBox(
            width: _kFullWidth * t,
            height: 40,
            child: Opacity(opacity: t, child: child),
          );
        },
        child: circle,
      );
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.centerLeft,
      child: widget.searchFocused ? circle : const SizedBox(height: 40),
    );
  }

  Widget _buildCircle(BuildContext context) {
    final surfaceColor = resolveThemeColor(kCardColor, context);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    return TapRegion(
      groupId: kSbGroupId,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: GelBloomButton(
          peakScale: 1.15,
          tapDelay: const Duration(milliseconds: 130),
          onTap: widget.onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: surfaceColor,
              shape: CircleBorder(),
              shadows: shadows,
            ),
            child: Center(
              child: SearchWeightedIcon(
                CupertinoIcons.xmark,
                size: 20,
                color: primaryLabel,
                weight: kGelBloomIconWeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── SearchNoResults ───────────────────────────────────────────────────────────
/// "No Results" empty-state content — just the icon + title + subtitle.
/// Call sites are responsible for adding the separator above and centring this
/// widget in the correct available area (accounting for keyboard height).
class SearchNoResults extends StatelessWidget {
  const SearchNoResults({super.key});

  @override
  Widget build(BuildContext context) {
    final emptyStateIcon = resolveThemeColor(kEmptyStateIcon, context);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SearchWeightedIcon(
          CupertinoIcons.search,
          size: 64,
          color: emptyStateIcon,
        ),
        SizedBox(height: 18),
        Text(
          'No Results',
          textAlign: TextAlign.center,
          style: TextStyle(
            inherit: false,
            color: primaryLabel,
            fontSize: 22,
            fontFamily: kSFProDisplay,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            letterSpacing: -0.3,
            height: 1.15,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Check the spelling or try a new search.',
          textAlign: TextAlign.center,
          style: TextStyle(
            inherit: false,
            color: secondaryLabel,
            fontSize: 15,
            fontFamily: kSFProText,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            letterSpacing: kTracking16,
            height: kLineHeight,
          ),
        ),
      ],
    );
  }
}
