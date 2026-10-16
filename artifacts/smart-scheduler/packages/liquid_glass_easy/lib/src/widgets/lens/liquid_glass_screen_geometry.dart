import 'package:flutter/widgets.dart';

/// Returns the full logical FlutterView size for screen-space glass shaders.
///
/// A descendant MediaQuery can intentionally be narrowed to a safe content
/// rectangle, while Impeller's FlutterFragCoord remains relative to the full
/// physical view. Shader resolution must use the latter coordinate space.
Size liquidGlassFlutterViewSize(BuildContext context) =>
    MediaQueryData.fromView(View.of(context)).size;
