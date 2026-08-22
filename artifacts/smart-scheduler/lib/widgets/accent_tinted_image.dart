import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// An asset image whose blue artwork is replaced with [accentColor].
///
/// The source image remains the authority for brightness, shading, and alpha.
/// Only pixels that are confidently blue are hue-shifted, so the neutral grey
/// artwork is left untouched.
class AccentTintedImage extends StatelessWidget {
  final String assetName;
  final Color accentColor;
  final BoxFit fit;

  const AccentTintedImage({
    super.key,
    required this.assetName,
    required this.accentColor,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final tintedImage = _AccentImageCache.image(
      assetName: assetName,
      accentColor: accentColor,
    );

    return FutureBuilder<ui.Image>(
      future: tintedImage,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) {
          return Image.asset(assetName, fit: fit);
        }

        return RawImage(
          image: image,
          fit: fit,
          filterQuality: FilterQuality.high,
        );
      },
    );
  }
}

/// Warms the transformed preview images for every supplied accent color.
///
/// The source WebP files are small enough to decode in the background, while
/// the transformed images are kept in [_AccentImageCache] so the first visit
/// to the Liquid Glass settings screen does not need to tint them on demand.
Future<void> precacheAccentTintedImages({
  required Iterable<Color> lightAccentColors,
  required Iterable<Color> darkAccentColors,
}) async {
  await Future.wait<void>([
    for (final color in lightAccentColors)
      _AccentImageCache.image(
        assetName: 'assets/liquid_glass_background_light.webp',
        accentColor: color,
      ),
    for (final color in darkAccentColors)
      _AccentImageCache.image(
        assetName: 'assets/liquid_glass_background_dark.webp',
        accentColor: color,
      ),
  ]);
}

class _AccentImageCache {
  static final Map<String, Future<ui.Image>> _images =
      <String, Future<ui.Image>>{};

  static Future<ui.Image> image({
    required String assetName,
    required Color accentColor,
  }) {
    final key = '$assetName:${accentColor.toARGB32()}';
    return _images.putIfAbsent(key, () => _tint(assetName, accentColor));
  }

  static Future<ui.Image> _tint(String assetName, Color accentColor) async {
    final data = await rootBundle.load(assetName);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final source = frame.image;
    final pixels = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (pixels == null) {
      return source;
    }

    final rgba = Uint8List.fromList(pixels.buffer.asUint8List());
    final target = accentColor;
    final targetRed = target.r;
    final targetGreen = target.g;
    final targetBlue = target.b;
    final targetLuminance =
        (0.2126 * targetRed) + (0.7152 * targetGreen) + (0.0722 * targetBlue);

    for (var i = 0; i < rgba.length; i += 4) {
      final red = rgba[i];
      final green = rgba[i + 1];
      final blue = rgba[i + 2];
      final alpha = rgba[i + 3];

      // The preview's accent bubble is blue. Requiring both a blue channel
      // lead and meaningful saturation avoids touching the grey reflections.
      final isBlue =
          blue > red * 1.08 &&
          blue > green * 1.03 &&
          blue - red > 12 &&
          blue - green > 4 &&
          (blue - red) / 255 > 0.10;
      if (!isBlue || alpha == 0) continue;

      // Use the source blue only as a shading mask. HSV replacement keeps
      // the blue pixels' original Value, which makes pale accents (Tan and
      // Sand) too bright and lets blue-biased accents (Slate) remain visibly
      // blue. Reconstructing the target colour at the source pixel's
      // luminance preserves the artwork's depth without changing the
      // selected swatch's visual identity.
      final sourceLuminance =
          (0.2126 * red / 255.0) +
          (0.7152 * green / 255.0) +
          (0.0722 * blue / 255.0);
      final shade = (sourceLuminance / targetLuminance).clamp(0.0, 1.0);
      rgba[i] = (targetRed * shade * 255.0).round().clamp(0, 255);
      rgba[i + 1] = (targetGreen * shade * 255.0).round().clamp(0, 255);
      rgba[i + 2] = (targetBlue * shade * 255.0).round().clamp(0, 255);
    }

    final result = await _decodePixels(rgba, source.width, source.height);
    source.dispose();
    codec.dispose();
    return result;
  }

  static Future<ui.Image> _decodePixels(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
