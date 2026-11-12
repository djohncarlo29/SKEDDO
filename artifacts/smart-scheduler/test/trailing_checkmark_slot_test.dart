import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/trailing_checkmark_slot.dart';

void main() {
  testWidgets(
    'trailing checkmark matches Settings size and preserves the 16pt card inset',
    (tester) async {
      const color = Color(0xff1685f8);
      final cardKey = GlobalKey();

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: _TestCheckmarkRow(color: color, cardKey: cardKey),
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.checkmark));
      expect(icon.size, 25.5);
      expect(icon.color, color);
      expect(tester.getRect(find.byType(TrailingCheckmarkSlot)).width, 41.5);

      // The parent row's 16pt inset places the glyph 16pt from the card edge.
      final cardRight = tester.getRect(find.byKey(cardKey)).right;
      final iconRight = tester
          .getRect(find.byIcon(CupertinoIcons.checkmark))
          .right;
      expect(cardRight - iconRight, 16);
    },
  );

  testWidgets('unselected rows reserve the same checkmark column', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: TrailingCheckmarkSlot(
              selected: false,
              color: Color(0xff1685f8),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(CupertinoIcons.checkmark), findsNothing);
    expect(tester.getSize(find.byType(TrailingCheckmarkSlot)).width, 41.5);
  });
}

class _TestCheckmarkRow extends StatelessWidget {
  const _TestCheckmarkRow({required this.color, required this.cardKey});

  final Color color;
  final GlobalKey cardKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: cardKey,
      width: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Expanded(child: Text('Selected option')),
            TrailingCheckmarkSlot(selected: true, color: color),
          ],
        ),
      ),
    );
  }
}
