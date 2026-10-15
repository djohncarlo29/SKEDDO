import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/modal_sheet_scroll_under.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

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

  testWidgets(
    'restores the top edge from an existing offset after the sheet state remounts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final scrollableKey = GlobalKey();
      final remountVersion = ValueNotifier<int>(0);
      addTearDown(remountVersion.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox.expand(
              child: ValueListenableBuilder<int>(
                valueListenable: remountVersion,
                builder: (context, version, _) => ModalSheetScrollUnder(
                  key: ValueKey(version),
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
                    key: scrollableKey,
                    controller: controller,
                    primary: false,
                    padding: padding,
                    children: List.generate(
                      20,
                      (index) => SizedBox(height: 40, child: Text('Row $index')),
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

      // Recreate only the edge-effect owner while preserving the actual
      // scrollable and its position, as happens when a covered route settles.
      remountVersion.value++;
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(50, 0.01));
      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

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
    'opt-in short content shows the top edge while rubberbanding',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox.expand(
              child: ModalSheetScrollUnder(
                showTopEdgeOnShortContentRubberband: true,
                headerHeight: 40,
                baseScrollPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                surfaceColor: CupertinoColors.systemBackground,
                header: const SizedBox(
                  height: 40,
                  child: Text('Pinned header'),
                ),
                scrollBuilder:
                    (context, padding) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
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

      await tester.drag(find.text('Short content'), const Offset(0, 80));
      await tester.pump();

      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      final edge = tester.widget<LiquidGlassScrollEdge>(
        find.byType(LiquidGlassScrollEdge),
      );
      expect(edge.edge, LiquidGlassEdge.top);
      expect(edge.color.a, greaterThan(0));
      expect(edge.blur, greaterThan(0));

      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassScrollEdge), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'controller-backed short content shows the top edge while rubberbanding',
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
                showTopEdgeOnShortContentRubberband: true,
                headerHeight: 40,
                baseScrollPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                surfaceColor: CupertinoColors.systemBackground,
                header: const SizedBox(
                  height: 40,
                  child: Text('Pinned header'),
                ),
                scrollBuilder:
                    (context, padding) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: SingleChildScrollView(
                        controller: controller,
                        primary: false,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: padding,
                        child: const SizedBox(
                          height: 24,
                          child: Text('Short content'),
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Short content'), const Offset(0, 80));
      await tester.pump();

      final edge = tester.widget<LiquidGlassScrollEdge>(
        find.byType(LiquidGlassScrollEdge),
      );
      expect(edge.edge, LiquidGlassEdge.top);
      expect(edge.color.a, greaterThan(0));
      expect(edge.blur, greaterThan(0));

      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassScrollEdge), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Group-style upward touch pull blurs short content under the fixed header',
    (tester) async {
      const surfaceSize = Size(400, 700);
      const sheetColor = Color(0xFFF4F4F4);
      const backdropColor = Color(0xFF173A5E);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScrollController();
      final captureKey = GlobalKey();
      final cardKey = GlobalKey();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => RepaintBoundary(
            key: captureKey,
            child: child ?? const SizedBox.shrink(),
          ),
          home: CupertinoPageScaffold(
            backgroundColor: backdropColor,
            child: SizedBox.expand(
              child: ModalSheetScrollUnder(
                // These are the New Group sheet's existing header clearances.
                headerTopInset: 24,
                headerHeight: 40,
                headerGap: 12,
                baseScrollPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                surfaceColor: sheetColor,
                header: const SizedBox(
                  key: ValueKey('group-header'),
                  height: 40,
                  child: Center(child: Text('New Group')),
                ),
                scrollBuilder: (context, scrollPadding) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: SingleChildScrollView(
                    controller: controller,
                    primary: false,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: scrollPadding,
                    child: Container(
                      key: cardKey,
                      height: 120,
                      alignment: Alignment.center,
                      color: const Color(0xFFD84A45),
                      child: const Text('Group content'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.position.maxScrollExtent, 0);
      expect(find.byType(LiquidGlassScrollEdge), findsNothing);
      final headerFinder = find.byKey(const ValueKey('group-header'));
      final headerTop = tester.getTopLeft(headerFinder).dy;
      final headerBottom = headerTop + 40;
      final cardTop = tester.getTopLeft(find.byKey(cardKey)).dy;
      expect(cardTop, closeTo(headerTop + 40 + 12 + 8, 1));

      Future<Uint8List> capturePixels() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            return (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        }))!;
      }

      int differingByteCount(Uint8List first, Uint8List second) {
        var differences = 0;
        for (var index = 0; index < first.length; index++) {
          if (first[index] != second[index]) differences++;
        }
        return differences;
      }

      List<int> pixelAt(Uint8List pixels, int x, int y) {
        final index = (y * surfaceSize.width.toInt() + x) * 4;
        return pixels.sublist(index, index + 4);
      }

      final restingPixels = await capturePixels();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(cardKey)),
        kind: PointerDeviceKind.touch,
      );
      for (var step = 1; step <= 8; step++) {
        await gesture.moveBy(
          const Offset(0, -25),
          timeStamp: Duration(milliseconds: 16 * step),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(controller.position.maxScrollExtent, 0);
      expect(
        controller.position.pixels,
        greaterThan(controller.position.maxScrollExtent),
        reason:
            'The upward pull produces positive pixels beyond the zero range.',
      );
      expect(
        tester.getTopLeft(find.byKey(cardKey)).dy,
        lessThan(headerBottom),
        reason: 'The short card must move beneath the fixed header while held.',
      );
      expect(tester.getTopLeft(headerFinder).dy, headerTop);

      final edgeFinder = find.byType(LiquidGlassScrollEdge);
      expect(edgeFinder, findsOneWidget);
      final edge = tester.widget<LiquidGlassScrollEdge>(edgeFinder);
      expect(edge.edge, LiquidGlassEdge.top);
      expect(edge.blur, greaterThan(0));
      expect(edge.color.a, greaterThan(0));

      final pulledPixels = await capturePixels();
      expect(
        differingByteCount(restingPixels, pulledPixels),
        greaterThan(100),
        reason: 'The held pull must visibly change rendered pixels.',
      );
      expect(
        pixelAt(restingPixels, 200, 8),
        isNot(pixelAt(pulledPixels, 200, 8)),
        reason: 'The top scroll-edge band must visibly change during the pull.',
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.position.pixels, closeTo(0, 0.01));
      expect(find.byType(LiquidGlassScrollEdge), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Group route lets upward touch drags reach short content while title is focused',
    (tester) async {
      const surfaceSize = Size(400, 700);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      final scrollController = ScrollController();
      final titleFocus = FocusNode();
      addTearDown(scrollController.dispose);
      addTearDown(titleFocus.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const CupertinoPageScaffold(
            child: ColoredBox(color: Color(0xFF173A5E)),
          ),
        ),
      );

      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) => CupertinoPageScaffold(
            child: SafeArea(
              bottom: false,
              child: ModalSheetScrollUnder(
                scrollController: scrollController,
                headerTopInset: 24,
                headerHeight: 40,
                headerGap: 12,
                baseScrollPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                surfaceColor: const Color(0xFFF4F4F4),
                header: const SizedBox(
                  height: 40,
                  child: Center(child: Text('New Group')),
                ),
                scrollBuilder: (context, scrollPadding) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    primary: false,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: scrollPadding,
                    child: Container(
                      key: const ValueKey('group-route-card'),
                      color: const Color(0xFFD84A45),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: CupertinoTextField(
                              key: const ValueKey('group-route-title'),
                              focusNode: titleFocus,
                              placeholder: 'Title',
                              scrollPhysics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          const SizedBox(
                            key: ValueKey('group-route-include'),
                            height: 52,
                            child: Center(child: Text('Include')),
                          ),
                        ],
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
      titleFocus.requestFocus();
      await tester.pump();

      expect(scrollController.position.maxScrollExtent, 0);
      final headerFinder = find.text('New Group');
      final headerTopBefore = tester.getTopLeft(headerFinder).dy;
      final cardTopBefore = tester
          .getTopLeft(find.byKey(const ValueKey('group-route-card')))
          .dy;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('group-route-include'))),
        kind: PointerDeviceKind.touch,
      );
      for (var step = 1; step <= 8; step++) {
        await gesture.moveBy(
          const Offset(0, -25),
          timeStamp: Duration(milliseconds: 16 * step),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }

      final headerTopAfter = tester.getTopLeft(headerFinder).dy;
      final cardTopAfter = tester
          .getTopLeft(find.byKey(const ValueKey('group-route-card')))
          .dy;
      expect(
        scrollController.position.physics.shouldAcceptUserOffset(
          scrollController.position,
        ),
        isTrue,
      );
      expect(
        scrollController.position.pixels,
        greaterThan(scrollController.position.maxScrollExtent),
        reason:
            'An Include-row drag must reach the Group scroller '
            '(pixels=${scrollController.position.pixels}, '
            'headerDelta=${headerTopAfter - headerTopBefore}, '
            'cardDelta=${cardTopAfter - cardTopBefore}).',
      );
      expect(headerTopAfter, headerTopBefore);
      expect(cardTopAfter, lessThan(cardTopBefore));
      final topEdge = tester.widget<LiquidGlassScrollEdge>(
        find.byType(LiquidGlassScrollEdge),
      );
      expect(topEdge.edge, LiquidGlassEdge.top);
      expect(topEdge.blur, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scrollController.position.pixels, closeTo(0, 0.01));
      expect(find.byType(LiquidGlassScrollEdge), findsNothing);
      expect(tester.getTopLeft(headerFinder).dy, headerTopBefore);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

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
