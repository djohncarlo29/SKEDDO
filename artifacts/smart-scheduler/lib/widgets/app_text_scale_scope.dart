import 'package:flutter/widgets.dart';

import '../app_settings.dart';

const _customTextScaleTransitionDuration = Duration(milliseconds: 150);

/// Applies SKEDDO's Custom text scaler to the app content without making
/// text-size changes rebuild the CupertinoApp configuration.
///
/// System mode leaves the platform's ambient [MediaQuery.textScaler]
/// untouched. Custom mode animates between the selected scaler curves while
/// the slider moves.
class AppTextScaleScope extends StatelessWidget {
  const AppTextScaleScope({super.key, required this.child});

  final Widget child;

  static final Listenable _settings = Listenable.merge([
    appTextSizeUsesSystemNotifier,
    appTextSizeIndexNotifier,
    appSkeddoTextScaleMappingNotifier,
    appCustomTextScalerNotifier,
  ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _settings,
    child: child,
    builder: (context, child) {
      final content = child!;
      final mediaQuery = MediaQuery.of(context);
      final usesSystem = appTextSizeUsesSystemNotifier.value;
      final targetScaler = usesSystem
          ? mediaQuery.textScaler
          : _customTextScaler();
      final animationsDisabled = usesSystem || mediaQuery.disableAnimations;

      return TweenAnimationBuilder<TextScaler>(
        tween: _TextScalerTween(begin: targetScaler, end: targetScaler),
        duration: animationsDisabled
            ? Duration.zero
            : _customTextScaleTransitionDuration,
        curve: Curves.easeOutCubic,
        child: content,
        builder: (context, scaler, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        ),
      );
    },
  );

  static TextScaler _customTextScaler() {
    final selectedScaler = appCustomTextScalerNotifier.value;
    if (selectedScaler != null) return selectedScaler;

    final mapping = appSkeddoTextScaleMappingNotifier.value;
    final index = appTextSizeIndexNotifier.value;
    final mappedScale = index < mapping.length
        ? mapping[index].scale
        : skeddoTextScaleForIndex(index);
    return TextScaler.linear(mappedScale);
  }
}

/// Interpolates the output of both curves at each font size, preserving
/// nonlinear platform scaling throughout the transition.
class _TextScalerTween extends Tween<TextScaler> {
  _TextScalerTween({required super.begin, required super.end});

  @override
  TextScaler lerp(double t) {
    if (t <= 0) return begin!;
    if (t >= 1) return end!;
    return _InterpolatedTextScaler(begin!, end!, t);
  }
}

class _InterpolatedTextScaler extends TextScaler {
  const _InterpolatedTextScaler(this.begin, this.end, this.progress);

  final TextScaler begin;
  final TextScaler end;
  final double progress;

  @override
  double scale(double fontSize) {
    final start = begin.scale(fontSize);
    return start + (end.scale(fontSize) - start) * progress;
  }

  @override
  double get textScaleFactor => scale(16) / 16;
}
