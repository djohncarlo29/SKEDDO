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
    final isDark = brightness == Brightness.dark;
    final borderColor = resolveThemeColor(kTertiaryLabel, context);

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: FrostedGlassCard(
        // Use the complete ActionPanel glass material, including the bounded
        // backdrop blur, so content directly behind the tab bar is frosted.
        progress: 1.0,
        enableBackdropFilter: true,
        // Clamp the blur sample at the pill edge so the frosted treatment
        // remains visually uniform through the bottom of this permanent shell
        // control instead of fading where decal samples outside the clip.
        tileMode: TileMode.clamp,
        fillOpacity: isDark ? 0.75 : 0.65,
        shadowOpacity: 0.22,
        stadium: true,
        border: isDark
            ? BorderSide(color: borderColor, width: 0.5)
            : BorderSide.none,
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

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: kFloatingTabBarTouchTargetHeight,
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
