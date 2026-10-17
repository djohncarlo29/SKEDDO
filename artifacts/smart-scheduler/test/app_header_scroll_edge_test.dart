import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassScrollEdge;
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';

void main() {
  testWidgets(
    'scroll content remains visible through the app edge above its viewport',
    (tester) async {
      const surfaceSize = Size(320, 300);
      const captureKey = ValueKey('app-scroll-edge-capture');
      const contentKey = ValueKey('content-under-app-scroll-edge');
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController(initialScrollOffset: 130);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: RepaintBoundary(
              key: captureKey,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 40,
                    child: RepaintBoundary(
                      child: AppHeaderScrollStack(
                        children: [
                          AppHeaderScrollView(
                            controller: controller,
                            physics: const NeverScrollableScrollPhysics(),
                            slivers: const [
                              SliverToBoxAdapter(child: SizedBox(height: 120)),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  key: contentKey,
                                  height: 40,
                                  child: ColoredBox(color: Color(0xFFD84A45)),
                                ),
                              ),
                              SliverToBoxAdapter(child: SizedBox(height: 600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const AppHeaderScrollEdge(
                    progress: 1,
                    surfaceColor: Color(0xFFFFFFFF),
                    height: 100,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollViewFinder = find.byType(AppHeaderScrollView);
      final stack = tester.widget<AppHeaderScrollStack>(
        find.byType(AppHeaderScrollStack),
      );
      final scrollViewWidget = tester.widget<AppHeaderScrollView>(
        scrollViewFinder,
      );
      final edge = tester.widget<LiquidGlassScrollEdge>(
        find.byType(LiquidGlassScrollEdge),
      );
      final contentRect = tester.getRect(find.byKey(contentKey));

      expect(controller.offset, closeTo(130, 1));
      expect(
        contentRect.top,
        lessThan(40),
        reason: 'The row should physically pass above the scroll viewport.',
      );
      expect(scrollViewWidget.clipBehavior, Clip.none);
      expect(stack.clipBehavior, Clip.none);
      expect(
        find.ancestor(
          of: scrollViewFinder,
          matching: find.byType(AppHeaderScrollEdge),
        ),
        findsNothing,
        reason: 'The edge must overlay the viewport, not wrap or clip it.',
      );
      expect(
        edge.color.a,
        lessThanOrEqualTo(0.25),
        reason: 'The glass tint must not make passing content look removed.',
      );
      expect(
        edge.blur,
        lessThanOrEqualTo(8),
        reason: 'The glass blur must retain perceptible content detail.',
      );

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final pixels = (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      }))!;
      final pixelOffset = (35 * surfaceSize.width.toInt() + 160) * 4;
      final pixel = pixels.sublist(pixelOffset, pixelOffset + 4);
      expect(
        pixel[0] - pixel[1],
        greaterThan(50),
        reason:
            'A red row crossing the edge must still be rendered there, not clipped away.',
      );
    },
  );
}
