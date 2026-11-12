import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassMenu, GlassMenuItem;

import 'package:smart_scheduler/widgets/action_panel.dart'
    show ActionItem, ModalSheetGlassMenu;

void main() {
  testWidgets('modal picker menu keeps its text trigger free of a glass blob', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Center(
            child: ModalSheetGlassMenu(
              trigger: const Text('October'),
              actions: [
                ActionItem(
                  label: 'November',
                  icon: CupertinoIcons.circle,
                  checkmark: true,
                  onTap: () {},
                ),
                ActionItem(
                  label: 'December',
                  icon: CupertinoIcons.circle,
                  onTap: () {},
                ),
              ],
              semanticLabel: 'Month, October',
              builder: (context, menuTrigger, openMenu) => menuTrigger,
            ),
          ),
        ),
      ),
    );

    final menu = tester.widget<GlassMenu>(find.byType(GlassMenu));
    expect(menu.morphFromZero, isTrue);
    expect(menu.triggerImpactStrength, 1.15);
    expect(menu.keepTriggerAnchorOnOverflow, isTrue);
    expect(menu.menuContentHorizontalInset, 0);
    expect(find.text('October'), findsOneWidget);

    final options = menu.items.whereType<GlassMenuItem>().toList();
    expect(options, hasLength(2));
    for (final option in options) {
      expect(option.iconSize, 25.5);
      expect(option.iconLabelGap, 16);
      expect(option.trailing, isNull);
      final iconSlot = option.icon! as SizedBox;
      expect(iconSlot.width, 25.5);
      expect(iconSlot.height, 25.5);
    }
    final checkmark = (options.first.icon! as SizedBox).child as Icon;
    expect(checkmark.icon, CupertinoIcons.checkmark);
    expect(checkmark.size, 25.5);
    expect((options.last.icon! as SizedBox).child, isA<SizedBox>());
  });
}
