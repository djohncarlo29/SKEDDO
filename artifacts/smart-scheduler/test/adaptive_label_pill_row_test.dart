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
}