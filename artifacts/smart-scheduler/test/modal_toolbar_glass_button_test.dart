import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';

void main() {
  testWidgets('active checkmark keeps glass and follows the action color', (
    tester,
  ) async {
    const actionColor = Color(0xFF7B3FE4);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: Center(
            child: ModalToolbarGlassButton(
              icon: CupertinoIcons.checkmark,
              iconColor: CupertinoColors.white,
              surfaceColor: actionColor,
              isCheckmark: true,
              onTap: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<StaticLiquidGlassActionButton>(
        find.byType(StaticLiquidGlassActionButton),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(button.color, kModalCard);
      expect(button.isCheckmark, isFalse);
      expect(button.size, 40);
      expect(icon.color!.toARGB32(), actionColor.toARGB32());
    }
  });

  testWidgets('unavailable checkmark remains glass and is non-interactive', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: ModalToolbarGlassButton(
            icon: CupertinoIcons.checkmark,
            iconColor: CupertinoColors.white,
            surfaceColor: kDisabledActionSurface,
            isCheckmark: true,
            onTap: _noOp,
          ),
        ),
      ),
    );

    final button = tester.widget<StaticLiquidGlassActionButton>(
      find.byType(StaticLiquidGlassActionButton),
    );
    final ignorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(StaticLiquidGlassActionButton),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(button, isNotNull);
    expect(ignorePointer.ignoring, isTrue);
  });
}

void _noOp() {}
