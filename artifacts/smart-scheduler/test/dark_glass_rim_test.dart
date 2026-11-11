import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    as flutter_glass;
import 'package:liquid_glass_easy/liquid_glass_easy.dart' as easy_glass;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass;

import 'package:smart_scheduler/app_theme.dart' show kLiquidGlassHairlineColor;
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart'
    show
        kSkeddoDarkGlassEdgeIntensityMultiplier,
        skeddoGlassEdgeLightForBrightness,
        skeddoGlassEdgeStyleForBrightness;

void main() {
  test('dark package themes use half-strength edge lighting', () {
    expect(flutter_glass.GlassThemeVariant.dark.settings!.lightIntensity, 0.35);
    expect(
      navigation_glass.GlassThemeVariant.dark.settings!.lightIntensity,
      0.35,
    );
    expect(
      navigation_glass.GlassThemeVariant.ios27Dark.settings!.rimLight,
      0.575,
    );
    expect(navigation_glass.LiquidGlassSettings.ios27Dark.rimLight, 0.575);
    expect(kSkeddoDarkGlassEdgeIntensityMultiplier, 0.5);
  });

  test('dark action-control hairline opacity is halved', () {
    expect(kLiquidGlassHairlineColor.a, closeTo(19 / 255, 0.000001));
  });

  test('app-owned bright edge lights are halved only in Dark Mode', () {
    const original = easy_glass.LiquidGlassLight.specular(intensity: 0.8);
    expect(
      skeddoGlassEdgeLightForBrightness(Brightness.light, original).intensity,
      0.8,
    );
    expect(
      skeddoGlassEdgeLightForBrightness(Brightness.dark, original).intensity,
      0.4,
    );

    final darkStyle = skeddoGlassEdgeStyleForBrightness(
      Brightness.dark,
      easy_glass.LiquidGlassSlider.defaultStyle,
    );
    expect(
      darkStyle.specular!.intensity,
      easy_glass.LiquidGlassSlider.defaultStyle.specular!.intensity * 0.5,
    );
    expect(easy_glass.LiquidGlassSlider.defaultStyle.specular!.intensity, 1.0);
  });
}
