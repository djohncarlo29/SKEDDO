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
    await tester.pumpAndSettle();

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
