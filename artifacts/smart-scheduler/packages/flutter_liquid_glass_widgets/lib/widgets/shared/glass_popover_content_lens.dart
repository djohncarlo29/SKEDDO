import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Applies the menu lens response to popover foreground content while it
/// crosses the moving glass edge. The settled content remains unfiltered.
class GlassPopoverContentLens extends StatefulWidget {
  /// Peak content blur sigma shared with the other SKEDDO menu morphs.
  static const double peakContentBlurSigma = 4.0;

  /// Foreground optics used while popover content crosses the moving glass edge.
  /// Thickness in logical pixels.
  static const double foregroundThickness = 30.0;

  /// Refractive index for the foreground edge response.
  static const double foregroundRefractiveIndex = 1.30;

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
    super.key,
  });

  final Widget child;
  final double progress;
  final Size size;
  final double cornerRadius;
  final double thickness;
  final double refractiveIndex;
  final double chromaticAberration;

  /// Optional normalized foreground-lens strength driven by the same curve as
  /// the content blur. Zero is neutral; one uses the peak optical settings.
  /// When omitted, preserve the original symmetric progress envelope.
  final double? effectStrength;

  /// Clamped normalized strength applied to the foreground lens.
  double get normalizedEffectStrength =>
      (effectStrength ?? 4.0 * progress * (1.0 - progress))
          .clamp(0.0, 1.0)
          .toDouble();

  /// Thickness remaining after applying the current strength curve.
  double get effectiveThickness => thickness * normalizedEffectStrength;

  /// Effective foreground refractive index, returning 1.0 at rest.
  double get effectiveRefractiveIndex =>
      1.0 + (refractiveIndex - 1.0) * normalizedEffectStrength;

  /// Effective color separation, returning zero at rest.
  double get effectiveChromaticAberration =>
      chromaticAberration * normalizedEffectStrength;

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
    final intensity = widget.normalizedEffectStrength;
    final effectiveThickness = widget.effectiveThickness;
    if (shader == null ||
        shortSide <= 0 ||
        intensity <= 0.001 ||
        effectiveThickness <= 0.001 ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return widget.child;
    }

    shader
      ..setFloat(2, 1.0)
      ..setFloat(3, effectiveThickness / shortSide)
      ..setFloat(4, widget.effectiveRefractiveIndex)
      ..setFloat(5, widget.effectiveChromaticAberration.clamp(0.0, 1.0))
      ..setFloat(6, (widget.cornerRadius / shortSide).clamp(0.0, 0.5));

    return ImageFiltered(
      key: const ValueKey<String>('glass-popover-content-lens'),
      imageFilter: ui.ImageFilter.shader(shader),
      child: widget.child,
    );
  }
}
