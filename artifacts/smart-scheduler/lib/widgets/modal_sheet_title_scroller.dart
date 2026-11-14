import 'package:flutter/cupertino.dart';

import '../app_theme.dart'
    show kModalSheetButtonDiameter, kModalSheetButtonEdgeGap;
import 'header_title_scroller.dart';
import 'horizontal_edge_fade.dart' show kHorizontalFadeEdgeGap;
import 'modal_toolbar_glass_button.dart'
    show
        kModalSheetLeadingToolbarOffset,
        kModalSheetToolbarHorizontalShift;

/// Centers a modal title when it fits and gives it the same horizontal
/// scrolling, rubberband, and edge-fade behavior as the AppShell title.
///
/// The title viewport ends one shared fade gap inside the header controls, so
/// the opaque edge of each fade stays 16 pt clear of the button's inner edge.
class ModalSheetTitleScroller extends StatelessWidget {
  final String title;
  final TextStyle style;
  final Color fadeColor;
  final bool hasLeadingToolbar;
  final bool hasTrailingToolbar;

  const ModalSheetTitleScroller({
    super.key,
    required this.title,
    required this.style,
    required this.fadeColor,
    this.hasLeadingToolbar = true,
    this.hasTrailingToolbar = true,
  });

  static const double _titleToolbarInset =
      kModalSheetButtonEdgeGap +
      kModalSheetButtonDiameter +
      kHorizontalFadeEdgeGap +
      kModalSheetToolbarHorizontalShift;

  @override
  Widget build(BuildContext context) {
    final leadingInset = hasLeadingToolbar
        ? _titleToolbarInset
        : kHorizontalFadeEdgeGap;
    final trailingInset = hasTrailingToolbar
        ? _titleToolbarInset
        : kHorizontalFadeEdgeGap;
    return Padding(
      padding: EdgeInsets.only(
        left: leadingInset,
        right: trailingInset,
      ),
      child: Transform.translate(
        offset: Offset(0, kModalSheetLeadingToolbarOffset.dy),
        child: HeaderTitleScroller(
          title: title,
          style: style,
          fadeColor: fadeColor,
          centerWhenContentFits: true,
          contentAlignment: Alignment.centerLeft,
          fittingContentOffsetX: (trailingInset - leadingInset) / 2,
        ),
      ),
    );
  }
}
