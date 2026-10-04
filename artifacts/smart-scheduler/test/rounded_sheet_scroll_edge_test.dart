import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassScrollEdge;
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/modal_sheet_scroll_under.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'aligns the dim overlay with the parent sheet under a subsheet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      Widget buildMainSheet(BuildContext context) {
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          child: SizedBox.expand(
            child: ModalSheetScrollUnder(
              scrollController: scrollController,
              headerHeight: 40,
              headerGap: 6,
              baseScrollPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              surfaceColor: const Color(0xFFFFFFFF),
              header: const SizedBox(
                height: 40,
                child: Text('Main sheet'),
              ),
              scrollBuilder: (context, padding) => SingleChildScrollView(
                controller: scrollController,
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: padding,
                child: Column(
                  children: List.generate(
                    20,
                    (index) => SizedBox(
                      height: 40,
                      child: Text('Main row $index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SizedBox.shrink(),
        ),
      );

      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(builder: buildMainSheet),
      );
      await tester.pumpAndSettle();

      scrollController.jumpTo(50);
      await tester.pump();
      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      final parentSheetState = tester.state(
        find.byType(ModalSheetScrollUnder),
      );

      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text('Subsheet')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final edgeFinder = find.byType(LiquidGlassScrollEdge);
      expect(edgeFinder, findsOneWidget);
      final scrimFinder = find.byKey(
        const ValueKey('rounded-sheet-dim-overlay'),
      );
      expect(scrimFinder, findsOneWidget);
      expect(
        tester.getTopLeft(scrimFinder).dy,
        closeTo(
          tester.getTopLeft(find.byType(ModalSheetScrollUnder)).dy,
          1,
        ),
      );
      final filterFinder = find.descendant(
        of: edgeFinder,
        matching: find.byType(BackdropFilter),
      );
      expect(filterFinder, findsOneWidget);
      expect(
        tester.widget<BackdropFilter>(filterFinder).blendMode,
        BlendMode.srcOver,
      );
      expect(
        find.ancestor(
          of: filterFinder,
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
      // The app behind the top-level sheet keeps its alpha-aware dim path;
      // only the covered modal uses the sibling overlay for its scroll edge.
      expect(find.byType(ColorFiltered), findsOneWidget);

      final visibleBlur = tester.widget<LiquidGlassScrollEdge>(edgeFinder).blur;
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        tester.state(find.byType(ModalSheetScrollUnder)),
        same(parentSheetState),
      );
      expect(scrollController.offset, closeTo(50, 0.01));
      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      expect(
        tester.widget<LiquidGlassScrollEdge>(
          find.byType(LiquidGlassScrollEdge),
        ).blur,
        closeTo(visibleBlur, 0.001),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
