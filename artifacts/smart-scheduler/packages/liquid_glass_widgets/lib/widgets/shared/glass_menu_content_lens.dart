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
  /// Creates a transition lens for glass menu content.
  const GlassMenuContentLens({
    required this.child,
    required this.progress,
    required this.size,
    required this.cornerRadius,
    required this.thickness,
    required this.refractiveIndex,
    required this.chromaticAberration,
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
    final progress = widget.progress.clamp(0.0, 1.0);
    final intensity = 4.0 * progress * (1.0 - progress);
    if (shader == null ||
        shortSide <= 0 ||
        intensity <= 0.001 ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return widget.child;
    }

    shader
      ..setFloat(2, intensity)
      ..setFloat(3, widget.thickness / shortSide)
      ..setFloat(4, widget.refractiveIndex)
      ..setFloat(5, widget.chromaticAberration.clamp(0.0, 1.0))
      ..setFloat(6, (widget.cornerRadius / shortSide).clamp(0.0, 0.5));

    return ImageFiltered(
      key: const ValueKey<String>('glass-menu-content-lens-filter'),
      imageFilter: ui.ImageFilter.shader(shader),
      child: widget.child,
    );
  }
}
