import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_screen_geometry.dart';

void main() {
  testWidgets(
    'glass screen geometry uses the FlutterView size when MediaQuery is narrowed',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Size? shaderResolution;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(700, 400),
              devicePixelRatio: 2,
            ),
            child: Builder(
              builder: (context) {
                shaderResolution = liquidGlassFlutterViewSize(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(shaderResolution, const Size(800, 450));
    },
  );
}
