import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  test('touch-glow metrics share one package-wide default', () {
    expect(GlassDefaults.touchGlowRadius, 1.6);
    expect(GlassDefaults.touchGlowBlurRadius, 16);
    expect(GlassDefaults.touchGlowSpreadRadius, 0);
    expect(GlassDefaults.touchGlowOpacity, 0.6);
    expect(GlassDefaults.touchGlowLightModeColor, const Color(0x1A000000));
    expect(GlassDefaults.touchGlowDarkModeColor, const Color(0x26FFFFFF));

    final themeGlow = GlassGlowColors.fallback;
    expect(themeGlow.glowBlurRadius, GlassDefaults.touchGlowBlurRadius);
    expect(themeGlow.glowSpreadRadius, GlassDefaults.touchGlowSpreadRadius);
    expect(themeGlow.glowOpacity, GlassDefaults.touchGlowOpacity);
  });

  test('menu and popover defaults use the shared glow radius', () {
    const menu = GlassMenu(items: [], trigger: Text('Open'));
    final popover = GlassPopover(
      trigger: const Text('Open'),
      contentBuilder: (context, close) => const SizedBox.shrink(),
    );

    expect(menu.glowRadius, GlassDefaults.touchGlowRadius);
    expect(popover.glowRadius, GlassDefaults.touchGlowRadius);
  });
}
