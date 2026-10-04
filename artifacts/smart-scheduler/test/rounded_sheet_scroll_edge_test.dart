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
    'keeps the scroll-edge blur outside the covering-sheet dim layer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      final captureKey = GlobalKey();
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      const backgroundColor = Color(0xFF22CC88);

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
          builder: (context, child) => RepaintBoundary(
            key: captureKey,
            child: ColoredBox(
              color: backgroundColor,
              child: AppWindowContentBoundary(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
          home: const ColoredBox(color: Color(0x00000000)),
        ),
      );

      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(builder: buildMainSheet),
      );
      await tester.pumpAndSettle();

      scrollController.jumpTo(50);
      await tester.pump();
      expect(find.byType(LiquidGlassScrollEdge), findsOneWidget);
      expect(
        await _readPixel(tester, captureKey, 200, 10),
        backgroundColor,
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

      // The area above the first sheet is transparent and must remain
      // unchanged while the subsheet dims that sheet.
      expect(
        await _readPixel(tester, captureKey, 200, 10),
        backgroundColor,
      );

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
      // The app behind the top-level sheet keeps its alpha-aware dim path;
      // only the covered modal uses the sibling overlay for its scroll edge.
      expect(find.byType(ColorFiltered), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

Future<Color> _readPixel(
  WidgetTester tester,
  GlobalKey boundaryKey,
  int x,
  int y,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (bytes == null) throw StateError('Could not read rendered test pixels');
  final index = (y * image.width + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(index + 3),
    bytes.getUint8(index),
    bytes.getUint8(index + 1),
    bytes.getUint8(index + 2),
  );
}