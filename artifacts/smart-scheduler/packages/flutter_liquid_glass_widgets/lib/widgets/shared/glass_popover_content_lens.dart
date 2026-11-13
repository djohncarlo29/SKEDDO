import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Applies the menu lens response to popover foreground content while it
/// crosses the moving glass edge. The settled content remains unfiltered.
class GlassPopoverContentLens extends StatefulWidget {
  /// Peak content blur sigma shared with the other SKEDDO menu morphs.
  static const double peakContentBlurSigma = 4.0;

  /// Fraction of the morph at which the foreground thickness fade begins.
  static const double thicknessFadeStartFraction = 0.85;

  /// Foreground optics used while popover content crosses the moving glass edge.
  /// Thickness in logical pixels.
  static const double foregroundThickness = 30.0;

  /// Refractive index for the foreground edge response.
  static const double foregroundRefractiveIndex = 1.45;

  /// Channel separation strength for the foreground edge response.
  static const double foregroundChromaticAberration = 0.06;

  const GlassPopoverContentLens({
    required this.child,
    required this.progress,
    required this.size,
    required this.cornerRadius,
    required this.thickness,
    required this.refractiveIndex,
    required this.chromaticAberration,
    this.effectStrength,
    this.thicknessStrength,
    this.refractiveIndexActive,
    super.key,
  });

  final Widget child;
  final double progress;
  final Size size;
  final double cornerRadius;
  final double thickness;
  final double refractiveIndex;
  final double chromaticAberration;

  /// Optional normalized color-separation strength driven by content blur.
  /// When omitted, preserve the original symmetric progress envelope.
  final double? effectStrength;

  /// Optional thickness strength, independent of the chromatic-aberration
  /// curve.
  final double? thicknessStrength;

  /// Whether the morph is active. Refraction stays at its peak while active,
  /// then returns to the neutral refractive index of 1.0.
  final bool? refractiveIndexActive;

  /// Clamped normalized strength applied to the foreground lens.
  double get normalizedEffectStrength =>
      (effectStrength ?? 4.0 * progress * (1.0 - progress))
          .clamp(0.0, 1.0)
          .toDouble();

  /// Thickness remaining after applying the thickness-specific curve.
  double get effectiveThickness {
    final strength = (thicknessStrength ?? normalizedEffectStrength)
        .clamp(0.0, 1.0)
        .toDouble();
    return thickness * strength;
  }

  /// Effective foreground refractive index, held at peak during the morph.
  double get effectiveRefractiveIndex =>
      (refractiveIndexActive ?? normalizedEffectStrength > 0.001)
          ? refractiveIndex
          : 1.0;

  /// Effective color separation, returning zero at rest.
  double get effectiveChromaticAberration =>
      chromaticAberration * normalizedEffectStrength;

  /// Thickness strength across a normalized opening or closing morph.
  static double thicknessStrengthForPhase(double phase) {
    final t = phase.clamp(0.0, 1.0).toDouble();
    if (t <= thicknessFadeStartFraction) return 1.0;
    final fadeProgress =
        (t - thicknessFadeStartFraction) / (1.0 - thicknessFadeStartFraction);
    return 1.0 - Curves.easeInCubic.transform(fadeProgress);
  }

  static ui.FragmentProgram? _program;
  static Future<void>? _loadFuture;

  /// Loads the shader before a popover is first opened.
  static Future<void> preWarm() => _loadFuture ??= _loadProgram();

  static Future<void> _loadProgram() async {
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'packages/flutter_liquid_glass_widgets/shaders/menu_content_lens.frag',
      );
    } catch (_) {
      try {
        _program = await ui.FragmentProgram.fromAsset(
          'shaders/menu_content_lens.frag',
        );
      } catch (error) {
        debugPrint('[GlassPopoverContentLens] Shader load failed: $error');
      }
    }
  }

  @override
  State<GlassPopoverContentLens> createState() =>
      _GlassPopoverContentLensState();
}

class _GlassPopoverContentLensState extends State<GlassPopoverContentLens> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _prepareShader();
  }

  Future<void> _prepareShader() async {
    await GlassPopoverContentLens.preWarm();
    if (!mounted) return;
    final program = GlassPopoverContentLens._program;
    if (program == null) return;
    _shader = program.fragmentShader();
    setState(() {});
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final shortSide = math.min(widget.size.width, widget.size.height);
    final effectiveThickness = widget.effectiveThickness;
    final effectiveRefractiveIndex = widget.effectiveRefractiveIndex;
    final effectiveChromaticAberration =
        widget.effectiveChromaticAberration.clamp(0.0, 1.0).toDouble();
    if (shader == null ||
        shortSide <= 0 ||
        effectiveThickness <= 0.001 ||
        (effectiveRefractiveIndex <= 1.0 &&
            effectiveChromaticAberration <= 0.001) ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return widget.child;
    }

    shader
      ..setFloat(2, 1.0)
      ..setFloat(3, effectiveThickness / shortSide)
      ..setFloat(4, effectiveRefractiveIndex)
      ..setFloat(5, effectiveChromaticAberration)
      ..setFloat(6, (widget.cornerRadius / shortSide).clamp(0.0, 0.5));

    return ImageFiltered(
      key: const ValueKey<String>('glass-popover-content-lens'),
      imageFilter: ui.ImageFilter.shader(shader),
      child: widget.child,
    );
  }
}
