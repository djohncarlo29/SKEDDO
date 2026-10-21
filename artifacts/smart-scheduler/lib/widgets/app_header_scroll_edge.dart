import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;

const double kAppHeaderToolbarHeight = 44;
const double kAppHeaderTitleHeight = 57;
const double kAppHeaderCompactTitleReadyFraction = 0.9;
const double kAppHeaderScrollEdgeHeaderBottomExtension = 16;
const double kAppHeaderScrollCollapsedOffset =
    kAppHeaderTitleHeight + kAppHeaderToolbarHeight;
const double _kAppHeaderScrollEdgeMaxTintOpacity = 0.24;
const double _kAppHeaderScrollEdgeMaxBlurSigma = 4;
const Duration _kAppHeaderScrollSettleDuration = Duration(milliseconds: 260);

/// Shared scroll rules for second-level app headers.
///
/// Normal scrolling moves the title with its owning content and drives the
/// shell's Liquid Glass edge. Leading overscroll is different: content may
/// rubber-band, but the title stays at its resting position.
abstract final class AppHeaderScrollBehavior {
  /// Returns the non-negative distance scrolled away from the top.
  ///
  /// Use this for shell-owned titles and the shared scroll-edge progress so
  /// leading rubber-band overscroll never pulls those titles downward.
  static double contentOffset(ScrollMetrics metrics) {
    final offset = scrollOffsetIncludingOverscroll(metrics);
    if (!offset.isFinite || offset <= 0.0) return 0.0;
    return offset;
  }

  /// Returns the signed scroll position, including leading overscroll.
  ///
  /// Only use this while translating an active user drag into header movement.
  /// Clamping here would make a collapsed header immovable during a downward
  /// drag when the underlying scroll position is already at its leading edge.
  static double scrollOffsetIncludingOverscroll(ScrollMetrics metrics) {
    final offset = metrics.pixels - metrics.minScrollExtent;
    return offset.isFinite ? offset : 0.0;
  }

  /// Progress for fading the title-region surface during its collapse.
  static double titleCollapseProgress(double contentOffset) {
    if (!contentOffset.isFinite || contentOffset <= 0.0) return 0.0;
    return (contentOffset / kAppHeaderTitleHeight).clamp(0.0, 1.0).toDouble();
  }

  /// The shell-owned large title must move with both the scrollable content
  /// and the title slot as that slot collapses. Otherwise the content gains
  /// an extra upward displacement and closes the gap beneath the title.
  static double shellLargeTitleTravelOffset(double contentOffset) {
    if (!contentOffset.isFinite || contentOffset <= 0.0) return 0.0;
    return contentOffset +
        kAppHeaderTitleHeight * titleCollapseProgress(contentOffset);
  }

  /// Fades the outgoing title after its descenders enter the pinned toolbar.
  /// It is fully hidden before the compact title begins to appear.
  static double largeTitleFadeProgress(
    double contentOffset, {
    required double titleBottomInset,
  }) {
    if (!contentOffset.isFinite ||
        contentOffset <= 0.0 ||
        !titleBottomInset.isFinite) {
      return 0.0;
    }
    final titleBottom =
        (kAppHeaderTitleHeight - titleBottomInset)
            .clamp(0.0, kAppHeaderTitleHeight)
            .toDouble();
    final compactTitleReadyOffset =
        kAppHeaderTitleHeight * kAppHeaderCompactTitleReadyFraction;
    final handoffSplit = (titleBottom + compactTitleReadyOffset) / 2.0;
    if (contentOffset <= titleBottom) return 0.0;
    if (contentOffset >= handoffSplit) return 1.0;
    final fadeDistance = handoffSplit - titleBottom;
    if (fadeDistance <= 0.0) return 1.0;
    return ((contentOffset - titleBottom) / fadeDistance)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Fades the compact title in only after the large title has fully
  /// disappeared. It is fully opaque just before the content edge reaches the
  /// bottom of the second-level title slot.
  static double compactTitleFadeProgress(
    double contentOffset, {
    required double titleBottomInset,
  }) {
    if (!contentOffset.isFinite ||
        contentOffset <= 0.0 ||
        !titleBottomInset.isFinite) {
      return 0.0;
    }
    final titleBottom =
        (kAppHeaderTitleHeight - titleBottomInset)
            .clamp(0.0, kAppHeaderTitleHeight)
            .toDouble();
    final compactTitleReadyOffset =
        kAppHeaderTitleHeight * kAppHeaderCompactTitleReadyFraction;
    final handoffSplit = (titleBottom + compactTitleReadyOffset) / 2.0;
    if (contentOffset <= handoffSplit) return 0.0;
    final fadeDistance = compactTitleReadyOffset - handoffSplit;
    if (fadeDistance <= 0.0) return 1.0;
    return ((contentOffset - handoffSplit) / fadeDistance)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Builds the glass edge while the large title passes through the pinned
  /// header, then continues as content passes beneath the toolbar.
  static double scrollEdgeProgress(double contentOffset) {
    if (!contentOffset.isFinite || contentOffset <= 0.0) return 0.0;
    return (contentOffset /
            (kAppHeaderTitleHeight + kAppHeaderToolbarHeight))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Settles the page header into one of its two persistent scroll states.
  ///
  /// ScrollDirection.reverse means the content is moving up; forward means the
  /// user is moving back toward the top. The header does not follow any later
  /// ballistic return unless the user starts scrolling in the opposite
  /// direction.
  static double settledHeaderOffset(ScrollDirection direction) {
    return direction == ScrollDirection.reverse
        ? kAppHeaderScrollCollapsedOffset
        : 0.0;
  }

  /// Returns the translation that cancels leading overscroll for a title
  /// which is otherwise laid out inside the scrollable content.
  static double leadingOverscrollCorrection(ScrollMetrics metrics) {
    final offset = metrics.pixels - metrics.minScrollExtent;
    if (!offset.isFinite || offset >= 0.0) return 0.0;
    return offset;
  }
}

/// Tracks the direct-manipulation portion of a header scroll independently
/// from the scroll view's ballistic bounce after the user's finger lifts.
class AppHeaderScrollTracker {
  bool _isUserScrollActive = false;
  ScrollDirection _lastUserScrollDirection = ScrollDirection.idle;
  double _offsetAdjustment = 0.0;

  bool get isUserScrollActive => _isUserScrollActive;

  /// Whether an update marks the transition from a direct drag to ballistic
  /// motion. The first such update must trigger settling before it is applied.
  bool shouldSettleBeforeScrollUpdate({required bool hasDragDetails}) =>
      _isUserScrollActive && !hasDragDetails;

  void beginUserScroll({
    required ScrollDirection direction,
    required double headerOffset,
    required double scrollOffset,
  }) {
    if (direction == ScrollDirection.idle ||
        !headerOffset.isFinite ||
        !scrollOffset.isFinite) {
      return;
    }
    _offsetAdjustment = headerOffset - scrollOffset;
    _lastUserScrollDirection = direction;
    _isUserScrollActive = true;
  }

  /// Returns a new header offset only while the finger-driven scroll is active.
  ///
  /// Signed scroll offsets let downward drags expand a settled collapsed header
  /// even when the native scroll position has reached its leading edge.
  double? headerOffsetForUserScroll(double scrollOffset) {
    if (!_isUserScrollActive || !scrollOffset.isFinite) return null;
    return (scrollOffset + _offsetAdjustment)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  /// Ends direct tracking and returns the last deliberate scroll direction.
  ///
  /// Call this at the drag-to-ballistic handoff, or on ScrollEnd when a drag
  /// stops without a ballistic phase.
  ScrollDirection? finishUserScroll() {
    _isUserScrollActive = false;
    final direction = _lastUserScrollDirection;
    _lastUserScrollDirection = ScrollDirection.idle;
    if (direction == ScrollDirection.idle) return null;
    return direction;
  }

  void reset() {
    _isUserScrollActive = false;
    _lastUserScrollDirection = ScrollDirection.idle;
    _offsetAdjustment = 0.0;
  }
}

/// Animates the shell-owned header from its live scroll position into the
/// settled expanded or collapsed state. The same easing is used in both
/// directions so returning to the top reverses the collapse motion.
class AppHeaderScrollSettler {
  AppHeaderScrollSettler({
    required TickerProvider vsync,
    required this.offset,
    required this.onSettled,
  }) : _controller = AnimationController(
         vsync: vsync,
         duration: _kAppHeaderScrollSettleDuration,
       ) {
    _controller
      ..addListener(_updateOffset)
      ..addStatusListener(_handleStatus);
  }

  final ValueNotifier<double> offset;
  final VoidCallback onSettled;
  final AnimationController _controller;
  double _from = 0.0;
  double _to = 0.0;

  bool get isAnimating => _controller.isAnimating;

  void animateTo(double target) {
    _controller.stop(canceled: false);
    _from = offset.value;
    _to = target;
    final distance = (_to - _from).abs();
    if (!distance.isFinite || distance < 0.01) {
      offset.value = target;
      onSettled();
      return;
    }

    final durationFraction =
        (distance / kAppHeaderScrollCollapsedOffset).clamp(0.18, 1.0);
    _controller.duration = Duration(
      milliseconds:
          (_kAppHeaderScrollSettleDuration.inMilliseconds * durationFraction)
              .round(),
    );
    _controller.forward(from: 0.0);
  }

  void stop() => _controller.stop(canceled: false);

  void _updateOffset() {
    final progress = Curves.easeInOutCubic.transform(_controller.value);
    offset.value = _from + (_to - _from) * progress;
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    offset.value = _to;
    onSettled();
  }

  void dispose() => _controller.dispose();
}

/// Keeps centered placeholders aligned with the center of the usable content
/// area as the large-title slot collapses.
///
/// Lists retain their normal scroll behavior. This adjustment follows the
/// owning scroll position continuously and ignores leading overscroll.
class AppHeaderScrollCentered extends StatelessWidget {
  const AppHeaderScrollCentered({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled ||
        MediaQuery.orientationOf(context) != Orientation.portrait) {
      return child;
    }

    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;

    return AnimatedBuilder(
      animation: position,
      builder: (context, _) {
        if (!position.hasContentDimensions) return child;
        final contentOffset = AppHeaderScrollBehavior.contentOffset(position);
        final collapsedDistance = contentOffset
            .clamp(0.0, kAppHeaderTitleHeight)
            .toDouble();
        if (collapsedDistance == 0.0) return child;
        return Transform.translate(
          offset: Offset(0.0, collapsedDistance * 0.5),
          child: child,
        );
      },
    );
  }
}

/// Keeps a second-level title fixed during leading rubber-band overscroll while
/// leaving its ordinary scroll-away motion unchanged.
///
/// The title remains part of the scrollable content, so it still travels
/// beneath the app header and participates in the shared Liquid Glass edge
/// during normal upward scrolling. Only negative top overscroll is cancelled.
class AppHeaderScrollTitle extends StatelessWidget {
  const AppHeaderScrollTitle({
    super.key,
    required this.controller,
    required this.titleBottomInset,
    required this.child,
  });

  final ScrollController? controller;
  final double titleBottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrollController = controller;
    if (scrollController == null) return child;
    final settledScrollState = AppHeaderScrollInsetScope.maybeHeaderScrolled(
      context,
    );
    final userScrollActive = AppHeaderScrollInsetScope.maybeUserScrollActive(
      context,
    );
    final sharedScrollOffset = AppHeaderScrollInsetScope.maybeScrollOffset(
      context,
    );

    // Resolve the Scrollable that actually contains this title. Some calendar
    // modes intentionally share one controller with an embedded list, so the
    // controller can have multiple positions even though this title belongs to
    // exactly one of them.
    final owningPosition = Scrollable.maybeOf(context)?.position;
    final positionListenable = owningPosition ?? scrollController;
    final listenables = <Listenable>[
      positionListenable,
      if (settledScrollState != null) settledScrollState,
      if (userScrollActive != null) userScrollActive,
      if (sharedScrollOffset != null) sharedScrollOffset,
    ];
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final positions = scrollController.positions;
        final position =
            owningPosition ??
            (positions.length == 1 ? positions.single : null);
        if (position == null) return child;
        if (!position.hasContentDimensions) return child;
        final positionOffset = AppHeaderScrollBehavior.contentOffset(position);
        final isUserScrolling =
            userScrollActive?.value ??
            position.userScrollDirection != ScrollDirection.idle;
        final contentOffset =
            isUserScrolling && sharedScrollOffset != null
            ? sharedScrollOffset.value
            : positionOffset;
        final fadeProgress =
            settledScrollState != null && !isUserScrolling
            ? (settledScrollState.value ? 1.0 : 0.0)
            : AppHeaderScrollBehavior.largeTitleFadeProgress(
                contentOffset,
                titleBottomInset: titleBottomInset,
              );
        final correction =
            AppHeaderScrollBehavior.leadingOverscrollCorrection(position);
        final title = AppHeaderLargeTitleHandoff(
          progress: fadeProgress,
          child: child,
        );
        if (correction == 0.0) return title;
        return Transform.translate(
          offset: Offset(0.0, correction),
          child: title,
        );
      },
    );
  }
}

/// Provides the amount of app-shell space between a page's layout origin and
/// the physical top of its scroll viewport.
///
/// The page can keep its existing layout below the fixed header. App-level
/// scroll views use this inset to extend their viewport upward and add the same
/// amount to their scroll extent, so slivers remain alive while passing behind
/// the header instead of being culled at the page's internal top.
class AppHeaderScrollInsetScope extends InheritedWidget {
  const AppHeaderScrollInsetScope({
    super.key,
    required this.leadingInset,
    this.headerIsScrolled,
    this.headerScrollIsActive,
    this.headerTitleScrollOffset,
    required super.child,
  });

  final double leadingInset;
  final ValueListenable<bool>? headerIsScrolled;
  final ValueListenable<bool>? headerScrollIsActive;
  final ValueListenable<double>? headerTitleScrollOffset;

  static double maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderScrollInsetScope>()
          ?.leadingInset ??
      0.0;

  static ValueListenable<bool>? maybeHeaderScrolled(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderScrollInsetScope>()
          ?.headerIsScrolled;

  static ValueListenable<bool>? maybeUserScrollActive(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderScrollInsetScope>()
          ?.headerScrollIsActive;

  static ValueListenable<double>? maybeScrollOffset(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderScrollInsetScope>()
          ?.headerTitleScrollOffset;

  @override
  bool updateShouldNotify(AppHeaderScrollInsetScope oldWidget) =>
      leadingInset != oldWidget.leadingInset ||
      !identical(headerIsScrolled, oldWidget.headerIsScrolled) ||
      !identical(headerScrollIsActive, oldWidget.headerScrollIsActive) ||
      !identical(headerTitleScrollOffset, oldWidget.headerTitleScrollOffset);
}

/// Extends a page scroll viewport upward by the shell inset without moving its
/// parent's layout. The scrollable's own content must include a matching
/// leading inset so its initial on-screen position stays unchanged.
class AppHeaderScrollViewport extends StatelessWidget {
  const AppHeaderScrollViewport({
    super.key,
    required this.leadingInset,
    required this.child,
    this.topExtension = 0.0,
  });

  final double leadingInset;
  final Widget child;
  final double topExtension;

  @override
  Widget build(BuildContext context) {
    final safeLeadingInset =
        leadingInset.isFinite && leadingInset > 0.0 ? leadingInset : 0.0;
    final safeTopExtension =
        topExtension.isFinite && topExtension > 0.0 ? topExtension : 0.0;
    if (safeLeadingInset == 0.0 && safeTopExtension == 0.0) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        final totalTopExtension = safeLeadingInset + safeTopExtension;
        final viewportHeight = constraints.maxHeight + totalTopExtension;
        return OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: viewportHeight,
          maxHeight: viewportHeight,
          child: Transform.translate(
            offset: Offset(0.0, -totalTopExtension),
            child: SizedBox(height: viewportHeight, child: child),
          ),
        );
      },
    );
  }
}

/// A [SingleChildScrollView] whose viewport reaches behind the persistent
/// first-level header while retaining the normal scrollable lifecycle.
class AppHeaderSingleChildScrollView extends SingleChildScrollView {
  const AppHeaderSingleChildScrollView({
    super.key,
    required this.leadingInset,
    super.controller,
    super.physics,
    super.padding,
    super.child,
  });

  final double leadingInset;

  @override
  Widget build(BuildContext context) => AppHeaderScrollViewport(
    leadingInset: leadingInset,
    child: super.build(context),
  );
}

/// Keeps pane and page clips aligned with the physical viewport when their
/// children scroll beneath the fixed app header. The clip still constrains the
/// horizontal pane and bottom edge; only its top reaches through the shell
/// inset.
class AppHeaderScrollClip extends StatelessWidget {
  const AppHeaderScrollClip({
    super.key,
    required this.child,
    this.clipBehavior = Clip.hardEdge,
  });

  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final leadingInset = AppHeaderScrollInsetScope.maybeOf(context);
    return ClipRect(
      clipBehavior: clipBehavior,
      clipper: leadingInset > 0.0 && leadingInset.isFinite
          ? _AppHeaderScrollClipper(leadingInset)
          : null,
      child: child,
    );
  }
}

class _AppHeaderScrollClipper extends CustomClipper<Rect> {
  const _AppHeaderScrollClipper(this.leadingInset);

  final double leadingInset;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0.0, -leadingInset, size.width, size.height + leadingInset);

  @override
  bool shouldReclip(_AppHeaderScrollClipper oldClipper) =>
      leadingInset != oldClipper.leadingInset;
}

/// A scroll viewport whose physical extent reaches behind the pinned
/// first-level header, where [AppHeaderScrollEdge] applies its visual treatment.
/// The scroll extent grows by the same amount as the viewport so initial layout
/// and normal scroll metrics remain stable.
class AppHeaderScrollView extends StatelessWidget {
  const AppHeaderScrollView({
    Key? key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.scrollBehavior,
    this.shrinkWrap = false,
    this.center,
    this.anchor = 0.0,
    this.cacheExtent,
    this.paintOrder = SliverPaintOrder.firstIsTop,
    this.slivers = const <Widget>[],
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.clipBehavior = Clip.none,
    this.topExtension = 0.0,
  }) : _scrollViewKey = key,
       super(key: null);

  final Key? _scrollViewKey;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final ScrollBehavior? scrollBehavior;
  final bool shrinkWrap;
  final Key? center;
  final double anchor;
  final double? cacheExtent;
  final SliverPaintOrder paintOrder;
  final List<Widget> slivers;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final HitTestBehavior hitTestBehavior;
  final Clip clipBehavior;
  final double topExtension;

  @override
  Widget build(BuildContext context) {
    final leadingInset =
        scrollDirection == Axis.vertical && !reverse && !shrinkWrap
        ? AppHeaderScrollInsetScope.maybeOf(context)
        : 0.0;
    final scrollSlivers = <Widget>[
      if (leadingInset > 0.0)
        SliverToBoxAdapter(child: SizedBox(height: leadingInset)),
      ...slivers,
    ];
    final scrollView = CustomScrollView(
      key: _scrollViewKey,
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      scrollBehavior: scrollBehavior,
      shrinkWrap: shrinkWrap,
      center: center,
      anchor: anchor,
      cacheExtent: cacheExtent,
      paintOrder: paintOrder,
      slivers: scrollSlivers,
      semanticChildCount: semanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      hitTestBehavior: hitTestBehavior,
      clipBehavior: clipBehavior,
    );

    return AppHeaderScrollViewport(
      leadingInset: leadingInset,
      topExtension: topExtension,
      child: scrollView,
    );
  }
}

/// A page-level stack that lets scroll content paint up behind the app header.
///
/// The full-screen AppShell remains the physical viewport clip. Do not put a
/// hard clip around a page-sized stack below the header, or it will cut off
/// scrolling content at that internal boundary before the glass overlay.
class AppHeaderScrollStack extends Stack {
  const AppHeaderScrollStack({
    super.key,
    super.alignment = AlignmentDirectional.topStart,
    super.textDirection,
    super.fit = StackFit.loose,
    super.children,
  }) : super(clipBehavior: Clip.none);
}

/// Keeps a fixed large-title slot in the page's scroll extent while the title
/// itself is painted in the AppShell header above the scrolling content.
class AppHeaderScrollInset extends StatelessWidget {
  const AppHeaderScrollInset({
    super.key,
    this.collapseAnimation,
    this.enabled = true,
  });

  final Animation<double>? collapseAnimation;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final animation = collapseAnimation;
    if (!enabled) return const SizedBox.shrink();
    final headerIsScrolled = AppHeaderScrollInsetScope.maybeHeaderScrolled(
      context,
    );
    final headerScrollOffset = AppHeaderScrollInsetScope.maybeScrollOffset(
      context,
    );
    if (animation == null &&
        headerIsScrolled == null &&
        headerScrollOffset == null) {
      return const SizedBox(height: kAppHeaderTitleHeight);
    }

    final listenables = <Listenable>[
      if (animation != null) animation,
      if (headerIsScrolled != null) headerIsScrolled,
      if (headerScrollOffset != null) headerScrollOffset,
    ];
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        var expanded = headerScrollOffset != null
            ? 1.0 -
                  AppHeaderScrollBehavior.titleCollapseProgress(
                    headerScrollOffset.value,
                  )
            : headerIsScrolled?.value == true
            ? 0.0
            : 1.0;
        if (animation != null) {
          final searchExpanded =
              (1 - animation.value.clamp(0.0, 1.0)).toDouble();
          if (searchExpanded < expanded) expanded = searchExpanded;
        }
        return SizedBox(height: kAppHeaderTitleHeight * expanded);
      },
    );
  }
}

/// Keeps the compact title in the first-level toolbar. In portrait it begins
/// fading in only after its large-title counterpart is fully invisible.
class AppHeaderCompactTitle extends StatelessWidget {
  const AppHeaderCompactTitle({
    super.key,
    required this.progress,
    required this.isLandscape,
    required this.child,
  });

  final double progress;
  final bool isLandscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visibleProgress = isLandscape
        ? 1.0
        : (progress.isFinite ? progress.clamp(0.0, 1.0).toDouble() : 0.0);
    return IgnorePointer(
      // Keep the compact title's controls from intercepting taps while they
      // are still mostly transparent during the scroll handoff.
      ignoring: !isLandscape && visibleProgress < 0.5,
      child: Opacity(opacity: visibleProgress, child: child),
    );
  }
}

/// Fades the outgoing large title before [AppHeaderCompactTitle] begins to
/// appear and hands pointer interaction away once the large title is mostly
/// faded.
class AppHeaderLargeTitleHandoff extends StatelessWidget {
  const AppHeaderLargeTitleHandoff({
    super.key,
    required this.progress,
    required this.child,
  });

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visibleProgress = progress.isFinite
        ? progress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    return IgnorePointer(
      ignoring: visibleProgress >= 0.5,
      child: Opacity(opacity: 1.0 - visibleProgress, child: child),
    );
  }
}

/// The shared Liquid Glass treatment for the first, pinned header level only.
/// Its height is the physical top inset plus the toolbar; title and page
/// content are blurred only while they pass through that bounded region. A
/// persistent background gradient keeps the physical top edge covered. This
/// is a visual sibling overlay: its local filter clip bounds only the glass
/// effect, never the scrollable content.
class AppHeaderScrollEdge extends StatelessWidget {
  const AppHeaderScrollEdge({
    super.key,
    required this.progress,
    required this.surfaceColor,
    required this.headerHeight,
    required this.backgroundGradientHeight,
  });

  final double progress;
  final Color surfaceColor;
  final double headerHeight;
  final double backgroundGradientHeight;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    final effectProgress = Curves.easeOutCubic.transform(normalizedProgress);
    if (headerHeight <= 0) {
      return const SizedBox.shrink();
    }

    final gradientHeight =
        backgroundGradientHeight.clamp(0.0, headerHeight).toDouble();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      // Start at the physical top of the screen and extend 16pt past the
      // bottom of the complete first-level header.
      height: headerHeight + kAppHeaderScrollEdgeHeaderBottomExtension,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: normalizedProgress <= 0.01,
            child: IgnorePointer(
              child: LiquidGlassScrollEdge(
                edge: LiquidGlassEdge.top,
                color: surfaceColor.withValues(
                  // Keep the shared app-level edge translucent while applying
                  // blur as content passes beneath the pinned header.
                  // The edge remains a compositing treatment, never a
                  // visibility threshold.
                  alpha:
                      (_kAppHeaderScrollEdgeMaxTintOpacity *
                              effectProgress *
                              surfaceColor.a)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                ),
                // Hold most of the glass strength across the scroll interval,
                // then ease it away near the end instead of fading linearly.
                blur: effectProgress > 0
                    ? _kAppHeaderScrollEdgeMaxBlurSigma * effectProgress
                    : 0.001,
              ),
            ),
          ),
          if (gradientHeight > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: gradientHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        surfaceColor.withValues(alpha: 1.0),
                        surfaceColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
