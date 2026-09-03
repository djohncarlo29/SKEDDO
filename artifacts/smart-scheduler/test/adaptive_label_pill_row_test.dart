import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';

void main() {
  testWidgets(
    'keeps reminder label and both pills on one line at smallest text scale',
    (tester) async {
      final labelStyle = TextStyle(
        fontSize: 17,
        fontFamily: kSFProText,
        letterSpacing: kTracking17,
        height: kLineHeight,
      );
      final pillStyle = TextStyle(
        fontSize: 15,
        fontFamily: kSFProText,
        fontWeight: FontWeight.w500,
        letterSpacing: kTracking17,
      );
      final scaler = TextScaler.linear(0.5);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: SizedBox(
                width: 311,
                child: AdaptiveLabelPillRow(
                  label: 'Reminder Date',
                  labelStyle: labelStyle,
                  wrapLabelLast: true,
                  labelValueGap: 8.0,
                  pills: [
                    AdaptivePillSpec(
                      text: 'Aug 17, 2026',
                      style: pillStyle,
                      backgroundColor: CupertinoColors.systemGrey5,
                    ),
                    AdaptivePillSpec(
                      text: '9:00 AM',
                      style: pillStyle,
                      backgroundColor: CupertinoColors.systemGrey5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsNothing);
    },
  );

  testWidgets(
    'keeps Category Type single-line before shared wrapping Shopping List',
    (tester) async {
      final labelStyle = TextStyle(
        fontSize: 17,
        fontFamily: kSFProText,
        letterSpacing: kTracking17,
        height: kLineHeight,
      );
      final valueStyle = TextStyle(
        fontSize: 15,
        fontFamily: kSFProText,
        fontWeight: FontWeight.w500,
        letterSpacing: kTracking17,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: SizedBox(
                width: 550,
                child: MinGapLabelValueRow(
                  label: 'Category Type',
                  labelStyle: labelStyle,
                  value: 'Shopping List',
                  valueStyle: valueStyle,
                  trailing: Text('Shopping List', style: valueStyle),
                  alignTrailing: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labelSize = tester.getSize(find.text('Category Type'));
      final valueSize = tester.getSize(find.text('Shopping List'));
      expect(labelSize.height, lessThan(50));
      expect(valueSize.height, greaterThan(30));
    },
  );

  testWidgets(
    'preserves a generic chevron-row label before wrapping its value',
    (tester) async {
      const labelStyle = TextStyle(fontSize: 17);
      const valueStyle = TextStyle(fontSize: 15);

      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox(
              width: 220,
              child: MinGapLabelValueRow(
                label: 'Long Label',
                labelStyle: labelStyle,
                value: 'First Second Third',
                valueStyle: valueStyle,
                trailing: Text('First Second Third', style: valueStyle),
                alignTrailing: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labelSize = tester.getSize(find.text('Long Label'));
      final valueSize = tester.getSize(find.text('First Second Third'));
      // The app's default 17 px text style resolves to a 34 px line height.
      expect(labelSize.height, lessThan(40));
      expect(valueSize.height, greaterThan(labelSize.height));
    },
  );

  testWidgets(
    'keeps one-character word values together while the label wraps first',
    (tester) async {
      const labelStyle = TextStyle(fontSize: 17);
      const valueStyle = TextStyle(fontSize: 15);
      const valueKey = Key('protected-short-pair-value');

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox(
              width: 140,
              child: const MinGapLabelValueRow(
                label: 'Long Label',
                labelStyle: labelStyle,
                value: '1 hour',
                valueStyle: valueStyle,
                trailing: _ProtectedPairText(
                  valueKey: valueKey,
                  valueStyle: valueStyle,
                ),
                trailingExtraWidth: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labelSize = tester.getSize(find.text('Long Label'));
      final valueSize = tester.getSize(find.byKey(valueKey));
      expect(labelSize.height, greaterThan(valueSize.height));
      final valueContext = tester.element(find.byKey(valueKey));
      expect(
        chevronValueTextForWidth(
          valueContext,
          '1 hour',
          valueStyle,
          valueSize.width,
        ),
        contains('\u00a0'),
      );
      expect(
        chevronValueTextForWidth(
          valueContext,
          '1 hour',
          valueStyle,
          1,
        ),
        contains(' '),
      );
    },
  );

  test(
    'allows a protected short pair to unwrap only below its full width',
    () {
      expect(
        smartWrapChevronValueAsProtectedPair('1 hour'),
        contains('\u00a0'),
      );
      expect(
        smartWrapChevronValueAsProtectedPair('10 hours'),
        contains(' '),
      );
    },
  );
}

class _ProtectedPairText extends StatelessWidget {
  final Key valueKey;
  final TextStyle valueStyle;

  const _ProtectedPairText({
    required this.valueKey,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        chevronValueTextForWidth(
          context,
          '1 hour',
          valueStyle,
          constraints.maxWidth,
        ),
        key: valueKey,
      ),
    );
  }
}