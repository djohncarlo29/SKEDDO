import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

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
    final selectedColor = selectedIndex == 2
        ? CupertinoDynamicColor.resolve(eventsAccent, context)
        : resolveAccentColor(context);
    final unselectedColor = resolveThemeColor(kSecondaryLabel, context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: LiquidGlassTabBar.withImpeller(
        items: [
          _tabItem(SFIcons.sf_text_document, 'Notes'),
          _tabItem(SFIcons.sf_calendar, 'Calendar'),
          _tabItem(SFIcons.sf_list_bullet, 'Events'),
        ],
        selectedIndex: selectedIndex,
        onChanged: onTabSelected,
        width: (screenWidth - (kFloatingTabBarHorizontalMargin * 2))
            .clamp(0.0, double.infinity),
        height: kFloatingTabBarHeight,
        margin: const EdgeInsets.only(bottom: kFloatingTabBarBottomSpacing),
        itemPadding: 4,
        itemStyle: LiquidGlassTabItemStyle(
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          iconSize: 20,
          labelFontSize: 11,
          iconLabelGap: 3,
          selectedFontWeight: FontWeight.w700,
          unselectedFontWeight: FontWeight.w700,
        ),
        // Keep the package's tuned glass pill, including its raised
        // transition, magnifier layer, optical rim, and settled appearance.
        pillStyle: const LiquidGlassTabPillStyle(
          mode: LiquidGlassPillMode.impellerOnly,
          animated: true,
        ),
      ),
    );
  }

  LiquidGlassTabBarItem _tabItem(IconData icon, String label) {
    return LiquidGlassTabBarItem(
      label: label,
      iconBuilder: (context, glyph) => FixedSFIcon(
        icon,
        fontSize: glyph.size,
        fontWeight: glyph.selected ? FontWeight.w500 : FontWeight.normal,
        color: glyph.color,
      ),
      labelBuilder: (context, tabLabel) => Text(
        tabLabel.text ?? label,
        style: tabLabel.textStyle.copyWith(
          fontFamily: kSFProText,
          letterSpacing: kTracking10,
          height: kLineHeight,
        ),
      ),
    );
  }
}
