import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import '../app_theme.dart';
import 'fixed_size_icon.dart';

// SF Symbols are variable-font glyphs, so their weight is rendered by the
// symbol font itself instead of by a blurred shadow.  Keeping this wrapper
// local to the action-panel system also leaves SearchWeightedIcon unchanged
// for the search-bar UI, where it is still used elsewhere.
class _ActionPanelSFIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final FontWeight weight;
  final double boxPadding;

  const _ActionPanelSFIcon(
    this.icon, {
    required this.size,
    required this.color,
    this.weight = FontWeight.w500,
    this.boxPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final boxSize = size + boxPadding * 2;
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(
        child: FixedSFIcon(
          icon,
          // Keep the layout box unchanged while making every action-panel
          // SF Symbol two pixels smaller.
          fontSize: size - 2,
          fontWeight: weight,
          color: color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ActionPanel — reusable frosted-glass context-menu options card
// ══════════════════════════════════════════════════════════════════════════════
//
// Usage:
//   Positioned(
//     child: ActionPanel(items: _items, isClosing: _isClosingNotifier),
//   )
//
// Duration policy (the rule applied to EVERY context menu in the app):
//   Fewer options → slower open/close so the gel animation stays visible.
//   More  options → faster open/close because the larger card is already rich.
//
//   openMs = closeMs = 600 − (count − 2) × 50   →  2: 600  3: 550  4+: 500
//   Close is the exact time-reverse of open (same duration, easeIn vs easeOut).
//
// Layout policy:
//   • Panel width is set by the caller via a Positioned/SizedBox.
//   • Each row is 52 px tall; separators add 0.5 px between rows.
//   • Glass appearance: BackdropFilter blur + semi-transparent white fill.
//     Rows cascade top→bottom on open, bottom→top on close (natural reverse).

// ── Picker-panel layout constants ────────────────────────────────────────────
// Used by every chevron_up_chevron_down picker row that opens a mini ActionPanel
// in the Add / Edit Category sheet and anywhere this same pattern is reused.

/// Width of the mini picker panel.
const double kPickerPanelWidth = 250.0;

/// When the panel appears ABOVE the row, its bottom edge is placed at
/// (buttonRect.bottom − kPickerPanelAboveAnchorInset).
/// 0.0 = flush with the row's bottom edge.
const double kPickerPanelAboveAnchorInset = 0.0;

/// When the panel appears BELOW the row, its top edge is placed at
/// (buttonRect.bottom − kPickerPanelBelowAnchorInset).
/// 0.0 = flush with the row's bottom edge, directly below the value+chevron.
const double kPickerPanelBelowAnchorInset = 0.0;

/// Height of the scroll-edge fade gradient shown when the panel is scrollable
/// and has hidden content above or below the visible area.
const double kPickerPanelFadeHeight = 50.0;

/// Opacity of the value + chevron in a picker row while its panel is open.
/// Matches the iOS "secondary → tertiary" visual shift (~half of secondary alpha).
const double kPickerRowOpenDimOpacity = 0.40;

// ── Public data class ─────────────────────────────────────────────────────────
class ActionItem {
  final String label;
  final IconData icon;
  final double iconSize;
  final FontWeight iconWeight;
  final bool isDestructive;
  final bool groupBreakAbove;
  final bool hasChevron;
  // When true and hasChevron is also true, renders chevron_down instead of
  // chevron_right — used by the Sort By row when its sub-panel is open.
  final bool chevronDown;
  final bool checkmark;
  // When true, checkmark + label use the dark primary colour instead of the
  // blue accent — suitable for sort/filter option lists.
  final bool primaryCheckmark;
  // When non-null, overrides kAccentColor for this row's checkmark glyph and
  // checked-label colour — used by modal-sheet mini picker panels to follow
  // the current category colour instead of the app-wide accent.
  final Color? checkmarkColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final Offset iconOffset;
  // When non-null, this builder is used instead of icon/iconSize.
  // Receives the resolved text colour so it can tint itself appropriately.
  final Widget Function(Color color)? iconBuilder;
  // When non-null, replaces the auto-generated chevron in the left column so
  // callers can supply an animated (e.g. rotating) chevron widget.
  final Widget? chevronOverride;
  // When true, the separator drawn ABOVE this row uses kSeparatorColor at full
  // opacity (same as Calendar month-view separators) instead of the default
  // light hairline.  Height stays at ActionItem.separatorH (0.5 px).
  final bool strongSeparatorAbove;
  // When true, this row skips the open-phase stagger animation and renders at
  // full opacity/scale from frame 0 — giving a "shared element stays in place"
  // feel.  During close, the row animates out normally with the panel.
  final bool instantOnOpen;
  // Controls the opacity of the row's visible content (label, icon, subtitle,
  // chevron) independently of the panel's rowOpacity and stagger animation.
  // Set to 0.0 to make only the content invisible while the row slot, height,
  // background, and hit-test area all remain — used for the Sort By shared-
  // element effect where the nested panel's copy takes over the visuals while
  // the original row holds its layout position so nothing shifts below it.
  final double contentOpacity;
  // When non-null, overrides the label (and icon) colour — used to gray out
  // rows that are disabled but should remain visible in the list.
  final Color? labelColor;

  const ActionItem({
    required this.label,
    required this.icon,
    this.iconSize = 20.0,
    this.iconWeight = FontWeight.w500,
    this.isDestructive = false,
    this.groupBreakAbove = false,
    this.hasChevron = false,
    this.chevronDown = false,
    this.checkmark = false,
    this.primaryCheckmark = false,
    this.subtitle,
    this.onTap,
    this.iconOffset = Offset.zero,
    this.iconBuilder,
    this.chevronOverride,
    this.strongSeparatorAbove = false,
    this.instantOnOpen = false,
    this.contentOpacity = 1.0,
    this.checkmarkColor,
    this.labelColor,
  });

  static const double rowHeight = 52.0;
  static const double rowHeightWithSubtitle = 62.0;
  static const double separatorH = 0.5;
  static const double groupBreakH = 8.0;

  /// Creates an [ActionItem] that toggles between two states.
  ///
  /// The row label and icon reflect the **current** [value] at construction
  /// time.  On tap, [onChanged] is called with `!value` and [onDismiss] fires
  /// after 80 ms — no `setState` is involved, so the row stays visually frozen
  /// during the panel's close animation.
  ///
  /// To add a future two-state toggle row to any action panel, call this
  /// factory instead of building the `ActionItem` and dismiss logic manually.
  ///
  ///   [value]                — current boolean state.
  ///   [labelWhenTrue]        — label shown while value is true.
  ///   [labelWhenFalse]       — label shown while value is false.
  ///   [iconWhenTrue]         — fallback icon while value is true.
  ///   [iconWhenFalse]        — fallback icon while value is false.
  ///   [iconBuilderWhenTrue]  — custom widget builder (overrides iconWhenTrue).
  ///   [iconBuilderWhenFalse] — custom widget builder (overrides iconWhenFalse).
  ///   [onChanged]            — receives the new (flipped) value.
  ///   [onDismiss]            — closes the panel (called after 80 ms delay).
  ///   [groupBreakAbove]      — whether to add a group break above this row.
  static ActionItem toggle({
    required bool value,
    required String labelWhenTrue,
    required String labelWhenFalse,
    required IconData iconWhenTrue,
    required IconData iconWhenFalse,
    Widget Function(Color)? iconBuilderWhenTrue,
    Widget Function(Color)? iconBuilderWhenFalse,
    required void Function(bool) onChanged,
    required VoidCallback onDismiss,
    bool groupBreakAbove = false,
  }) {
    return ActionItem(
      label: value ? labelWhenTrue : labelWhenFalse,
      icon: value ? iconWhenTrue : iconWhenFalse,
      iconBuilder: value ? iconBuilderWhenTrue : iconBuilderWhenFalse,
      groupBreakAbove: groupBreakAbove,
      onTap: () {
        onChanged(!value);
        Future.delayed(const Duration(milliseconds: 80), onDismiss);
      },
    );
  }

  /// Height for a flat list with no group breaks or subtitles.
  static double panelHeight(int count) =>
      count * rowHeight + (count - 1) * separatorH;

  /// Height accounting for groupBreakAbove and per-item subtitle height.
  static double panelHeightForItems(List<ActionItem> items) {
    if (items.isEmpty) return 0;
    double h = 0;
    for (int i = 0; i < items.length; i++) {
      if (i > 0) h += items[i].groupBreakAbove ? groupBreakH : separatorH;
      h += items[i].subtitle != null ? rowHeightWithSubtitle : rowHeight;
    }
    return h;
  }
}

// ── ActionPanel ───────────────────────────────────────────────────────────────
class ActionPanel extends StatefulWidget {
  final List<ActionItem> items;
  final ValueNotifier<bool> isClosing;
  // When true every row reserves a fixed-width left column for the chevron;
  // only rows with hasChevron:true render the › glyph there.  All label text
  // then starts at the same x-position regardless of whether a chevron shows.
  final bool chevronColumn;
  // 1.0 = rows at full opacity (normal). < 1.0 dims only row content (text +
  // icons), leaving the frosted-glass card background unaffected.
  final double rowOpacity;
  // Optional per-corner border radius — passed through to FrostedGlassCard so
  // callers can create asymmetric cards (e.g. flat-top for connected panels).
  final BorderRadius? borderRadius;
  // When non-null, overrides the auto-computed open duration so callers can
  // speed up the bloom for sub-panels that need to feel more responsive.
  final int? openDurationOverrideMs;
  // When non-null the content is clipped to this height and becomes scrollable.
  // Scroll-edge fade gradients (kPickerPanelFadeColor) indicate hidden content.
  final double? maxHeight;
  // Label font size for each row.  Defaults to 16 (standard action panels).
  // Pass 15 for mini panels inside modal sheets.
  final double labelFontSize;
  // When true the scroll view uses BouncingScrollPhysics (rubberband).
  // False (default) → ClampingScrollPhysics, used for all outer tab panels.
  // Set true for mini panels inside modal sheets.
  final bool bouncingScroll;

  const ActionPanel({
    super.key,
    required this.items,
    required this.isClosing,
    this.chevronColumn = false,
    this.rowOpacity = 1.0,
    this.borderRadius,
    this.openDurationOverrideMs,
    this.maxHeight,
    this.labelFontSize = 16,
    this.bouncingScroll = false,
  });

  @override
  State<ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends State<ActionPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _isClosingNow = false;

  // Scroll state — only active when widget.maxHeight != null.
  final _scrollCtrl = ScrollController();
  bool _showTopFade = false;
  bool _showBottomFade =
      true; // assume overflow until first scroll notification

  // Scroll pill indicator — appears on scroll, auto-hides after 1.5 s.
  Timer? _pillHideTimer;
  bool _pillVisible = false;

  // Open: 500–700 ms. Fewer items → slower (gel animation more perceptible).
  static Duration _openDuration(int count) =>
      Duration(milliseconds: (600 - (count - 2) * 50).clamp(500, 700));

  // Close: 65 % of open duration — reverse of open but slightly snappier.
  static Duration _closeDuration(int count) => Duration(
    milliseconds: (((600 - (count - 2) * 50).clamp(500, 700)) * 0.65).round(),
  );

  // The pill is deliberately gone in the first ~18% of the panel close.
  // Keep this proportional to the actual close duration so mini panels with
  // different row counts all get the same early-dismiss feel.
  Duration get _pillFadeDuration => Duration(
    milliseconds: (_closeDuration(widget.items.length).inMilliseconds * 0.18)
        .round()
        .clamp(1, 100),
  );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    widget.isClosing.addListener(_onClosingChanged);
    _ctrl.animateTo(
      1.0,
      duration: widget.openDurationOverrideMs != null
          ? Duration(milliseconds: widget.openDurationOverrideMs!)
          : _openDuration(widget.items.length),
      curve: Curves.easeOut,
    );
    // Scrollable mode: after first layout, check if content actually overflows
    // so the bottom fade is only shown when there is something below to reveal.
    if (widget.maxHeight != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollCtrl.hasClients) {
          final pos = _scrollCtrl.position;
          if (_showBottomFade != (pos.maxScrollExtent > 1.0)) {
            setState(() => _showBottomFade = pos.maxScrollExtent > 1.0);
          }
        }
      });
    }
  }

  void _onClosingChanged() {
    if (widget.isClosing.value && mounted) {
      // Mirror of open: easeIn instead of easeOut, slightly faster.
      // Row stagger automatically reverses (row N disappears before row 0)
      // because _rowT(i) decreases for higher i first as ctrl → 0.
      _isClosingNow = true;
      // Fade the scroll pill out immediately — faster than the panel close.
      if (_pillVisible) setState(() => _pillVisible = false);
      _pillHideTimer?.cancel();
      _ctrl.animateTo(
        0.0,
        duration: _closeDuration(widget.items.length),
        curve: Curves.easeIn,
      );
    }
  }

  // Called by NotificationListener inside the scrollable content.
  // Updates top/bottom fade visibility and shows the scroll pill.
  bool _onScrollNotification(ScrollNotification n) {
    // A closing panel must never resurrect or animate its indicator from a
    // final overscroll notification.  The dismissal owns the pill lifecycle.
    if (_isClosingNow || widget.isClosing.value) return false;
    final pos = n.metrics;
    final newTop = pos.pixels > 1.0;
    final newBot = pos.pixels < pos.maxScrollExtent - 1.0;
    if (newTop != _showTopFade || newBot != _showBottomFade) {
      setState(() {
        _showTopFade = newTop;
        _showBottomFade = newBot;
      });
    }
    // Show pill on any scroll interaction; schedule auto-hide after 1.5 s.
    if (!_pillVisible) setState(() => _pillVisible = true);
    _pillHideTimer?.cancel();
    _pillHideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _pillVisible = false);
    });
    return false;
  }

  @override
  void dispose() {
    widget.isClosing.removeListener(_onClosingChanged);
    _pillHideTimer?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Derived progress ──────────────────────────────────────────────────────

  double get _panelT => _ctrl.value;

  // Glass-specific progress: identical to _panelT on open, but leads the
  // close by 50 ms so the blur/fill dissolve finishes before the card shrinks away.
  double get _glassT {
    if (!_isClosingNow) return _ctrl.value;
    final closeDurMs = _closeDuration(widget.items.length).inMilliseconds;
    final lead = 50.0 / closeDurMs; // fraction that equals 50 ms
    return ((_ctrl.value - lead) / (1.0 - lead)).clamp(0.0, 1.0);
  }

  // The outline and hairline rules are deliberately ahead of the glass and
  // row content on close.  Keeping this separate from panelScale is important:
  // the gel still shrinks with exactly the same motion while the chrome
  // dissolves first.
  double get _outlineT {
    if (!_isClosingNow) return _ctrl.value;
    final closeDurMs = _closeDuration(widget.items.length).inMilliseconds;
    final lead = 100.0 / closeDurMs;
    return ((_ctrl.value - lead) / (1.0 - lead)).clamp(0.0, 1.0);
  }

  // Row i stagger: starts at ctrl=0.08, staggered evenly across the remaining
  // [0.08, 0.60] range so the last row always finishes at exactly ctrl=1.0,
  // regardless of item count.  Each row's own animation runs over 0.40 of [0,1].
  // On close (ctrl 1→0): last row fades first, row 0 fades last — exact reverse.
  double _rowT(int i) {
    final n = widget.items.length;
    final step = n > 1 ? 0.52 / (n - 1) : 0.52;
    return ((_ctrl.value - 0.08 - i * step) / 0.40).clamp(0.0, 1.0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pt = _panelT;
        final gt = _glassT; // leads close by 50 ms; identical to pt on open
        final outlineT = _outlineT; // leads close by 100 ms
        // easeOutBack: peaks at ~1.07 before settling —
        // starting from 0.60 makes the gel bloom visually pronounced.
        // On close (pt 1→0) this naturally behaves like easeInBack.
        final panelScale = 0.60 + 0.40 * Curves.easeOutBack.transform(pt);

        // Frosted glass — strictly confined to the squircle card bounds.
        //
        // Why this structure:
        //   • Container.clipBehavior does NOT create a compositing boundary for
        //     BackdropFilter — the blur leaks outside the card shape.
        //   • ClipPath as the DIRECT parent of BackdropFilter establishes the
        //     correct compositing clip so the blur is truly bounded.
        //   • DecoratedBox sits outside ClipPath so its shadow renders beyond
        //     the card edge as intended (shadows are designed to overflow).
        //   • TileMode.decal prevents the Gaussian kernel from clamping at the
        //     clip edge (which would create a bright halo "residue").
        //   • Do NOT wrap in Opacity — it forces an offscreen layer that breaks
        //     BackdropFilter. Blur sigma and fill alpha are animated via gt/pt.
        //   • gt (glass progress) leads the close by 50 ms so the blur and fill
        //     dissolve fully before the card shell finishes shrinking.
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < widget.items.length; i++) ...[
              if (i > 0) _buildSeparator(i),
              _buildRow(i),
            ],
          ],
        );

        // Outer tab panels: ClampingScrollPhysics (no rubberband).
        // Mini panels inside modal sheets: BouncingScrollPhysics (rubberband).
        final scrollable = SingleChildScrollView(
          controller: _scrollCtrl,
          physics: widget.bouncingScroll
              ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const ClampingScrollPhysics(),
          child: column,
        );

        // When maxHeight is set, clip the content and add a ShaderMask that
        // fades the rendered pixels at the scroll edges — this works correctly
        // on frosted-glass because it masks the actual child output rather than
        // painting an opaque colour on top.
        Widget panelContent;
        if (widget.maxHeight != null) {
          // Shared shader callback — fades rendered pixels at scroll edges.
          // Works correctly on frosted-glass (masks child output, not a paint-over).
          Shader shaderCb(Rect bounds) {
            const white = Color(0xFFFFFFFF);
            const transparent = Color(0x00FFFFFF);
            if (bounds.height == 0) {
              return const LinearGradient(
                colors: [white, white],
              ).createShader(bounds);
            }
            final topFrac = _showTopFade
                ? (kPickerPanelFadeHeight / bounds.height).clamp(0.0, 0.45)
                : 0.0;
            final botFrac = _showBottomFade
                ? (kPickerPanelFadeHeight / bounds.height).clamp(0.0, 0.45)
                : 0.0;
            // Multi-stop cubic-ish gradient — strong edge fade, quick transition
            // to solid so the pill text lands readable.
            final tf0 = topFrac * 0.30;
            final tf1 = topFrac * 0.65;
            final bf0 = 1.0 - botFrac * 0.65;
            final bf1 = 1.0 - botFrac * 0.30;
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _showTopFade ? transparent : white,
                _showTopFade ? const Color(0x06FFFFFF) : white,
                _showTopFade ? const Color(0x38FFFFFF) : white,
                white,
                white,
                _showBottomFade ? const Color(0x38FFFFFF) : white,
                _showBottomFade ? const Color(0x06FFFFFF) : white,
                _showBottomFade ? transparent : white,
              ],
              stops: [0.0, tf0, tf1, topFrac, 1.0 - botFrac, bf0, bf1, 1.0],
            ).createShader(bounds);
          }

          panelContent = NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight!),
              child: Stack(
                children: [
                  // ── Faded scroll content ────────────────────────────────
                  ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: shaderCb,
                    child: scrollable,
                  ),
                  // ── iOS-style scroll indicator pill ─────────────────────
                  // • Visible only while scrolling; auto-hides after 1.5 s.
                  // • On hide: slides right off the panel edge + fades out.
                  //   On show: instant position snap + fade-in only.
                  // • Inset 10 px from top & bottom so it never touches the
                  //   squircle card corners.
                  // • During rubber-band overscroll the pill tracks the edge
                  //   (pillTop clamped rather than ratio clamped).
                  Positioned(
                    right: 3,
                    top: 10,
                    bottom: 10,
                    width: 2.5,
                    child: AnimatedSlide(
                      // Mirrors on both show and hide: slides in from the right
                      // edge on appear, slides back out to the right on dismiss.
                      offset: _pillVisible ? Offset.zero : const Offset(3.0, 0),
                      duration: _isClosingNow
                          ? Duration.zero
                          : _pillFadeDuration,
                      curve: _pillVisible ? Curves.easeOut : Curves.easeIn,
                      child: AnimatedOpacity(
                        opacity: _pillVisible ? 1.0 : 0.0,
                        duration: _isClosingNow
                            ? Duration.zero
                            : _pillFadeDuration,
                        curve: _pillVisible ? Curves.easeOut : Curves.easeIn,
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            final trackH = constraints.maxHeight;
                            return AnimatedBuilder(
                              animation: _scrollCtrl,
                              builder: (ctx, _) {
                                if (!_scrollCtrl.hasClients || trackH <= 0) {
                                  return const SizedBox.shrink();
                                }
                                final pos = _scrollCtrl.position;
                                if (pos.maxScrollExtent < 1.0) {
                                  return const SizedBox.shrink();
                                }
                                // Add overscroll distance to total so the pill
                                // shrinks proportionally during rubber-band —
                                // more virtual content = smaller thumb.
                                final overscroll = pos.pixels < 0
                                    ? -pos.pixels
                                    : pos.pixels > pos.maxScrollExtent
                                    ? pos.pixels - pos.maxScrollExtent
                                    : 0.0;
                                final total =
                                    pos.maxScrollExtent +
                                    pos.viewportDimension +
                                    overscroll;
                                final fraction = (pos.viewportDimension / total)
                                    .clamp(0.0, 1.0);
                                final pillH = (fraction * trackH).clamp(
                                  20.0,
                                  trackH,
                                );
                                // Unclamped ratio + clamped pillTop: pill tracks
                                // the edge during overscroll rather than freezing.
                                final ratio = pos.maxScrollExtent > 0
                                    ? pos.pixels / pos.maxScrollExtent
                                    : 0.0;
                                final pillTop = (ratio * (trackH - pillH))
                                    .clamp(
                                      0.0,
                                      (trackH - pillH).clamp(
                                        0.0,
                                        double.infinity,
                                      ),
                                    );
                                return Stack(
                                  children: [
                                    Positioned(
                                      top: pillTop,
                                      left: 0,
                                      right: 0,
                                      height: pillH,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: CupertinoDynamicColor.resolve(
                                            kTertiaryLabel,
                                            ctx,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            1.25,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          panelContent = scrollable;
        }

        final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
        final borderColor = resolveThemeColor(kTertiaryLabel, context);
        final resolvedBorder = borderColor.withValues(
          alpha: borderColor.a * outlineT,
        );
        // Standard overlays sit over the app rather than inside a modal sheet.
        // Give their dark glass another 10 percentage points of fill opacity.
        // Picker mini-panels opt into bouncingScroll and retain their existing
        // modal-sheet glass value.
        final fillOpacity = isDark && !widget.bouncingScroll ? 0.75 : 0.65;

        return Transform.scale(
          scale: panelScale,
          alignment: Alignment.topCenter,
          child: FrostedGlassCard(
            progress: gt,
            fillOpacity: fillOpacity,
            shadowOpacity: 0.22,
            borderRadius: widget.borderRadius,
            stadium: widget.items.length == 1,
            border: isDark
                ? BorderSide(color: resolvedBorder, width: 0.5)
                : BorderSide.none,
            child: panelContent,
          ),
        );
      },
    );
  }

  Widget _buildRow(int i) {
    // instantOnOpen: row renders at full progress from frame 0 during the open
    // phase so it appears to "stay in place" (shared-element feel).
    // During close (_isClosingNow) it fades out normally with the panel.
    final t = (widget.items[i].instantOnOpen && !_isClosingNow)
        ? 1.0
        : _rowT(i);
    // Starting from 0.76 gives each row a more pronounced easeOutBack pop.
    final scale = 0.76 + 0.24 * Curves.easeOutBack.transform(t);
    // Multiply t (open/close anim) by rowOpacity (content dim) so only row
    // content dims — the FrostedGlassCard background is outside this Opacity.
    return Opacity(
      opacity: (t * widget.rowOpacity).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: _ActionRow(
          item: widget.items[i],
          chevronColumn: widget.chevronColumn,
          labelFontSize: widget.labelFontSize,
        ),
      ),
    );
  }

  Widget _buildSeparator(int i) {
    final item = widget.items[i];
    final isGroupBreak = item.groupBreakAbove;
    final isStrong = item.strongSeparatorAbove;
    final separatorColor = resolveThemeColor(
      isGroupBreak
          ? kActionPanelGroupBreak
          : isStrong
          ? kSeparatorColor
          : kActionPanelSeparator,
      context,
    );
    return Opacity(
      // Separators are chrome, so they leave before the row content rather
      // than lingering as floating rules after the panel starts dissolving.
      opacity: math.min(_rowT(i), _outlineT) * widget.rowOpacity,
      child: Container(
        height: isGroupBreak ? ActionItem.groupBreakH : ActionItem.separatorH,
        color: separatorColor,
      ),
    );
  }
}

// ── Single action row ─────────────────────────────────────────────────────────
class _ActionRow extends StatefulWidget {
  final ActionItem item;
  final bool chevronColumn;
  final double labelFontSize;
  const _ActionRow({
    required this.item,
    required this.chevronColumn,
    this.labelFontSize = 16,
  });

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  // Fixed width reserved for the chevron icon in chevronColumn mode.
  // Matches the action-item icon size (20 px) so all labels share one indent.
  static const double _chevW = 18.0;
  static const double _chevGap = 7.0;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dest = item.isDestructive;
    // Checked items: primary colour when primaryCheckmark, accent otherwise.
    final checkColor = item.primaryCheckmark
        ? CupertinoDynamicColor.resolve(kPrimaryLabel, context)
        : item.checkmarkColor ?? resolveAccentColor(context);
    final textColor = item.labelColor != null
        ? CupertinoDynamicColor.resolve(item.labelColor!, context)
        : dest
        ? CupertinoColors.destructiveRed
        : item.checkmark
        ? checkColor
        : CupertinoDynamicColor.resolve(kPrimaryLabel, context);

    final labelStyle = TextStyle(
      inherit: false,
      color: textColor,
      fontSize: widget.labelFontSize,
      fontFamily: kSFProText,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      letterSpacing: kTracking16,
    );

    // Left column priority: chevronOverride > checkmark > chevron > empty.
    final leftWidget = SizedBox(
      width: _chevW,
      child:
          item.chevronOverride ??
          (item.checkmark
              ? _ActionPanelSFIcon(
                  SFIcons.sf_checkmark,
                  size: _chevW,
                  color: checkColor,
                  weight: FontWeight.w500,
                  boxPadding: 3,
                )
              : item.hasChevron
              ? _ActionPanelSFIcon(
                  item.chevronDown
                      ? SFIcons.sf_chevron_down
                      : SFIcons.sf_chevron_right,
                  size: _chevW,
                  color: textColor,
                  weight: FontWeight.w500,
                  boxPadding: 0,
                )
              : null),
    );

    final hasSubtitle = item.subtitle != null;
    final rowH = hasSubtitle
        ? ActionItem.rowHeightWithSubtitle
        : ActionItem.rowHeight;

    // Label + optional subtitle block.
    final Widget labelBlock = hasSubtitle
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: labelStyle),
              SizedBox(height: 2),
              Text(
                item.subtitle!,
                style: TextStyle(
                  inherit: false,
                  color: CupertinoDynamicColor.resolve(
                    kSecondaryLabel,
                    context,
                  ),
                  fontSize: 13,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.08,
                ),
              ),
            ],
          )
        : Text(item.label, style: labelStyle);

    // iconOffset is applied to both iconBuilder and default icon paths so
    // callers can nudge any icon (e.g. view-mode icons 8 px left) uniformly.
    final iconWidget = Transform.translate(
      offset: item.iconOffset,
      child: item.iconBuilder != null
          ? item.iconBuilder!(textColor)
          : _ActionPanelSFIcon(
              item.icon,
              size: item.iconSize,
              color: textColor,
              weight: item.iconWeight,
              boxPadding: 4,
            ),
    );

    // In chevronColumn mode every row has a fixed-width glyph region on the
    // left so all label text starts at the same x-position.
    // In standard mode the chevron (if any) sits inline before the label.
    final List<Widget> rowChildren = widget.chevronColumn
        ? [
            leftWidget,
            const SizedBox(width: _chevGap),
            Expanded(child: labelBlock),
            iconWidget,
          ]
        : [
            if (item.hasChevron || item.checkmark) ...[
              leftWidget,
              const SizedBox(width: _chevGap),
            ],
            Expanded(child: labelBlock),
            iconWidget,
          ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        item.onTap?.call();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.60 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: SizedBox(
            height: rowH,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Opacity(
                opacity: item.contentOpacity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: rowChildren,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ExpandableActionMenu — full-screen overlay with a two-panel "drill-down" row.
//
// When the designated trigger row is tapped:
//   1. The main panel scales to 0.96 and dims its row content.
//   2. A sub-panel blooms below the trigger row with additional options.
//   3. A floating shared-element renders the trigger row at 100 % scale above
//      both panels so neither transform distorts it.
//
// To add a future expandable sub-panel to any action menu, construct this
// widget instead of reimplementing the scale/dim/bloom/shared-element pattern.
//
// Usage:
//   Pass [itemsBuilder] which receives (isExpanded, isScalingBack, onTriggerTap)
//   and returns the main-panel item list.  The trigger row must:
//     • use  contentOpacity: isExpanded || isScalingBack ? 0.0 : 1.0
//     • pass onTriggerTap as its onTap
//   Sub-panel item onTap callbacks are the caller's responsibility (they should
//   call onDismiss — with an 80 ms delay — after applying any state change).
// ══════════════════════════════════════════════════════════════════════════════
class ExpandableActionMenu extends StatefulWidget {
  // ── Outer positioning ────────────────────────────────────────────────────────
  final double panelTop;
  final double panelLeft;
  // ── Lifecycle ────────────────────────────────────────────────────────────────
  final ValueNotifier<bool>
  isClosing; // outer close signal (barrier tap / parent)
  final VoidCallback onDismiss; // barrier-tap dismiss handler
  final bool chevronColumn;
  // ── Main panel ───────────────────────────────────────────────────────────────
  /// Called on every build; receives expansion state and the trigger-tap handler
  /// so the caller can set contentOpacity and wire onTap on the trigger row.
  final List<ActionItem> Function(
    bool isExpanded,
    bool isScalingBack,
    VoidCallback onTriggerTap,
  )
  itemsBuilder;
  // ── Trigger row config ───────────────────────────────────────────────────────
  final double triggerRowTop; // px offset from panel top to the trigger row
  final double
  triggerRowHeight; // ActionItem.rowHeight or rowHeightWithSubtitle
  final String triggerLabel;
  final String triggerSubtitle; // current selection shown below triggerLabel
  final IconData triggerIcon;
  // ── Sub-panel ────────────────────────────────────────────────────────────────
  final List<ActionItem> subItems;

  /// Standard panel width used throughout the app.
  static const double panelW = 240.0;

  const ExpandableActionMenu({
    super.key,
    required this.panelTop,
    required this.panelLeft,
    required this.isClosing,
    required this.onDismiss,
    required this.itemsBuilder,
    required this.triggerRowTop,
    required this.triggerRowHeight,
    required this.triggerLabel,
    required this.triggerSubtitle,
    required this.triggerIcon,
    required this.subItems,
    this.chevronColumn = false,
  });

  @override
  State<ExpandableActionMenu> createState() => _ExpandableActionMenuState();
}

class _ExpandableActionMenuState extends State<ExpandableActionMenu>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _scalingBack = false;

  // Two independent closing notifiers so each panel can animate out on its own.
  final _origClosing = ValueNotifier<bool>(false);
  final _expandedClosing = ValueNotifier<bool>(false);

  // Drives the trigger-row chevron: 0 = pointing right (›), 1 = pointing down (∨).
  late final AnimationController _chevronCtrl;

  @override
  void initState() {
    super.initState();
    widget.isClosing.addListener(_onOuterClosing);
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    widget.isClosing.removeListener(_onOuterClosing);
    _origClosing.dispose();
    _expandedClosing.dispose();
    _chevronCtrl.dispose();
    super.dispose();
  }

  // Route an outer close signal (barrier tap, parent dismissal) to whichever
  // panels are currently on screen.
  void _onOuterClosing() {
    if (!widget.isClosing.value) return;
    if (_expanded) _chevronCtrl.reverse();
    if (!_origClosing.value) _origClosing.value = true;
    if (!_expandedClosing.value) _expandedClosing.value = true;
  }

  // Toggle the sub-panel open/closed.  Second tap starts the close animation
  // and, after a short delay, removes the sub-panel from the tree.
  void _onTriggerTap() {
    if (_expanded) {
      _expandedClosing.value = true;
      _chevronCtrl.reverse();
      // _scalingBack keeps the floating shared element alive while the main panel
      // scales back from 0.96 → 1.0 after the sub-panel closes, so the trigger
      // row's built-in content does not pop in before the scale is complete.
      setState(() => _scalingBack = true);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _expanded = false;
            _expandedClosing.value = false;
          });
          Future.delayed(const Duration(milliseconds: 160), () {
            if (mounted) setState(() => _scalingBack = false);
          });
        }
      });
      return;
    }
    setState(() {
      _expanded = true;
      _expandedClosing.value = false;
    });
    _chevronCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.itemsBuilder(_expanded, _scalingBack, _onTriggerTap);
    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        // Barrier — dismiss on outside tap.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: const SizedBox.expand(),
        ),

        // Main panel — scales to 0.96 and dims row content while sub-panel open.
        Positioned(
          left: widget.panelLeft,
          top: widget.panelTop,
          width: ExpandableActionMenu.panelW,
          child: AnimatedScale(
            scale: _expanded ? 0.96 : 1.0,
            alignment: Alignment.topLeft,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: _expanded,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _expanded ? 0.52 : 1.0),
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                builder: (ctx, rowOp, _) => ActionPanel(
                  items: items,
                  isClosing: _origClosing,
                  chevronColumn: widget.chevronColumn,
                  rowOpacity: rowOp,
                ),
              ),
            ),
          ),
        ),

        // Sub-panel — blooms below the trigger row.
        // The trigger-row slot (index 0) uses contentOpacity:0 so the floating
        // shared element is the sole visual for that row while both are live.
        if (_expanded)
          Positioned(
            left: widget.panelLeft,
            top: widget.panelTop + widget.triggerRowTop,
            width: ExpandableActionMenu.panelW,
            child: ActionPanel(
              items: [
                ActionItem(
                  label: widget.triggerLabel,
                  icon: widget.triggerIcon,
                  hasChevron: true,
                  subtitle: widget.triggerSubtitle,
                  instantOnOpen: true,
                  contentOpacity: 0.0,
                ),
                ...widget.subItems,
              ],
              isClosing: _expandedClosing,
              chevronColumn: widget.chevronColumn,
              openDurationOverrideMs: 280,
            ),
          ),

        // Floating shared element — rendered LAST so it paints above both panels
        // and stays at 100 % scale while the sub-panel blooms.
        // Fades out via AnimatedOpacity when the outer overlay closes so it
        // dissolves together with the panels' bloom-back animation.
        if (_expanded || _scalingBack)
          Positioned(
            left: widget.panelLeft + 16,
            top: widget.panelTop + widget.triggerRowTop,
            width: ExpandableActionMenu.panelW - 32,
            height: widget.triggerRowHeight,
            child: ValueListenableBuilder<bool>(
              valueListenable: _origClosing,
              builder: (ctx, origClosing, child) => AnimatedOpacity(
                opacity: origClosing ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeIn,
                child: child,
              ),
              child: _ExpandableRowSharedContent(
                label: widget.triggerLabel,
                subtitle: widget.triggerSubtitle,
                icon: widget.triggerIcon,
                chevronCtrl: _chevronCtrl,
                onTap: _onTriggerTap,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Floating shared-element for ExpandableActionMenu ─────────────────────────
// Rendered above both panels so it stays at 100 % scale while the sub-panel
// blooms.  Generalised from the original _SortBySharedContent: accepts any
// label / subtitle / icon so the same widget drives any expandable row.
class _ExpandableRowSharedContent extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final AnimationController chevronCtrl;
  final VoidCallback onTap;
  const _ExpandableRowSharedContent({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.chevronCtrl,
    required this.onTap,
  });
  @override
  State<_ExpandableRowSharedContent> createState() =>
      _ExpandableRowSharedContentState();
}

class _ExpandableRowSharedContentState
    extends State<_ExpandableRowSharedContent> {
  bool _pressed = false;

  static const double _chevW = 18.0;
  static const double _chevGap = 7.0;

  @override
  Widget build(BuildContext context) {
    final textColor = CupertinoDynamicColor.resolve(kPrimaryLabel, context);
    final labelStyle = TextStyle(
      inherit: false,
      color: textColor,
      fontSize: 16,
      fontFamily: kSFProText,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      letterSpacing: kTracking16,
    );
    final subtitleStyle = TextStyle(
      inherit: false,
      color: CupertinoDynamicColor.resolve(kSecondaryLabel, context),
      fontSize: 13,
      fontFamily: kSFProText,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      letterSpacing: -0.08,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.60 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated chevron: › rotates to ∨ as the sub-panel opens.
              SizedBox(
                width: _chevW,
                child: AnimatedBuilder(
                  animation: widget.chevronCtrl,
                  builder: (ctx, _) => Transform.rotate(
                    angle: widget.chevronCtrl.value * (math.pi / 2),
                    child: _ActionPanelSFIcon(
                      SFIcons.sf_chevron_right,
                      size: _chevW,
                      color: textColor,
                      weight: FontWeight.w500,
                      boxPadding: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _chevGap),
              // Label + subtitle
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: labelStyle),
                    const SizedBox(height: 2),
                    Text(widget.subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              // Right icon
              _ActionPanelSFIcon(
                widget.icon,
                size: 20,
                color: textColor,
                weight: FontWeight.w500,
                boxPadding: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ActionMenuOverlay — full-screen overlay that positions an ActionPanel near
// a source button.  The barrier dismisses the panel on outside tap.
// Shared by NotesTab (attach menu) and AppShell (DCV ellipsis menu).
// ══════════════════════════════════════════════════════════════════════════════
class ActionMenuOverlay extends StatelessWidget {
  final Rect buttonRect;
  final ValueNotifier<bool> isClosing;
  final VoidCallback onDismiss;
  final List<ActionItem> actions;
  final bool chevronColumn;
  // Override the default 240 px panel width.  Pass [kPickerPanelWidth] for
  // the standard picker-row mini panel, or any other value as needed.
  final double panelWidth;
  // When true the panel's RIGHT edge is anchored to buttonRect.right instead
  // of its left edge to buttonRect.left.  Use for picker-row mini panels whose
  // chevrons sit at the right of the row.
  final bool anchorToRight;
  // Label font size forwarded to ActionPanel.  Default 16 (standard panels).
  // Pass 15 for modal-sheet mini panels.
  final double labelFontSize;
  // Forwarded to ActionPanel — true restores BouncingScrollPhysics for
  // mini panels inside modal sheets.
  final bool bouncingScroll;

  const ActionMenuOverlay({
    super.key,
    required this.buttonRect,
    required this.isClosing,
    required this.onDismiss,
    required this.actions,
    this.chevronColumn = false,
    this.panelWidth = 240.0,
    this.anchorToRight = false,
    this.labelFontSize = 16,
    this.bouncingScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final safeTop = mq.padding.top + 16.0;
    final safeBtm = mq.padding.bottom + 16.0;

    final panelW = panelWidth;
    final panelH = ActionItem.panelHeightForItems(actions);

    // Decide which side has more usable room.
    final goAbove =
        (buttonRect.top - safeTop) > (screenH - safeBtm - buttonRect.bottom);

    double panelTop;
    double? effectiveMaxHeight;

    if (goAbove) {
      // Anchor: bottom of panel flush with the row's top edge — no gap.
      panelTop = buttonRect.top - panelH;
      if (panelTop < safeTop) {
        // Insufficient room above — clamp to ceiling, make panel scrollable.
        panelTop = safeTop;
        final v1 = buttonRect.top - safeTop;
        effectiveMaxHeight = v1 > 0 ? v1 : null;
      }
    } else {
      // Anchor: top of panel flush with the row's bottom edge — no gap.
      panelTop = buttonRect.bottom;
      final maxBottom = screenH - safeBtm;
      if (panelTop + panelH > maxBottom) {
        // Insufficient room below — make panel scrollable up to the floor.
        final v2 = maxBottom - panelTop;
        effectiveMaxHeight = v2 > 0 ? v2 : null;
      }
    }

    // anchorToRight: right edge of panel aligns to buttonRect.right (picker rows).
    // Default: left edge of panel aligns to buttonRect.left.
    var panelLeft = anchorToRight ? buttonRect.right - panelW : buttonRect.left;
    panelLeft = panelLeft.clamp(16.0, screenW - panelW - 16.0);

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: panelLeft,
          top: panelTop,
          width: panelW,
          child: ActionPanel(
            items: actions,
            isClosing: isClosing,
            chevronColumn: chevronColumn,
            maxHeight: effectiveMaxHeight,
            labelFontSize: labelFontSize,
            bouncingScroll: bouncingScroll,
          ),
        ),
      ],
    );
  }
}
