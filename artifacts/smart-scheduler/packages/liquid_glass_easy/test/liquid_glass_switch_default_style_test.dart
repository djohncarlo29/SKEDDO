import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  test('switch default matches liquid_glass_easy 5.0.0 defaults', () {
    final style = LiquidGlassSwitch.defaultStyle;

    expect(
      style.shape!.cornerStyle,
      LiquidGlassCornerStyle.continuousRoundedRectangle,
    );
    expect(style.shape!.lightDirection, 39);
    expect((style.shape!.borderType as OpticalBorder).lightSpread, 0.9);
    expect(style.appearance.color, const Color(0x00FFFFFF));
    expect(style.appearance.blur.sigmaX, 0);
    expect(style.appearance.blur.sigmaY, 0);
    expect(style.appearance.shadow!.inset, 3);
    expect(style.refraction.effectiveRefractionIndex, 1.03);
    expect(style.refraction.effectiveDistortionWidth, 8);
    expect(style.refraction.effectiveDistortion, 1);
    expect(style.refraction.chromaticAberration, closeTo(1 / 660, 1e-12));
  });
}
