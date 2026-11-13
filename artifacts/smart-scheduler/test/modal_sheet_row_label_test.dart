import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart'
    show ModalSheetRowLabel, modalSheetScaledRowExtent;

void main() {
  testWidgets('modal row label grows with OS text scaling', (tester) async {
    Future<double> measure(double scale) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Center(
              child: SizedBox(
                width: 260,
                child: ModalSheetRowLabel(
                  text: 'Unscheduled',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(ModalSheetRowLabel)).height;
    }

    final normalHeight = await measure(1);
    final largeHeight = await measure(2);

    expect(normalHeight, 30);
    expect(largeHeight, greaterThan(normalHeight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('modal row label grows further when scaled text wraps', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.4)),
          child: Center(
            child: SizedBox(
              width: 110,
              child: ModalSheetRowLabel(
                text: 'Days of Week',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ModalSheetRowLabel)).height,
      greaterThan(50),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed modal grid rows grow with OS text scaling', (
    tester,
  ) async {
    Future<double> measure(double scale) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Center(
              child: Builder(
                builder: (context) => SizedBox(
                  key: const Key('scaled-modal-grid-row'),
                  height: modalSheetScaledRowExtent(context, 44),
                ),
              ),
            ),
          ),
        ),
      );
      return tester
          .getSize(find.byKey(const Key('scaled-modal-grid-row')))
          .height;
    }

    expect(await measure(1), 44);
    expect(await measure(2), greaterThan(44));
  });
}
