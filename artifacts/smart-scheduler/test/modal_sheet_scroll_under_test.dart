import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/modal_sheet_scroll_under.dart';

void main() {
  testWidgets(
    'Android top fallback masks the blur so sharp content returns at the edge',
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

      expect(find.byType(BackdropFilter), findsNothing);
      final headerTop = tester.getTopLeft(find.byKey(headerKey)).dy;
      final firstRowTop = tester.getTopLeft(find.text('Row 0')).dy;
      expect(firstRowTop, closeTo(headerTop + 40 + 6 + 4, 1));

      controller.jumpTo(50);
      await tester.pump();

      expect(find.byType(BackdropFilter), findsOneWidget);
      if (!ImageFilter.isShaderFilterSupported) {
        expect(
          tester.widget<BackdropFilter>(find.byType(BackdropFilter)).blendMode,
          BlendMode.src,
        );
        expect(find.byType(ShaderMask), findsOneWidget);
        final topGradient =
            tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: find.byType(ModalSheetScrollUnder),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .map((box) => box.decoration)
                .whereType<BoxDecoration>()
                .map((decoration) => decoration.gradient)
                .whereType<LinearGradient>()
                .single;
        expect(topGradient.colors.first.a, lessThan(1));
        expect(topGradient.colors.last.a, 0);
      }
      expect(tester.getTopLeft(find.byKey(headerKey)).dy, headerTop);
      expect(
        tester.getTopLeft(find.text('Row 0')).dy,
        closeTo(firstRowTop - 50, 1),
      );

      controller.jumpTo(0);
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
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

    expect(find.byType(BackdropFilter), findsNothing);

    controller.jumpTo(20);
    await tester.pump();

    expect(find.byType(BackdropFilter), findsWidgets);
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

    expect(find.byType(BackdropFilter), findsNothing);
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
      expect(find.byType(BackdropFilter), findsNothing);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNWidgets(2));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
