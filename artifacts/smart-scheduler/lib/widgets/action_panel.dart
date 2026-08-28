import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
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
  final bool scaleWithText;

  const _ActionPanelSFIcon(
    this.icon, {
    required this.size,
    required this.color,
    this.weight = FontWeight.w500,
    this.boxPadding = 0,
    this.scaleWithText = false,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = scaleWithText
        ? MediaQuery.textScalerOf(context).scale(size - 2)
        : size - 2;
    final boxSize = math
        .max(
          size + boxPadding * 2,
          scaleWithText ? fontSize + boxPadding * 2 : 0,
        )
        .toDouble();
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(
        child: FixedSFIcon(
          icon,
          // Keep the authored two-pixel inset at the base size. Checkmarks
          // opt into OS scaling while the row's outer 16 px padding remains
          // outside this widget.
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
        ),
      ),
    );
  }
}

const double _actionPanelCheckmarkBaseSize = 18.0;
const double _actionPanelCheckmarkOptionGap = 16.0;
const double _actionPanelLeadingGlyphBoxPadding = 3.0;
const double _actionPanelHorizontalInset = 16.0;
const double _actionPanelLabelTrailingIconGap = 16.0;
const double _actionPanelCustomIconBaseSize = 24.0;

double _actionPanelLeadingColumnWidth(BuildContext context) {
  // The leading slot is sized to the complete glyph footprint, including the
  // optical inset used by _ActionPanelSFIcon. This is intentionally derived
  // from the text scaler: the slot grows with the glyph, while the row's
  // outer 16 px padding and following 16 px label gap do not.
  final scaledCheckmarkSize = MediaQuery.textScalerOf(
    context,
  ).scale(_actionPanelCheckmarkBaseSize - 2);
  return math.max(_actionPanelCheckmarkBaseSize, scaledCheckmarkSize) +
      _actionPanelLeadingGlyphBoxPadding * 2;
}

double _actionPanelRightIconWidth(BuildContext context, ActionItem item) {
  final scaler = MediaQuery.textScalerOf(context);
  if (item.iconBuilder != null) {
    // Custom action-panel icons are authored in a 24 px box. Keep that box
    // wide enough for the scaled version while preserving the base footprint
    // at the smaller accessibility stops.
    return math.max(
      _actionPanelCustomIconBaseSize,
      scaler.scale(_actionPanelCustomIconBaseSize),
    );
  }

  // _ActionPanelSFIcon uses (iconSize - 2) for the glyph and adds 4 px of
  // internal padding on both sides.
  return math.max(item.iconSize, scaler.scale(item.iconSize - 2.0)) + 8.0;
}

// The "New Section" action icon: a solid heading bar with a plus badge above
// two bulleted list rows.  It is drawn as vectors rather than using the
// reference raster so it stays crisp at the action-panel's native scale.
class NewSectionIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool showPlusBadge;

  const NewSectionIcon({
    super.key,
    this.size = 16,
    required this.color,
    this.showPlusBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    const topInset = 4.0;
    final paintWidth = size + (showPlusBadge ? 10.0 : 5.0);
    final paintHeight = size + topInset + 1.0;
    return SizedBox(
      // Keep the layout width at the original icon width so the -7 px action
      // panel offset remains unchanged. The wider paint viewport is allowed
      // to extend to the right without moving the icon's anchor point. The
      // extra height gives the top of the icon room to render before the
      // complete icon is shifted down by one pixel.
      width: size,
      height: size,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: paintWidth,
        maxWidth: paintWidth,
        minHeight: paintHeight,
        maxHeight: paintHeight,
        child: Transform.translate(
          offset: const Offset(0, -topInset),
          child: CustomPaint(
            size: Size(paintWidth, paintHeight),
            painter: _NewSectionIconPainter(
              color,
              showPlusBadge: showPlusBadge,
              topInset: topInset,
            ),
          ),
        ),
      ),
    );
  }
}

class _NewSectionIconPainter extends CustomPainter {
  final Color color;
  final bool showPlusBadge;
  final double topInset;

  const _NewSectionIconPainter(
    this.color, {
    this.showPlusBadge = false,
    this.topInset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Keep the 16 px layout box and shrink the painted base to 15 px. The
    // half-pixel translation centers that smaller base in the original
    // viewBox, so both New Section states stay anchored in the same place
    // while every edge moves inward.
    const baseShrink = 1.0;
    final scale = (size.height - topInset - 1.0 - baseShrink) / 24.0;
    canvas.save();
    if (showPlusBadge) {
      // The badge and its surrounding separation are transparent punches
      // through the icon layer, revealing the glass surface beneath it. Keep
      // the layer one pixel wider on the left so the shared base bar's
      // negative-x overhang is not clipped only in the New Section state.
      canvas.saveLayer(
        Rect.fromLTRB(-1.0, 0, size.width, size.height),
        Paint(),
      );
    }
    // Leave the added top inset available for the geometry, then center the
    // one-pixel-smaller base inside its original 16 px painted height.
    canvas.translate(baseShrink / 2, topInset + 1.0 + baseShrink / 2);
    canvas.scale(scale, scale);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Section heading bar — this base geometry is shared by both states.
    // New Section only adds the badge and its transparent punch below.
    canvas.drawRect(const Rect.fromLTRB(-1.0, 0.6, 28.0, 5.1), fill);

    // List rows: both bullets share the same outer diameter.  The adjacent
    // bars are two-thirds of that diameter, matching the updated icon
    // proportions.
    // Increase each dot by 0.5 px overall while keeping the list lines at
    // their original thickness.
    const bulletRadius = 3.35;
    const lineHeight = 2.6 * 2 * 2 / 3 - 0.2;
    // Use one shared outer radius for both bullets.  An outlined circle's
    // stroke extends beyond its path, so inset the path radius by half the
    // stroke width; otherwise the outlined bullet appears larger than the
    // filled one.
    final bulletPathRadius = bulletRadius - stroke.strokeWidth / 2;

    // Preserve the existing first-to-second row gap as the dots grow.
    const firstRowY = 11.6;
    // Both states use the exact same row geometry.
    const secondRowY = 20.65;
    const listLineLeft = 10.0;
    const listLineRight = 24.0;
    const listLineWidth = listLineRight - listLineLeft;

    // First row: filled bullet with an outline.
    canvas.drawCircle(const Offset(3.5, firstRowY), bulletPathRadius, fill);
    canvas.drawCircle(const Offset(3.5, firstRowY), bulletPathRadius, stroke);
    canvas.drawRect(
      // Keep the left edge fixed while leaving a small gap after the bullet
      // instead of letting the line overlap its outer edge.
      const Rect.fromLTWH(
        listLineLeft,
        firstRowY - lineHeight / 2,
        listLineWidth + 1.5,
        lineHeight,
      ),
      fill,
    );

    // Second row: outlined bullet and solid list line.
    canvas.drawCircle(Offset(3.5, secondRowY), bulletPathRadius, stroke);
    canvas.drawRect(
      Rect.fromLTWH(
        listLineLeft,
        secondRowY - lineHeight / 2,
        listLineWidth + 1.5,
        lineHeight,
      ),
      fill,
    );

    if (showPlusBadge) {
      // Grow toward the upper-right while keeping the lower-left edge fixed.
      const badgeCenter = Offset(29.8, 2.4);
      const badgeRadius = 7.2;
      // Double the transparent separation around the badge without changing
      // the badge or the shared list-icon geometry.
      const badgeGapRadius = 10.6;
      final clear = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      // Clear a slightly larger circle first so the badge is detached from
      // the bar by a deliberate ring of transparent space.
      canvas.drawCircle(badgeCenter, badgeGapRadius, clear);

      canvas.drawCircle(badgeCenter, badgeRadius, fill);

      // The plus is a true negative-space knockout, not a second coloured
      // glyph.
      final plus = Path()
        ..addRect(Rect.fromCenter(center: badgeCenter, width: 2.2, height: 8.8))
        ..addRect(
          Rect.fromCenter(center: badgeCenter, width: 8.8, height: 2.2),
        );
      canvas.drawPath(plus, clear);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NewSectionIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.showPlusBadge != showPlusBadge;
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
//   • Each row has a 52 px minimum height (62 px with a subtitle); rows grow
//     when Dynamic Type makes their text wrap. Separators add 0.5 px between
//     rows.
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
    double iconSize = 20.0,
    Widget Function(Color)? iconBuilderWhenTrue,
    Widget Function(Color)? iconBuilderWhenFalse,
    required void Function(bool) onChanged,
    required VoidCallback onDismiss,
    bool groupBreakAbove = false,
  }) {
    return ActionItem(
      label: value ? labelWhenTrue : labelWhenFalse,
      icon: value ? iconWhenTrue : iconWhenFalse,
      iconSize: iconSize,
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

  /// Measures a row using the same text metrics as [_ActionRow].
  ///
  /// The baseline row heights remain the minimums, so normal-size layouts do
  /// not move. Larger system text can increase the measured text block and
  /// therefore the row height without clipping.
  static double rowHeightForItem(
    BuildContext context,
    ActionItem item, {
    required double panelWidth,
    bool chevronColumn = false,
    double labelFontSize = 16,
    bool enforceTrailingIconSpacing = true,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final leftWidth = chevronColumn
        ? _actionPanelLeadingColumnWidth(context) +
              _actionPanelCheckmarkOptionGap
        : (item.hasChevron || item.checkmark ? 18.0 + 7.0 : 0);
    final rightWidth = _actionPanelRightIconWidth(context, item);
    final trailingGap = enforceTrailingIconSpacing
        ? _actionPanelLabelTrailingIconGap
        : 0.0;
    final textWidth = math.max(
      1.0,
      panelWidth -
          _actionPanelHorizontalInset * 2 -
          leftWidth -
          trailingGap -
          rightWidth,
    );

    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: textWidth);
      return painter.height;
    }

    final labelHeight = measure(
      item.label,
      TextStyle(
        inherit: false,
        fontSize: labelFontSize,
        fontFamily: kSFProText,
        fontWeight: FontWeight.w400,
        letterSpacing: kTracking16,
      ),
    );
    final contentHeight = item.subtitle == null
        ? labelHeight
        : labelHeight +
              2.0 +
              measure(
                item.subtitle!,
                TextStyle(
                  inherit: false,
                  fontSize: 13,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.08,
                ),
              );
    final minimumHeight = item.subtitle != null
        ? rowHeightWithSubtitle
        : rowHeight;
    // _ActionRow uses 10 px of vertical breathing room on each side.
    return math.max(minimumHeight, contentHeight + 20.0);
  }

  /// Height accounting for group breaks, separators, subtitles, and wrapped
  /// text when [context] is supplied.
  static double panelHeightForItems(
    List<ActionItem> items, {
    BuildContext? context,
    double panelWidth = 240.0,
    bool chevronColumn = false,
    double labelFontSize = 16,
    bool enforceTrailingIconSpacing = true,
  }) {
    if (items.isEmpty) return 0;
    double h = 0;
    for (int i = 0; i < items.length; i++) {
      if (i > 0) h += items[i].groupBreakAbove ? groupBreakH : separatorH;
      h += context == null
          ? (items[i].subtitle != null ? rowHeightWithSubtitle : rowHeight)
          : rowHeightForItem(
              context,
              items[i],
              panelWidth: panelWidth,
              chevronColumn: chevronColumn,
              labelFontSize: labelFontSize,
              enforceTrailingIconSpacing: enforceTrailingIconSpacing,
            );
    }
    return h;
  }

  /// Returns the smallest width that preserves the standard row geometry.
  ///
  /// Normal labels remain free to wrap within the caller's width. A panel only
  /// grows when a single unbreakable label/subtitle word is wider than the
  /// available label column, so the word is never clipped into the trailing
  /// icon or the fixed gap.
  static double panelWidthForItems(
    List<ActionItem> items, {
    required BuildContext context,
    double minWidth = 240.0,
    bool chevronColumn = false,
    double labelFontSize = 16,
    bool enforceTrailingIconSpacing = true,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    var width = minWidth;

    double longestWordWidth(String text, TextStyle style) {
      var result = 0.0;
      for (final word in text.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout();
        result = math.max(result, painter.width);
      }
      return result;
    }

    for (final item in items) {
      final leftWidth = chevronColumn
          ? _actionPanelLeadingColumnWidth(context) +
                _actionPanelCheckmarkOptionGap
          : (item.hasChevron || item.checkmark ? 18.0 + 7.0 : 0.0);
      final trailingGap = enforceTrailingIconSpacing
          ? _actionPanelLabelTrailingIconGap
          : 0.0;
      final rightWidth = _actionPanelRightIconWidth(context, item);
      final labelStyle = TextStyle(
        inherit: false,
        fontSize: labelFontSize,
        fontFamily: kSFProText,
        fontWeight: FontWeight.w400,
        letterSpacing: kTracking16,
      );
      final subtitleStyle = TextStyle(
        inherit: false,
        fontSize: 13,
        fontFamily: kSFProText,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
      );
      final longestWord = math.max(
        longestWordWidth(item.label, labelStyle),
        item.subtitle == null
            ? 0.0
            : longestWordWidth(item.subtitle!, subtitleStyle),
      );
      width = math.max(
        width,
        _actionPanelHorizontalInset * 2 +
            leftWidth +
            trailingGap +
            rightWidth +
            longestWord,
      );
    }
    return width;
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
  // When non-null, overrides the auto-computed close duration.  This is useful
  // when another surface needs to present immediately after this panel exits.
  final int? closeDurationOverrideMs;
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
  // Optional live scroll offset for expandable menus that position a
  // connected sub-panel relative to a row inside this panel.
  final ValueNotifier<double>? scrollOffsetNotifier;
  // Keeps the first items fixed above the scrollable body. This is used by
  // expandable sub-panels so their trigger row remains visible while only the
  // options below it move.
  final int pinnedTopItemCount;
  // When true, the separator/group gap above the first scrollable item stays
  // with the pinned header instead of scrolling away with the options.
  final bool pinSeparatorAfterTop;
  // Uses the liquid-glass lens surface for this panel only. The default stays
  // on FrostedGlassCard because the shared action-panel API serves other menus.
  final bool useLiquidGlass;
  // Standard action panels keep a fixed 16 px label-to-trailing-icon gap.
  // Modal picker mini-panels opt out to preserve their compact legacy layout.
  final bool enforceTrailingIconSpacing;

  const ActionPanel({
    super.key,
    required this.items,
    required this.isClosing,
    this.chevronColumn = false,
    this.rowOpacity = 1.0,
    this.borderRadius,
    this.openDurationOverrideMs,
    this.closeDurationOverrideMs,
    this.maxHeight,
    this.labelFontSize = 16,
    this.bouncingScroll = false,
    this.scrollOffsetNotifier,
    this.pinnedTopItemCount = 0,
    this.pinSeparatorAfterTop = false,
    this.useLiquidGlass = false,
    this.enforceTrailingIconSpacing = true,
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

  Duration get _effectiveCloseDuration => widget.closeDurationOverrideMs != null
      ? Duration(milliseconds: widget.closeDurationOverrideMs!)
      : _closeDuration(widget.items.length);

  // The pill is deliberately gone in the first ~18% of the panel close.
  // Keep this proportional to the actual close duration so mini panels with
  // different row counts all get the same early-dismiss feel.
  Duration get _pillFadeDuration => Duration(
    milliseconds: (_effectiveCloseDuration.inMilliseconds * 0.18).round().clamp(
      1,
      100,
    ),
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
        duration: _effectiveCloseDuration,
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
    widget.scrollOffsetNotifier?.value = pos.pixels;
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
    final closeDurMs = _effectiveCloseDuration.inMilliseconds;
    final lead = 50.0 / closeDurMs; // fraction that equals 50 ms
    return ((_ctrl.value - lead) / (1.0 - lead)).clamp(0.0, 1.0);
  }

  // The outline and hairline rules are deliberately ahead of the glass and
  // row content on close.  Keeping this separate from panelScale is important:
  // the gel still shrinks with exactly the same motion while the chrome
  // dissolves first.
  double get _outlineT {
    if (!_isClosingNow) return _ctrl.value;
    final closeDurMs = _effectiveCloseDuration.inMilliseconds;
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

        final pinnedCount = widget.maxHeight == null
            ? 0
            : widget.pinnedTopItemCount.clamp(0, widget.items.length).toInt();
        final hasPinnedSeparator =
            pinnedCount > 0 &&
            widget.pinSeparatorAfterTop &&
            pinnedCount < widget.items.length;
        final pinnedHeight = pinnedCount == 0
            ? 0.0
            : ActionItem.panelHeightForItems(
                    widget.items.sublist(0, pinnedCount),
                    context: context,
                    panelWidth: 240.0,
                    chevronColumn: widget.chevronColumn,
                    labelFontSize: widget.labelFontSize,
                    enforceTrailingIconSpacing:
                        widget.enforceTrailingIconSpacing,
                  ) +
                  (hasPinnedSeparator
                      ? (widget.items[pinnedCount].groupBreakAbove
                            ? ActionItem.groupBreakH
                            : ActionItem.separatorH)
                      : 0.0);

        final pinnedContent = pinnedCount == 0
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < pinnedCount; i++) ...[
                    if (i > 0) _buildSeparator(i),
                    _buildRow(i),
                  ],
                  if (hasPinnedSeparator) _buildSeparator(pinnedCount),
                ],
              );
        final bodyColumn = pinnedCount == 0
            ? column
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = pinnedCount; i < widget.items.length; i++) ...[
                    if (i > pinnedCount) _buildSeparator(i),
                    _buildRow(i),
                  ],
                ],
              );
        final bodyScrollable = SingleChildScrollView(
          controller: _scrollCtrl,
          physics: widget.bouncingScroll
              ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const ClampingScrollPhysics(),
          child: bodyColumn,
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

          Widget scrollBody({
            required Widget child,
          }) => NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: Stack(
              children: [
                // ── Faded scroll content ────────────────────────────────
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: shaderCb,
                  child: child,
                ),
                // ── iOS-style scroll indicator pill ─────────────────────
                // • Visible only while scrolling; auto-hides after 1.5 s.
                // • The track belongs only to the moving options area when
                //   a pinned header is present.
                Positioned(
                  right: 3,
                  top: 10,
                  bottom: 10,
                  width: 2.5,
                  child: AnimatedSlide(
                    offset: _pillVisible ? Offset.zero : const Offset(3.0, 0),
                    duration: _isClosingNow ? Duration.zero : _pillFadeDuration,
                    curve: _pillVisible ? Curves.easeOut : Curves.easeIn,
                    child: AnimatedOpacity(
                      opacity: _pillVisible ? 0.80 : 0.0,
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
                              final ratio = pos.maxScrollExtent > 0
                                  ? pos.pixels / pos.maxScrollExtent
                                  : 0.0;
                              final pillTop = (ratio * (trackH - pillH)).clamp(
                                0.0,
                                (trackH - pillH).clamp(0.0, double.infinity),
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
          );

          final scrollViewport = pinnedContent == null
              ? scrollBody(child: scrollable)
              : LayoutBuilder(
                  builder: (ctx, constraints) {
                    final availableHeight = constraints.hasBoundedHeight
                        ? constraints.maxHeight
                        : widget.maxHeight!;
                    final bodyMaxHeight = math.max(
                      1.0,
                      availableHeight - pinnedHeight,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        pinnedContent,
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: bodyMaxHeight),
                          child: scrollBody(child: bodyScrollable),
                        ),
                      ],
                    );
                  },
                );

          panelContent = ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight!),
            child: scrollViewport,
          );
        } else {
          panelContent = scrollable;
        }

        final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
        final borderColor = resolveThemeColor(kTertiaryLabel, context);
        final resolvedBorder = borderColor.withValues(
          alpha: borderColor.a * outlineT,
        );
        // The Notes attachment panel uses the same translucent material density
        // as the Floating Tab Bar.  Keep the rows independent from this value
        // so their content animation never dims the glass surface itself.
        final fillOpacity = widget.useLiquidGlass
            ? 0.80
            : (isDark && !widget.bouncingScroll ? 0.75 : 0.65);

        // liquid_glass_easy intentionally paints no lens when its shader
        // cannot load. The web preview can run in a CPU-only renderer, so
        // keep the panel visible there with the proven frosted surface.
        // Native iOS/Android renderers continue through the real Liquid Glass
        // composition below.
        final panelCard = widget.useLiquidGlass && !kIsWeb
            ? _LiquidGlassActionPanelCard(
                progress: gt,
                fillOpacity: fillOpacity,
                shadowOpacity: 0.18,
                child: panelContent,
              )
            : FrostedGlassCard(
                progress: gt,
                fillOpacity: fillOpacity,
                shadowOpacity: 0.22,
                borderRadius: widget.borderRadius,
                stadium: widget.items.length == 1,
                border: isDark
                    ? BorderSide(color: resolvedBorder, width: 0.5)
                    : BorderSide.none,
                child: panelContent,
              );

        return Transform.scale(
          scale: panelScale,
          alignment: Alignment.topCenter,
          child: panelCard,
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
          enforceTrailingIconSpacing: widget.enforceTrailingIconSpacing,
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
  final bool enforceTrailingIconSpacing;
  const _ActionRow({
    required this.item,
    required this.chevronColumn,
    this.labelFontSize = 16,
    this.enforceTrailingIconSpacing = true,
  });

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  // The leading slot is dynamic with OS text size, but its outer edge is
  // always anchored by the row's fixed 16 px horizontal inset.  It is shared
  // by chevrons and checkmarks so the parent trigger and nested options keep
  // the same label geometry while the nested panel is opening.
  static const double _chevW = _actionPanelCheckmarkBaseSize;
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
    final leadingColumnWidth = widget.chevronColumn
        ? _actionPanelLeadingColumnWidth(context)
        : _chevW;
    final leftWidget = SizedBox(
      width: leadingColumnWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child:
            item.chevronOverride ??
            (item.checkmark
                ? _ActionPanelSFIcon(
                    SFIcons.sf_checkmark,
                    size: _chevW,
                    color: checkColor,
                    weight: FontWeight.w500,
                    boxPadding: _actionPanelLeadingGlyphBoxPadding,
                    scaleWithText: true,
                  )
                : item.hasChevron
                ? _ActionPanelSFIcon(
                    item.chevronDown
                        ? SFIcons.sf_chevron_down
                        : SFIcons.sf_chevron_right,
                    size: _chevW,
                    color: textColor,
                    weight: FontWeight.w500,
                    boxPadding: _actionPanelLeadingGlyphBoxPadding,
                    scaleWithText: true,
                  )
                : null),
      ),
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
    // callers can nudge any icon uniformly. Right-side icons use the same
    // platform text scaler as their labels. Custom icons are authored in a
    // 24 px box, so scale both their paint and their reserved layout box.
    final Widget iconWidget;
    if (item.iconBuilder != null) {
      final scaler = MediaQuery.textScalerOf(context);
      final scaledBase = scaler.scale(_actionPanelCustomIconBaseSize);
      final iconScale = scaledBase / _actionPanelCustomIconBaseSize;
      final iconBox = _actionPanelRightIconWidth(context, item);
      iconWidget = SizedBox(
        width: iconBox,
        height: iconBox,
        child: Align(
          alignment: Alignment.centerRight,
          child: Transform.scale(
            alignment: Alignment.centerRight,
            scale: iconScale,
            child: Transform.translate(
              offset: item.iconOffset,
              child: item.iconBuilder!(textColor),
            ),
          ),
        ),
      );
    } else {
      iconWidget = Transform.translate(
        offset: item.iconOffset,
        child: _ActionPanelSFIcon(
          item.icon,
          size: item.iconSize,
          color: textColor,
          weight: item.iconWeight,
          boxPadding: 4,
          scaleWithText: true,
        ),
      );
    }

    // In chevronColumn mode every row shares a text-scale-aware glyph region.
    // Its left edge is fixed by the row inset, while its width and therefore
    // the label position grow with the scaled checkmark footprint.
    // In standard mode the chevron (if any) sits inline before the label.
    final List<Widget> rowChildren = widget.chevronColumn
        ? [
            leftWidget,
            const SizedBox(width: _actionPanelCheckmarkOptionGap),
            Expanded(child: labelBlock),
            if (widget.enforceTrailingIconSpacing)
              const SizedBox(width: _actionPanelLabelTrailingIconGap),
            iconWidget,
          ]
        : [
            if (item.hasChevron || item.checkmark) ...[
              leftWidget,
              const SizedBox(width: _chevGap),
            ],
            Expanded(child: labelBlock),
            if (widget.enforceTrailingIconSpacing)
              const SizedBox(width: _actionPanelLabelTrailingIconGap),
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
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: rowH),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _actionPanelHorizontalInset,
                vertical: 10,
              ),
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
// ExpandableActionMenu — full-screen overlay with two-panel "drill-down" rows.
//
// When an expandable trigger row is tapped:
//   1. The main panel scales to 0.96 and dims its row content.
//   2. A sub-panel blooms below the trigger row with additional options.
//   3. A floating shared-element renders the trigger row at 100 % scale above
//      both panels so neither transform distorts it.
//
// Only one trigger can be expanded at a time, but a menu can expose multiple
// expandable rows. This keeps the interaction reusable for menus such as the
// DCV menu, which has both Manage Sections and Sort By drill-downs.
//
// Usage:
//   Pass [itemsBuilder] which receives (expandedTriggerId, isScalingBack,
//   onTriggerTap) and returns the main-panel item list. Each trigger row must:
//     • use contentOpacity: expandedTriggerId == its id || isScalingBack
//       ? 0.0 : 1.0
//     • pass onTriggerTap(its id) as its onTap
//   Sub-panel item onTap callbacks are the caller's responsibility (they should
//   call onDismiss — with an 80 ms delay — after applying any state change).
// ══════════════════════════════════════════════════════════════════════════════
class ExpandableActionSpec {
  final String id;
  final double rowTop;
  final double rowHeight;
  final String label;
  final String? subtitle;
  final IconData icon;
  final Widget Function(Color color)? iconBuilder;
  final Offset iconOffset;
  final List<ActionItem> subItems;

  const ExpandableActionSpec({
    required this.id,
    required this.rowTop,
    required this.rowHeight,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.subItems,
    this.iconBuilder,
    this.iconOffset = Offset.zero,
  });
}

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
  /// Called on every build; receives the expanded trigger id, the close-phase
  /// flag, and a trigger-tap handler so callers can wire multiple rows.
  final List<ActionItem> Function(
    String? expandedTriggerId,
    bool isScalingBack,
    void Function(String triggerId) onTriggerTap,
  )
  itemsBuilder;
  // ── Trigger row configs ──────────────────────────────────────────────────────
  final List<ExpandableActionSpec> expandableActions;
  // Optional fast close for transitions into another surface, such as a
  // modal sheet opened from one of the main-panel rows.
  final int? closeDurationOverrideMs;
  // Maximum height for the main panel. When omitted, the menu derives a safe
  // viewport height from panelTop so every expandable menu has the same
  // scroll fallback as ActionMenuOverlay.
  final double? maxHeight;
  // Standard expandable menus use 240 px unless their caller widens them for
  // an unbreakable word.
  final double panelWidth;

  /// Standard panel width used throughout the app.
  static const double panelW = 240.0;

  const ExpandableActionMenu({
    super.key,
    required this.panelTop,
    required this.panelLeft,
    required this.isClosing,
    required this.onDismiss,
    required this.itemsBuilder,
    required this.expandableActions,
    this.closeDurationOverrideMs,
    this.maxHeight,
    this.panelWidth = panelW,
    this.chevronColumn = false,
  });

  @override
  State<ExpandableActionMenu> createState() => _ExpandableActionMenuState();
}

class _ExpandableActionMenuState extends State<ExpandableActionMenu>
    with SingleTickerProviderStateMixin {
  String? _expandedTriggerId;
  // Keeps the closing row identified while the main panel scales back.  This
  // is deliberately separate from _expandedTriggerId: the expanded sub-panel
  // can be removed before the shared trigger row finishes its close transition.
  String? _closingTriggerId;
  bool _scalingBack = false;

  // Two independent closing notifiers so each panel can animate out on its own.
  final _origClosing = ValueNotifier<bool>(false);
  final _expandedClosing = ValueNotifier<bool>(false);
  final _mainScrollOffset = ValueNotifier<double>(0.0);

  // Drives the trigger-row chevron: 0 = pointing right (›), 1 = pointing down (∨).
  late final AnimationController _chevronCtrl;

  bool get _expanded => _expandedTriggerId != null;

  ExpandableActionSpec? _specForId(String? id) {
    if (id == null) return null;
    for (final spec in widget.expandableActions) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    widget.isClosing.addListener(_onOuterClosing);
    _mainScrollOffset.addListener(_onMainScrollChanged);
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    widget.isClosing.removeListener(_onOuterClosing);
    _mainScrollOffset.removeListener(_onMainScrollChanged);
    _mainScrollOffset.dispose();
    _origClosing.dispose();
    _expandedClosing.dispose();
    _chevronCtrl.dispose();
    super.dispose();
  }

  void _onMainScrollChanged() {
    if (mounted) setState(() {});
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
  void _onTriggerTap(String triggerId) {
    if (_expandedTriggerId == triggerId) {
      _expandedClosing.value = true;
      _chevronCtrl.reverse();
      // _scalingBack keeps the floating shared element alive while the main panel
      // scales back from 0.96 → 1.0 after the sub-panel closes, so the trigger
      // row's built-in content does not pop in before the scale is complete.
      setState(() {
        _closingTriggerId = triggerId;
        _scalingBack = true;
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _expandedTriggerId = null;
            _expandedClosing.value = false;
          });
          Future.delayed(const Duration(milliseconds: 160), () {
            if (mounted) {
              setState(() {
                _scalingBack = false;
                _closingTriggerId = null;
              });
            }
          });
        }
      });
      return;
    }
    setState(() {
      _expandedTriggerId = triggerId;
      _closingTriggerId = null;
      _expandedClosing.value = false;
    });
    _chevronCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final activeSpec = _specForId(_expandedTriggerId);
    final mediaQuery = MediaQuery.of(context);
    final safeBottom = mediaQuery.padding.bottom + 16.0;
    final availableMainHeight = math.max(
      1.0,
      mediaQuery.size.height - safeBottom - widget.panelTop,
    );
    final mainMaxHeight = widget.maxHeight ?? availableMainHeight;
    // During close, expose the closing row id to the main-panel builder rather
    // than a global "scaling back" state.  That lets callers hide only the row
    // whose shared element is currently on top; sibling expandable rows remain
    // visible instead of blinking out.
    final visibleTriggerId =
        _expandedTriggerId ?? (_scalingBack ? _closingTriggerId : null);
    final sharedSpec = _specForId(visibleTriggerId);
    final triggerHeight = math.max(
      sharedSpec?.rowHeight ?? 0.0,
      sharedSpec == null
          ? 0.0
          : ActionItem.rowHeightForItem(
              context,
              ActionItem(
                label: sharedSpec.label,
                icon: sharedSpec.icon,
                hasChevron: true,
                subtitle: sharedSpec.subtitle,
              ),
              panelWidth: widget.panelWidth,
              chevronColumn: widget.chevronColumn,
            ),
    );
    final items = widget.itemsBuilder(
      visibleTriggerId,
      _scalingBack,
      _onTriggerTap,
    );
    final subPanelItems = activeSpec == null
        ? null
        : [
            ActionItem(
              label: activeSpec.label,
              icon: activeSpec.icon,
              hasChevron: true,
              subtitle: activeSpec.subtitle,
              iconBuilder: activeSpec.iconBuilder,
              iconOffset: activeSpec.iconOffset,
              instantOnOpen: true,
              contentOpacity: 0.0,
            ),
            ...activeSpec.subItems,
          ];
    final subPanelTop = activeSpec == null
        ? 0.0
        : widget.panelTop + activeSpec.rowTop - _mainScrollOffset.value;
    final subPanelMaxHeight = activeSpec == null
        ? null
        : math.max(1.0, mediaQuery.size.height - safeBottom - subPanelTop);
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
          width: widget.panelWidth,
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
                  closeDurationOverrideMs: widget.closeDurationOverrideMs,
                  rowOpacity: rowOp,
                  maxHeight: mainMaxHeight,
                  scrollOffsetNotifier: _mainScrollOffset,
                ),
              ),
            ),
          ),
        ),

        // Sub-panel — blooms below the active trigger row.
        // The trigger-row slot (index 0) uses contentOpacity:0 so the floating
        // shared element is the sole visual for that row while both are live.
        if (activeSpec != null)
          Positioned(
            left: widget.panelLeft,
            top: subPanelTop,
            width: widget.panelWidth,
            child: ActionPanel(
              items: subPanelItems!,
              isClosing: _expandedClosing,
              chevronColumn: widget.chevronColumn,
              closeDurationOverrideMs: widget.closeDurationOverrideMs,
              openDurationOverrideMs: 280,
              maxHeight: subPanelMaxHeight,
              pinnedTopItemCount: 1,
              pinSeparatorAfterTop: true,
            ),
          ),

        // Floating shared element — rendered LAST so it paints above both panels
        // and stays at 100 % scale while the sub-panel blooms.
        // Fades out via AnimatedOpacity when the outer overlay closes so it
        // dissolves together with the panels' bloom-back animation.
        if (sharedSpec != null)
          Positioned(
            left: widget.panelLeft + 16,
            // Keep the shared trigger row aligned with the row inside the
            // main panel after that panel has been scrolled. Without this,
            // the nested panel follows the live scroll offset while the
            // trigger copy stays at its original, unscrolled position.
            top: widget.panelTop + sharedSpec.rowTop - _mainScrollOffset.value,
            width: widget.panelWidth - _actionPanelHorizontalInset * 2,
            height: triggerHeight,
            child: ValueListenableBuilder<bool>(
              valueListenable: _origClosing,
              builder: (ctx, origClosing, child) => AnimatedOpacity(
                opacity: origClosing ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeIn,
                child: child,
              ),
              child: _ExpandableRowSharedContent(
                label: sharedSpec.label,
                subtitle: sharedSpec.subtitle,
                icon: sharedSpec.icon,
                iconBuilder: sharedSpec.iconBuilder,
                iconOffset: sharedSpec.iconOffset,
                rowHeight: sharedSpec.rowHeight,
                chevronCtrl: _chevronCtrl,
                onTap: _scalingBack
                    ? () {}
                    : () => _onTriggerTap(sharedSpec.id),
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
  final String? subtitle;
  final IconData icon;
  final Widget Function(Color color)? iconBuilder;
  final Offset iconOffset;
  final double rowHeight;
  final AnimationController chevronCtrl;
  final VoidCallback onTap;
  const _ExpandableRowSharedContent({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconBuilder,
    required this.iconOffset,
    required this.rowHeight,
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

  static const double _chevW = _actionPanelCheckmarkBaseSize;

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
    final leadingColumnWidth = _actionPanelLeadingColumnWidth(context);

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
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.rowHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated chevron: › rotates to ∨ as the sub-panel opens.
                  SizedBox(
                    width: leadingColumnWidth,
                    child: AnimatedBuilder(
                      animation: widget.chevronCtrl,
                      builder: (ctx, _) => Transform.rotate(
                        angle: widget.chevronCtrl.value * (math.pi / 2),
                        child: _ActionPanelSFIcon(
                          SFIcons.sf_chevron_right,
                          size: _chevW,
                          color: textColor,
                          weight: FontWeight.w500,
                          boxPadding: _actionPanelLeadingGlyphBoxPadding,
                          scaleWithText: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _actionPanelCheckmarkOptionGap),
                  // Label + subtitle
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.label, style: labelStyle),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(widget.subtitle!, style: subtitleStyle),
                        ],
                      ],
                    ),
                  ),
                  // Right icon
                  Transform.translate(
                    offset: widget.iconOffset,
                    child:
                        widget.iconBuilder?.call(textColor) ??
                        _ActionPanelSFIcon(
                          widget.icon,
                          size: 20,
                          color: textColor,
                          weight: FontWeight.w500,
                          boxPadding: 4,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Liquid-glass action-panel surface ─────────────────────────────────────────
// Used only by the Notes attachment menu. The rows and their animation remain
// owned by ActionPanel; this widget swaps just the card material.
class _LiquidGlassActionPanelCard extends StatelessWidget {
  const _LiquidGlassActionPanelCard({
    required this.progress,
    required this.fillOpacity,
    required this.shadowOpacity,
    required this.child,
  });

  final double progress;
  final double fillOpacity;
  final double shadowOpacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    // Keep the bounded stadium-squircle geometry used by the rest of the app.
    // This is intentionally not derived from the panel's animated height.
    final radius = kSquircleStadiumRadius;
    final fill = (fillOpacity * progress).clamp(0.0, 1.0);
    final shadow = isDark ? 0.0 : shadowOpacity * progress;
    final shape = LiquidGlassShape.squircle(
      cornerRadius: radius,
      // Match the Floating Tab Bar's optical rim and edge-light response.
      borderWidth: 0.45,
      lightIntensity: 0.46,
      lightDirection: 62,
      borderType: const OpticalBorder(
        borderSaturation: 1.0,
        ambientIntensity: 0.18,
        borderSolidity: 0.28,
        lightSpread: 0.12,
      ),
    );
    final style = LiquidGlassTabBar.defaultStyle.copyWith(
      shape: shape,
      appearance: LiquidGlassTabBar.defaultStyle.appearance.copyWith(
        // Use the resolved card surface, matching the tab bar, rather than a
        // separate glass tint.  The 80% alpha is the tab bar's settled density.
        color: resolveThemeColor(kCardColor, context).withValues(alpha: fill),
      ),
      refraction: LiquidGlassTabBar.defaultStyle.refraction.copyWith(
        // Keep the tab bar's refraction and only suppress visible colour
        // fringing, as its own renderer does.
        chromaticAberration: 0.0002,
      ),
    );

    return LiquidGlassShadow(
      // Environmental shadow stays outside the capture, using the same
      // broad, low-opacity lift as the Floating Tab Bar.
      blur: 16,
      opacity: shadow,
      offset: const Offset(0, 5),
      cornerRadius: radius,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // LiquidGlassView owns a rectangular capture layer. Keep both its
          // fallback background and rendered lens output inside the same
          // continuous panel silhouette so the optical surface cannot expose
          // square corners during the open/close scale animation.
          ClipPath(
            clipper: ShapeBorderClipper(
              shape: BoundedSquircleStadiumBorder(radius: radius),
            ),
            child: LiquidGlassView(
              // The overlay is above the Notes card, so keep its capture live:
              // the lens must sample the input card and page behind the panel,
              // rather than rendering only the static fallback colour.
              backgroundWidget: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: BoundedSquircleStadiumBorder(radius: radius),
                ),
                child: ColoredBox(
                  color: resolveThemeColor(
                    kCardColor,
                    context,
                  ).withValues(alpha: fill),
                ),
              ),
              realTimeCapture: true,
              useSync: true,
              useImpellerBackdrop: true,
              child: LiquidGlassLens(
                style: style,
                // Keep the lens' geometry alive independently from the
                // action rows. If a renderer cannot load the shader, the
                // package omits the lens subtree; the rows must still paint.
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Action-panel behavior and content stay outside the lens. The
          // Liquid Glass layer is visual-only, so shader availability can
          // never make the menu's actions disappear.
          Positioned.fill(child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: BoundedSquircleStadiumBorder(
                    radius: radius,
                    side: const BorderSide(
                      color: Color(0x26FFFFFF),
                      width: 0.5,
                    ),
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
  final bool useLiquidGlass;
  // Modal sheet picker-row panels intentionally retain their compact legacy
  // spacing. All other action panels use the standard trailing-icon geometry.
  final bool isPickerMiniPanel;

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
    this.useLiquidGlass = false,
    this.isPickerMiniPanel = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final safeTop = mq.padding.top + 16.0;
    final safeBtm = mq.padding.bottom + 16.0;

    final maxPanelW = math.max(1.0, screenW - _actionPanelHorizontalInset * 2);
    final requestedPanelW = isPickerMiniPanel
        ? panelWidth
        : ActionItem.panelWidthForItems(
            actions,
            context: context,
            minWidth: panelWidth,
            chevronColumn: chevronColumn,
            labelFontSize: labelFontSize,
          );
    final panelW = isPickerMiniPanel
        ? requestedPanelW
        : math.min(requestedPanelW, maxPanelW);
    final panelH = ActionItem.panelHeightForItems(
      actions,
      context: context,
      panelWidth: panelW,
      chevronColumn: chevronColumn,
      labelFontSize: labelFontSize,
    );

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
            useLiquidGlass: useLiquidGlass,
            enforceTrailingIconSpacing: !isPickerMiniPanel,
          ),
        ),
      ],
    );
  }
}
