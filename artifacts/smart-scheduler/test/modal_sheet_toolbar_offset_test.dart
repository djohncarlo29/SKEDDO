import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';

void main() {
  testWidgets('modal sheet toolbar controls use the shared offsets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const leadingKey = ValueKey('leading-control');
    const trailingKey = ValueKey('trailing-control');

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 300,
          height: 100,
          child: Stack(
            children: [
              Positioned(
                left: 16,
                top: 12,
                child: shiftModalSheetToolbarControl(
                  isLeading: true,
                  child: const SizedBox(
                    key: leadingKey,
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 12,
                child: shiftModalSheetToolbarControl(
                  isLeading: false,
                  child: const SizedBox(
                    key: trailingKey,
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(leadingKey)),
      const Rect.fromLTWH(20, 14, 40, 40),
    );
    expect(
      tester.getRect(find.byKey(trailingKey)),
      const Rect.fromLTWH(240, 14, 40, 40),
    );
    expect(tester.getSize(find.byKey(leadingKey)), const Size(40, 40));
    expect(tester.getSize(find.byKey(trailingKey)), const Size(40, 40));
  });
}
