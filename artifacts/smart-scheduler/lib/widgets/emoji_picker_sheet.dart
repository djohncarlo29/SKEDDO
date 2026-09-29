// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import '../app_theme.dart';
import 'horizontal_edge_fade.dart';
import 'picker_grid_geometry.dart';
import 'rounded_cupertino_sheet.dart';
import 'vertical_edge_fade.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Emoji category data
// ─────────────────────────────────────────────────────────────────────────────

typedef _EmojiCat = ({String icon, String name, List<String> emojis});

class _EmojiGridLayout {
  final PickerGridGeometry geometry;
  final double cellFontSize;

  const _EmojiGridLayout({
    required this.geometry,
    required this.cellFontSize,
  });

  double get gridInset => geometry.verticalInset;
  double get horizontalInset => geometry.horizontalInset;
  double get minimumSpacing => geometry.verticalGap;
  double get cellSize => geometry.itemSize;
  double get crossAxisSpacing => geometry.horizontalGap;
  double get gridHeight => geometry.height;
  int get columns => geometry.columns;
}

const List<_EmojiCat> kEmojiCategories = [
  (
    icon: '😀',
    name: 'Smileys',
    emojis: [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '🙃',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😗',
      '😚',
      '😙',
      '🥲',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤑',
      '🤗',
      '🤭',
      '🫢',
      '🤫',
      '🤔',
      '🫡',
      '🤐',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '🤥',
      '😌',
      '😔',
      '😪',
      '🤤',
      '😴',
      '😷',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🤧',
      '🥵',
      '🥶',
      '🥴',
      '😵',
      '🤯',
      '🤠',
      '🥳',
      '🥸',
      '😎',
      '🤓',
      '🧐',
      '😕',
      '😟',
      '🙁',
      '☹️',
      '😮',
      '😯',
      '😲',
      '😳',
      '🥺',
      '😦',
      '😧',
      '😨',
      '😰',
      '😥',
      '😢',
      '😭',
      '😱',
      '😖',
      '😣',
      '😞',
      '😓',
      '😩',
      '😫',
      '🥱',
      '😤',
      '😡',
      '😠',
      '🤬',
      '😈',
      '👿',
      '💀',
      '☠️',
      '💩',
      '🤡',
      '👻',
      '👽',
      '🤖',
      '😺',
      '😸',
      '😹',
      '😻',
      '😼',
      '😽',
      '🙀',
      '😿',
      '😾',
    ],
  ),
  (
    icon: '👋🏻',
    name: 'People',
    emojis: [
      '👋🏻',
      '🤚🏻',
      '🖐🏻',
      '✋🏻',
      '🖖🏻',
      '👌🏻',
      '🤌🏻',
      '🤏🏻',
      '✌🏻',
      '🤞🏻',
      '🤟🏻',
      '🤘🏻',
      '🤙🏻',
      '👈🏻',
      '👉🏻',
      '👆🏻',
      '👇🏻',
      '☝🏻',
      '👍🏻',
      '👎🏻',
      '✊🏻',
      '👊🏻',
      '🤛🏻',
      '🤜🏻',
      '👏🏻',
      '🙌🏻',
      '🫶🏻',
      '👐🏻',
      '🤲🏻',
      '🤝🏻',
      '🙏🏻',
      '💪🏻',
      '🦾',
      '🦵🏻',
      '🦶🏻',
      '👂🏻',
      '🦻🏻',
      '👃🏻',
      '🧠',
      '👀',
      '👅',
      '💋',
      '🧑🏻',
      '👦🏻',
      '👧🏻',
      '👨🏻',
      '👩🏻',
      '🧓🏻',
      '👴🏻',
      '👵🏻',
      '👶🏻',
      '🧒🏻',
      '💆🏻',
      '💇🏻',
      '🚶🏻',
      '🏃🏻',
      '💃🏻',
      '🕺🏻',
      '🧗🏻',
      '🤸🏻',
      '⛹🏻',
      '🏋🏻',
      '🤼🏻',
      '🏄🏻',
      '🚣🏻',
      '🧘🏻',
      '🏊🏻',
      '🚴🏻',
      '🛀🏻',
      '🧖🏻',
      '🧘🏻',
      '👫🏻',
      '👬🏻',
      '👭🏻',
    ],
  ),
  (
    icon: '🐶',
    name: 'Animals',
    emojis: [
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
      '🙈',
      '🙉',
      '🙊',
      '🐔',
      '🐧',
      '🐦',
      '🐤',
      '🦆',
      '🦅',
      '🦉',
      '🦇',
      '🐝',
      '🦋',
      '🐛',
      '🐌',
      '🐞',
      '🐜',
      '🕷️',
      '🦂',
      '🐢',
      '🐍',
      '🦎',
      '🦖',
      '🦕',
      '🐙',
      '🦑',
      '🦐',
      '🦀',
      '🐟',
      '🐠',
      '🐡',
      '🐬',
      '🐳',
      '🐋',
      '🦈',
      '🦭',
      '🐊',
      '🐅',
      '🐆',
      '🦓',
      '🐘',
      '🦛',
      '🦏',
      '🐪',
      '🦒',
      '🦘',
      '🦬',
      '🐃',
      '🐄',
      '🐎',
      '🐖',
      '🐑',
      '🦙',
      '🐐',
      '🦌',
      '🐕',
      '🐩',
      '🦮',
      '🐕‍🦺',
      '🐈',
      '🐈‍⬛',
      '🐓',
      '🦃',
      '🦚',
      '🦜',
      '🦢',
      '🕊️',
      '🐇',
      '🦝',
      '🦨',
      '🦡',
      '🦦',
      '🦥',
      '🐁',
      '🐀',
      '🐿️',
      '🦔',
      '🐾',
      '🌸',
      '🌺',
      '🌻',
      '🌹',
      '🌷',
      '🌼',
      '🪷',
      '🌱',
      '🌿',
      '☘️',
      '🍀',
      '🌵',
      '🌲',
      '🌳',
      '🌴',
      '🍄',
      '🌾',
      '💐',
      '☀️',
      '🌤️',
      '⛅',
      '🌦️',
      '🌧️',
      '⛈️',
      '🌩️',
      '🌨️',
      '❄️',
      '⚡',
      '🔥',
      '💧',
      '🌊',
      '🌈',
      '🌙',
      '⭐',
      '🌟',
      '✨',
      '🌠',
    ],
  ),
  (
    icon: '🍎',
    name: 'Food',
    emojis: [
      '🍏',
      '🍎',
      '🍐',
      '🍊',
      '🍋',
      '🍌',
      '🍉',
      '🍇',
      '🍓',
      '🫐',
      '🍒',
      '🍑',
      '🥭',
      '🍍',
      '🥥',
      '🥝',
      '🍅',
      '🫒',
      '🥑',
      '🌽',
      '🥕',
      '🥦',
      '🥬',
      '🌶️',
      '🧄',
      '🧅',
      '🥔',
      '🥜',
      '🫘',
      '🍞',
      '🥐',
      '🥖',
      '🫓',
      '🧀',
      '🥚',
      '🍳',
      '🥞',
      '🧇',
      '🥓',
      '🥩',
      '🍗',
      '🍖',
      '🌭',
      '🍔',
      '🍟',
      '🍕',
      '🌮',
      '🌯',
      '🥗',
      '🍝',
      '🍜',
      '🍲',
      '🍛',
      '🍣',
      '🍱',
      '🥟',
      '🍤',
      '🍙',
      '🍚',
      '🍘',
      '🍥',
      '🧁',
      '🍰',
      '🎂',
      '🍮',
      '🍭',
      '🍬',
      '🍫',
      '🍿',
      '🍩',
      '🍪',
      '🌰',
      '🍯',
      '☕',
      '🫖',
      '🍵',
      '🧃',
      '🥤',
      '🧋',
      '🍺',
      '🍻',
      '🥂',
      '🍷',
      '🥃',
      '🍸',
      '🍹',
      '🧊',
      '🥄',
      '🍴',
      '🍽️',
      '🥢',
      '🧂',
    ],
  ),
  (
    icon: '⚽',
    name: 'Activities',
    emojis: [
      '⚽',
      '🏀',
      '🏈',
      '⚾',
      '🥎',
      '🎾',
      '🏐',
      '🏉',
      '🥏',
      '🎱',
      '🪀',
      '🏓',
      '🏸',
      '🏒',
      '🥊',
      '🥋',
      '🎽',
      '🛹',
      '🛼',
      '🛷',
      '⛸️',
      '🥌',
      '🎿',
      '⛷️',
      '🏂️',
      '🪂',
      '🏋🏻',
      '🤼🏻',
      '🤸🏻',
      '🤺',
      '🏇🏻',
      '⛹🏻',
      '🤾🏻',
      '🏌🏻',
      '🏄🏻',
      '🚣🏻',
      '🧘🏻',
      '🏊🏻',
      '🚴🏻',
      '🏆',
      '🥇',
      '🥈',
      '🥉',
      '🏅',
      '🎖️',
      '🎪',
      '🤹🏻',
      '🎭',
      '🎨',
      '🎬',
      '🎰',
      '🎮',
      '🕹️',
      '🎲',
      '🎯',
      '🎳',
      '🎻',
      '🎺',
      '🥁',
      '🎸',
      '🎵',
      '🎶',
      '🎤',
      '🎧',
      '🎷',
      '🎹',
      '🪗',
      '🪘',
      '🪕',
      '🎼',
      '🎋',
      '🎍',
      '🎎',
      '🎏',
      '🎐',
      '🎑',
      '🎃',
      '🎄',
      '🎁',
      '🎀',
      '🎊',
      '🎉',
      '🎗️',
      '🎫',
      '🎟️',
    ],
  ),
  (
    icon: '✈️',
    name: 'Travel',
    emojis: [
      '🚗',
      '🚕',
      '🚙',
      '🚌',
      '🏎️',
      '🚓',
      '🚑',
      '🚒',
      '🚐',
      '🛻',
      '🚚',
      '🚛',
      '🚜',
      '🛴',
      '🚲',
      '🛵',
      '🏍️',
      '🚁',
      '🛸',
      '🚀',
      '✈️',
      '🛩️',
      '🚂',
      '🚆',
      '🚇',
      '🚉',
      '🚊',
      '🚝',
      '🚞',
      '🛳️',
      '⛴️',
      '🚢',
      '🛥️',
      '⛵',
      '🚤',
      '🛶',
      '⚓',
      '🛟',
      '🏔️',
      '⛰️',
      '🌋',
      '🗻',
      '🏕️',
      '🏖️',
      '🏗️',
      '🏘️',
      '🏠',
      '🏡',
      '🏢',
      '🏣',
      '🏤',
      '🏥',
      '🏦',
      '🏨',
      '🏩',
      '🏪',
      '🏫',
      '🏬',
      '🏭',
      '🏯',
      '🏰',
      '💒',
      '🗼',
      '🗽',
      '⛪',
      '🕌',
      '🛕',
      '⛩️',
      '⛲',
      '🌁',
      '🌃',
      '🏙️',
      '🌄',
      '🌅',
      '🌆',
      '🌇',
      '🌉',
      '🗺️',
      '🧭',
      '🌐',
      '🏁',
      '🚩',
      '🎌',
      '🏴',
      '🏳️',
    ],
  ),
  (
    icon: '💡',
    name: 'Objects',
    emojis: [
      '⌚',
      '📱',
      '💻',
      '⌨️',
      '🖥️',
      '🖨️',
      '🖱️',
      '💽',
      '💾',
      '💿',
      '📷',
      '📸',
      '📹',
      '🎥',
      '📽️',
      '📞',
      '☎️',
      '📺',
      '📻',
      '🧭',
      '⏰',
      '⏱️',
      '⏲️',
      '🕰️',
      '⌛',
      '⏳',
      '📡',
      '🔋',
      '🔌',
      '💡',
      '🔦',
      '🕯️',
      '🧯',
      '💸',
      '💵',
      '💰',
      '💳',
      '🪙',
      '🔑',
      '🗝️',
      '🔐',
      '🔒',
      '🔓',
      '🔨',
      '🪓',
      '⚒️',
      '🛠️',
      '🔧',
      '🪛',
      '🔩',
      '⚙️',
      '🧲',
      '🪜',
      '🧱',
      '🚪',
      '🛋️',
      '🪑',
      '🚽',
      '🚿',
      '🛁',
      '🧴',
      '🪥',
      '🧷',
      '🧹',
      '🧺',
      '🧻',
      '🧼',
      '🛒',
      '🎒',
      '🧳',
      '👜',
      '👛',
      '👓',
      '🕶️',
      '🧤',
      '🧣',
      '🧦',
      '👒',
      '🎩',
      '🧢',
      '👗',
      '👔',
      '👕',
      '👖',
      '🧥',
      '🥼',
      '🧤',
      '🩱',
      '🩲',
      '🩳',
      '👟',
      '👠',
      '👡',
      '👢',
      '🥾',
      '🥿',
      '🧶',
      '🪡',
      '🪢',
      '✉️',
      '📧',
      '📦',
      '📫',
      '📜',
      '📃',
      '📄',
      '📊',
      '📈',
      '📉',
      '📋',
      '📁',
      '📂',
      '📓',
      '📔',
      '📒',
      '📕',
      '📗',
      '📘',
      '📙',
      '📚',
      '📖',
      '🔖',
      '🏷️',
      '📌',
      '📍',
      '✂️',
      '📏',
      '📐',
      '✒️',
      '🖊️',
      '🖍️',
      '📝',
      '🔍',
      '🔎',
    ],
  ),
  (
    icon: '❤️',
    name: 'Symbols',
    emojis: [
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❤️‍🔥',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '☮️',
      '✝️',
      '☪️',
      '🕉️',
      '🔯',
      '☸️',
      '🛐',
      '♈',
      '♉',
      '♊',
      '♋',
      '♌',
      '♍',
      '♎',
      '♏',
      '♐',
      '♑',
      '♒',
      '♓',
      '⛎',
      '♻️',
      '✅',
      '☑️',
      '🔱',
      '⚜️',
      '🔰',
      '💯',
      '❌',
      '❓',
      '❗',
      '🔔',
      '🚫',
      '⛔',
      '📣',
      '📢',
      '💬',
      '💭',
      '💤',
      '🎵',
      '🎶',
      '♠️',
      '♣️',
      '♥️',
      '♦️',
      '🃏',
      '🀄',
      '🎴',
      '🔵',
      '🟠',
      '🟡',
      '🟢',
      '🔴',
      '🟣',
      '⚫',
      '⚪',
      '🟤',
      '🔶',
      '🔷',
      '🔸',
      '🔹',
      '🔺',
      '🔻',
      '💠',
      '🔘',
      '🔲',
      '🔳',
      '⬛',
      '⬜',
      '▪️',
      '▫️',
      '◼️',
      '◻️',
      '◾',
      '◽',
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// EmojiPickerSheet — full-page sheet content for showRoundedCupertinoSheet
// ─────────────────────────────────────────────────────────────────────────────

enum _EmojiHorizontalGesture { undecided, paging, rubberband }

class EmojiPickerSheet extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  const EmojiPickerSheet({super.key, required this.onEmojiSelected});

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  int _catIndex = 0;
  double _dragOffset = 0.0;
  final _scrollCtrl = ScrollController();
  final _categoryScrollCtrl = ScrollController();
  final List<GlobalKey> _categoryTabKeys = List<GlobalKey>.generate(
    kEmojiCategories.length,
    (_) => GlobalKey(),
  );
  int _categoryTabVisibilityRequest = 0;
  int? _emojiEdgePointer;
  Offset? _emojiEdgeStart;
  bool _emojiEdgeRubberbanding = false;
  _EmojiHorizontalGesture _emojiHorizontalGesture =
      _EmojiHorizontalGesture.undecided;
  bool _isEmojiDragging = false;
  Timer? _emojiRubberbandTimer;
  double _emojiScrollRubberbandOffset = 0.0;
  bool _emojiGlyphsWarmed = false;

  static const double _emojiGestureSlop = 12.0;
  static const double _emojiAxisBias = 6.0;
  static const double _emojiPageVelocity = 700.0;
  // These are layout dimensions, not text dimensions. Keep them fixed so
  // Dynamic Type cannot stretch this card farther below the parent sheet's
  // Card 1.
  static const double _emojiSheetHeaderHeight = 64.0;
  static const double _emojiSheetHorizontalInset = 16.0;
  static const double _emojiCategoryInset = 16.0;
  // Four points of breathing room on each side of a category slot gives the
  // strip an authored 8pt minimum gap between neighboring emoji glyphs.
  static const double _emojiCategoryMinimumGap = 8.0;
  static const ScrollPhysics _emojiRubberbandPhysics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_emojiGlyphsWarmed) return;
    _emojiGlyphsWarmed = true;
    _warmEmojiGlyphs(Directionality.of(context));
  }

  void _warmEmojiGlyphs(TextDirection textDirection) {
    final emojis = <String>{
      for (final category in kEmojiCategories) ...[
        category.icon,
        ...category.emojis,
      ],
    };
    for (final emoji in emojis) {
      final painter = TextPainter(
        text: TextSpan(
          text: emoji,
          style: const TextStyle(fontSize: 26),
        ),
        textDirection: textDirection,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      );
      painter.layout();
    }
  }

  @override
  void dispose() {
    _emojiRubberbandTimer?.cancel();
    _scrollCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  void _ensureCategoryTabVisible(int index, {bool animate = true}) {
    if (index < 0 || index >= _categoryTabKeys.length) return;
    final request = ++_categoryTabVisibilityRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          request != _categoryTabVisibilityRequest ||
          index != _catIndex) {
        return;
      }
      final tabContext = _categoryTabKeys[index].currentContext;
      if (tabContext == null) return;
      Scrollable.ensureVisible(
        tabContext,
        alignment: 0.5,
        duration:
            animate ? const Duration(milliseconds: 260) : Duration.zero,
        curve: animate ? Curves.easeInOut : Curves.linear,
      );
    });
  }

  void _switchCategory(int i) {
    if (i < 0 || i >= kEmojiCategories.length) return;
    // A prior swipe may still be animating the tab strip, and its queued
    // ensureVisible callback can otherwise overwrite this newer selection.
    _categoryTabVisibilityRequest++;
    if (_categoryScrollCtrl.hasClients) {
      // Stop the existing ballistic/ensureVisible activity first. A no-op
      // jumpTo(offset) is not needed here and can invalidate the horizontally
      // scrolling emoji layers immediately before the selection repaint.
      final position = _categoryScrollCtrl.position;
      if (position is ScrollPositionWithSingleContext) {
        position.goIdle();
      }
    }
    _emojiRubberbandTimer?.cancel();
    _emojiRubberbandTimer = null;
    _emojiEdgeRubberbanding = false;
    _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
    _emojiSwipeStartOffset = 0.0;
    _emojiScrollRubberbandOffset = 0.0;
    setState(() {
      _catIndex = i;
      _dragOffset = 0.0;
      // Category selection is a direct navigation action. The animated
      // position is reserved for a completed horizontal swipe below.
      _isEmojiDragging = true;
    });
    _scrollCtrl.jumpTo(0);
    // Keep tap navigation consistent with swipe navigation: when the strip
    // overflows, bring the selected tab into view with a smooth scroll. The
    // selection repaint remains independent because the tab uses its
    // selection-dependent keyed child and Opacity layer above.
    _ensureCategoryTabVisible(i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _isEmojiDragging = false);
    });
  }

  void _onEmojiPointerDown(PointerDownEvent event) {
    _emojiRubberbandTimer?.cancel();
    _emojiEdgePointer = event.pointer;
    _emojiEdgeStart = event.position;
    _emojiEdgeRubberbanding = false;
    _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
    _emojiScrollRubberbandOffset = 0.0;
  }

  void _onEmojiPointerMove(PointerMoveEvent event, double panelWidth) {
    if (event.pointer != _emojiEdgePointer) return;
    final start = _emojiEdgeStart;
    if (start == null) return;
    final delta = event.position - start;
    final isHorizontal =
        delta.dx.abs() >= _emojiGestureSlop &&
        delta.dx.abs() > delta.dy.abs() + _emojiAxisBias;
    final pullingPastLeadingEdge = _catIndex == 0 && delta.dx > 0;
    final pullingPastTrailingEdge =
        _catIndex == kEmojiCategories.length - 1 && delta.dx < 0;

    if (isHorizontal &&
        _emojiHorizontalGesture == _EmojiHorizontalGesture.undecided) {
      _emojiHorizontalGesture =
          pullingPastLeadingEdge || pullingPastTrailingEdge
              ? _EmojiHorizontalGesture.rubberband
              : _EmojiHorizontalGesture.paging;
    }
    if (_emojiHorizontalGesture == _EmojiHorizontalGesture.rubberband) {
      _emojiRubberbandTimer?.cancel();
      _emojiEdgeRubberbanding = true;
      final rubberbandOffset = _applyEmojiRubberbandUserOffset(
        event.delta.dx,
        panelWidth,
      );
      setState(() {
        _isEmojiDragging = true;
        _dragOffset = rubberbandOffset;
      });
    }
  }

  void _onEmojiPointerEnd(PointerEvent event) {
    if (event.pointer != _emojiEdgePointer) return;
    final endedRubberbandPointer =
        _emojiEdgeRubberbanding && event.pointer == _emojiEdgePointer;
    if (endedRubberbandPointer) {
      _emojiRubberbandTimer?.cancel();
      _emojiRubberbandTimer = Timer(
        const Duration(milliseconds: 90),
        _resetEmojiRubberband,
      );
    }
    _emojiEdgePointer = null;
    _emojiEdgeStart = null;
  }

  void _resetEmojiRubberband() {
    if (!mounted) return;
    setState(() {
      _dragOffset = 0;
      _isEmojiDragging = false;
      _emojiEdgeRubberbanding = false;
      _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
      _emojiScrollRubberbandOffset = 0.0;
    });
  }

  // Model the horizontal edge as a one-dimensional scroll position so the
  // emoji picker uses the same distance-dependent friction as the vertical
  // emoji grid. The virtual scrollable has no content outside its viewport:
  // pixels below zero represent leading-edge overscroll and positive pixels
  // represent trailing-edge overscroll.
  double _applyEmojiRubberbandUserOffset(
    double userOffset,
    double viewportDimension,
  ) {
    if (userOffset == 0.0) {
      return -_emojiScrollRubberbandOffset;
    }

    final metrics = FixedScrollMetrics(
      minScrollExtent: 0.0,
      maxScrollExtent: 0.0,
      pixels: _emojiScrollRubberbandOffset,
      viewportDimension: viewportDimension,
      axisDirection: AxisDirection.right,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final physicsOffset = _emojiRubberbandPhysics.applyPhysicsToUserOffset(
      metrics,
      userOffset,
    );
    _emojiScrollRubberbandOffset -= physicsOffset;
    return -_emojiScrollRubberbandOffset;
  }

  void _onDragStart(DragStartDetails d) {
    _emojiSwipeStartOffset = _dragOffset;
  }

  double _emojiSwipeStartOffset = 0.0;

  void _onDragUpdate(DragUpdateDetails d, double panelWidth) {
    if (_emojiHorizontalGesture == _EmojiHorizontalGesture.rubberband) {
      return;
    }

    if (_emojiHorizontalGesture == _EmojiHorizontalGesture.undecided) {
      final start = _emojiEdgeStart;
      final deltaFromStart =
          start == null ? Offset.zero : d.globalPosition - start;
      final isHorizontal =
          deltaFromStart.dx.abs() >= _emojiGestureSlop &&
          deltaFromStart.dx.abs() >
              deltaFromStart.dy.abs() + _emojiAxisBias;
      if (!isHorizontal) return;

      final pullingPastLeadingEdge = _catIndex == 0 && deltaFromStart.dx > 0;
      final pullingPastTrailingEdge =
          _catIndex == kEmojiCategories.length - 1 && deltaFromStart.dx < 0;
      _emojiHorizontalGesture =
          pullingPastLeadingEdge || pullingPastTrailingEdge
              ? _EmojiHorizontalGesture.rubberband
              : _EmojiHorizontalGesture.paging;
      if (_emojiHorizontalGesture == _EmojiHorizontalGesture.rubberband) {
        _emojiEdgeRubberbanding = true;
        final rubberbandOffset = _applyEmojiRubberbandUserOffset(
          d.delta.dx,
          panelWidth,
        );
        setState(() {
          _isEmojiDragging = true;
          _dragOffset = rubberbandOffset;
        });
        return;
      }
    }

    setState(() {
      _isEmojiDragging = true;
      _dragOffset += d.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails d, double panelWidth) {
    if (_emojiHorizontalGesture == _EmojiHorizontalGesture.rubberband ||
        _emojiEdgeRubberbanding) {
      if (_emojiRubberbandTimer == null) {
        _emojiRubberbandTimer = Timer(
          const Duration(milliseconds: 90),
          _resetEmojiRubberband,
        );
      }
      return;
    }

    final vel = d.primaryVelocity ?? 0;
    final pageOffset = _dragOffset - _emojiSwipeStartOffset;
    final distanceThreshold = math.max(56.0, panelWidth * 0.24);
    final flickDistanceThreshold =
        math.max(_emojiGestureSlop * 2, panelWidth * 0.06);
    final hasEnoughFlickDistance =
        pageOffset.abs() >= flickDistanceThreshold;
    final outwardAtEdge =
        (_catIndex == 0 && pageOffset > 0) ||
        (_catIndex == kEmojiCategories.length - 1 && pageOffset < 0);
    final goNext =
        !outwardAtEdge &&
        _catIndex < kEmojiCategories.length - 1 &&
        (pageOffset <= -distanceThreshold ||
            (vel <= -_emojiPageVelocity && hasEnoughFlickDistance));
    final goPrevious =
        !outwardAtEdge &&
        _catIndex > 0 &&
        (pageOffset >= distanceThreshold ||
            (vel >= _emojiPageVelocity && hasEnoughFlickDistance));

    if (goNext || goPrevious) {
      final nextCategory = _catIndex + (goNext ? 1 : -1);
      setState(() {
        _catIndex = nextCategory;
        _dragOffset = 0;
        _isEmojiDragging = false;
        _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
      });
      _scrollCtrl.jumpTo(0);
      _ensureCategoryTabVisible(nextCategory);
    } else {
      setState(() {
        _dragOffset = 0;
        _isEmojiDragging = false;
        _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
      });
    }
  }

  void _onDragCancel() {
    if (_emojiHorizontalGesture == _EmojiHorizontalGesture.rubberband) {
      return;
    }
    setState(() {
      _dragOffset = 0;
      _isEmojiDragging = false;
      _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
    });
  }

  void _onEmojiPointerSignal(PointerSignalEvent event, double panelWidth) {
    if (event is! PointerScrollEvent) return;
    final deltaX = event.scrollDelta.dx;
    if (deltaX == 0) return;

    // Scroll deltas move content opposite to the user's scroll direction.
    // Convert that into the same user offset used by touch swipes. Keep
    // applying the physics while an existing overscroll is easing back.
    final attemptedPixels = _emojiScrollRubberbandOffset + deltaX;
    final atLeadingEdge = _catIndex == 0 && attemptedPixels < 0;
    final atTrailingEdge =
        _catIndex == kEmojiCategories.length - 1 && attemptedPixels > 0;
    if (!atLeadingEdge &&
        !atTrailingEdge &&
        _emojiScrollRubberbandOffset == 0) {
      return;
    }

    _emojiRubberbandTimer?.cancel();
    _emojiHorizontalGesture = _EmojiHorizontalGesture.rubberband;
    final rubberbandOffset = _applyEmojiRubberbandUserOffset(
      -deltaX,
      panelWidth,
    );
    setState(() {
      _isEmojiDragging = true;
      _dragOffset = rubberbandOffset;
    });
    _emojiRubberbandTimer = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      setState(() {
        _dragOffset = 0;
        _isEmojiDragging = false;
        _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
        _emojiScrollRubberbandOffset = 0.0;
      });
    });
  }

  _EmojiGridLayout _resolveEmojiGridLayoutFromCheckpoint(
    int emojiCount,
    double maxWidth,
    TextScaler textScaler,
  ) {
    final gridInset = textScaler.scale(6.0);
    final minimumSpacing = textScaler.scale(2.0);
    final emojiFontSize = textScaler.scale(26.0);
    const horizontalInset = _emojiSheetHorizontalInset;
    const authoredColumns = 7;
    final screenSize = MediaQuery.sizeOf(context);
    final isWideLayout = screenSize.width > screenSize.height;
    final portraitViewportWidth = isWideLayout
        ? math.min(maxWidth, screenSize.shortestSide)
        : maxWidth;
    final targetCellSize = PickerGridGeometry.scaledPortraitItemSize(
      viewportWidth: portraitViewportWidth,
      horizontalInset: horizontalInset,
      authoredColumns: authoredColumns,
      minimumGap: minimumSpacing,
      textScaleRatio: emojiFontSize / 26.0,
    );
    final portraitGeometry = PickerGridGeometry.resolve(
      itemCount: emojiCount,
      viewportWidth: portraitViewportWidth,
      horizontalInset: horizontalInset,
      targetItemSize: targetCellSize,
      minimumHorizontalGap: minimumSpacing,
      verticalGap: minimumSpacing,
      verticalInset: gridInset,
      authoredMaximumColumns: emojiCount,
    );
    final geometry = isWideLayout
        ? PickerGridGeometry.landscape(
            portrait: portraitGeometry,
            itemCount: emojiCount,
            viewportWidth: maxWidth,
            horizontalInset: horizontalInset,
            authoredMaximumColumns: emojiCount,
          )
        : portraitGeometry;
    return _EmojiGridLayout(
      geometry: geometry,
      cellFontSize: math.max(
        1.0,
        emojiFontSize * (geometry.itemSize / targetCellSize),
      ),
    );
  }

  Widget _buildGrid(int idx, {bool active = false}) {
    final emojis = kEmojiCategories[idx].emojis;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _resolveEmojiGridLayoutFromCheckpoint(
          emojis.length,
          constraints.maxWidth,
          textScaler,
        );

        return SingleChildScrollView(
          controller: active ? _scrollCtrl : null,
          physics: active
              ? const BouncingScrollPhysics(
                  decelerationRate: ScrollDecelerationRate.fast,
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: constraints.maxWidth,
            height: layout.gridHeight,
            child: Stack(
              children: List.generate(emojis.length, (i) {
                final emoji = Text(
                  emojis[i],
                  style: TextStyle(
                    fontSize: layout.cellFontSize,
                    height: 1.0,
                  ),
                  textScaler: TextScaler.noScaling,
                );
                final child =
                    active
                        ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _close();
                            widget.onEmojiSelected(emojis[i]);
                          },
                          child: emoji,
                        )
                        : Center(child: emoji);

                return Positioned.fromRect(
                  key: ValueKey(i),
                  rect: layout.geometry.itemRects[i],
                  child: child,
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // The category strip and the grid use different visual slot sizes. Align
  // their endpoint centers rather than aligning their slot edges.
  double _categoryHorizontalInset(
    double cardWidth,
    TextScaler textScaler,
  ) {
    final minimumSpacing = textScaler.scale(2.0);
    final emojiFontSize = textScaler.scale(26.0);
    const authoredColumns = 7;
    final screenSize = MediaQuery.sizeOf(context);
    final isWideLayout = screenSize.width > screenSize.height;
    final portraitCardWidth = isWideLayout
        ? math.min(cardWidth, screenSize.shortestSide)
        : cardWidth;
    final targetCellSize = PickerGridGeometry.scaledPortraitItemSize(
      viewportWidth: portraitCardWidth,
      horizontalInset: _emojiSheetHorizontalInset,
      authoredColumns: authoredColumns,
      minimumGap: minimumSpacing,
      textScaleRatio: emojiFontSize / 26.0,
    );
    final grid = PickerGridGeometry.resolve(
      itemCount: authoredColumns,
      viewportWidth: portraitCardWidth,
      horizontalInset: _emojiSheetHorizontalInset,
      targetItemSize: targetCellSize,
      minimumHorizontalGap: minimumSpacing,
      verticalGap: minimumSpacing,
      verticalInset: textScaler.scale(6.0),
      authoredMaximumColumns: authoredColumns,
    );
    final categorySlotWidth = math.max(28.0, textScaler.scale(28.0));

    return math.max(
      0.0,
      grid.horizontalInset + grid.itemSize / 2 - categorySlotWidth / 2,
    );
  }

  Widget _positionEmojiPage({
    required Key key,
    required double left,
    required double width,
    required Widget child,
  }) {
    return AnimatedPositioned(
      key: key,
      duration:
          _isEmojiDragging ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      left: left,
      top: 0,
      bottom: 0,
      width: width,
      child: child,
    );
  }

  void _close() => Navigator.of(context, rootNavigator: true).pop();

  @override
  Widget build(BuildContext context) {
    final sepLineColor = kSeparatorColor.resolveFrom(context);
    final labelColor = kPrimaryLabel.resolveFrom(context);
    final cardColor = resolveThemeColor(kModalCard, context);
    final opaqueSeparatorColor = Color.alphaBlend(sepLineColor, cardColor);
    final textScaler = MediaQuery.textScalerOf(context);
    const headerInset = _emojiSheetHorizontalInset;

    // Back chevron — replaces xmark in sub-sheets to indicate navigation back.
    // Uses chevron_left to match the DCV header back indicator.
    const _xIcon = CupertinoIcons.chevron_left;
    final _xFamily = _xIcon.fontPackage != null
        ? 'packages/${_xIcon.fontPackage}/${_xIcon.fontFamily}'
        : (_xIcon.fontFamily ?? '');
    final xBtn = StaticLiquidGlassActionButton(
      color: cardColor,
      peakScale: 1.15,
      tapDelay: const Duration(milliseconds: 130),
      onTap: _close,
      child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: Transform.translate(
                offset: const Offset(-1.5, 0),
                child: RichText(
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  text: TextSpan(
                    text: String.fromCharCode(_xIcon.codePoint),
                    style: TextStyle(
                      inherit: false,
                      color: labelColor,
                      fontSize: 20,
                      fontFamily: _xFamily,
                      fontStyle: FontStyle.normal,
                      shadows: resolveThemeTextShadows([
                        Shadow(
                          color: labelColor,
                          blurRadius: kGelBloomIconWeight,
                        ),
                      ], context),
                    ),
                  ),
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ),
          ),
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: kModalBackground,
      child: Column(
        children: [
          // ── Navigation bar ───────────────────────────────────────────────
          RoundedCupertinoSheetHeader(
            child: SizedBox(
              height: _emojiSheetHeaderHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: headerInset),
                child: Row(
                  children: [
                    xBtn,
                    Expanded(
                      child: Center(
                        child: Text(
                          'Choose Emoji',
                          style: TextStyle(
                            inherit: false,
                            color: labelColor,
                            fontFamily: kSFProText,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 40,
                    ), // mirrors xBtn width for symmetry
                  ],
                ),
              ),
            ),
          ),
      // ── Card: grid (row 1) + separator + category strip (row 2) ─────
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.zero,
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        headerInset,
                        12.0,
                        headerInset,
                        math.max(
                          headerInset,
                          systemSafeAreaBottomInset(context),
                        ),
                      ),
                      child: Container(
                        decoration: ShapeDecoration(
                          color: kModalCard.resolveFrom(context),
                          shape: const BoundedSquircleStadiumBorder(),
                          shadows: resolveThemeShadows(kCardShadow, context),
                        ),
                        // Preserve the card's layout inset, but let picker
                        // blooms paint beyond it instead of being clipped at
                        // the card edge.
                        clipBehavior: Clip.none,
                        child: Column(
                          children: [
                            // Row 1 — swipeable emoji grid
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final w = constraints.maxWidth;
                                  final activeGridLayout =
                                      _resolveEmojiGridLayoutFromCheckpoint(
                                        kEmojiCategories[_catIndex]
                                            .emojis
                                            .length,
                                        w,
                                        textScaler,
                                      );
                                  final activeGridOverflows =
                                      activeGridLayout.gridHeight >
                                      constraints.maxHeight + 0.5;
                                  return Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: _onEmojiPointerDown,
                                    onPointerMove: (event) =>
                                        _onEmojiPointerMove(event, w),
                                    onPointerUp: _onEmojiPointerEnd,
                                    onPointerCancel: _onEmojiPointerEnd,
                                    onPointerSignal: (event) =>
                                        _onEmojiPointerSignal(event, w),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragStart: _onDragStart,
                                      onHorizontalDragUpdate: (d) =>
                                          _onDragUpdate(d, w),
                                      onHorizontalDragEnd: (d) =>
                                          _onDragEnd(d, w),
                                      onHorizontalDragCancel: _onDragCancel,
                                      child: VerticalEdgeFade(
                                        fadeColor: cardColor,
                                        fadeHeight: textScaler.scale(36.0),
                                        topInset: 16.0,
                                        bottomInset: 16.0,
                                        fadeOnRubberbandWhenContentFits: true,
                                        scrollController: _scrollCtrl,
                                        contentOverflows:
                                            activeGridOverflows,
                                        contentKey: Object.hash(
                                          _catIndex,
                                          activeGridLayout.columns,
                                          activeGridLayout.gridHeight,
                                          constraints.maxHeight,
                                        ),
                                        child: Stack(
                                          // Preserve the grid's layout inset,
                                          // but let picker gel blooms paint
                                          // into that inset instead of being
                                          // clipped at the grid boundary.
                                          clipBehavior: Clip.none,
                                          children: [
                                            if (_catIndex > 0)
                                              _positionEmojiPage(
                                                key: ValueKey(
                                                  'emoji-grid-${_catIndex - 1}',
                                                ),
                                                left: _dragOffset - w,
                                                width: w,
                                                child: _buildGrid(
                                                  _catIndex - 1,
                                                ),
                                              ),
                                            _positionEmojiPage(
                                              key: ValueKey(
                                                'emoji-grid-$_catIndex',
                                              ),
                                              left: _dragOffset,
                                              width: w,
                                              child: _buildGrid(
                                                _catIndex,
                                                active: true,
                                              ),
                                            ),
                                            if (_catIndex <
                                                kEmojiCategories.length - 1)
                                              _positionEmojiPage(
                                                key: ValueKey(
                                                  'emoji-grid-${_catIndex + 1}',
                                                ),
                                                left: _dragOffset + w,
                                                width: w,
                                            child: _buildGrid(
                                                  _catIndex + 1,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Separator between the two rows
                            // Pre-compose the translucent separator over the
                            // card surface so grid pixels can never show
                            // through it during scroll/rubberband motion.
                            Container(
                              height: 0.5,
                              color: opaqueSeparatorColor,
                            ),
                            // Row 2 — category strip
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: _emojiCategoryInset,
                              ),
                              child: LayoutBuilder(
                                builder: (context, cardConstraints) {
                                  final categoryHorizontalInset =
                                      _categoryHorizontalInset(
                                        cardConstraints.maxWidth,
                                        textScaler,
                                      );
                                  return HorizontalEdgeFade(
                                    fadeColor: cardColor,
                                    // The fade belongs to the full card edge.
                                    // Keep its opaque tail at the same inset as
                                    // the endpoint icon slot.
                                    fadeOnRubberbandWhenContentFits: true,
                                    leadingInset: categoryHorizontalInset,
                                    trailingInset: categoryHorizontalInset,
                                    child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              categoryHorizontalInset,
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                        // Keep every category centered in the
                                        // same slot. Without this, the
                                        // selected 24pt glyph makes the first
                                        // or last tab move inward by 2pt,
                                        // while the grid keeps its cell center
                                        // fixed.
                                        final categorySlotWidth = math.max(
                                          28.0,
                                          textScaler.scale(28.0),
                                        );
                                            return SingleChildScrollView(
                                              controller:
                                                  _categoryScrollCtrl,
                                              primary: false,
                                              scrollDirection: Axis.horizontal,
                                              clipBehavior: Clip.none,
                                              physics:
                                                  const BouncingScrollPhysics(
                                                parent:
                                                    AlwaysScrollableScrollPhysics(),
                                              ),
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  minWidth:
                                                      constraints.maxWidth,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  // Keep this gap at all text
                                                  // scales. spaceBetween may
                                                  // add more when the strip
                                                  // fits, but never less.
                                                  spacing:
                                                      _emojiCategoryMinimumGap,
                                                  children: List.generate(
                                                    kEmojiCategories.length,
                                                    (i) {
                                                      final sel =
                                                          i == _catIndex;
                                                      final fontSize =
                                                          textScaler.scale(
                                                        sel ? 24.0 : 20.0,
                                                      );
                                                      return SizedBox(
                                                        key:
                                                            _categoryTabKeys[i],
                                                        width:
                                                            categorySlotWidth,
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              _switchCategory(i),
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          child: Center(
                                                            child: KeyedSubtree(
                                                              key: ValueKey(
                                                                'emoji-category-$i-${sel ? 'selected' : 'idle'}',
                                                              ),
                                                              child: Opacity(
                                                                opacity:
                                                                    sel ? 1.0 : 0.42,
                                                                child: Text(
                                                                  kEmojiCategories[i]
                                                                      .icon,
                                                                  style: TextStyle(
                                                                    inherit: false,
                                                                    fontSize:
                                                                        fontSize,
                                                                    color:
                                                                        labelColor,
                                                                  ),
                                                                  textScaler:
                                                                      TextScaler
                                                                          .noScaling,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
