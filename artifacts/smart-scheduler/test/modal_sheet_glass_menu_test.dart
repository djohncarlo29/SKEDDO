import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' show GlassMenu;

import 'package:smart_scheduler/widgets/action_panel.dart'
    show ActionItem, ModalSheetGlassMenu;

void main() {
  testWidgets('modal picker menu keeps its text trigger free of a glass blob', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: ModalSheetGlassMenu(
            trigger: const Text('October'),
            actions: [
              ActionItem(
                label: 'November',
                icon: CupertinoIcons.circle,
                onTap: () {},
              ),
            ],
            semanticLabel: 'Month, October',
            builder: (context, menuTrigger, openMenu) => menuTrigger,
          ),
        ),
      ),
    );

    final menu = tester.widget<GlassMenu>(find.byType(GlassMenu));
    expect(menu.morphFromZero, isTrue);
    expect(menu.triggerImpactStrength, 1.15);
    expect(find.text('October'), findsOneWidget);
  });
}
