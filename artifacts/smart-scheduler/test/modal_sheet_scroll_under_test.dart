import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;
import 'package:smart_scheduler/widgets/modal_sheet_scroll_under.dart';

void main() {
  testWidgets(
    'top edge uses the package scroll treatment over the fixed header',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final headerKey = GlobalKey();

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox.expand(
              child: ModalSheetScrollUnder(
                headerTopInset: 8,
                headerHeight: 40,
                headerGap: 6,
                baseScrollPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                surfaceColor: CupertinoColors.systemBackground,
                header: SizedBox(
                  key: headerKey,
                  height: 40,
                  child: const Text('Pinned header'),
                ),
                scrollBuilder:
                    (context, padding) => ListView(
                      controller: controller,
                      padding: padding,
                      children: List.generate(
                        20,
                        (index) => SizedBox(
                          height: 40,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text('Row $index'),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassScrollEdge), findsNothing);
      final headerTop = tester.getTopLeft(find.byKey(headerKey)).dy;
      final firstRowTop = tester.getTopLeft(find.text('Row 0')).dy;
      expect(firstRowTop, closeTo(headerTop + 40 + 6 + 4, 1));

      controller.jumpTo(50);
      await tester.pump();

      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      final edge = tester.widget<LiquidGlassScrollEdge>(
        find.byType(LiquidGlassScrollEdge),
      );
      expect(edge.edge, LiquidGlassEdge.top);
      expect(edge.color.a, closeTo(0.78, 0.001));
      expect(edge.blur, closeTo(12 * 0.85, 0.001));
      expect(tester.getTopLeft(find.byKey(headerKey)).dy, headerTop);
      expect(
        tester.getTopLeft(find.text('Row 0')).dy,
        closeTo(firstRowTop - 50, 1),
      );

      controller.jumpTo(0);
      await tester.pump();
      expect(find.byType(LiquidGlassScrollEdge), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'top edge uses source compositing under a covering-sheet color layer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x1A000000),
                BlendMode.srcATop,
              ),
              child: SizedBox.expand(
                child: ModalSheetScrollUnder(
                  scrollController: controller,
                  headerHeight: 40,
                  headerGap: 6,
                  baseScrollPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  surfaceColor: CupertinoColors.systemBackground,
                  header: const SizedBox(
                    height: 40,
                    child: Text('Pinned header'),
                  ),
                  scrollBuilder: (context, padding) => ListView(
                    controller: controller,
                    padding: padding,
                    children: List.generate(
                      20,
                      (index) => SizedBox(
                        height: 40,
                        child: Text('Covered row $index'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.jumpTo(50);
      await tester.pump();

      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      final filter = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(LiquidGlassScrollEdge),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(filter.blendMode, BlendMode.src);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('tracks the sheet scroll controller through nested viewports', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SizedBox.expand(
            child: ModalSheetScrollUnder(
              scrollController: controller,
              headerTopInset: 8,
              headerHeight: 40,
              headerGap: 6,
              baseScrollPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              surfaceColor: CupertinoColors.systemBackground,
              header: const SizedBox(height: 40, child: Text('Pinned header')),
              scrollBuilder:
                  (context, padding) => SingleChildScrollView(
                    padding: padding,
                    child: SizedBox(
                      height: 500,
                      child: ListView(
                        controller: controller,
                        primary: false,
                        children: List.generate(
                          20,
                          (index) => SizedBox(
                            height: 40,
                            child: Text('Nested row $index'),
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiquidGlassScrollEdge), findsNothing);

    controller.jumpTo(20);
    await tester.pump();

    expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
  });

  testWidgets('short content does not add an edge blur', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SizedBox.expand(
            child: ModalSheetScrollUnder(
              headerHeight: 40,
              baseScrollPadding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              surfaceColor: CupertinoColors.systemBackground,
              header: SizedBox(height: 40, child: Text('Pinned header')),
              scrollBuilder:
                  (context, padding) => ListView(
                    padding: padding,
                    children: const [
                      SizedBox(height: 24, child: Text('Short content')),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiquidGlassScrollEdge), findsNothing);
  });

  testWidgets(
    'short scroll range keeps the footer effect off until scrolling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox.expand(
              child: ModalSheetScrollUnder(
                scrollController: controller,
                headerHeight: 40,
                baseScrollPadding: EdgeInsets.zero,
                surfaceColor: CupertinoColors.systemBackground,
                header: const SizedBox(
                  height: 40,
                  child: Text('Pinned header'),
                ),
                footerHeight: 32,
                footer: const SizedBox(height: 32),
                scrollBuilder:
                    (context, padding) => ListView(
                      controller: controller,
                      padding: padding,
                      children: const [SizedBox(height: 660)],
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.position.maxScrollExtent, greaterThan(1));
      expect(controller.position.maxScrollExtent, lessThan(48));
      expect(find.byType(LiquidGlassScrollEdge), findsNothing);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      expect(find.byType(LiquidGlassScrollEdge), findsNWidgets(2));
      final edges = tester
          .widgetList<LiquidGlassScrollEdge>(
            find.byType(LiquidGlassScrollEdge),
          )
          .toList();
      final footerEdge = edges.singleWhere(
        (edge) => edge.edge == LiquidGlassEdge.bottom,
      );
      expect(footerEdge.color.a, greaterThan(0));
      expect(footerEdge.color.a, lessThan(0.78));
      expect(footerEdge.blur, lessThan(12));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
