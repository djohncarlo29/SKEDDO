import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/release_reset_interactive_viewer.dart';

void main() {
  testWidgets('pinch zoom resets smoothly after the gesture ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: ReleaseResetInteractiveViewer(
              child: ColoredBox(color: CupertinoColors.activeBlue),
            ),
          ),
        ),
      ),
    );

    final viewerFinder = find.byType(InteractiveViewer);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final transform = viewer.transformationController!;
    final rect = tester.getRect(viewerFinder);
    final firstTouch = await tester.startGesture(
      Offset(rect.center.dx - 50, rect.center.dy),
      pointer: 1,
      kind: PointerDeviceKind.touch,
    );
    final secondTouch = await tester.startGesture(
      Offset(rect.center.dx + 50, rect.center.dy),
      pointer: 2,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();

    await firstTouch.moveTo(Offset(rect.center.dx - 100, rect.center.dy));
    await secondTouch.moveTo(Offset(rect.center.dx + 100, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 80));
    expect(transform.value.getMaxScaleOnAxis(), greaterThan(1.4));

    await firstTouch.up();
    await secondTouch.up();
    await tester.pump();
    final scaleImmediatelyAfterRelease = transform.value.getMaxScaleOnAxis();
    expect(scaleImmediatelyAfterRelease, greaterThan(1));

    await tester.pump(const Duration(milliseconds: 120));
    final halfwayScale = transform.value.getMaxScaleOnAxis();
    expect(halfwayScale, greaterThan(1));
    expect(halfwayScale, lessThan(scaleImmediatelyAfterRelease));

    await tester.pump(const Duration(milliseconds: 250));
    expect(transform.value.isIdentity(), isTrue);
  });
}
