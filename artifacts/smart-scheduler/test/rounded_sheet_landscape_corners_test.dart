import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart' show kRoundedSheetSafeAreaGap;
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/modal_sheet_scroll_under.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'landscape parent and nested sheet surfaces keep rounded top corners',
    (tester) async {
      const surfaceSize = Size(1024, 600);
      const sideInset = 48.0;
      const topInset = 24.0;
      const backgroundColor = Color(0xFF00AA44);
      const parentColor = Color(0xFFFFFFFF);
      const nestedColor = Color(0xFF3366CC);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      final captureKey = GlobalKey();
      const parentKey = ValueKey('landscape-rounded-parent');
      const nestedKey = ValueKey('landscape-rounded-nested');

      Widget buildSheet(Color color, Key key) => CupertinoPageScaffold(
        backgroundColor: color,
        child: SafeArea(
          bottom: false,
          child: ModalSheetScrollUnder(
            key: key,
            headerTopInset: 8,
            headerHeight: 40,
            headerGap: 12,
            baseScrollPadding: EdgeInsets.zero,
            surfaceColor: color,
            header: const SizedBox(height: 40),
            scrollBuilder: (context, padding) => ListView(
              padding: padding,
              children: [
                SizedBox(height: 800, child: ColoredBox(color: color)),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return AppWindowContentScope(
              horizontalInset: sideInset,
              physicalWidth: surfaceSize.width,
              child: RepaintBoundary(
                key: captureKey,
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
              ),
            );
          },
          home: const ColoredBox(color: backgroundColor),
        ),
      );

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

      List<int> pixelAt(Uint8List pixels, int x, int y) {
        final index = (y * surfaceSize.width.toInt() + x) * 4;
        return pixels.sublist(index, index + 4);
      }

      void expectScrollEdgeClipWithinSheet(Key sheetKey) {
        final clip = find.descendant(
          of: find.byKey(sheetKey),
          matching: find.byKey(
            const ValueKey('modal-sheet-scroll-edge-clip'),
          ),
        );
        final clipRect = tester.getRect(clip);
        expect(clipRect.left, sideInset);
        expect(clipRect.right, surfaceSize.width - sideInset);
      }

      final top = (topInset + kRoundedSheetSafeAreaGap).round();
      final cornerX = sideInset.round() + 2;
      final cornerY = top + 2;
      final centerX = surfaceSize.width ~/ 2;

      final parentFuture = navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) => buildSheet(parentColor, parentKey),
        ),
      );
      await tester.pumpAndSettle();
      expectScrollEdgeClipWithinSheet(parentKey);

      final parentPixels = await capturePixels();
      expect(
        pixelAt(parentPixels, cornerX, cornerY),
        const [0, 170, 68, 255],
        reason: 'The inset top-left corner must reveal the AppShell.',
      );
      expect(
        pixelAt(parentPixels, centerX, cornerY),
        const [255, 255, 255, 255],
        reason: 'The center of the sheet top edge must remain covered.',
      );
      final nestedFuture = showRoundedCupertinoSheet<void>(
        context: tester.element(find.byKey(parentKey)),
        pageBuilder: (_) => buildSheet(nestedColor, nestedKey),
      );
      await tester.pumpAndSettle();
      expectScrollEdgeClipWithinSheet(nestedKey);

      final nestedPixels = await capturePixels();
      expect(
        pixelAt(nestedPixels, cornerX, cornerY),
        const [0, 170, 68, 255],
        reason: 'Nested-sheet dimming must not square off the parent corner.',
      );
      expect(
        pixelAt(nestedPixels, centerX, cornerY),
        const [51, 102, 204, 255],
        reason: 'The nested sheet must cover the center of its top edge.',
      );

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await nestedFuture;
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await parentFuture;
    },
  );
}
