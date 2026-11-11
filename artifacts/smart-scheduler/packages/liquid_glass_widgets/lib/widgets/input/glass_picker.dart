import 'package:flutter/cupertino.dart';
import '../../src/renderer/liquid_glass_renderer.dart';
import '../../types/glass_quality.dart';
import '../shared/adaptive_glass.dart';
import '../../theme/glass_theme_helpers.dart';

/// A glass picker widget following iOS design patterns.
///
/// [GlassPicker] displays a selected value in a glass container and delegates
/// taps to [onTap]. The caller owns the selection state and the picker or menu
/// presented in response.
class GlassPicker extends StatelessWidget {
  /// Creates a glass picker.
  const GlassPicker({
    required this.value,
    this.onTap,
    super.key,
    this.placeholder = 'Select',
    this.icon,
    this.iconGap = 8.0,
    this.height = 48.0,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.textStyle,
    this.placeholderStyle,
    this.maxLines = 1,
    this.softWrap,
    this.textAlign = TextAlign.start,
    this.textWidthBasis = TextWidthBasis.parent,
    this.overflow = TextOverflow.ellipsis,
    this.settings,
    this.useOwnLayer = false,
    this.quality,
    this.shape = const LiquidRoundedRectangle(borderRadius: 10),
    this.semanticLabel,
  });

  /// The currently selected text value.
  final String? value;

  /// Placeholder when value is null.
  final String placeholder;

  /// Icon widget to display at the end (defaults to chevron down).
  final Widget? icon;

  /// Gap between the value and trailing [icon].
  final double iconGap;

  /// Called when tapped.
  final VoidCallback? onTap;

  /// Height of the picker field.
  ///
  /// This is the field's minimum height: with a large system text size the
  /// field grows to fit the text instead of clipping it.
  final double height;

  /// Optional width.
  final double? width;

  /// Padding.
  final EdgeInsetsGeometry padding;

  /// Style for the value text.
  final TextStyle? textStyle;

  /// Style for the placeholder text.
  final TextStyle? placeholderStyle;

  /// Maximum number of value lines. Set to `null` to allow wrapping.
  final int? maxLines;

  /// Whether the value may wrap at line breaks. Defaults to Flutter's behavior.
  final bool? softWrap;

  /// Alignment of the displayed value inside the field.
  final TextAlign textAlign;

  /// Width basis used when laying out a wrapping value.
  final TextWidthBasis textWidthBasis;

  /// How to handle any text that overflows the field.
  final TextOverflow overflow;

  /// Glass settings.
  final LiquidGlassSettings? settings;

  /// Whether to use its own layer (true) or grouped (false).
  final bool useOwnLayer;

  /// Quality.
  final GlassQuality? quality;

  /// Shape of the container.
  final LiquidShape shape;

  /// What the picker chooses, announced by screen readers (for example
  /// "Size"), with the current [value] read as the value.
  ///
  /// When null, the visible text ([value] or [placeholder]) is the label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Inherit quality from parent layer if not explicitly set
    final effectiveQuality = GlassThemeHelpers.resolveQuality(
      context,
      widgetQuality: quality,
    );

    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    final effectiveTextStyle =
        TextStyle(fontSize: 16, color: labelColor).merge(textStyle);

    final effectivePlaceholderStyle =
        TextStyle(fontSize: 16, color: secondaryColor).merge(placeholderStyle);

    // A minimum height rather than a fixed one, so the value survives a
    // large system text size (SC 1.4.4); at the default scale it is the same.
    final child = Container(
      constraints: BoxConstraints(minHeight: height),
      width: width,
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              value ?? placeholder,
              style: value != null
                  ? effectiveTextStyle
                  : effectivePlaceholderStyle,
              maxLines: maxLines,
              softWrap: softWrap,
              textAlign: textAlign,
              textWidthBasis: textWidthBasis,
              overflow: overflow,
            ),
          ),
          SizedBox(width: iconGap),
          IconTheme(
            data: IconThemeData(size: 16, color: secondaryColor),
            child: icon ?? const Icon(CupertinoIcons.chevron_up_chevron_down),
          ),
        ],
      ),
    );

    final glassWidget = AdaptiveGlass(
      shape: shape,
      settings: settings ?? const LiquidGlassSettings(blur: 8),
      quality: effectiveQuality,
      useOwnLayer: useOwnLayer,
      child: child,
    );

    final shownText = value ?? placeholder;
    // One node for the whole field: a button named by [semanticLabel] (or the
    // visible text) whose value is the current selection. The text below is
    // excluded so it is not read a second time.
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: semanticLabel ?? shownText,
      value: semanticLabel != null ? shownText : null,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: glassWidget,
      ),
    );
  }

  /// Helper to show a bottom sheet picker.
  static Future<T?> showSheet<T>({
    required BuildContext context,
    required List<T> items,
    required Widget Function(T item) itemBuilder,
    String? title,
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            if (title != null)
              Container(
                // Minimum, not fixed, so a scaled-up title is not clipped.
                constraints: const BoxConstraints(minHeight: 50),
                alignment: Alignment.center,
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            Expanded(
              child: CupertinoPicker.builder(
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  // Handle live update if needed
                },
                itemBuilder: (context, index) {
                  if (index < 0 || index >= items.length) return null;
                  return itemBuilder(items[index]);
                },
                childCount: items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
