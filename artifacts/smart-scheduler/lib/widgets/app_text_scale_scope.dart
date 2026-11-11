import 'package:flutter/widgets.dart';

import '../app_settings.dart';

/// Applies SKEDDO's Custom text scaler to the app content without making
/// text-size changes rebuild the CupertinoApp configuration.
///
/// System mode leaves the platform's ambient [MediaQuery.textScaler]
/// untouched. Custom mode updates this scope live while the slider moves.
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
      if (appTextSizeUsesSystemNotifier.value) return content;

      final customScaler = appCustomTextScalerNotifier.value;
      if (customScaler != null) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: customScaler),
          child: content,
        );
      }

      final mapping = appSkeddoTextScaleMappingNotifier.value;
      final index = appTextSizeIndexNotifier.value;
      final mappedScale = index < mapping.length
          ? mapping[index].scale
          : skeddoTextScaleForIndex(index);
      return MediaQuery.withClampedTextScaling(
        minScaleFactor: mappedScale,
        maxScaleFactor: mappedScale,
        child: content,
      );
    },
  );
}
