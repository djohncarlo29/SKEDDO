import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart'
    show
        kLightModeSheetAppShellDimColor,
        kRoundedSheetLandscapeSafeAreaGap,
        kRoundedSheetSafeAreaGap;
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'portrait sheets move together and preserve their previous stack spacing',
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
          theme: const CupertinoThemeData(brightness: Brightness.light),
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
          home: RoundedSheetAppShellDimmer(
            child: ColoredBox(key: rootKey, color: Color(0xFF1F4D72)),
          ),
        ),
      );

      final parentSheetFuture = navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) =>
              const ColoredBox(key: sheetKey, color: Color(0xFFFFFFFF)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final movingSheetTop = tester.getRect(find.byKey(sheetKey)).top;
      await tester.pumpAndSettle();
      final preservedStackGap =
          (topInset + kRoundedSheetSafeAreaGap) * 0.0835 +
          surfaceSize.height * 0.005;

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
        topInset + preservedStackGap,
        reason: 'A single portrait sheet must use the adjusted resting position.',
      );
      final appShellFilter = tester
          .widget<ColorFiltered>(
            find.byKey(
              const ValueKey('rounded-sheet-app-shell-dim-overlay'),
            ),
          )
          .colorFilter;
      expect(
        appShellFilter,
        ColorFilter.mode(
          kLightModeSheetAppShellDimColor,
          BlendMode.multiply,
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(sheetKey),
          matching: find.byKey(
            const ValueKey('rounded-sheet-app-shell-dim-overlay'),
          ),
        ),
        findsNothing,
        reason: 'Only the AppShell receives the top-level sheet tint.',
      );

      const nestedSheetKey = ValueKey('nested-sheet-content');
      final nestedSheetFuture = showRoundedCupertinoSheet<void>(
        context: tester.element(find.byKey(sheetKey)),
        pageBuilder: (_) =>
            const ColoredBox(key: nestedSheetKey, color: Color(0xFFEFEFEF)),
      );
      await tester.pumpAndSettle();
      final rearSheetTop = tester.getRect(find.byKey(sheetKey)).top;
      final frontSheetTop = tester.getRect(find.byKey(nestedSheetKey)).top;
      expect(
        rearSheetTop,
        topInset,
        reason: 'The sheet peeking behind must not enter the status safe area.',
      );
      expect(frontSheetTop, topInset + preservedStackGap);
      expect(
        frontSheetTop - rearSheetTop,
        closeTo(preservedStackGap, 1e-9),
        reason: 'The active sheet must move with the rear-sheet adjustment.',
      );

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await nestedSheetFuture;
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await parentSheetFuture;

      expect(
        find.byKey(const ValueKey('rounded-sheet-app-shell-dim-overlay')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ColorFiltered>(
              find.byKey(
                const ValueKey('rounded-sheet-app-shell-dim-overlay'),
              ),
            )
            .colorFilter,
        ColorFilter.mode(const Color(0x00A8A8A3), BlendMode.multiply),
        reason: 'The app-shell filter remains mounted and neutral after pop.',
      );
    },
  );

  testWidgets(
    'top-level sheet dismissal preserves the AppShell scroll state',
    (tester) async {
      const surfaceSize = Size(400, 700);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      final shellKey = GlobalKey<_ScrollableShellState>();

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
          home: RoundedSheetAppShellDimmer(
            child: _ScrollableShell(key: shellKey),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shellState = shellKey.currentState!;
      shellState.controller.jumpTo(180);
      await tester.pump();

      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) => const ColoredBox(color: Color(0xFFFFFFFF)),
        ),
      );
      await tester.pumpAndSettle();
      expect(shellKey.currentState, same(shellState));
      expect(shellState.controller.offset, 180);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(shellKey.currentState, same(shellState));
      expect(
        shellState.controller.offset,
        180,
        reason: 'Dismissing a top-level sheet must not reset the parent scroll.',
      );
    },
  );

  testWidgets(
    'landscape parent and nested sheets use the inset and lower top offset',
    (tester) async {
      const surfaceSize = Size(1024, 600);
      const sideInset = 48.0;
      const topInset = 24.0;
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      final rootKey = GlobalKey();
      const sheetKey = ValueKey('landscape-sheet-content');

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return AppWindowContentScope(
              horizontalInset: sideInset,
              physicalWidth: surfaceSize.width,
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  size: Size(
                    surfaceSize.width - sideInset * 2,
                    surfaceSize.height,
                  ),
                  padding: mediaQuery.padding.copyWith(
                    left: 0,
                    top: topInset,
                    right: 0,
                    bottom: 0,
                  ),
                  viewPadding: mediaQuery.viewPadding.copyWith(
                    left: 0,
                    top: topInset,
                    right: 0,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: ColoredBox(
            key: rootKey,
            color: const Color(0xFF1F4D72),
          ),
        ),
      );

      final parentFuture = navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) =>
              const ColoredBox(key: sheetKey, color: Color(0xFFFFFFFF)),
        ),
      );
      await tester.pumpAndSettle();

      final rootRect = tester.getRect(find.byKey(rootKey));
      expect(rootRect.left, 0);
      expect(rootRect.width, surfaceSize.width);

      final parentRect = tester.getRect(find.byKey(sheetKey));
      expect(parentRect.left, sideInset);
      expect(parentRect.right, surfaceSize.width - sideInset);
      expect(parentRect.top, topInset + kRoundedSheetLandscapeSafeAreaGap);

      const nestedSheetKey = ValueKey('landscape-nested-sheet-content');
      final nestedFuture = showRoundedCupertinoSheet<void>(
        context: tester.element(find.byKey(sheetKey)),
        pageBuilder: (_) => const ColoredBox(
          key: nestedSheetKey,
          color: Color(0xFFEFEFEF),
        ),
      );
      await tester.pumpAndSettle();

      final nestedRect = tester.getRect(find.byKey(nestedSheetKey));
      expect(nestedRect.left, sideInset);
      expect(nestedRect.right, surfaceSize.width - sideInset);
      expect(nestedRect.top, topInset + kRoundedSheetLandscapeSafeAreaGap);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await nestedFuture;
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await parentFuture;
    },
  );
}

class _ScrollableShell extends StatefulWidget {
  const _ScrollableShell({super.key});

  @override
  State<_ScrollableShell> createState() => _ScrollableShellState();
}

class _ScrollableShellState extends State<_ScrollableShell> {
  final ScrollController controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SingleChildScrollView(
      controller: controller,
      child: const SizedBox(
        height: 1500,
        child: ColoredBox(color: Color(0xFF1F4D72)),
      ),
    ),
  );
}
