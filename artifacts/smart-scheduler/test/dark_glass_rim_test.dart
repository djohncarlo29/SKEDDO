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
        kSkeddoDarkGlassInteractionGlowMultiplier,
        kSkeddoSharedGlassRimStrength,
        skeddoGlassEdgeLightForBrightness,
        skeddoGlassEdgeStyleForBrightness,
        skeddoNavigationGlassSettingsFromShared,
        skeddoNavigationTabBarGlassSettingsFor,
        skeddoPinnedNavigationGlassSettingsFor,
        skeddoPopoverGlassSettingsFor;

void main() {
  test('package glass surfaces use one shared rim strength', () {
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
    expect(kSkeddoSharedGlassRimStrength, 1.0);
  });

  test('bar, toolbar, and popover map to the shared rim strength', () {
    const tint = Color(0xff202024);
    final bar = skeddoNavigationTabBarGlassSettingsFor(Brightness.dark);
    final toolbar = skeddoPinnedNavigationGlassSettingsFor(Brightness.dark);
    final popover = skeddoNavigationGlassSettingsFromShared(
      skeddoPopoverGlassSettingsFor(Brightness.dark, tint),
    );

    expect(bar.fresnelStrength, kSkeddoSharedGlassRimStrength);
    expect(toolbar.fresnelStrength, kSkeddoSharedGlassRimStrength);
    expect(popover.fresnelStrength, kSkeddoSharedGlassRimStrength);
    expect(bar.lightIntensity, toolbar.lightIntensity);
    expect(popover.lightIntensity, toolbar.lightIntensity);
  });

  test('dark action-control hairline uses the shared rim strength', () {
    expect(
      kLiquidGlassHairlineColor.a,
      closeTo(0.15 * kSkeddoSharedGlassRimStrength, 0.000001),
    );
  });

  test('app-owned edge lights retain their base rim strength in Dark Mode', () {
    const original = easy_glass.LiquidGlassLight.specular(intensity: 0.8);
    expect(
      skeddoGlassEdgeLightForBrightness(Brightness.light, original).intensity,
      0.8,
    );
    expect(
      skeddoGlassEdgeLightForBrightness(Brightness.dark, original).intensity,
      0.8,
    );

    final darkStyle = skeddoGlassEdgeStyleForBrightness(
      Brightness.dark,
      easy_glass.LiquidGlassSlider.defaultStyle,
    );
    expect(
      darkStyle.specular!.intensity,
      easy_glass.LiquidGlassSlider.defaultStyle.specular!.intensity,
    );
    expect(easy_glass.LiquidGlassSlider.defaultStyle.specular!.intensity, 1.0);
    expect(kSkeddoDarkGlassInteractionGlowMultiplier, 0.5);
  });
}
