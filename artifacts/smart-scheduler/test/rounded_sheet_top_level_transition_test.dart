import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'top-level sheet leaves the app full-size and clears the header control',
    (tester) async {
      const surfaceSize = Size(400, 700);
      const topInset = 30.0;
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      final rootKey = GlobalKey();
      const sheetKey = ValueKey('top-level-sheet-content');

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return AppWindowContentBoundary(
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  padding: mediaQuery.padding.copyWith(top: topInset),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: ColoredBox(key: rootKey, color: Color(0xFF1F4D72)),
        ),
      );

      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) =>
              const ColoredBox(key: sheetKey, color: Color(0xFFFFFFFF)),
        ),
      );

      await tester.pump(const Duration(milliseconds: 120));
      final movingSheetTop = tester.getRect(find.byKey(sheetKey)).top;
      await tester.pumpAndSettle();

      final rootRect = tester.getRect(find.byKey(rootKey));
      expect(rootRect.topLeft, Offset.zero);
      expect(rootRect.size, surfaceSize);

      final sheetTop = tester.getRect(find.byKey(sheetKey)).top;
      expect(
        movingSheetTop,
        greaterThan(sheetTop),
        reason: 'The sheet must continue moving until it reaches its top gap.',
      );
      final headerControlBottom = topInset + 2.0 + 36.0;
      expect(
        sheetTop,
        greaterThanOrEqualTo(headerControlBottom + 4.0),
        reason:
            'The sheet must leave the app-shell hamburger/X LiquidGlassButton uncovered.',
      );
      expect(sheetTop, greaterThanOrEqualTo(surfaceSize.height * 0.08));
    },
  );
}
