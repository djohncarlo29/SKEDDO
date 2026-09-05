import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../app_theme.dart';

/// The app-wide liquid-glass switch.
///
/// All switch controls go through this wrapper so their interaction sizing,
/// disabled treatment, and theme colors stay consistent while the visual
/// control is always [LiquidGlassSwitch].
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.height = 44.0,
    this.color,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? CupertinoTheme.of(context).primaryColor;
    final inactiveColor = resolveThemeColor(kTertiaryLabel, context);

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: SizedBox(
          height: height,
          child: Center(
            child: LiquidGlassSwitch(
              value: value,
              onChanged: onChanged,
              width: 70.0,
              height: 31.0,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Makes a row containing an [AppSwitch] toggle from any point in the row.
///
/// Keep the row's complete layout in [child]. The wrapper expands it to the
/// available width and uses the same value callback as the switch itself, so
/// future switch rows get consistent interaction behavior by construction.
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onChanged(!value) : null,
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}
