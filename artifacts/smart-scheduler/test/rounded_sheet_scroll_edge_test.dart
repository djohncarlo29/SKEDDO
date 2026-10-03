import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassScrollEdge;
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/modal_sheet_scroll_under.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'keeps the scroll-edge blur outside the covering-sheet dim layer',
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
              scrollBuilder: (context, padding) => ListView(
                controller: scrollController,
                padding: padding,
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
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}