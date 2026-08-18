import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app_theme.dart';
import 'fixed_size_icon.dart';

/// The AppShell's platform-neutral floating tab control.
///
/// This widget owns the pill's presentation and tab-item interaction only.
/// AppShell remains responsible for the selected index, navigation callbacks,
/// safe-area positioning, and overlay ordering.
class FloatingTabPill extends StatelessWidget {
  const FloatingTabPill({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.eventsAccent,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color eventsAccent;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final cardColor = resolveThemeColor(kCardColor, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);

    final glassSurface = cardColor.withValues(
      alpha: brightness == Brightness.dark ? 0.92 : 0.84,
    );
    final glassBorder = brightness == Brightness.dark
        ? Color.lerp(separatorColor, CupertinoColors.white, 0.18)!
        : Color.lerp(separatorColor, CupertinoColors.white, 0.48)!;
    final stadiumShape = SquircleStadiumBorder(
      side: BorderSide(color: glassBorder, width: 0.75),
    );

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shadows: resolveThemeShadows([
            BoxShadow(
              color: kTabBarShadowColor,
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ], context),
          shape: stadiumShape,
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: stadiumShape),
          // The resolved translucent surface is the portable glass fallback.
          // It intentionally avoids requiring a blur compositor on Android and
          // Flutter web, where BackdropFilter support varies by renderer.
          child: ColoredBox(
            color: glassSurface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                children: [
                  _FloatingTabItem(
                    icon: SFIcons.sf_text_document,
                    label: 'Notes',
                    active: selectedIndex == 0,
                    accentColor: resolveAccentColor(context),
                    onTap: () => onTabSelected(0),
                  ),
                  _FloatingTabItem(
                    icon: SFIcons.sf_calendar,
                    label: 'Calendar',
                    active: selectedIndex == 1,
                    accentColor: resolveAccentColor(context),
                    onTap: () => onTabSelected(1),
                  ),
                  _FloatingTabItem(
                    icon: SFIcons.sf_list_bullet,
                    label: 'Events',
                    active: selectedIndex == 2,
                    accentColor: eventsAccent,
                    onTap: () => onTabSelected(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingTabItem extends StatelessWidget {
  const _FloatingTabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? CupertinoDynamicColor.resolve(accentColor, context)
        : resolveThemeColor(kSecondaryLabel, context);
    final activeFill = active
        ? resolveThemeColor(kFloatingTabBarActivePillColor, context)
        : const Color(0x00000000);

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: kFloatingTabBarTouchTargetHeight,
            decoration: ShapeDecoration(
              color: activeFill,
              shape: const SquircleStadiumBorder(),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FixedSFIcon(
                  icon,
                  fontSize: 20,
                  fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSFProText,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.normal,
                    color: color,
                    letterSpacing: kTracking10,
                    height: kLineHeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}