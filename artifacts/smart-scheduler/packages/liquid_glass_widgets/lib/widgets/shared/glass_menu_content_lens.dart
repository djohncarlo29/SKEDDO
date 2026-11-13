import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Applies a short, edge-local lens pass to menu content during its morph.
///
/// The normal glass surface refracts the backdrop behind it. This additional
/// pass makes the menu's own foreground content respond as it crosses the
/// moving rounded edge, then leaves the settled menu untouched.
class GlassMenuContentLens extends StatefulWidget {
  /// Foreground optics used while menu content crosses the moving platter edge.
  /// Thickness in logical pixels.
  static const double foregroundThickness = 30.0;

  /// Refractive index for the foreground edge response.
  static const double foregroundRefractiveIndex = 1.45;

  /// Channel separation strength for the foreground edge response.
  static const double foregroundChromaticAberration = 0.06;

  /// Creates a transition lens for glass menu content.
  const GlassMenuContentLens({
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

  /// Menu content to filter during the transition.
  final Widget child;

  /// Current open/close morph progress, from zero to one.
  final double progress;

  /// Current animated glass bounds.
  final Size size;

  /// Current animated corner radius.
  final double cornerRadius;

  /// Glass thickness used to derive the child-edge displacement.
  final double thickness;

  /// Refractive index used to derive the child-edge displacement.
  final double refractiveIndex;

  /// Chromatic separation applied to the child edge.
  final double chromaticAberration;

  /// Optional normalized color-separation strength from the content-blur
  /// curve.
  ///
  /// When omitted, the original symmetric progress envelope is retained.
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

  static ui.FragmentProgram? _program;
  static Future<void>? _loadFuture;

  /// Loads the shader before a menu is first opened.
  static Future<void> preWarm() => _loadFuture ??= _loadProgram();

  static Future<void> _loadProgram() async {
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'packages/liquid_glass_widgets/shaders/menu_content_lens.frag',
      );
    } catch (_) {
      try {
        _program = await ui.FragmentProgram.fromAsset(
          'shaders/menu_content_lens.frag',
        );
      } catch (error) {
        debugPrint('[GlassMenuContentLens] Shader load failed: $error');
      }
    }
  }

  @override
  State<GlassMenuContentLens> createState() => _GlassMenuContentLensState();
}

class _GlassMenuContentLensState extends State<GlassMenuContentLens> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _prepareShader();
  }

  Future<void> _prepareShader() async {
    await GlassMenuContentLens.preWarm();
    if (!mounted) return;
    final program = GlassMenuContentLens._program;
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
      // The live optical values carry the curve; do not attenuate the same
      // strength a second time through the shader's contact multiplier.
      ..setFloat(2, 1.0)
      ..setFloat(3, effectiveThickness / shortSide)
      ..setFloat(4, effectiveRefractiveIndex)
      ..setFloat(5, effectiveChromaticAberration)
      ..setFloat(6, (widget.cornerRadius / shortSide).clamp(0.0, 0.5));

    return ImageFiltered(
      key: const ValueKey<String>('glass-menu-content-lens-filter'),
      imageFilter: ui.ImageFilter.shader(shader),
      child: widget.child,
    );
  }
}
