import 'package:flutter/cupertino.dart';

/// A single-line Large Header title that can be explored horizontally when its
/// rendered width is larger than the title slot.
///
/// The title keeps the Large Header's authored size and height.  Edge fades
/// communicate whether more content is available in either direction:
/// start-only, both, or end-only depending on the current scroll position.
class HeaderTitleScroller extends StatefulWidget {
  final String title;
  final TextStyle style;
  final Color fadeColor;
  final double fadeWidth;

  const HeaderTitleScroller({
    super.key,
    required this.title,
    required this.style,
    required this.fadeColor,
    this.fadeWidth = 24,
  });

  @override
  State<HeaderTitleScroller> createState() => _HeaderTitleScrollerState();
}

class _HeaderTitleScrollerState extends State<HeaderTitleScroller> {
  late final ScrollController _scrollController;
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateFades);
    _scheduleFadeUpdate();
  }

  @override
  void didUpdateWidget(covariant HeaderTitleScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      // Every newly displayed title starts at its logical beginning, including
      // titles arriving through the tab/DCV and Settings navigation animations.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
        _updateFades();
      });
    } else {
      _scheduleFadeUpdate();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateFades)
      ..dispose();
    super.dispose();
  }

  void _scheduleFadeUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateFades();
    });
  }

  void _updateFades() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    final offset = position.pixels;
    final hasOverflow = maxExtent > 0.5;
    final showLeading = hasOverflow && offset > 0.5;
    final showTrailing = hasOverflow && offset < maxExtent - 0.5;

    if (showLeading == _showLeadingFade && showTrailing == _showTrailingFade) {
      return;
    }
    setState(() {
      _showLeadingFade = showLeading;
      _showTrailingFade = showTrailing;
    });
  }

  bool _handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      _updateFades();
    }
    return false;
  }

  Widget _buildFade({required bool visible, required bool opaqueAtStart}) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.fadeWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: opaqueAtStart
                    ? [widget.fadeColor, widget.fadeColor.withValues(alpha: 0)]
                    : [widget.fadeColor.withValues(alpha: 0), widget.fadeColor],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.title,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleMetricsNotification,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.zero,
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      // Large Header titles are intentionally fixed-height. The
                      // rest of the app continues to follow the active OS scaler.
                      textScaler: TextScaler.noScaling,
                      style: widget.style,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _buildFade(
                  visible: _showLeadingFade,
                  opaqueAtStart: true,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _buildFade(
                  visible: _showTrailingFade,
                  opaqueAtStart: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
