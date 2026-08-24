import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../liquid_glass_tab_item.dart'
    show
        LiquidGlassTabBarItem,
        buildLiquidGlassNavGlyph,
        buildLiquidGlassNavLabel;
import 'liquid_glass_nav_bar_layout.dart';
import 'liquid_glass_nav_bar_style.dart';

/// The single icon + label cell shared by every bottom-nav tier (the
/// static bar, the sliding bar, and the glass-morph shell). Driven
/// entirely by [LiquidGlassTabItemStyle], so colors, sizes, the
/// icon→label gap, and the label weights all flow from one descriptor —
/// there is no hardcoded styling here.
class LiquidGlassNavTabCell extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final bool selected;

  /// How much **glass** is over this cell in the layer being drawn,
  /// `0`–`1` — the glass's state, distinct from [selected]. `1` while
  /// the moving glass pill covers it, easing back to `0` as the landed
  /// pill sheds into the static rest pill, and always `0` under a flat
  /// pill or none. The under-glass sizes lerp on this; color, weight
  /// and icon art key off [selected].
  final double underGlass;

  final LiquidGlassTabItemStyle style;

  const LiquidGlassNavTabCell({
    super.key,
    required this.item,
    required this.selected,
    this.underGlass = 0,
    this.style = const LiquidGlassTabItemStyle(),
  });

  @override
  Widget build(BuildContext context) {
    final color = style.colorFor(selected: selected);
    final double glass = underGlass.clamp(0.0, 1.0);
    final baseIconSize = style.iconSizeFor(underGlass: glass);
    // The app deliberately disables ambient text scaling for ordinary icons,
    // but the tab bar is a text-and-icon control. Scale its glyph using the
    // same nonlinear TextScaler curve as the labels, including SKEDDO's
    // custom profile when that mode is active.
    final textScaler = MediaQuery.textScalerOf(context);
    final iconSize = textScaler.scale(baseIconSize);
    final label = item.hasLabel
        ? buildLiquidGlassNavLabel(
            context,
            item,
            color: color,
            fontSize: style.labelFontSizeFor(underGlass: glass),
            fontWeight: style.fontWeightFor(selected: selected),
            selected: selected,
            underGlass: glass > 0,
          )
        : null;

    // The phone's text scaler is intentionally respected for both the glyph
    // and label. The floating bar is a compact control, though, so a label
    // that no longer fits at its OS-requested size is removed instead of
    // being shrunk or allowed to escape the pill. This leaves the scaled
    // icon visible as the compact fallback.
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableLabelHeight = math.max(
          0.0,
          constraints.maxHeight - iconSize - style.iconLabelGap,
        );
        final labelFits = label != null &&
            (item.label == null ||
                _labelFitsAtSystemScale(
                  context,
                  item.label!,
                  style.labelFontSizeFor(underGlass: glass),
                  style.fontWeightFor(selected: selected),
                  constraints.maxWidth,
                  availableLabelHeight,
                ));

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildLiquidGlassNavGlyph(
                context,
                item,
                color: color,
                size: iconSize,
                selected: selected,
                underGlass: glass > 0,
              ),
              if (labelFits && availableLabelHeight > 0) ...[
                SizedBox(height: style.iconLabelGap),
                SizedBox(
                  width: constraints.maxWidth,
                  height: availableLabelHeight,
                  child: label,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _labelFitsAtSystemScale(
    BuildContext context,
    String text,
    double fontSize,
    FontWeight fontWeight,
    double maxWidth,
    double maxHeight,
  ) {
    if (maxWidth <= 0 || maxHeight <= 0) return false;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout(maxWidth: maxWidth);

    return !painter.didExceedMaxLines &&
        painter.width <= maxWidth &&
        painter.height <= maxHeight;
  }
}

/// The transparent tap layer shared by the bottom-nav tiers: one
/// full-height `InkWell` per cell, sitting above the icon layers and
/// owning all pointer events. The ripple corner radius is **derived**
/// from the cell height (a capsule) rather than a hardcoded constant.
///
/// Wrap in [IgnorePointer] (and pass a no-op [onChanged]) only where a
/// separate gesture overlay owns the taps — but prefer simply not
/// placing this row there at all.
class NavBarTapRow extends StatelessWidget {
  final int itemCount;
  final ValueChanged<int> onChanged;

  /// Height of a cell — the ripple radius is `cellHeight / 2` so the
  /// splash is a capsule matching the cell, at any bar height.
  final double cellHeight;

  const NavBarTapRow({
    super.key,
    required this.itemCount,
    required this.onChanged,
    required this.cellHeight,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cellHeight / 2);
    return Row(
      children: [
        for (int i = 0; i < itemCount; i++)
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: radius,
                onTap: () => onChanged(i),
              ),
            ),
          ),
      ],
    );
  }
}

/// Single pass of icons + labels. Used both as the non-animated
/// single-layer renderer and as the dual-layer building block for
/// the iOS-26 highlight effect.
class NavBarIconRow extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final LiquidGlassTabBarLayout layout;

  /// Icon/label styling for every cell.
  final LiquidGlassTabItemStyle itemStyle;

  /// When supplied, the matching cell renders in its selected
  /// state. Ignored when [forceSelected] or [forceUnselected] is
  /// true.
  final int? selectedIndex;

  /// All cells render in their selected state. Used by the
  /// "inside-the-pill" layer.
  final bool forceSelected;

  /// All cells render in their unselected state. Used by the
  /// "outside-the-pill" layer.
  final bool forceUnselected;

  /// How much glass, `0`–`1`, sits over the cells rendering selected:
  /// the moving glass pill's presence on the inside-the-pill layer
  /// (only what the pill covers is visible there), easing to `0` as the
  /// landed pill sheds into the static rest pill. `0` — the default —
  /// when nothing over the selection is glass: then selected cells keep
  /// the shared sizes and differ by color/weight alone.
  final double selectedUnderGlass;

  const NavBarIconRow({
    super.key,
    required this.items,
    required this.layout,
    this.itemStyle = const LiquidGlassTabItemStyle(),
    this.selectedIndex,
    this.forceSelected = false,
    this.forceUnselected = false,
    this.selectedUnderGlass = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(layout.padding),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: LiquidGlassNavTabCell(
                item: items[i],
                selected: forceSelected
                    ? true
                    : forceUnselected
                        ? false
                        : i == selectedIndex,
                underGlass: (forceSelected ||
                        (!forceUnselected && i == selectedIndex))
                    ? selectedUnderGlass
                    : 0,
                style: itemStyle,
              ),
            ),
        ],
      ),
    );
  }
}
