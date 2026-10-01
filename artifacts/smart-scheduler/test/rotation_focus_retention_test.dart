import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/live_rotation_geometry.dart';

void main() {
  testWidgets('restores text-field focus lost during a rotation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => LiveRotationGeometry(
          child: AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 320,
              child: CupertinoTextField(focusNode: focusNode),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    tester.view.physicalSize = const Size(874, 402);
    await tester.pump();
    // Simulate a platform text-input blur delivered during the rotation.
    focusNode.unfocus();
    await tester.pump();
    // Rotate back before the IME's late blur/recovery window has elapsed.
    tester.view.physicalSize = const Size(402, 874);
    await tester.pump();
    await tester.pumpAndSettle();
    // The platform may deliver its final IME blur after the last orientation
    // metric. Exercise the delayed retry that keeps the original focus target.
    await tester.pump(const Duration(milliseconds: 300));

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('does not restore focus that was already dismissed', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => LiveRotationGeometry(
          child: AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 320,
              child: CupertinoTextField(focusNode: focusNode),
            ),
          ),
        ),
      ),
    );

    tester.view.physicalSize = const Size(874, 402);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);
  });
}
