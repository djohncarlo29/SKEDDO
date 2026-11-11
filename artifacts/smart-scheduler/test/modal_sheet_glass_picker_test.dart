import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassPicker;
import 'package:smart_scheduler/app_theme.dart';

void main() {
  testWidgets('modal picker trailing delegates taps through GlassPicker', (
    tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 240,
              child: ModalSheetPickerTrailing(
                value: 'Weekly',
                style: const TextStyle(fontSize: 15),
                chevronColor: CupertinoColors.systemGrey,
                semanticLabel: 'Repeat',
                onTap: () => tapCount++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final picker = tester.widget<GlassPicker>(find.byType(GlassPicker));
    expect(picker.value!.replaceAll('\u2060', ''), 'Weekly');
    expect(picker.semanticLabel, 'Repeat');
    expect(picker.maxLines, isNull);

    await tester.tap(find.byType(GlassPicker));
    expect(tapCount, 1);
  });

  testWidgets('modal picker trailing can omit its chevron', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 160,
              child: ModalSheetPickerTrailing(
                value: 'Day',
                style: const TextStyle(fontSize: 15),
                chevronColor: CupertinoColors.systemGrey,
                showChevron: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final picker = tester.widget<GlassPicker>(find.byType(GlassPicker));
    expect(picker.iconGap, 0);
    expect(picker.icon, isA<SizedBox>());
  });
}
