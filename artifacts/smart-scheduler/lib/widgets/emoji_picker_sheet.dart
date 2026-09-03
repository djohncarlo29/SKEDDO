// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import '../app_theme.dart';
import 'rounded_cupertino_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Emoji category data
// ─────────────────────────────────────────────────────────────────────────────

typedef _EmojiCat = ({String icon, String name, List<String> emojis});

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
      '🤼',
      '🏄🏻',
      '🚣🏻',
      '🧘🏻',
      '🏊🏻',
      '🚴🏻',
      '🛀🏻',
      '🧖🏻',
      '🧘🏻',
      '👫',
      '👬',
      '👭',
      '👨‍👩‍👦',
      '👨‍👩‍👧',
      '👨‍👩‍👧‍👦',
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
      '🏂',
      '🪂',
      '🏋️',
      '🤼',
      '🤸',
      '🤺',
      '🏇',
      '⛹️',
      '🤾',
      '🏌️',
      '🏄',
      '🚣',
      '🧘',
      '🏊',
      '🚴',
      '🏆',
      '🥇',
      '🥈',
      '🥉',
      '🏅',
      '🎖️',
      '🎪',
      '🤹',
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
      '🗺️',
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
  int _emojiColumns = 8;
  int _automaticEmojiColumns = 8;
  bool _emojiColumnsWasPinched = false;
  final Map<int, Offset> _emojiPointers = {};
  double? _emojiPinchStartDistance;
  bool _emojiPinchActive = false;
  bool _emojiPinchHandled = false;
  bool _isEmojiDragging = false;
  Timer? _emojiRubberbandTimer;

  @override
  void dispose() {
    _emojiRubberbandTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _switchCategory(int i) {
    setState(() {
      _catIndex = i;
      _dragOffset = 0.0;
    });
    _scrollCtrl.jumpTo(0);
  }

  double _currentEmojiPointerDistance() {
    final points = _emojiPointers.values.toList(growable: false);
    if (points.length < 2) return 0.0;
    return (points[0] - points[1]).distance;
  }

  void _onEmojiPointerDown(PointerDownEvent event) {
    _emojiPointers[event.pointer] = event.position;
    if (_emojiPointers.length == 2) {
      _emojiPinchStartDistance = _currentEmojiPointerDistance();
      _emojiPinchActive = true;
      _emojiPinchHandled = false;
      if (_dragOffset != 0) {
        setState(() => _dragOffset = 0);
      }
    }
  }

  void _onEmojiPointerMove(PointerMoveEvent event) {
    if (!_emojiPointers.containsKey(event.pointer)) return;
    _emojiPointers[event.pointer] = event.position;
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
    if (_emojiPointers.length < 2) {
      _emojiPinchStartDistance = null;
      _emojiPinchActive = false;
      _emojiPinchHandled = false;
    }
  }

  void _onDragUpdate(DragUpdateDetails d, double panelWidth) {
    if (_emojiPinchActive) return;
    setState(() {
      _isEmojiDragging = true;
      double next = _dragOffset + d.delta.dx;
      // Rubber-band resistance at left/right edges
      if ((_catIndex == 0 && next > 0) ||
          (_catIndex == kEmojiCategories.length - 1 && next < 0)) {
        next = next * 0.15;
      }
      _dragOffset = next;
    });
  }

  void _onDragEnd(DragEndDetails d, double panelWidth) {
    if (_emojiPinchActive) return;
    final vel = d.primaryVelocity ?? 0;
    final threshold = panelWidth / 2;

    if ((_dragOffset < -threshold || vel < -400) &&
        _catIndex < kEmojiCategories.length - 1) {
      setState(() {
        _catIndex++;
        _dragOffset = 0;
        _isEmojiDragging = false;
      });
      _scrollCtrl.jumpTo(0);
    } else if ((_dragOffset > threshold || vel > 400) && _catIndex > 0) {
      setState(() {
        _catIndex--;
        _dragOffset = 0;
        _isEmojiDragging = false;
      });
      _scrollCtrl.jumpTo(0);
    } else {
      setState(() {
        _dragOffset = 0;
        _isEmojiDragging = false;
      });
    }
  }

  void _onEmojiPointerSignal(PointerSignalEvent event) {
    if (_emojiPinchActive || event is! PointerScrollEvent) return;
    final deltaX = event.scrollDelta.dx;
    if (deltaX == 0) return;

    // Scroll deltas move content opposite to the user's scroll direction.
    // Convert that into the same page offset used by touch swipes.
    final attemptedOffset = _dragOffset - deltaX;
    final atLeadingEdge = _catIndex == 0 && attemptedOffset > 0;
    final atTrailingEdge =
        _catIndex == kEmojiCategories.length - 1 && attemptedOffset < 0;
    if (!atLeadingEdge && !atTrailingEdge) return;

    _emojiRubberbandTimer?.cancel();
    setState(() {
      _isEmojiDragging = true;
      _dragOffset = attemptedOffset * 0.15;
    });
    _emojiRubberbandTimer = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      setState(() {
        _dragOffset = 0;
        _isEmojiDragging = false;
      });
    });
  }

  // Builds the emoji grid for a given category index.
  // Only the active grid is tappable; peeking grids are visual only.
  Widget _buildGrid(int idx, {bool active = false}) {
    final emojis = kEmojiCategories[idx].emojis;
    final textScaler = MediaQuery.textScalerOf(context);
    final gridInset = textScaler.scale(6.0);
    final minimumSpacing = textScaler.scale(2.0);
    final emojiFontSize = textScaler.scale(26.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        const authoredColumns = 8;
        final contentWidth = math.max(
          1.0,
          constraints.maxWidth - 2 * gridInset,
        );
        final defaultCellSize =
            (contentWidth -
                    minimumSpacing * (authoredColumns - 1)) /
                authoredColumns;
        final targetCellSize = math.max(
          1.0,
          defaultCellSize * (emojiFontSize / 26.0),
        );
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
        final cellSize =
            _emojiColumnsWasPinched
                ? (contentWidth - minimumSpacing * (columns - 1)) /
                    columns
                : targetCellSize;
        final crossAxisSpacing =
            columns > 1
                ? (contentWidth - columns * cellSize) /
                    (columns - 1)
                : 0.0;
        final rowCount = (emojis.length / columns).ceil();
        final gridHeight =
            2 * gridInset +
            rowCount * cellSize +
            math.max(0, rowCount - 1) * minimumSpacing;

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
            height: gridHeight,
            child: Stack(
              children: List.generate(emojis.length, (i) {
                final emoji = Text(
                  emojis[i],
                  style: TextStyle(fontSize: emojiFontSize, height: 1.0),
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
                      gridInset +
                      (i % columns) * (cellSize + crossAxisSpacing),
                  top:
                      gridInset +
                      (i ~/ columns) * (cellSize + minimumSpacing),
                  width: cellSize,
                  height: cellSize,
                  child: child,
                );
              }),
            ),
          ),
        );
      },
    );
  }

  void _close() => Navigator.of(context, rootNavigator: true).pop();

  @override
  Widget build(BuildContext context) {
    final sepLineColor = kSeparatorColor.resolveFrom(context);
    final labelColor = kPrimaryLabel.resolveFrom(context);
    final cardColor = resolveThemeColor(kModalCard, context);
    final textScaler = MediaQuery.textScalerOf(context);
    final headerInset = textScaler.scale(16.0);

    // Back chevron — replaces xmark in sub-sheets to indicate navigation back.
    // Uses chevron_left to match the DCV header back indicator.
    const _xIcon = CupertinoIcons.chevron_left;
    final _xFamily = _xIcon.fontPackage != null
        ? 'packages/${_xIcon.fontPackage}/${_xIcon.fontFamily}'
        : (_xIcon.fontFamily ?? '');
    final xBtn = GelBloomButton(
      peakScale: 1.15,
      tapDelay: const Duration(milliseconds: 130),
      onTap: _close,
      child: LiquidGlassGelCircle(
        color: cardColor,
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
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: kModalBackground,
      child: Column(
        children: [
          // ── Navigation bar ───────────────────────────────────────────────
          RoundedCupertinoSheetHeader(
            child: SizedBox(
              height: textScaler.scale(64.0),
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
                        textScaler.scale(8.0),
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
                                  return Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: _onEmojiPointerDown,
                                    onPointerMove: _onEmojiPointerMove,
                                    onPointerUp: _onEmojiPointerEnd,
                                    onPointerCancel: _onEmojiPointerEnd,
                                    onPointerSignal: _onEmojiPointerSignal,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragUpdate: (d) =>
                                          _onDragUpdate(d, w),
                                      onHorizontalDragEnd: (d) =>
                                          _onDragEnd(d, w),
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
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
                                              curve: Curves.easeOutBack,
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
                                            curve: Curves.easeOutBack,
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
                                              curve: Curves.easeOutBack,
                                              left: _dragOffset + w,
                                              top: 0,
                                              bottom: 0,
                                              width: w,
                                              child: _buildGrid(_catIndex + 1),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Separator between the two rows
                            Container(height: 0.5, color: sepLineColor),
                            // Row 2 — category strip
                            SizedBox(
                              height: textScaler.scale(52.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: List.generate(
                                  kEmojiCategories.length,
                                  (i) {
                                    final sel = i == _catIndex;
                                    return GestureDetector(
                                      onTap: () => _switchCategory(i),
                                      behavior: HitTestBehavior.opaque,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: textScaler.scale(4.0),
                                          vertical: textScaler.scale(8.0),
                                        ),
                                        child: Text(
                                          kEmojiCategories[i].icon,
                                          style: TextStyle(
                                            fontSize: textScaler.scale(
                                              sel ? 24.0 : 20.0,
                                            ),
                                            height: 1.0,
                                            color: sel
                                                ? null
                                                : const Color(0x66000000),
                                          ),
                                          textScaler: TextScaler.noScaling,
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
