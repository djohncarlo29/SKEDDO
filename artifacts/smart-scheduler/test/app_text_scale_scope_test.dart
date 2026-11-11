import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/widgets/app_text_scale_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool previousSystemMode;
  late int previousIndex;
  late List<SkeddoTextScaleMapping> previousMapping;
  late TextScaler? previousCustomScaler;

  setUp(() {
    previousSystemMode = appTextSizeUsesSystemNotifier.value;
    previousIndex = appTextSizeIndexNotifier.value;
    previousMapping = appSkeddoTextScaleMappingNotifier.value;
    previousCustomScaler = appCustomTextScalerNotifier.value;
    appTextSizeUsesSystemNotifier.value = true;
    appTextSizeIndexNotifier.value = 3;
    appSkeddoTextScaleMappingNotifier.value = [
      _mapping(1.1, 0),
      _mapping(1.7, 1),
    ];
    appCustomTextScalerNotifier.value = null;
  });

  tearDown(() {
    appTextSizeUsesSystemNotifier.value = previousSystemMode;
    appTextSizeIndexNotifier.value = previousIndex;
    appSkeddoTextScaleMappingNotifier.value = previousMapping;
    appCustomTextScalerNotifier.value = previousCustomScaler;
  });

  testWidgets('System mode leaves the ambient text scaler unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScaleHarness(TextScaler.linear(1.3)));

    expect(find.text('26.0'), findsOneWidget);
  });

  testWidgets('Custom text scaling updates live as positions change', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScaleHarness(TextScaler.linear(1.0)));
    expect(find.text('20.0'), findsOneWidget);

    selectCustomTextScaleIndex(0);
    await tester.pump();
    expect(find.text('22.0'), findsOneWidget);

    selectCustomTextScaleIndex(1);
    await tester.pump();
    expect(find.text('34.0'), findsOneWidget);
  });

  testWidgets(
    'live text changes do not rebuild the CupertinoApp content builder',
    (tester) async {
      var appBuilderCalls = 0;
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) {
            appBuilderCalls++;
            return AppTextScaleScope(child: child ?? const SizedBox.shrink());
          },
          home: Builder(
            builder: (context) =>
                Text('${MediaQuery.textScalerOf(context).scale(20)}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialBuilderCalls = appBuilderCalls;
      expect(find.text('20.0'), findsOneWidget);

      selectCustomTextScaleIndex(0);
      await tester.pump();

      expect(find.text('22.0'), findsOneWidget);
      expect(appBuilderCalls, initialBuilderCalls);
    },
  );

  testWidgets('Custom fallback applies the selected mapped scale', (
    tester,
  ) async {
    appTextSizeUsesSystemNotifier.value = false;
    appTextSizeIndexNotifier.value = 1;

    await tester.pumpWidget(_buildScaleHarness(TextScaler.linear(1.0)));

    expect(find.text('34.0'), findsOneWidget);
  });
}

SkeddoTextScaleMapping _mapping(double scale, int index) =>
    SkeddoTextScaleMapping(
      scale: scale,
      kind: SkeddoTextScaleMappingKind.native,
      nativeIndex: index,
      scaler: TextScaler.linear(scale),
    );

Widget _buildScaleHarness(TextScaler ambientScaler) => CupertinoApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: ambientScaler),
    child: AppTextScaleScope(
      child: Builder(
        builder: (context) =>
            Text('${MediaQuery.textScalerOf(context).scale(20)}'),
      ),
    ),
  ),
);
