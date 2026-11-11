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
    await tester.pump(const Duration(milliseconds: 75));
    expect(_readScale(tester), greaterThan(20));
    expect(_readScale(tester), lessThan(22));
    await tester.pumpAndSettle();
    expect(find.text('22.0'), findsOneWidget);

    selectCustomTextScaleIndex(1);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('34.0'), findsOneWidget);

    appTextSizeUsesSystemNotifier.value = true;
    await tester.pump();
    expect(find.text('20.0'), findsOneWidget);
  });

  testWidgets('interpolates nonlinear curves and retargets without a jump', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCurveHarness(TextScaler.linear(1.0)));

    appTextSizeUsesSystemNotifier.value = false;
    appCustomTextScalerNotifier.value = const _NonlinearTextScaler();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));

    expect(_readScale(tester, const ValueKey('small')), closeTo(10.875, 0.001));
    expect(_readScale(tester, const ValueKey('large')), closeTo(37.875, 0.001));

    final currentScale = _readScale(tester);
    selectCustomTextScaleIndex(1);
    await tester.pump();
    expect(_readScale(tester), closeTo(currentScale, 0.000001));

    await tester.pump(const Duration(milliseconds: 75));
    expect(_readScale(tester), greaterThan(currentScale));
    expect(_readScale(tester), lessThan(34));
    await tester.pumpAndSettle();
    expect(find.text('34.0'), findsOneWidget);
  });

  testWidgets('disabled animations apply the selected scale immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScaleHarness(TextScaler.linear(1.0), disableAnimations: true),
    );

    selectCustomTextScaleIndex(0);
    await tester.pump();

    expect(find.text('22.0'), findsOneWidget);
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
            builder: (context) => Text(
              '${MediaQuery.textScalerOf(context).scale(20)}',
              key: const ValueKey('scaled-text'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialBuilderCalls = appBuilderCalls;
      expect(find.text('20.0'), findsOneWidget);

      selectCustomTextScaleIndex(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));

      expect(_readScale(tester), greaterThan(20));
      expect(_readScale(tester), lessThan(22));
      expect(appBuilderCalls, initialBuilderCalls);

      await tester.pumpAndSettle();
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

Widget _buildScaleHarness(
  TextScaler ambientScaler, {
  bool disableAnimations = false,
}) => CupertinoApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: ambientScaler,
      disableAnimations: disableAnimations,
    ),
    child: AppTextScaleScope(
      child: Builder(
        builder: (context) => Text(
          '${MediaQuery.textScalerOf(context).scale(20)}',
          key: const ValueKey('scaled-text'),
        ),
      ),
    ),
  ),
);

Widget _buildCurveHarness(TextScaler ambientScaler) => CupertinoApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: ambientScaler),
    child: AppTextScaleScope(
      child: Builder(
        builder: (context) {
          final scaler = MediaQuery.textScalerOf(context);
          return Column(
            children: [
              Text(
                scaler.scale(10).toStringAsFixed(3),
                key: const ValueKey('small'),
              ),
              Text(
                scaler.scale(30).toStringAsFixed(3),
                key: const ValueKey('large'),
              ),
              Text('${scaler.scale(20)}', key: const ValueKey('scaled-text')),
            ],
          );
        },
      ),
    ),
  ),
);

double _readScale(
  WidgetTester tester, [
  Key key = const ValueKey('scaled-text'),
]) => double.parse(tester.widget<Text>(find.byKey(key)).data!);

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) => fontSize * (1 + fontSize / 100);

  @override
  double get textScaleFactor => scale(16) / 16;
}
