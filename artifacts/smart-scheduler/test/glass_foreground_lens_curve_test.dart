import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/widgets/shared/glass_popover_content_lens.dart'
    show GlassPopoverContentLens;
import 'package:liquid_glass_widgets/widgets/shared/glass_menu_content_lens.dart'
    show GlassMenuContentLens;

void main() {
  void expectOptics({
    required double strength,
    required double normalizedStrength,
    required double thickness,
    required double effectiveThickness,
    required double refractiveIndex,
    required double effectiveRefractiveIndex,
    required double chromaticAberration,
    required double effectiveChromaticAberration,
  }) {
    expect(normalizedStrength, strength);
    expect(effectiveThickness, closeTo(thickness * strength, 0.0001));
    expect(
      effectiveRefractiveIndex,
      closeTo(1.0 + (refractiveIndex - 1.0) * strength, 0.0001),
    );
    expect(
      effectiveChromaticAberration,
      closeTo(chromaticAberration * strength, 0.0001),
    );
  }

  test('menu and popover foreground optics share the same strength curve', () {
    for (final strength in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final menuLens = GlassMenuContentLens(
        progress: 0.5,
        size: const Size(280, 180),
        cornerRadius: 32,
        thickness: GlassMenuContentLens.foregroundThickness,
        refractiveIndex: GlassMenuContentLens.foregroundRefractiveIndex,
        chromaticAberration:
            GlassMenuContentLens.foregroundChromaticAberration,
        effectStrength: strength,
        child: const SizedBox(),
      );
      final popoverLens = GlassPopoverContentLens(
        progress: 0.5,
        size: const Size(280, 180),
        cornerRadius: 32,
        thickness: GlassPopoverContentLens.foregroundThickness,
        refractiveIndex: GlassPopoverContentLens.foregroundRefractiveIndex,
        chromaticAberration:
            GlassPopoverContentLens.foregroundChromaticAberration,
        effectStrength: strength,
        child: const SizedBox(),
      );

      expectOptics(
        strength: strength,
        normalizedStrength: menuLens.normalizedEffectStrength,
        thickness: menuLens.thickness,
        effectiveThickness: menuLens.effectiveThickness,
        refractiveIndex: menuLens.refractiveIndex,
        effectiveRefractiveIndex: menuLens.effectiveRefractiveIndex,
        chromaticAberration: menuLens.chromaticAberration,
        effectiveChromaticAberration: menuLens.effectiveChromaticAberration,
      );
      expectOptics(
        strength: strength,
        normalizedStrength: popoverLens.normalizedEffectStrength,
        thickness: popoverLens.thickness,
        effectiveThickness: popoverLens.effectiveThickness,
        refractiveIndex: popoverLens.refractiveIndex,
        effectiveRefractiveIndex: popoverLens.effectiveRefractiveIndex,
        chromaticAberration: popoverLens.chromaticAberration,
        effectiveChromaticAberration:
            popoverLens.effectiveChromaticAberration,
      );
      expect(menuLens.effectiveThickness, popoverLens.effectiveThickness);
      expect(
        menuLens.effectiveRefractiveIndex,
        popoverLens.effectiveRefractiveIndex,
      );
      expect(
        menuLens.effectiveChromaticAberration,
        popoverLens.effectiveChromaticAberration,
      );
    }
  });

  test('settled foreground lenses have no thickness, refraction, or color split', () {
    final menuLens = GlassMenuContentLens(
      progress: 1,
      size: const Size(280, 180),
      cornerRadius: 32,
      thickness: GlassMenuContentLens.foregroundThickness,
      refractiveIndex: GlassMenuContentLens.foregroundRefractiveIndex,
      chromaticAberration:
          GlassMenuContentLens.foregroundChromaticAberration,
      effectStrength: 0,
      child: const SizedBox(),
    );
    final popoverLens = GlassPopoverContentLens(
      progress: 1,
      size: const Size(280, 180),
      cornerRadius: 32,
      thickness: GlassPopoverContentLens.foregroundThickness,
      refractiveIndex: GlassPopoverContentLens.foregroundRefractiveIndex,
      chromaticAberration:
          GlassPopoverContentLens.foregroundChromaticAberration,
      effectStrength: 0,
      child: const SizedBox(),
    );

    expect(menuLens.effectiveThickness, 0);
    expect(menuLens.effectiveRefractiveIndex, 1);
    expect(menuLens.effectiveChromaticAberration, 0);
    expect(popoverLens.effectiveThickness, 0);
    expect(popoverLens.effectiveRefractiveIndex, 1);
    expect(popoverLens.effectiveChromaticAberration, 0);
  });
}
