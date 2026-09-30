import 'package:flutter/cupertino.dart';

import '../app_theme.dart'
    show kModalSheetButtonDiameter, kModalSheetButtonEdgeGap;
import 'header_title_scroller.dart';
import 'horizontal_edge_fade.dart' show kHorizontalFadeEdgeGap;

/// Centers a modal title when it fits and gives it the same horizontal
/// scrolling, rubberband, and edge-fade behavior as the AppShell title.
///
/// The title viewport ends one shared fade gap inside the header controls, so
/// the opaque edge of each fade stays 16 pt clear of the button's inner edge.
class ModalSheetTitleScroller extends StatelessWidget {
  final String title;
  final TextStyle style;
  final Color fadeColor;

  const ModalSheetTitleScroller({
    super.key,
    required this.title,
    required this.style,
    required this.fadeColor,
  });

  static const double _titleSideInset =
      kModalSheetButtonEdgeGap +
      kModalSheetButtonDiameter +
      kHorizontalFadeEdgeGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _titleSideInset),
      child: HeaderTitleScroller(
        title: title,
        style: style,
        fadeColor: fadeColor,
        centerWhenContentFits: true,
        contentAlignment: Alignment.centerLeft,
      ),
    );
  }
}
