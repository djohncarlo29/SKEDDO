import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart'
    show kRoundedSheetSafeAreaGap;
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'parent and nested sheets rest exactly 10pt below the top safe area',
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
                  size: surfaceSize,
                  padding: mediaQuery.padding.copyWith(top: topInset),
                  viewPadding: mediaQuery.viewPadding.copyWith(top: topInset),
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

      await tester.pump();
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
      expect(
        sheetTop,
        topInset + kRoundedSheetSafeAreaGap,
      );

      const nestedSheetKey = ValueKey('nested-sheet-content');
      final nestedSheetFuture = showRoundedCupertinoSheet<void>(
        context: tester.element(find.byKey(sheetKey)),
        pageBuilder: (_) =>
            const ColoredBox(key: nestedSheetKey, color: Color(0xFFEFEFEF)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(nestedSheetKey)).top,
        topInset + kRoundedSheetSafeAreaGap,
      );

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await nestedSheetFuture;
    },
  );
}
