import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassScrollEdge;
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/modal_sheet_scroll_under.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'keeps the rendered scroll edge after a subsheet dismissal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      final scrollController = ScrollController();
      final captureKey = GlobalKey();
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
              surfaceColor: const Color(0xFFF8F8F8),
              header: const SizedBox(
                height: 40,
                child: Text('Main sheet'),
              ),
              scrollBuilder: (context, padding) => ColoredBox(
                color: const Color(0xFF173A5E),
                child: SingleChildScrollView(
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
          ),
        );
      }

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => RepaintBoundary(
            key: captureKey,
            child: AppWindowContentBoundary(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const SizedBox.shrink(),
        ),
      );

      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(builder: buildMainSheet),
      );
      await tester.pumpAndSettle();

      Future<Uint8List> capturePixels() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            return bytes!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        }))!;
      }

      int differingByteCount(Uint8List a, Uint8List b) {
        expect(a.length, b.length);
        var differences = 0;
        for (var i = 0; i < a.length; i++) {
          if (a[i] != b[i]) differences++;
        }
        return differences;
      }

      final noEdgePixels = await capturePixels();
      scrollController.jumpTo(25);
      await tester.pump();
      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      final edgePixelsBeforeDismissal = await capturePixels();
      expect(
        differingByteCount(noEdgePixels, edgePixelsBeforeDismissal),
        greaterThan(100),
        reason: 'The scroll edge must make a visible rendered change.',
      );
      final parentSheetState = tester.state(
        find.byType(ModalSheetScrollUnder),
      );

      final nestedSheetFuture = showRoundedCupertinoSheet<void>(
        context: tester.element(find.byType(ModalSheetScrollUnder)),
        pageBuilder: (_) => const CupertinoPageScaffold(
          child: Center(child: Text('Subsheet')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final edgeFinder = find.byType(LiquidGlassScrollEdge);
      expect(edgeFinder, findsOneWidget);
      final edgeScaleTransitions = <ScaleTransition>[];
      tester.element(edgeFinder).visitAncestorElements((element) {
        if (element.widget is ScaleTransition) {
          edgeScaleTransitions.add(element.widget as ScaleTransition);
        }
        return true;
      });
      expect(edgeScaleTransitions, isNotEmpty);
      expect(
        edgeScaleTransitions.every(
          (transition) => transition.filterQuality == null,
        ),
        isTrue,
        reason:
            'A covered sheet must keep its BackdropFilter outside filtered raster transforms.',
      );
      final scrimFinder = find.byKey(
        const ValueKey('rounded-sheet-dim-overlay'),
      );
      final activeScrimCount = tester
          .widgetList<ColoredBox>(scrimFinder)
          .where((scrim) => scrim.color.a > 0)
          .length;
      expect(activeScrimCount, 1);
      final parentRoute = ModalRoute.of(
        tester.element(find.byType(ModalSheetScrollUnder)),
      )!;
      expect(
        parentRoute.receivedTransition,
        isNull,
        reason:
            'A nested sheet must animate the parent through its own secondary transition.',
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
      final edgeElementBeforeDismiss = tester.element(edgeFinder);
      final filterRenderObjectBeforeDismiss = tester.renderObject<RenderBackdropFilter>(
        filterFinder,
      );

      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        parentRoute.secondaryAnimation?.status,
        AnimationStatus.reverse,
      );
      expect(parentRoute.receivedTransition, isNull);
      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      expect(
        tester.widget<LiquidGlassScrollEdge>(edgeFinder).blur,
        closeTo(visibleBlur, 0.001),
      );
      expect(
        tester.renderObject<RenderBackdropFilter>(filterFinder),
        same(filterRenderObjectBeforeDismiss),
        reason:
            'The existing backdrop filter must remain attached during dismissal.',
      );
      final edgePixelsDuringDismissal = await capturePixels();

      await tester.pumpAndSettle();
      await nestedSheetFuture;
      final edgePixelsAfterSettling = await capturePixels();
      expect(
        differingByteCount(edgePixelsDuringDismissal, edgePixelsAfterSettling),
        greaterThan(100),
        reason:
            'The parent should finish its own secondary transition after the mid-dismissal frame.',
      );

      expect(
        tester.state(find.byType(ModalSheetScrollUnder)),
        same(parentSheetState),
      );
      expect(
        parentRoute.secondaryAnimation?.status,
        AnimationStatus.dismissed,
      );
      expect(parentRoute.receivedTransition, isNull);
      expect(scrollController.offset, closeTo(25, 0.01));
      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      expect(
        tester.widget<LiquidGlassScrollEdge>(
          find.byType(LiquidGlassScrollEdge),
        ).blur,
        closeTo(visibleBlur, 0.001),
      );
      expect(
        tester.element(edgeFinder),
        same(edgeElementBeforeDismiss),
        reason:
            'Dismissal must not replace the parent scroll-edge widget element.',
      );
      expect(
        tester.renderObject<RenderBackdropFilter>(filterFinder),
        same(filterRenderObjectBeforeDismiss),
        reason:
            'Dismissal must repaint the existing BackdropFilter render object, not replace it.',
      );
      expect(
        differingByteCount(edgePixelsBeforeDismissal, edgePixelsAfterSettling),
        0,
        reason:
            'The edge pixels after dismissal must match the pre-dismissal render.',
      );

      scrollController.jumpTo(26);
      await tester.pump();
      expect(scrollController.offset, closeTo(26, 0.01));
      expect(
        tester.widget<LiquidGlassScrollEdge>(edgeFinder).blur,
        greaterThan(visibleBlur),
      );
      expect(
        tester.renderObject<RenderBackdropFilter>(filterFinder),
        same(filterRenderObjectBeforeDismiss),
        reason: 'A parent scroll should update the existing filter render object.',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'keeps the top edge absent after returning from a subsheet at scroll offset zero',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();

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
        RoundedCupertinoSheetRoute<void>(
          builder: (context) => CupertinoPageScaffold(
            backgroundColor: const Color(0xFFFFFFFF),
            child: SizedBox.expand(
              child: ModalSheetScrollUnder(
                headerHeight: 40,
                headerGap: 6,
                baseScrollPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                surfaceColor: const Color(0xFFFFFFFF),
                header: const SizedBox(
                  height: 40,
                  child: Text('Main sheet'),
                ),
                scrollBuilder: (context, padding) => SingleChildScrollView(
                  primary: false,
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassScrollEdge), findsNothing);

      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text('Subsheet')),
          ),
          isNestedSheet: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassScrollEdge), findsNothing);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassScrollEdge), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
