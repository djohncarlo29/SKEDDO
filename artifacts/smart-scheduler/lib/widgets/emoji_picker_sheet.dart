// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import '../app_theme.dart';
import 'horizontal_edge_fade.dart';
import 'rounded_cupertino_sheet.dart';
import 'vertical_edge_fade.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Emoji category data
// ─────────────────────────────────────────────────────────────────────────────

typedef _EmojiCat = ({String icon, String name, List<String> emojis});

class _EmojiGridLayout {
  final double gridInset;
  final double minimumSpacing;
  final double cellSize;
  final double cellFontSize;
  final double crossAxisSpacing;
  final double gridHeight;
  final int columns;

  const _EmojiGridLayout({
    required this.gridInset,
    required this.minimumSpacing,
    required this.cellSize,
    required this.cellFontSize,
    required this.crossAxisSpacing,
    required this.gridHeight,
    required this.columns,
  });
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
  int _emojiColumns = 7;
  int _automaticEmojiColumns = 7;
  bool _emojiColumnsWasPinched = false;
  final Map<int, Offset> _emojiPointers = {};
  double? _emojiPinchStartDistance;
  bool _emojiPinchActive = false;
  bool _emojiPinchHandled = false;
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

  double _currentEmojiPointerDistance() {
    final points = _emojiPointers.values.toList(growable: false);
    if (points.length < 2) return 0.0;
    return (points[0] - points[1]).distance;
  }

  void _onEmojiPointerDown(PointerDownEvent event) {
    _emojiRubberbandTimer?.cancel();
    _emojiPointers[event.pointer] = event.position;
    if (_emojiPointers.length == 1) {
      _emojiEdgePointer = event.pointer;
      _emojiEdgeStart = event.position;
      _emojiEdgeRubberbanding = false;
      _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
      _emojiScrollRubberbandOffset = 0.0;
    }
    if (_emojiPointers.length == 2) {
      _emojiEdgePointer = null;
      _emojiEdgeStart = null;
      _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
      _emojiPinchStartDistance = _currentEmojiPointerDistance();
      _emojiPinchActive = true;
      _emojiPinchHandled = false;
      if (_dragOffset != 0) {
        setState(() => _dragOffset = 0);
      }
    }
  }

  void _onEmojiPointerMove(PointerMoveEvent event, double panelWidth) {
    if (!_emojiPointers.containsKey(event.pointer)) return;
    _emojiPointers[event.pointer] = event.position;
    if (!_emojiPinchActive && _emojiPointers.length == 1) {
      final start = _emojiEdgeStart;
      if (event.pointer == _emojiEdgePointer && start != null) {
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
        if (_emojiHorizontalGesture ==
            _EmojiHorizontalGesture.rubberband) {
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
    }
    if (!_emojiPinchActive || _emojiPinchHandled) return;

    final startDistance = _emojiPinchStartDistance;
    if (startDistance == null || startDistance == 0) return;
    final scale = _currentEmojiPointerDistance() / startDistance;
    final minimumPinchColumns = math.max(1, _automaticEmojiColumns - 1);
    final maximumPinchColumns = _automaticEmojiColumns + 1;

    if (scale > 1.18 && _emojiColumns > minimumPinchColumns) {
      setState(() {
        _emojiColumns -= 1;
        _emojiColumnsWasPinched = true;
      });
      _emojiPinchHandled = true;
    } else if (scale < 0.84 && _emojiColumns < maximumPinchColumns) {
      setState(() {
        _emojiColumns += 1;
        _emojiColumnsWasPinched = true;
      });
      _emojiPinchHandled = true;
    }
  }

  void _onEmojiPointerEnd(PointerEvent event) {
    _emojiPointers.remove(event.pointer);
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
    if (_emojiPointers.length < 2) {
      _emojiPinchStartDistance = null;
      _emojiPinchActive = false;
      _emojiPinchHandled = false;
    }
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
    if (_emojiPinchActive) return;
    _emojiSwipeStartOffset = _dragOffset;
  }

  double _emojiSwipeStartOffset = 0.0;

  void _onDragUpdate(DragUpdateDetails d, double panelWidth) {
    if (_emojiPinchActive ||
        _emojiHorizontalGesture == _EmojiHorizontalGesture.rubberband) {
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
    if (_emojiPinchActive) return;
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
    if (_emojiPinchActive ||
        _emojiHorizontalGesture == _EmojiHorizontalGesture.rubberband) {
      return;
    }
    setState(() {
      _dragOffset = 0;
      _isEmojiDragging = false;
      _emojiHorizontalGesture = _EmojiHorizontalGesture.undecided;
    });
  }

  void _onEmojiPointerSignal(PointerSignalEvent event, double panelWidth) {
    if (_emojiPinchActive || event is! PointerScrollEvent) return;
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

  _EmojiGridLayout _resolveEmojiGridLayout(
    int emojiCount,
    double maxWidth,
    TextScaler textScaler,
  ) {
    final gridInset = textScaler.scale(6.0);
    final minimumSpacing = textScaler.scale(2.0);
    final emojiFontSize = textScaler.scale(26.0);
    const authoredColumns = 7;
    final contentWidth = math.max(
      1.0,
      maxWidth - 2 * gridInset,
    );
    final defaultCellSize =
        (contentWidth - minimumSpacing * (authoredColumns - 1)) /
        authoredColumns;
    final targetCellSize =
        math.max(1.0, defaultCellSize * (emojiFontSize / 26.0));
    final automaticColumns = math.max(
      1,
      ((contentWidth + minimumSpacing + 0.001) /
              (targetCellSize + minimumSpacing))
          .floor(),
    );
    // The column count belongs to the entire subsheet, not this category.
    // Reset a manual pinch offset if the OS-derived baseline changes.
    if (!_emojiColumnsWasPinched ||
        automaticColumns != _automaticEmojiColumns) {
      _automaticEmojiColumns = automaticColumns;
      _emojiColumns = automaticColumns;
      _emojiColumnsWasPinched = false;
    }
    final columns =
        _emojiColumnsWasPinched ? _emojiColumns : automaticColumns;
    final cellSize = math.max(
      1.0,
      _emojiColumnsWasPinched
          ? (contentWidth - minimumSpacing * (columns - 1)) / columns
          : targetCellSize,
    );
    final cellFontSize =
        math.max(1.0, emojiFontSize * (cellSize / targetCellSize));
    final crossAxisSpacing =
        columns > 1
            ? (contentWidth - columns * cellSize) / (columns - 1)
            : 0.0;
    final rowCount = (emojiCount / columns).ceil();
    final gridHeight =
        2 * gridInset +
        rowCount * cellSize +
        math.max(0, rowCount - 1) * minimumSpacing;

    return _EmojiGridLayout(
      gridInset: gridInset,
      minimumSpacing: minimumSpacing,
      cellSize: cellSize,
      cellFontSize: cellFontSize,
      crossAxisSpacing: crossAxisSpacing,
      gridHeight: gridHeight,
      columns: columns,
    );
  }

  // Builds the emoji grid for a given category index.
  // Only the active grid is tappable; peeking grids are visual only.
  Widget _buildGrid(int idx, {bool active = false}) {
    final emojis = kEmojiCategories[idx].emojis;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _resolveEmojiGridLayout(
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
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

                return AnimatedPositioned(
                  key: ValueKey(i),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  left:
                      layout.gridInset +
                      (i % layout.columns) *
                          (layout.cellSize + layout.crossAxisSpacing),
                  top:
                      layout.gridInset +
                      (i ~/ layout.columns) *
                          (layout.cellSize + layout.minimumSpacing),
                  width: layout.cellSize,
                  height: layout.cellSize,
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
  // their endpoint *centers* rather than aligning their slot edges: the first
  // and last category icons then sit directly above the first and last emoji
  // in the OS-sized grid. The strip deliberately ignores the manual pinch
  // column count so pinching the list cannot move or resize the category tabs.
  double _categoryHorizontalInset(
    double cardWidth,
    TextScaler textScaler,
  ) {
    final gridInset = textScaler.scale(6.0);
    final minimumSpacing = textScaler.scale(2.0);
    final emojiFontSize = textScaler.scale(26.0);
    const authoredColumns = 7;
    final contentWidth = math.max(1.0, cardWidth - 2 * gridInset);
    final defaultCellSize =
        (contentWidth - minimumSpacing * (authoredColumns - 1)) /
        authoredColumns;
    final targetCellSize =
        math.max(1.0, defaultCellSize * (emojiFontSize / 26.0));
    final categorySlotWidth =
        math.max(28.0, textScaler.scale(28.0));

    return math.max(
      0.0,
      gridInset + targetCellSize / 2 - categorySlotWidth / 2,
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
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Row 1 — swipeable emoji grid
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final w = constraints.maxWidth;
                                  final activeGridLayout =
                                      _resolveEmojiGridLayout(
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
                                            AnimatedPositioned(
                                              key: ValueKey(
                                                'emoji-grid-${_catIndex - 1}',
                                              ),
                                              duration:
                                                  _isEmojiDragging
                                                      ? Duration.zero
                                                      : const Duration(
                                                        milliseconds: 280,
                                                      ),
                                              curve: Curves.easeInOutCubic,
                                              left: _dragOffset - w,
                                              top: 0,
                                              bottom: 0,
                                              width: w,
                                              child: _buildGrid(_catIndex - 1),
                                            ),
                                          AnimatedPositioned(
                                            key: ValueKey(
                                              'emoji-grid-$_catIndex',
                                            ),
                                            duration:
                                                _isEmojiDragging
                                                    ? Duration.zero
                                                    : const Duration(
                                                      milliseconds: 280,
                                                    ),
                                            curve: Curves.easeInOutCubic,
                                            left: _dragOffset,
                                            top: 0,
                                            bottom: 0,
                                            width: w,
                                            child: _buildGrid(
                                              _catIndex,
                                              active: true,
                                            ),
                                          ),
                                          if (_catIndex <
                                              kEmojiCategories.length - 1)
                                            AnimatedPositioned(
                                              key: ValueKey(
                                                'emoji-grid-${_catIndex + 1}',
                                              ),
                                              duration:
                                                  _isEmojiDragging
                                                      ? Duration.zero
                                                      : const Duration(
                                                        milliseconds: 280,
                                                      ),
                                              curve: Curves.easeInOutCubic,
                                              left: _dragOffset + w,
                                              top: 0,
                                              bottom: 0,
                                              width: w,
                                              child: _buildGrid(_catIndex + 1),
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
