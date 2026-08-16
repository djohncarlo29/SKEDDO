import 'dart:async';
import 'dart:convert';
import 'dart:math' show max, min;
import 'dart:ui';

import 'package:flutter/services.dart' show HapticFeedback;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart'
    show
        DeviceGestureSettings,
        GestureRecognizerFactoryWithHandlers,
        kTouchSlop,
        ScaleGestureRecognizer;
import 'package:flutter/material.dart'
    show Icons, ReorderableDragStartListener, ReorderableListView;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/physics.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../ai/ai_services.dart';
import '../services/event_store.dart';
import '../widgets/action_panel.dart';
import '../widgets/native_text_input.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/rounded_cupertino_sheet.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/app_switch.dart';
import '../widgets/fixed_size_icon.dart';
import '../ai/search/search_service.dart';
import '../services/category_registry.dart';
import '../widgets/smart_search_results.dart';

// ── ISO 8601 week number ──────────────────────────────────────────────────────
int _isoWeekNumber(DateTime date) {
  final thursday = date.subtract(
    Duration(days: date.weekday - DateTime.thursday),
  );
  final jan4 = DateTime(thursday.year, 1, 4);
  final week1Monday = jan4.subtract(
    Duration(days: jan4.weekday - DateTime.monday),
  );
  return ((thursday.difference(week1Monday).inDays) / 7).floor() + 1;
}

// ── shared card constants ─────────────────────────────────────────────────────
const _kCornerRadius = kSbCornerRadius;

void _dismissModalSheetFocus() {
  NativeTextInput.unfocusAll();
  FocusManager.instance.primaryFocus?.unfocus();
}

BorderSide _darkModeGhostBorder(
  BuildContext context, {
  bool suppress = false,
}) => !suppress && CupertinoTheme.brightnessOf(context) == Brightness.dark
    ? BorderSide(color: resolveThemeColor(kTertiaryLabel, context), width: 0.5)
    : BorderSide.none;

// ── Context footer constants ──────────────────────────────────────────────────
// Two kinds of context footer exist:
//
//   Dynamic context footer — appears / disappears depending on the current
//   selection in a card (e.g. shown only while "Groceries" is the active
//   category type).  Controlled by a plain `if` so it snaps in sync with the
//   card value, no animation.
//
//   Static context footer — always visible below a card, regardless of
//   selection.  Not yet used; pattern will match dynamic footer, minus the
//   conditional wrapper.
//
// Shared style for both kinds:
TextStyle _kContextFooterStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  height: 1.35,
  color: resolveThemeColor(kSecondaryLabel, context),
);

// ── Dynamic context footers ───────────────────────────────────────────────────
// Each entry: plain String constant consumed by a `if (condition)` block in
// the sheet column.  AnimatedSize/SizeTransition handles their appearance.

/// Shown below the Category Type card while "Shopping List" is selected.
const _kFooterGroceries =
    'Organize shopping items automatically using sections.';

/// Shown below the Category Type card while "Smart Category" is selected.
const _kFooterSmartCategory =
    'Organize matching events automatically based on its description.';

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOM CONTEXT MENU SYSTEM
// ══════════════════════════════════════════════════════════════════════════════

// ── Action descriptor ─────────────────────────────────────────────────────────
class _MenuAction {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback? onTap;
  const _MenuAction({
    required this.label,
    required this.icon,
    this.isDestructive = false,
    this.onTap,
  });
}

// ── _CategoryContextMenu ──────────────────────────────────────────────────────
//
// Wraps any card widget and provides:
//   • Press animation (scale + fade) on tap.
//   • A centred full-screen overlay menu on long press.
//
// The overlay shows:
//   1. A semi-transparent scrim over the whole screen.
//   2. A copy of the card centred horizontally at its original vertical
//      position — the card stays visible above the scrim.
//   3. A 260 pt action panel centred horizontally below (or above if the card
//      sits near the bottom of the screen).
//
// isSmartCategory = true  →  only Edit + Show Info actions (no Pin / Delete).
// isSmartCategory = false →  Pin/Unpin, Edit, Show Info, Delete.
//
// Broadcasts the active press animation into the tile's child subtree so that
// inner elements (icon circle, texts, count number, chevron) can compress on
// tap independently of the card background.  Read via _TilePress.of(ctx) and
// wire into an AnimatedBuilder + Transform.scale inside each _buildCard /
// _buildRowContent implementation.
class _TilePress extends InheritedWidget {
  final Animation<double> press;
  const _TilePress({required this.press, required super.child});

  static _TilePress? of(BuildContext ctx) =>
      ctx.dependOnInheritedWidgetOfExactType<_TilePress>();

  @override
  bool updateShouldNotify(_TilePress old) => old.press != press;
}

/// Wraps its child with a press-scale animation driven by the nearest
/// [_TilePress] ancestor.  The card background sits outside this widget and
/// stays static while inner content (icons, texts, counts, chevrons) compress.
class _TilePressScale extends StatelessWidget {
  final Widget child;
  const _TilePressScale({required this.child});

  @override
  Widget build(BuildContext context) {
    final press = _TilePress.of(context)?.press;
    if (press == null) return child;
    return AnimatedBuilder(
      animation: press,
      builder: (_, c) =>
          Transform.scale(scale: 1.0 - 0.04 * press.value, child: c),
      child: child,
    );
  }
}

class _CategoryContextMenu extends StatefulWidget {
  final Widget child;
  final WidgetBuilder previewBuilder;
  final bool isSmartCategory;
  final bool isPinned;

  /// When true, renders the group context menu (Edit Group Info, Delete Group)
  /// instead
  /// of the standard category menu (Pin, Edit, Archive, Delete).
  final bool isGroup;
  final VoidCallback? onTap;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onEditGroup;
  final VoidCallback? onDeleteGroup;

  /// Whether this tile/row supports long-press-drag reordering. When true,
  /// a brief grace window follows long-press-start: if the finger moves
  /// past a small threshold within it, the gesture becomes a reorder drag
  /// instead of opening the context menu.
  final bool reorderable;
  final void Function(Offset globalPosition)? onReorderStart;
  final void Function(Offset globalPosition)? onReorderUpdate;
  final VoidCallback? onReorderEnd;
  final VoidCallback? onReorderCancel;

  const _CategoryContextMenu({
    super.key,
    required this.child,
    required this.previewBuilder,
    this.isSmartCategory = false,
    this.isPinned = false,
    this.isGroup = false,
    this.onTap,
    this.onPin,
    this.onUnpin,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    this.onEditGroup,
    this.onDeleteGroup,
    this.reorderable = false,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
  });

  @override
  State<_CategoryContextMenu> createState() => _CategoryContextMenuState();
}

class _CategoryContextMenuState extends State<_CategoryContextMenu>
    with TickerProviderStateMixin {
  // upperBound > 1 so the spring simulation can overshoot without being clamped.
  // During dismiss the controller is animated to 1.06 (bloom phase) then to 0
  // (collapse phase), so values slightly above 1.0 are intentional.
  late final AnimationController _overlayCtrl = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 1.5,
  );

  // Signals the overlay which blur curve to use: fast-in on open, fast-out on close.
  final ValueNotifier<bool> _isClosing = ValueNotifier(false);

  OverlayEntry? _entry;
  OverlayEntry? _closingEntry;

  // ── Drag-reorder state ────────────────────────────────────────────────────
  // After onLongPressStart fires (system ≈ 500ms threshold), a second timer
  // begins.  Two things can happen before it fires:
  //   • Nothing    → timer fires at +500ms → show context menu.
  //   • Movement ≥ _kReorderSlop AND elapsed ≥ _kDragMinHoldMs → drag mode,
  //     timer is cancelled and will never show the menu.
  // The elapsed-time guard (_kDragMinHoldMs) lets the user distinguish a slow
  // deliberate drag (held ≥200ms before moving) from an accidental nudge
  // immediately after the long-press fires.
  static const double _kReorderSlop = 10.0; // px, movement threshold
  static const int _kMenuDelayMs = 250; // ms after longPressStart → menu
  static const int _kDragMinHoldMs = 200; // min ms before drag activates
  Offset? _pressStartGlobal;
  DateTime? _pressStartTime;
  bool _reorderActive = false;
  Timer? _menuShowTimer;

  // ── Press-feedback controller ─────────────────────────────────────────────
  // scale = 1.0 − 0.05 × value
  //   value = 0.0 → scale 1.00  (resting)
  //   value = 1.0 → scale 0.95  (pressed)
  //
  // No bloom above 1.0 — the GelBloom overlay animation is the visual "pop".
  // The tile simply compresses on press and releases smoothly on cancel/lift.
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  // ── Drag-lift controller ───────────────────────────────────────────────────
  // value = 0.0 → resting; value = 1.0 → full lift.
  //   scale  = 1.0 + 0.05 × value  (1.00 → 1.05)
  //   shadow = lerp(none, elevated) on value
  // Activated as soon as _reorderActive becomes true; reversed on end/cancel.
  late final AnimationController _liftCtrl = AnimationController(
    vsync: this,
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    // Capture before nulling — used below to detect mid-animation disposal.
    final wasMidClose = _closingEntry != null;
    _closingEntry?.remove();
    _closingEntry = null;
    // Reset the global exclusivity lock under all three scenarios:
    //   1. Disposed while fully open (_hide not yet called):
    //      sbContextMenuDismiss.value still points to _hide.
    //   2. Disposed mid-close animation (_hide was called but cleanup()
    //      never ran because animateTo().then() won't fire after dispose):
    //      sbContextMenuDismiss is already null; wasMidClose is true.
    //   3. Normal path (cleanup() already ran): both checks are false,
    //      sbContextMenuActive is already false — nothing to do.
    if (sbContextMenuDismiss.value == _hide) {
      sbContextMenuDismiss.value = null;
      sbContextMenuActive.value = false;
    } else if (wasMidClose) {
      sbContextMenuActive.value = false;
    }
    _menuShowTimer?.cancel();
    _menuShowTimer = null;
    _isClosing.dispose();
    _overlayCtrl.dispose();
    _pressCtrl.dispose();
    _liftCtrl.dispose();
    super.dispose();
  }

  void _show() {
    if (_entry != null) return;
    // Global exclusivity lock — prevents two simultaneous long-presses
    // (multi-touch) from each opening their own overlay at the same time.
    // Dart is single-threaded so this read-then-write is atomic; the first
    // long-press sets the flag to true before the second one can check it.
    if (sbContextMenuActive.value) return;
    sbContextMenuActive.value = true;
    sbContextMenuDismiss.value = _hide; // register OS-back dismiss hook

    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _isClosing.value = false;
    _overlayCtrl.value = 0;

    _entry = OverlayEntry(
      builder: (ctx) => _ContextMenuOverlay(
        animation: _overlayCtrl,
        isClosing: _isClosing,
        originalOffset: offset,
        originalSize: size,
        previewBuilder: widget.previewBuilder,
        isSmartCategory: widget.isSmartCategory,
        isPinned: widget.isPinned,
        onDismiss: _hide,
        // The closing overlay (~420ms) paints an opaque floating copy of the
        // row directly on top of the real one while it animates back down —
        // so firing the action synchronously (as before) let the real row's
        // pin/archive/delete animation run and finish *underneath* the
        // overlay, invisible to the user. Deferring the callback to `then`
        // (invoked from cleanup() once the overlay is actually gone) makes
        // every action's animation play out fully visible.
        isGroup: widget.isGroup,
        onPin: widget.onPin != null ? () => _hide(then: widget.onPin) : null,
        onUnpin: widget.onUnpin != null
            ? () => _hide(then: widget.onUnpin)
            : null,
        onEdit: widget.onEdit != null ? () => _hide(then: widget.onEdit) : null,
        onArchive: widget.onArchive != null
            ? () => _hide(then: widget.onArchive)
            : null,
        onDelete: widget.onDelete != null
            ? () => _hide(then: widget.onDelete)
            : null,
        onEditGroup: widget.onEditGroup != null
            ? () => _hide(then: widget.onEditGroup)
            : null,
        onDeleteGroup: widget.onDeleteGroup != null
            ? () => _hide(then: widget.onDeleteGroup)
            : null,
      ),
    );
    Overlay.of(context).insert(_entry!);

    // Real underdamped spring — controller briefly exceeds 1.0 on overshoot,
    // giving the card its gel "pop" before settling.
    _overlayCtrl.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1.0,
          stiffness: 460.0,
          ratio: 0.68, // softer overshoot, quicker settle than 0.50
        ),
        0,
        1,
        0,
      ),
    );
  }

  void _hide({VoidCallback? then}) {
    sbContextMenuDismiss.value =
        null; // unregister back-gesture hook immediately
    final entry = _entry;
    _entry = null;
    if (entry == null) {
      then?.call();
      return;
    }
    _closingEntry = entry;
    _isClosing.value = true;

    void cleanup() {
      _closingEntry = null;
      sbContextMenuActive.value = false;
      entry.remove();
      then?.call();
    }

    // Reverse of open: single easeIn collapse to 0 — no bloom phase.
    // Duration (~420 ms) mirrors the spring open so the close feels
    // like a played-back recording of the opening.
    _overlayCtrl
        .animateTo(
          0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeIn,
        )
        .then((_) => cleanup(), onError: (_) => cleanup());

    // sbContextMenuActive stays true until cleanup() (animation completion)
    // so that OS back-gesture interception remains active for the full
    // 420 ms close animation — no gap where the overlay is still visible
    // but back presses slip through to navigation.
  }

  // ── Drag-reorder gesture handlers ─────────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails d) {
    _pressStartGlobal = d.globalPosition;
    _pressStartTime = DateTime.now();
    _reorderActive = false;
    if (!widget.reorderable) {
      // Non-reorderable tiles (smart tiles): open menu immediately.
      _show();
      return;
    }
    // Start the menu timer.  If no qualifying movement arrives in
    // _kMenuDelayMs ms, open the context menu.
    _menuShowTimer = Timer(const Duration(milliseconds: _kMenuDelayMs), () {
      _menuShowTimer = null;
      if (!_reorderActive && mounted) _show();
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (!widget.reorderable) return;
    if (_reorderActive) {
      widget.onReorderUpdate?.call(d.globalPosition);
      return;
    }
    // Menu already opened — ignore subsequent moves.
    if (_entry != null || _closingEntry != null) return;
    final start = _pressStartGlobal;
    if (start == null) return;
    // Any movement ≥ _kReorderSlop px after long-press fires → drag mode.
    // The system long-press threshold (~500 ms) is already the disambiguation
    // window; no additional hold guard is needed once long-press has confirmed
    // intent. Removing the guard lets drag activate as soon as the user moves
    // during the long-press continuation phase, before the bloom timer fires.
    if ((d.globalPosition - start).distance >= _kReorderSlop) {
      _menuShowTimer?.cancel();
      _menuShowTimer = null;
      _reorderActive = true;
      // Snap press-down back to rest and animate the lift up simultaneously.
      _pressCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
      _liftCtrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      widget.onReorderStart?.call(d.globalPosition);
    }
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    _menuShowTimer?.cancel();
    _menuShowTimer = null;
    if (_reorderActive) {
      _reorderActive = false;
      _liftCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
      widget.onReorderEnd?.call();
    }
    // else: context menu already shown (or not yet — handled by timer firing
    // or not); nothing extra to do on finger lift.
  }

  void _onLongPressCancel() {
    _menuShowTimer?.cancel();
    _menuShowTimer = null;
    if (_reorderActive) {
      _reorderActive = false;
      _liftCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
      widget.onReorderCancel?.call();
    }
  }

  // ── Gesture helpers ───────────────────────────────────────────────────────

  void _onTapDown(TapDownDetails _) {
    // Always start from rest before animating so every tap — including rapid
    // repeated taps — produces a full-travel 0.05-scale squeeze.  Without the
    // reset, animateTo(1.0) starts from wherever the release animation left
    // the controller, producing a progressively weaker press each time.
    _pressCtrl.stop();
    _pressCtrl.value = 0.0;
    _pressCtrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 60),
      curve: Curves.easeOut,
    );
  }

  // Fires on a completed tap (finger lifted before long-press threshold).
  void _onTap() {
    _pressCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    widget.onTap!.call();
  }

  // Fires when the gesture is cancelled — either a scroll intercept or a
  // long-press promotion.  The tile releases smoothly back to 1.0; the
  // GelBloom overlay opening is the primary "pop" feedback.
  void _onTapCancel() {
    _pressCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tree-side card stays at natural scale — the overlay copy handles all
    // the spring/bloom animation so there is no discontinuity when the
    // overlay fades out and the tree card is revealed.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      onTap: widget.onTap != null ? _onTap : null,
      child: AnimatedBuilder(
        // Listen to lift only — press feedback is broadcast via _TilePress so
        // inner elements (icons, texts, counts, chevrons) scale independently
        // while the card background stays static.
        animation: _liftCtrl,
        builder: (context, child) {
          // Lift: 1.00 → 1.05 (elevate when drag activates)
          final scale = 1.0 + 0.05 * _liftCtrl.value;

          // Shadow fades in as the tile lifts; zero shadow at rest or press.
          final shadowOpacity = _liftCtrl.value * 0.28;
          final shadowBlur = _liftCtrl.value * 18.0;
          final shadowOffset = Offset(0, _liftCtrl.value * 6.0);

          return Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: _liftCtrl.value > 0.0
                    ? resolveThemeShadows([
                        BoxShadow(
                          color: const Color(
                            0xFF000000,
                          ).withValues(alpha: shadowOpacity),
                          blurRadius: shadowBlur,
                          offset: shadowOffset,
                        ),
                      ], context)
                    : const [],
              ),
              child: child,
            ),
          );
        },
        // _TilePress broadcasts _pressCtrl into the subtree so _TilePressScale
        // widgets inside _CategoryRow / _GroupRow animate on tap.
        child: _TilePress(press: _pressCtrl, child: widget.child),
      ),
    );
  }
}

// ── Blur hole clipper ─────────────────────────────────────────────────────────
// Clips the BackdropFilter to every pixel EXCEPT the card's original rect,
// so the underlying tile is never blurred or dimmed by the scrim.
class _BlurHoleClipper extends CustomClipper<Path> {
  final Rect hole;
  const _BlurHoleClipper({required this.hole});

  @override
  Path getClip(Size size) {
    final screen = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    // Use the same squircle shape as the card decoration.
    final holePath = BoundedContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(_kCornerRadius),
    ).getOuterPath(hole);
    return Path.combine(PathOperation.difference, screen, holePath);
  }

  @override
  bool shouldReclip(_BlurHoleClipper old) => old.hole != hole;
}

// ── Full-screen overlay ───────────────────────────────────────────────────────
class _ContextMenuOverlay extends StatelessWidget {
  // Raw controller value — may briefly exceed 1.0 during spring overshoot (open)
  // or during the bloom phase of dismiss (animateTo(1.06) → animateTo(0)).
  final Animation<double> animation;
  // True from the moment _hide() is called; drives asymmetric blur curves.
  final ValueNotifier<bool> isClosing;
  final Offset originalOffset;
  final Size originalSize;
  final WidgetBuilder previewBuilder;
  final bool isSmartCategory;
  final bool isPinned;

  /// Event mode: shows "Edit Event" and "Delete Event" instead of category actions.
  final bool isEvent;

  /// Group mode: shows "Edit Group Info" and "Delete Group" instead of
  /// category actions.
  final bool isGroup;
  final VoidCallback onDismiss;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onEditGroup;
  final VoidCallback? onDeleteGroup;

  const _ContextMenuOverlay({
    required this.animation,
    required this.isClosing,
    required this.originalOffset,
    required this.originalSize,
    required this.previewBuilder,
    required this.isSmartCategory,
    required this.isPinned,
    required this.onDismiss,
    this.isEvent = false,
    this.isGroup = false,
    this.onPin,
    this.onUnpin,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    this.onEditGroup,
    this.onDeleteGroup,
  });

  List<ActionItem> _actions() {
    if (isEvent) {
      return [
        ActionItem(
          label: 'Edit Event',
          icon: SFIcons.sf_pencil,
          iconSize: 22,
          iconWeight: FontWeight.w500,
          onTap: onEdit,
        ),
        ActionItem(
          label: 'Delete Event',
          icon: SFIcons.sf_trash,
          isDestructive: true,
          onTap: onDelete,
        ),
      ];
    }
    if (isGroup) {
      return [
        ActionItem(
          label: 'Edit Group Info',
          icon: SFIcons.sf_pencil,
          iconSize: 22,
          iconWeight: FontWeight.w500,
          onTap: onEditGroup,
        ),
        ActionItem(
          label: 'Delete Group',
          icon: SFIcons.sf_trash,
          isDestructive: true,
          onTap: onDeleteGroup,
        ),
      ];
    }
    return [
      if (!isSmartCategory)
        ActionItem(
          label: isPinned ? 'Unpin' : 'Pin',
          icon: isPinned ? SFIcons.sf_pin_slash : SFIcons.sf_pin,
          iconSize: 21,
          iconOffset: const Offset(-1.0, 0),
          onTap: isPinned ? onUnpin : onPin,
        ),
      ActionItem(
        label: 'Edit Category Info',
        icon: SFIcons.sf_pencil,
        iconSize: 22,
        iconWeight: FontWeight.w500,
        onTap: onEdit,
      ),
      ActionItem(
        label: 'Archive Category',
        icon: SFIcons.sf_archivebox,
        onTap: onArchive,
      ),
      if (!isSmartCategory)
        ActionItem(
          label: 'Delete Category',
          icon: SFIcons.sf_trash,
          isDestructive: true,
          onTap: onDelete,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;
    final safeTop = mq.padding.top + 16.0;
    final safeBtm = mq.padding.bottom + 16.0;

    // Preview — sits at the card's exact original position (no relocation).
    // The BackdropFilter below blurs the real card; this copy appears sharp
    // above the blur at the same coordinates, scaled up as the menu opens.
    final previewW = originalSize.width;
    final previewH = originalSize.height;

    // Action panel — centred horizontally, placed on whichever side of the
    // pressed tile has more available space.
    const panelW = 240.0;
    final panelLeft = (screenW - panelW) / 2;
    final actions = _actions();
    final panelH = actions.length * 52.0 + max(0, actions.length - 1) * 0.5;

    final tileBottom = originalOffset.dy + originalSize.height;
    final spaceAbove = originalOffset.dy - safeTop;
    final spaceBelow = screenH - safeBtm - tileBottom;

    var panelTop = spaceAbove > spaceBelow
        ? originalOffset.dy -
              panelH -
              12 // more room above → anchor above tile
        : tileBottom + 12; // more room below → anchor below tile
    panelTop = panelTop.clamp(safeTop, screenH - safeBtm - panelH);

    return AnimatedBuilder(
      // Rebuild on every animation tick AND whenever isClosing flips so the
      // blur curve switches immediately at the moment _hide() is called.
      animation: Listenable.merge([animation, isClosing]),
      builder: (context, _) {
        final rawT = animation.value; // spring: may briefly exceed 1.0
        final closing = isClosing.value;
        final clampedT = rawT.clamp(0.0, 1.0);

        // ── Blur / tint ──────────────────────────────────────────────────────
        // On open  : easeOut so the blur surges in quickly then decelerates —
        //            reaches 1.0 when rawT first hits 1.0, stays clamped while
        //            the spring overshoots. Blur is full before card settles.
        // On close : Curves.easeIn applied on top of the easeIn-curved animateTo,
        //            giving a "double-easeIn" that drops the blur far ahead of
        //            the linear cardOpacity — blur is the first thing to vanish.
        final blurT = closing
            ? Curves.easeIn.transform(clampedT)
            : Curves.easeOut.transform(clampedT);

        // ── Card scale ───────────────────────────────────────────────────────
        // Coefficient 0.07: card is 7% bigger when open — noticeably but not
        // dramatically larger. Spring overshoot (~1.163×) pushes to ~8.1%
        // at the bloom peak before settling, staying well within comfortable range.
        final cardScale = 1.0 + 0.07 * rawT;

        // ── Card opacity — linear fade in/out ────────────────────────────────
        final cardOpacity = clampedT;

        // Hole is fixed at the original tile footprint — the blur mask never
        // moves or resizes.  The below-blur tile overflows the hole as it
        // scales, but the overflow is covered by the surrounding blur.
        final holeRect = Rect.fromLTWH(
          originalOffset.dx,
          originalOffset.dy,
          previewW,
          previewH,
        );

        return Stack(
          children: [
            // ① Below-blur tile — painted BEFORE the BackdropFilter so it
            //   sits in the unblurred backdrop that shows through the hole.
            //   Scales and fades in sync with the card copy above, making
            //   the original tile appear to lift and magnify with the menu.
            Positioned(
              left: originalOffset.dx,
              top: originalOffset.dy,
              width: previewW,
              height: previewH,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: cardScale,
                  child: _DarkModeGhostOutline(child: previewBuilder(context)),
                ),
              ),
            ),

            // ② Full-screen backdrop blur + light tint, with a squircle hole
            //   at the original tile position.  GestureDetector wraps ClipPath
            //   so opaque hit-testing covers the whole screen and any tap
            //   dismisses the menu.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: ClipPath(
                clipper: _BlurHoleClipper(hole: holeRect),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 6 * blurT,
                    sigmaY: 6 * blurT,
                  ),
                  child: Container(
                    color: Color.fromRGBO(0, 0, 0, 0.18 * blurT),
                  ),
                ),
              ),
            ),

            // ③ Card copy at the card's exact screen position.
            //   Spring overshoot pushes cardScale briefly above its resting value
            //   on open; bloom inflates it slightly before the collapse on dismiss.
            Positioned(
              left: originalOffset.dx,
              top: originalOffset.dy,
              width: previewW,
              height: previewH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: Opacity(
                  opacity: cardOpacity,
                  child: Transform.scale(
                    scale: cardScale,
                    child: _DarkModeGhostOutline(
                      child: previewBuilder(context),
                    ),
                  ),
                ),
              ),
            ),

            // ③ Action panel — has its own AnimationController so the gel
            //   animation runs over a human-perceptible 500 ms, completely
            //   independent of the fast spring that drives rawT.
            Positioned(
              left: panelLeft,
              top: panelTop,
              width: panelW,
              child: ActionPanel(items: actions, isClosing: isClosing),
            ),
          ],
        );
      },
    );
  }
}

class _DarkModeGhostOutline extends StatelessWidget {
  final Widget child;

  const _DarkModeGhostOutline({required this.child});

  @override
  Widget build(BuildContext context) {
    final border = _darkModeGhostBorder(context);
    if (border == BorderSide.none) return child;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
          side: border,
        ),
      ),
      child: child,
    );
  }
}

// ── Action panel adaptive colours ─────────────────────────────────────────────
// Defined as private constants so they stay co-located with the panel widgets.
// Each value pairs a Light Mode hex with a Dark Mode equivalent so the panel
// adapts automatically once the app wires up dark-mode resolution.
//
// Panel background:
//   Light 0xFFFDFDFD — off-white (current always-light look)
//   Dark  0xFF1D1D1F — iOS primary label in light = near-black surface in dark
const _kPanelBg = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFDFDFD),
  darkColor: Color(0xFF1D1D1F),
);
// Panel shadow: visible in Light Mode, transparent in Dark Mode (matches the
// app-wide convention — see kCardShadowColor / kShadowBlack in app_theme.dart).
const _kPanelShadow = CupertinoDynamicColor.withBrightness(
  color: Color(0x28000000),
  darkColor: Color(0x00000000),
);
// Hairline row separator:
//   Light 0x1A000000 — 10 % black (subtler than kSeparatorColor, intentional)
//   Dark  0x1AFFFFFF — 10 % white — same visual weight on the inverted surface
const _kPanelSeparator = CupertinoDynamicColor.withBrightness(
  color: Color(0x1A000000),
  darkColor: Color(0x1A000000),
);
// Row press / highlight fill:
//   Light 0xFFE8E8E8 — iOS grouped-cell press state (~91 % white)
//   Dark  0xFF3A3A3C — iOS tertiary system background in Dark Mode
//                      (slightly lighter than the 0xFF1D1D1F panel floor)
const _kPanelPressHighlight = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFE8E8E8),
  darkColor: Color(0xFF3A3A3C),
);

// ── Action panel card ─────────────────────────────────────────────────────────
// StatefulWidget so the panel can own its AnimationController.  This is the
// critical design decision: tying the animation to rawT made it invisible
// because the spring traverses the relevant rawT range in only ~30-40 ms
// (2 render frames).  An independent 500 ms controller gives the gel entrance
// a duration the human eye can actually see.
//
// Open  : 500 ms easeOut — panel card pops in via easeOutBack scale, then
//          rows cascade in with 75 ms stagger each.
// Dismiss: 200 ms easeIn — everything collapses quickly.
class _ActionPanel extends StatefulWidget {
  final List<_MenuAction> actions;
  final ValueNotifier<bool> isClosing;

  const _ActionPanel({
    required this.actions,
    required this.isClosing,
    super.key,
  });

  @override
  State<_ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends State<_ActionPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    widget.isClosing.addListener(_onClosingChanged);
    // Drive open over 500 ms — long enough for the stagger to be clearly
    // visible at 60 fps (≈ 30 frames, ~4-5 frames per row step).
    _ctrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  void _onClosingChanged() {
    if (widget.isClosing.value && mounted) {
      _ctrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInCubic,
      );
    }
  }

  @override
  void dispose() {
    widget.isClosing.removeListener(_onClosingChanged);
    _ctrl.dispose();
    super.dispose();
  }

  // ── Derived progress values ───────────────────────────────────────────────

  // Panel card: easeOutBack on the raw controller value so the whole
  // container has a spring-like scale overshoot on open.
  double get _panelT => _ctrl.value;

  // The outline and separators dissolve before the panel body. This is kept
  // independent from the scale curve so the existing gel motion is untouched.
  double get _outlineT {
    if (!widget.isClosing.value) return _ctrl.value;
    const closeMs = 160.0;
    const leadMs = 60.0;
    final lead = leadMs / closeMs;
    return ((_ctrl.value - lead) / (1.0 - lead)).clamp(0.0, 1.0);
  }

  // Row i: starts at ctrl=0.10, staggered by 0.15 per row (= 75 ms), runs
  // over 0.45 of the [0,1] range (= 225 ms) with easeOutBack.
  //
  // With 4 rows (i=0..3):
  //   row 3 ends at ctrl = 0.10 + 3×0.15 + 0.45 = 1.00  ← exactly reachable.
  // The previous formula used duration=0.65, which pushed rows 2 & 3 past
  // ctrl=1.0 — they could never reach full opacity, causing the Delete and
  // Pin rows to appear permanently faded.
  double _rowT(int i) =>
      ((_ctrl.value - 0.08 - i * 0.15) / 0.40).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    // Resolve adaptive colours against the current brightness once per build
    // so every sub-widget gets consistent, already-resolved Color values.
    final panelBg = CupertinoDynamicColor.resolve(_kPanelBg, context);
    final panelShadow = CupertinoDynamicColor.resolve(_kPanelShadow, context);
    final panelSeparator = CupertinoDynamicColor.resolve(
      _kPanelSeparator,
      context,
    );

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pt = _panelT;
        final outlineT = _outlineT;
        // easeOutBack peaks at ~1.07 before settling — the whole card briefly
        // grows past its resting size giving the characteristic gel "bloom".
        // Starting from 0.60 (was 0.72) widens the bloom range so the spring
        // overshoot is more visually pronounced.
        final panelScale = 0.60 + 0.40 * Curves.easeOutBack.transform(pt);

        final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
        final resolvedOutline = resolveThemeColor(kTertiaryLabel, context)
            .withValues(
              alpha: resolveThemeColor(kTertiaryLabel, context).a * outlineT,
            );

        return Transform.scale(
          scale: panelScale,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: pt,
            child: Container(
              decoration: ShapeDecoration(
                color: panelBg,
                shape: widget.actions.length == 1
                    ? SquircleStadiumBorder(
                        side: isDark
                            ? BorderSide(color: resolvedOutline, width: 0.5)
                            : BorderSide.none,
                      )
                    : BoundedContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(_kCornerRadius),
                        side: isDark
                            ? BorderSide(color: resolvedOutline, width: 0.5)
                            : BorderSide.none,
                      ),
                shadows: resolveThemeShadows([
                  BoxShadow(
                    color: panelShadow,
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ], context),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < widget.actions.length; i++) ...[
                    if (i > 0) _buildSeparator(i, panelSeparator),
                    _buildRow(i),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(int i) {
    final t = _rowT(i);
    // easeOutBack overshoots ~1.27× at its peak before settling — the
    // visible spring "pop" on each individual row.
    // Starting from 0.76 (was 0.85) gives each row a more pronounced pop.
    final scale = 0.76 + 0.24 * Curves.easeOutBack.transform(t);
    return Opacity(
      opacity: t,
      child: Transform.scale(
        scale: scale,
        child: _ActionRow(action: widget.actions[i]),
      ),
    );
  }

  Widget _buildSeparator(int i, Color color) {
    return Opacity(
      opacity: min(_rowT(i), _outlineT),
      child: Container(height: 0.5, color: color),
    );
  }
}

// ── Single action row — always Light Mode, heavier weight ────────────────────
class _ActionRow extends StatefulWidget {
  final _MenuAction action;
  const _ActionRow({required this.action});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dest = widget.action.isDestructive;
    final textColor = dest
        ? CupertinoColors.destructiveRed
        : CupertinoDynamicColor.resolve(kPrimaryLabel, context);
    final pressColor = CupertinoDynamicColor.resolve(
      _kPanelPressHighlight,
      context,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        widget.action.onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        height: 52,
        color: _pressed ? pressColor : const Color(0x00000000),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.action.label,
                style: TextStyle(
                  inherit: false,
                  color: textColor,
                  fontSize: 15,
                  fontFamily: kSFProText,
                  // w500 gives the slightly bolder SF Pro look used in iOS menus.
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking16,
                ),
              ),
            ),
            // SearchWeightedIcon adds a thin halo shadow that fattens the
            // stroke to ≈ 2 px visually, matching iOS SF Symbol "Regular" weight.
            SearchWeightedIcon(
              widget.action.icon,
              size: 18,
              color: textColor,
              weight: 1.5,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAP-CALLBACK PROPAGATION
// ══════════════════════════════════════════════════════════════════════════════
// InheritedWidget so every tile/row can reach the "navigate to DCV" callback
// without prop-drilling through _CategoryCard → _CategoryRow.
class _CategoryTapCallback extends InheritedWidget {
  final void Function(String label, Color color)? onTileTapped;

  const _CategoryTapCallback({
    required this.onTileTapped,
    required super.child,
  });

  static _CategoryTapCallback? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CategoryTapCallback>();

  @override
  bool updateShouldNotify(_CategoryTapCallback old) =>
      old.onTileTapped != onTileTapped;
}

// ── Search header delegate ────────────────────────────────────────────────────
// Wraps the search bar row (and optional separator) inside a
// SliverPersistentHeader so the header can be either floating (normal mode,
// scrolls away / floats back) or pinned (search mode, never moves even during
// rubber-band overscroll).  The widget at the delegate's stable tree position
// is always the same type, so Flutter updates-in-place and the AppSearchBar
// element (and its NativeTextInput platform view) is never remounted — keyboard
// focus is preserved across normal ↔ search mode transitions.
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SearchHeaderDelegate({
    required this.searchBarRow,
    required this.extent,
    required this.showSeparator,
  });
  final Widget searchBarRow;
  final double extent;
  final bool showSeparator;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  // The widget tree structure is ALWAYS Column → [searchBarRow, ...] so the
  // AppSearchBar element is never remounted when showSeparator toggles.
  // Flutter preserves the element at each stable position in the children
  // list; only the separator children after it are added/removed.
  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: resolveThemeColor(kBackgroundColor, ctx),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchBarRow,
            if (showSeparator) ...[
              const SizedBox(height: 18),
              Container(
                height: 0.5,
                color: resolveThemeColor(kSeparatorColor, ctx),
              ),
            ],
          ],
        ),
      );

  @override
  bool shouldRebuild(_SearchHeaderDelegate old) => true;
}

// ══════════════════════════════════════════════════════════════════════════════
// STORAGE-FULL BANNER
// ══════════════════════════════════════════════════════════════════════════════

/// A non-intrusive banner that slides up from the bottom of the screen when
/// category persistence fails.  Auto-dismisses after 4 seconds.
class _StorageFullBanner extends StatefulWidget {
  final VoidCallback onDismissed;
  const _StorageFullBanner({required this.onDismissed});

  @override
  State<_StorageFullBanner> createState() => _StorageFullBannerState();
}

class _StorageFullBannerState extends State<_StorageFullBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _ctrl.reverse().then((_) => widget.onDismissed());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final fg = isDark ? CupertinoColors.white : CupertinoColors.black;
    final sub = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, (1 - _slide.value) * 120),
          child: child,
        ),
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            margin: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  color: CupertinoColors.systemOrange,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Couldn\u2019t save your categories',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Device storage may be full.',
                        style: TextStyle(fontSize: 13, color: sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN TAB WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class EventsTab extends StatefulWidget {
  final ValueChanged<bool>? onSearchFocusChanged;
  final Animation<double>? searchModeAnimation;
  final String? activeDCV;
  final void Function(String label, Color color)? onTileTapped;
  // AnimationController owned by AppShell.  0.0 = grid fully visible,
  // 1.0 = DCV fully visible.  Passing the same controller to both EventsTab
  // and the AppShell header AnimatedBuilder guarantees they rebuild and paint
  // in the exact same Flutter frame — zero lag on Impeller/Skia.
  final AnimationController dcvSlideController;

  // Fired whenever a category matching [activeDCV] has its color/icon edited
  // while its DCV is open, so AppShell can refresh the header's cached
  // accent colour (captured once at DCV-entry time) instead of leaving it
  // stale until the user leaves and re-enters the DCV.
  final void Function(String label, Color color)? onActiveDCVCategoryChanged;

  /// Called when the user taps the edit button on an event card.  AppShell
  /// forwards this to [CalendarTabState.showEditEventSheet] so the edit sheet
  /// can be opened without EventsTab importing CalendarTab's private widgets.
  final void Function(ScheduledEvent event)? onEditEvent;

  /// Active sort mode for the DCV ('Manual', 'Deadline', 'Title', …).
  final String? dcvSortBy;

  /// Active sort direction for the DCV ('Soonest First', 'A → Z', …).
  final String? dcvSortDir;

  /// Whether the DCV's initial Manual view should show date headers.
  ///
  /// This is separate from the category's Sections capability. Section-
  /// enabled categories start flat with no date headers; fixed date-based
  /// Smart Categories keep their existing manual date grouping.
  final bool dcvShowManualDateSections;

  const EventsTab({
    super.key,
    this.onSearchFocusChanged,
    this.searchModeAnimation,
    this.activeDCV,
    this.onTileTapped,
    this.onActiveDCVCategoryChanged,
    this.onEditEvent,
    this.dcvSortBy,
    this.dcvSortDir,
    this.dcvShowManualDateSections = true,
    required this.dcvSlideController,
  });

  @override
  State<EventsTab> createState() => EventsTabState();
}

/// Public so AppShell can hold a `GlobalKey<EventsTabState>` and call
/// `deactivate()` when the user switches away from the Events tab.
class EventsTabState extends State<EventsTab> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  // GlobalKey keeps _AppSearchBarState alive when the parent sliver switches
  // between SliverToBoxAdapter (unfocused) and SliverPersistentHeader (focused).
  // Without this key, the element is remounted on every search-mode transition,
  // which kills any in-progress STT session (onPartial/onFinal see !mounted).
  final _searchBarKey = GlobalKey<AppSearchBarState>();
  // dcvSlideController is owned by AppShell — EventsTabState must not dispose it.
  bool _searchFocused = false;
  bool _activatedFromOffScreen = false;
  double _savedScrollOffset = 0;
  // Re-entrancy guard for _enforceScrollLock — prevents jumpTo from
  // triggering the listener a second time and causing an infinite loop.
  bool _lockingScrollDrift = false;
  bool _greyActive = false;
  bool _greyFadeIn = false;
  String _searchText = '';
  bool _wasSearchFocusedBeforePause = false;

  // ── Smart search results (filled asynchronously by _scheduleSearch) ────────
  List<SearchHit> _searchPrimary = [];
  List<SearchHit> _searchOverflow = [];
  List<SearchHit> _searchAll = [];
  String? _searchSuggestion;
  Timer? _searchDebounce;

  // DCV category labels — used for display/lookup only.
  static const _kDCVLabels = [
    'Today',
    'Tomorrow',
    'This Week',
    'Next Week',
    'Scheduled',
    'Unscheduled',
    'All Events',
    'Completed',
  ];

  // ── Category state ────────────────────────────────────────────────────────
  // Mutable lists: user categories that are NOT pinned, and those that ARE.
  final List<_UserCategory> _userCategories = List.from(_kUserCategories);
  final List<_UserCategory> _pinnedUserCategories = [];

  /// User-created DCV sections, keyed by the category label. An empty name
  /// represents a newly-created section whose visible placeholder is
  /// "New Section".
  final Map<String, List<String>> _dcvCustomSectionNames = {};
  final Map<String, List<List<String>>> _dcvCustomSectionEventIds = {};

  // ── Group state ───────────────────────────────────────────────────────────
  // All groups in the CATEGORIES list section.
  final List<_CategoryGroup> _categoryGroups = [];
  // Ordered top-level token list for the CATEGORIES section.
  // Each entry is either a category ID (solo/ungrouped) or 'grp-<groupId>'.
  // Initialized in initState and persisted via SharedPreferences.
  final List<String> _listTopOrder = [];
  // IDs of currently expanded groups (members visible below header).
  final Set<String> _expandedGroupIds = {};
  // Groups whose members are animating into view (expand in-flight).
  final Set<String> _expandingGroupIds = {};
  // Groups whose members are animating out of view (collapse in-flight).
  final Set<String> _collapsingGroupIds = {};

  // ── Drag → group-creation state ───────────────────────────────────────────
  // _dragGroupTargetCat: confirmed group target (ghost snapped, glow visible).
  // _pendingGroupTarget: the category the ghost is hovering over but the dwell
  //   timer hasn't fired yet.  Normal reorder still runs during the dwell.
  // _groupDetectionTimer: fires after _kGroupDwellMs ms of hovering to confirm.
  // _dwellStartPhysicalY: ghost rawTopY when the current dwell timer started —
  //   used to keep the timer alive through reorder swaps (which change logical
  //   slot indices without moving the user's finger).
  _UserCategory? _dragGroupTargetCat;
  bool _dragGroupHapticFired = false;
  // Y-position (rawTopY) at the moment the dwell glow was confirmed.
  // Used as the anchor for the "significant move → cancel glow" threshold.
  double? _confirmedGroupY;
  _UserCategory? _pendingGroupTarget;
  double? _dwellStartPhysicalY;
  Timer? _groupDetectionTimer;
  // Non-null while a group-MEMBER tile is being dragged.  Tracks which group
  // the tile currently belongs to (can change to null if it exits the group).
  String? _draggingListGroupId;
  // Non-null while a group HEADER tile is being dragged.
  _CategoryGroup? _draggingGroupHeader;

  // Join-group dwell: a solo cat must hover over a group's member area for
  // 400 ms before actually joining (so expanded groups can be dragged past).
  Timer? _joinGroupDwellTimer;
  String? _pendingJoinGroupId;

  // Member→other group dwell: a group member must hover over a different
  // group's header or member area for 400 ms before joining it.
  Timer? _memberJoinGroupDwellTimer;
  String? _pendingMemberJoinGroupId;

  // Collapsed-group dwell: any dragged cat hovering over a COLLAPSED group
  // header glows immediately and joins on timer-fire if held long enough.
  Timer? _collapsedGroupDwellTimer;
  String? _collapsedGroupDwellId; // counting-down phase: glow showing
  String? _confirmedCollapsedGroupId; // timer fired: glow locked, join on lift
  double? _collapsedGroupDwellStartY; // rawTopY when ghost first entered zone

  // ── Cross-section drag ────────────────────────────────────────────────────
  // Set while a solo list-category ghost is above the list stack's top edge.
  // On lift the category is pinned (moved to the grid) instead of reordered.
  bool _listDragCrossingToGrid = false;
  // Set while a pinned user-category ghost is below the grid stack's bottom
  // edge.  On lift the category is unpinned (moved to the list).
  // Smart-label tiles (String keys) are never eligible.
  bool _gridDragCrossingToList = false;

  // Target slot in _gridCombinedOrder while a list-cat crosses into the grid.
  // The cat object is a live placeholder in _gridCombinedOrder while crossing.
  int? _crossGridTargetSlot;
  // Target index in _listTopOrder while a grid-cat crosses into the list.
  // The cat.id token is a live placeholder in _listTopOrder while crossing.
  int? _crossListTargetIdx;
  // Ghost's GLOBAL top-Y while a grid-cat crosses into the list.
  // Stored in global coords so the overlay builder does not depend on the list
  // RenderBox being accessible (it can be off-screen / lazily unmounted).
  double? _crossListGhostGlobalTop;

  // How long (ms) the ghost must hover over another solo category before group
  // mode is confirmed.  Long enough to feel deliberate, short enough to feel instant.
  static const int _kGroupDwellMs = 600;

  // Custom circle colors for the 8 fixed smart tiles, keyed by label.
  // Smart tiles have no title/description/icon to edit — only their color
  // swatch is user-editable — so this is the only piece of state they need.
  final Map<String, Color> _smartCategoryColors = {};

  /// Live event count per user category id, recomputed each build() from
  /// [EventStore.instance.expandedEvents()].  Replaces the stale persisted
  /// [_UserCategory.count] field everywhere in the UI so the numbers update
  /// immediately whenever events are added, edited, or removed.
  Map<String, int> _liveEventCounts = {};

  // Labels of smart tiles the user has archived (hidden from the grid).
  // Like user-category archiving, there's no reveal/unarchive UI yet.
  final Set<String> _archivedSmartCategories = {};

  // Animation sets — used by the grid and list to drive implicit animations.
  final Set<_UserCategory> _removingFromList = {};
  final Set<_UserCategory> _newInList = {};
  final Set<_UserCategory> _removingFromGrid = {};
  final Set<_UserCategory> _newInGrid = {};

  // Archive: soft slide + fade + collapse — reads as "tucked away", not
  // destroyed. Kept separate from pin/unpin's _removingFrom* sets so the two
  // actions can carry different curves/durations without interfering.
  final Set<_UserCategory> _archivingFromList = {};
  final Set<_UserCategory> _archivingFromGrid = {};
  // Delete: sharper shrink + fade + collapse with a brief destructive-red
  // flash — reads as final, distinct from archive's softness.
  final Set<_UserCategory> _deletingFromList = {};
  final Set<_UserCategory> _deletingFromGrid = {};
  // Create: scale + fade pop-in (with slight overshoot) — distinct from
  // unpin's height-expand so a brand new category doesn't look like one
  // returning from the grid.
  final Set<_UserCategory> _poppingInList = {};
  // Smart tiles are archive-only (no delete) and have no object identity to
  // key a Set<_UserCategory> by, so they're tracked by label instead.
  final Set<String> _archivingSmartLabels = {};

  // ── GlobalKeys for drag-reorder coordinate conversion ─────────────────────
  // These are attached to the grid Stack and list Stack so we can call
  // renderObject.globalToLocal() during drag updates.
  final GlobalKey _gridStackKey = GlobalKey();
  final GlobalKey _listStackKey = GlobalKey();

  // ── List drag overlay ──────────────────────────────────────────────────────
  // When a list row is being dragged, the ghost tile is rendered in the global
  // Overlay above all scroll content (headers, buttons, etc.) so its z-index
  // is always correct.  A transparent Opacity(0) placeholder stays in the
  // Stack to animate the drop-back when drag ends.
  OverlayEntry? _listDragOverlayEntry;

  // Smart category display order (all labels, including archived ones).
  // Initialised from _buildSmartTiles() in initState; persisted and updated
  // by drag-reorder so the user's arrangement survives restarts.
  final List<String> _smartCategoryOrder = [];
  // Unified ordering for the grid: both smart labels (String) and pinned
  // user categories (_UserCategory) in a single cross-section sequence.
  // Archived items are NOT kept here — they are removed on archive and not
  // re-added until an unarchive flow exists.
  final List<Object> _gridCombinedOrder = [];

  // ── Grid resize scroll compensation ───────────────────────────────────────
  // When the grid grows (a user-category is pinned), its AnimatedContainer
  // animates the height over 280 ms.  Because the grid sits above the list in
  // the CustomScrollView, each animation frame shifts the list section downward
  // in the viewport — appearing as an unwanted slow scroll.  We compensate by
  // reading the grid's rendered height every frame and immediately jumping the
  // scroll controller to (_gridResizeScrollBase + totalGrowth), keeping the
  // viewport anchored relative to the pre-pin scroll position.
  bool _trackingGridResize = false;
  double _prevGridRenderHeight = 0;
  double _initialGridRenderHeight = 0; // grid height at tracking start
  double _gridResizeScrollBase = 0; // scroll offset saved BEFORE phase-1

  /// Call this BEFORE the setState that adds a tile to the grid.
  /// [scrollBase] is the scroll offset saved BEFORE the phase-1 row collapse
  /// so that any maxScrollExtent clamp during collapse is not carried forward.
  void _startGridResizeTracking(double scrollBase) {
    final box = _gridStackKey.currentContext?.findRenderObject() as RenderBox?;
    final h = (box != null && box.hasSize) ? box.size.height : 0.0;
    _prevGridRenderHeight = h;
    _initialGridRenderHeight = h;
    _gridResizeScrollBase = scrollBase;
    _trackingGridResize = true;
    WidgetsBinding.instance.addPostFrameCallback(_tickGridResizeCompensation);
    // Stop tracking after the AnimatedContainer animation finishes.
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _trackingGridResize = false;
    });
  }

  void _tickGridResizeCompensation(Duration _) {
    if (!mounted || !_trackingGridResize) return;
    final box = _gridStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && _scrollController.hasClients) {
      final currentH = box.size.height;
      final totalGrowth = currentH - _initialGridRenderHeight;
      if (totalGrowth.abs() > 0.01) {
        // Target offset = pre-phase-1 base + however much the grid has grown
        // so far in this animation.  Using the saved base (not the live
        // offset) prevents the phase-1 maxScrollExtent clamp — which briefly
        // shifts the viewport upward as the collapsing list row shrinks the
        // scroll content — from carrying forward into the compensation.
        final newOffset = (_gridResizeScrollBase + totalGrowth).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(newOffset);
      }
      _prevGridRenderHeight = currentH;
    }
    if (_trackingGridResize) {
      WidgetsBinding.instance.addPostFrameCallback(_tickGridResizeCompensation);
    }
  }

  // ── Grid drag-reorder state (unified: smart tiles + pinned user tiles) ────
  // _draggingGridKey is 'smart_$label' for smart tiles, _UserCategory for pinned.
  Object? _draggingGridKey;
  Offset? _dragGridTopLeft; // tile top-left in grid-Stack-local coords
  Offset? _dragGridGrabOffset; // pointer offset within tile at grab time
  double? _dragGridTileWidth; // captured tileWidth at drag start
  bool _dragGridFullWidth =
      false; // true while targeting the solitary final slot
  OverlayEntry? _gridDragOverlayEntry;

  // ── List (user-categories) drag-reorder state ─────────────────────────────
  _UserCategory? _draggingListCat;
  double? _dragListTopY; // slot top-Y in list-Stack-local coords
  double? _dragListGrabOffsetY; // pointer offset within slot at grab time

  void _pinCategory(_UserCategory cat) {
    // Remove from any group before pinning.
    _removeFromGroupById(cat.id);
    _listTopOrder.remove(cat.id);

    // Save scroll position BEFORE the phase-1 row collapse so we can use it
    // as the base for phase-2 compensation.  The collapse temporarily shrinks
    // the list content, which can clamp the scroll offset upward and bring
    // the grid into view — this anchor prevents that clamp from carrying
    // forward into the per-frame compensation loop.
    final scrollBase = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    // Phase 1: collapse the list row (AnimatedAlign heightFactor 1 → 0).
    setState(() => _removingFromList.add(cat));

    // Phase 2: once the row has collapsed, move the data and reveal the
    // new grid tile with a spring-in scale + fade. The grid's own Stack
    // container height animates itself (see _buildGrid), and every other
    // tile's AnimatedPositioned smoothly reflows into its new row/column.
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      // Record the grid's current rendered height before it changes so the
      // per-frame compensation loop can compute the total growth each frame.
      _startGridResizeTracking(scrollBase);
      setState(() {
        _removingFromList.remove(cat);
        _userCategories.remove(cat);
        _pinnedUserCategories.add(cat);
        _gridCombinedOrder.add(cat); // append to end of unified order
        _newInGrid.add(cat); // tile starts at scale 0.75, opacity 0
      });
      _saveCategories();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _newInGrid.remove(cat));
      });
    });
  }

  void _unpinCategory(_UserCategory cat) {
    // Phase 1: fade + scale the grid tile out.
    setState(() => _removingFromGrid.add(cat));

    // Phase 2: once the tile has exited, move the data and expand the
    // list row (AnimatedAlign heightFactor 0 → 1) + fade it in. The grid
    // reflows the remaining tiles on its own (see _buildGrid).
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _removingFromGrid.remove(cat);
        _pinnedUserCategories.remove(cat);
        _gridCombinedOrder.remove(cat); // remove from unified order
        _userCategories.add(cat);
        _listTopOrder.add(cat.id); // append as solo at end of list
        _newInList.add(cat); // row starts at height 0, opacity 0
      });
      _saveCategories();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _newInList.remove(cat));
      });
    });
  }

  /// Non-archived user categories, in stored order — what the list actually
  /// displays. Archiving hides a category without deleting it.
  List<_UserCategory> get _visibleUserCategories =>
      _userCategories.where((c) => !c.archived).toList();

  /// Builds the ordered flat item list for the CATEGORIES section.
  /// Groups whose members are expanded also include their member rows.
  /// Used by _CategoryCard for rendering and by the drag-reorder system.
  List<_FlatItem> _buildFlatDisplayList() {
    final catById = <String, _UserCategory>{
      for (final c in _userCategories) c.id: c,
      // While a pinned category is crossing into the list section, include it
      // so the gap slot renders correctly and live-reorder can find it.
      if (_gridDragCrossingToList && _draggingListCat != null)
        _draggingListCat!.id: _draggingListCat!,
    };
    final groupById = <String, _CategoryGroup>{
      for (final g in _categoryGroups) g.id: g,
    };
    final result = <_FlatItem>[];

    for (final token in _listTopOrder) {
      if (token.startsWith('grp-')) {
        final gid = token.substring(4);
        final g = groupById[gid];
        if (g == null) continue;
        result.add(_FlatItem.groupHeader(g));
        final showMembers =
            _expandedGroupIds.contains(gid) ||
            _expandingGroupIds.contains(gid) ||
            _collapsingGroupIds.contains(gid);
        if (showMembers) {
          for (final mid in g.memberIds) {
            final c = catById[mid];
            if (c != null && !c.archived) {
              result.add(_FlatItem.groupMember(c, gid));
            }
          }
        }
      } else {
        final c = catById[token];
        if (c != null && !c.archived) {
          result.add(_FlatItem.solo(c));
        }
      }
    }
    return result;
  }

  /// Whether the CATEGORIES list has any visible content (solo cats or groups).
  bool get _hasVisibleListItems =>
      _listTopOrder.isNotEmpty &&
      (_listTopOrder.any(
        (t) =>
            t.startsWith('grp-') ||
            (_userCategories
                    .firstWhere(
                      (c) => c.id == t,
                      orElse: () => const _UserCategory(
                        id: '',
                        name: '',
                        description: '',
                        count: 0,
                        archived: true,
                      ),
                    )
                    .archived ==
                false),
      ));

  // ── Group management ──────────────────────────────────────────────────────

  /// Creates a group and updates the list order.
  void _createGroup(_CategoryGroup group) {
    setState(() {
      _categoryGroups.add(group);
      // Replace the first member's slot with the group token;
      // remove the remaining members' solo slots.
      bool inserted = false;
      final toRemove = <String>[];
      for (int i = 0; i < _listTopOrder.length; i++) {
        final token = _listTopOrder[i];
        if (group.memberIds.contains(token)) {
          if (!inserted) {
            _listTopOrder[i] = 'grp-${group.id}';
            inserted = true;
          } else {
            toRemove.add(token);
          }
        }
      }
      _listTopOrder.removeWhere((t) => toRemove.contains(t));
      if (!inserted) _listTopOrder.add('grp-${group.id}');
    });
    _saveCategories();
  }

  /// Dissolves a group, returning all its members to solo positions.
  void _ungroupGroup(_CategoryGroup group) {
    setState(() {
      final idx = _listTopOrder.indexOf('grp-${group.id}');
      if (idx != -1) {
        _listTopOrder.removeAt(idx);
        // Re-insert member IDs at the position the group occupied,
        // keeping only IDs of categories that still exist.
        final catById = {for (final c in _userCategories) c.id: c};
        final soloIds = group.memberIds
            .where((id) => catById.containsKey(id))
            .toList();
        _listTopOrder.insertAll(idx, soloIds);
      }
      _categoryGroups.remove(group);
      _expandedGroupIds.remove(group.id);
      _expandingGroupIds.remove(group.id);
      _collapsingGroupIds.remove(group.id);
    });
    _saveCategories();
  }

  /// Updates a group's name or member list.
  void _updateGroup(_CategoryGroup oldGroup, _CategoryGroup updated) {
    final idx = _categoryGroups.indexOf(oldGroup);
    if (idx == -1) return;
    // Find members removed from the group and re-insert them as solo items.
    final removedIds = oldGroup.memberIds
        .where((id) => !updated.memberIds.contains(id))
        .toList();
    // Find members added to the group and remove them from solo slots.
    final addedIds = updated.memberIds
        .where((id) => !oldGroup.memberIds.contains(id))
        .toList();

    setState(() {
      _categoryGroups[idx] = updated;
      // Remove newly-added members from their solo slots.
      _listTopOrder.removeWhere((t) => addedIds.contains(t));
      // Re-insert removed members after the group.
      final grpIdx = _listTopOrder.indexOf('grp-${oldGroup.id}');
      for (int i = 0; i < removedIds.length; i++) {
        final insertAt = grpIdx != -1 ? grpIdx + 1 + i : _listTopOrder.length;
        _listTopOrder.insert(
          insertAt.clamp(0, _listTopOrder.length),
          removedIds[i],
        );
      }
    });
    _saveCategories();
  }

  /// Toggles the expanded/collapsed state of a group with animation.
  void _toggleGroupExpanded(String groupId) {
    if (_expandedGroupIds.contains(groupId)) {
      // Collapse: members play out, then we hide them.
      // Also evict any stale _expandingGroupIds entry so showMembers goes false.
      setState(() {
        _expandedGroupIds.remove(groupId);
        _expandingGroupIds.remove(groupId);
        _collapsingGroupIds.add(groupId);
      });
      Future.delayed(const Duration(milliseconds: 280), () {
        if (mounted) setState(() => _collapsingGroupIds.remove(groupId));
      });
    } else {
      // Expand: add members to the flat list (triggers AnimatedPositioned).
      setState(() {
        _expandingGroupIds.add(groupId);
        _expandedGroupIds.add(groupId);
      });
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) setState(() => _expandingGroupIds.remove(groupId));
      });
    }
  }

  /// Removes a category from whatever group it belongs to (if any).
  /// If the group would drop below 2 members, dissolves it.
  void _removeFromGroupById(String catId) {
    for (final g in List<_CategoryGroup>.from(_categoryGroups)) {
      if (g.memberIds.contains(catId)) {
        final newIds = List<String>.from(g.memberIds)..remove(catId);
        if (newIds.length < 2) {
          // Dissolve the group — remaining member becomes a solo item.
          _ungroupGroup(g);
          // Also put the removed category's token back (it was already solo).
        } else {
          final gIdx = _categoryGroups.indexOf(g);
          if (gIdx != -1) _categoryGroups[gIdx] = g.copyWith(memberIds: newIds);
        }
        break;
      }
    }
  }

  /// Opens the New Group modal pre-seeded with the two categories that were
  /// dragged together.  Called when the user releases the drag over a target.
  void _openNewGroupSheet(_UserCategory cat1, _UserCategory cat2) {
    final allSolo = _userCategories.where((c) => !c.archived).toList();
    showRoundedCupertinoSheet<void>(
      context: context,
      pageBuilder: (ctx) => _NewGroupSheet(
        allCategories: allSolo,
        existingGroups: _categoryGroups,
        initialMemberIds: [cat1.id, cat2.id],
        onSave: _createGroup,
      ),
    );
  }

  /// Opens the Edit Group modal for an existing group.
  void _editGroupSheet(_CategoryGroup group) {
    final allSolo = _userCategories.where((c) => !c.archived).toList();
    showRoundedCupertinoSheet<void>(
      context: context,
      pageBuilder: (ctx) => _NewGroupSheet(
        allCategories: allSolo,
        existingGroups: _categoryGroups,
        initialMemberIds: group.memberIds,
        initial: group,
        onSave: (updated) => _updateGroup(group, updated),
      ),
    );
  }

  /// Opens the confirmation sheet before dissolving or deleting a group.
  void _openDeleteGroupSheet(_CategoryGroup group) async {
    final choice = await _DeleteGroupSheet.show(context, groupName: group.name);
    if (!mounted || choice == null) return;
    switch (choice) {
      case _DeleteGroupChoice.only:
        _ungroupGroup(group);
      case _DeleteGroupChoice.withCategories:
        _deleteGroupAndCategories(group);
    }
  }

  /// Deletes the group and its member categories using the same visible
  /// category-collapse animation as the existing Delete Category action.
  void _deleteGroupAndCategories(_CategoryGroup group) {
    final categories = _userCategories
        .where((cat) => group.memberIds.contains(cat.id))
        .toList();
    if (categories.isEmpty) {
      _ungroupGroup(group);
      return;
    }

    setState(() => _deletingFromList.addAll(categories));
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      EventStore.instance.reassignCategories(
        fromCategoryIds: categories.map((cat) => cat.id).toSet(),
      );
      setState(() {
        _deletingFromList.removeAll(categories);
        _userCategories.removeWhere((cat) => group.memberIds.contains(cat.id));
        _listTopOrder.removeWhere(
          (token) =>
              token == 'grp-${group.id}' || group.memberIds.contains(token),
        );
        _categoryGroups.removeWhere((candidate) => candidate.id == group.id);
        _expandedGroupIds.remove(group.id);
        _expandingGroupIds.remove(group.id);
        _collapsingGroupIds.remove(group.id);
      });
      _saveCategories();
    });
  }

  /// Phase 1: shrink + fade the row with a brief destructive-red flash.
  /// Phase 2 (after the flash + collapse finish): actually remove the data.
  void _deleteUserCategory(_UserCategory cat) {
    setState(() => _deletingFromList.add(cat));
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      EventStore.instance.reassignCategories(fromCategoryIds: {cat.id});
      setState(() {
        _deletingFromList.remove(cat);
        _userCategories.remove(cat);
        // Remove from group (dissolves if < 2 remain) or solo slot.
        _removeFromGroupById(cat.id);
        _listTopOrder.remove(cat.id);
      });
      _saveCategories();
    });
  }

  void _deletePinnedCategory(_UserCategory cat) {
    setState(() => _deletingFromGrid.add(cat));
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      EventStore.instance.reassignCategories(fromCategoryIds: {cat.id});
      setState(() {
        _deletingFromGrid.remove(cat);
        _pinnedUserCategories.remove(cat);
        _gridCombinedOrder.remove(cat);
      });
      _saveCategories();
    });
  }

  // ── Grid drag-reorder (unified: smart tiles + pinned user tiles) ──────────

  void _onGridReorderStart(Object key, Offset globalPos) {
    final box = _gridStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final tileWidth = (box.size.width - _AnimatedCategoryGrid._colGap) / 2;

    // Look up the tile's visual slot directly from _gridCombinedOrder, which is
    // always up-to-date.  Section-local lists (_smartCategoryOrder for smart
    // tiles, _pinnedUserCategories for pinned tiles) are NOT updated during
    // drag-reorder — only _gridCombinedOrder is mutated live — so using them
    // here would produce stale indices that drift further apart after each
    // reorder session.
    final Object lookupKey = key is String ? key.substring(6) : key;
    final gridIdx = _gridCombinedOrder.indexOf(lookupKey);
    if (gridIdx == -1) return;

    final col = gridIdx % 2;
    final row = gridIdx ~/ 2;
    final tileTopLeft = Offset(
      col * (tileWidth + _AnimatedCategoryGrid._colGap),
      row * (_AnimatedCategoryGrid._rowHeight + _AnimatedCategoryGrid._rowGap),
    );
    final localPos = box.globalToLocal(globalPos);
    // When dragging from the full-width (solitary last) tile the grab offset X
    // can be up to maxWidth, but the ghost is always tileWidth wide.  Clamp dx
    // so the ghost always appears under the finger rather than to its right.
    final rawGrab = localPos - tileTopLeft;
    final isFullWidth =
        _gridCombinedOrder.length.isOdd &&
        gridIdx == _gridCombinedOrder.length - 1;
    final grab = isFullWidth
        ? Offset(rawGrab.dx.clamp(0.0, tileWidth), rawGrab.dy)
        : rawGrab;
    setState(() {
      _draggingGridKey = key;
      _dragGridGrabOffset = grab;
      _dragGridTopLeft = tileTopLeft;
      _dragGridTileWidth = tileWidth;
      _dragGridFullWidth = isFullWidth;
    });
    // Insert drag ghost into the global Overlay (above all scroll content).
    _gridDragOverlayEntry?.remove();
    _gridDragOverlayEntry = OverlayEntry(builder: _buildGridDragOverlay);
    Overlay.of(context).insert(_gridDragOverlayEntry!);
  }

  void _onGridReorderUpdate(Object key, Offset globalPos) {
    final box = _gridStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || _draggingGridKey != key) return;
    final grab = _dragGridGrabOffset;
    if (grab == null) return;
    final localPos = box.globalToLocal(globalPos);
    final newTopLeft = localPos - grab;

    // ── Cross-section (unpin) detection ───────────────────────────────────────
    // Only pinned user-category tiles (not smart-label strings) may leave the
    // grid.  Crossing is confirmed when the ghost centre drops more than half a
    // tile height below the grid stack's bottom edge.
    if (key is _UserCategory) {
      final crossingDown =
          localPos.dy >
          box.size.height + _AnimatedCategoryGrid._rowHeight * 0.5;
      if (crossingDown && !_gridDragCrossingToList) {
        // ── First entry into list ─────────────────────────────────────────
        HapticFeedback.selectionClick();
        final listBox =
            _listStackKey.currentContext?.findRenderObject() as RenderBox?;
        final rowHeight = _eventsCategoryListRowHeight(
          context,
          item: _FlatItem.solo(key),
          liveEventCounts: _liveEventCounts,
        );
        if (listBox != null) {
          final listLocal = listBox.globalToLocal(globalPos);
          final listItems = _buildFlatDisplayList();
          final slot = _eventsCategoryListIndexAtY(
            context,
            listItems,
            listLocal.dy,
            _liveEventCounts,
          ).clamp(0, _listTopOrder.length);
          // Map the tile grab-Y to an equivalent list-row grab-Y so the row
          // ghost stays under the finger after the shape transition.
          final grabY = grab.dy.clamp(0.0, _AnimatedCategoryGrid._rowHeight);
          final rowGrabY = grabY.clamp(0.0, rowHeight).toDouble();
          setState(() {
            _gridDragCrossingToList = true;
            _crossListTargetIdx = slot;
            _listTopOrder.insert(slot, key.id);
            // Do NOT remove key from _gridCombinedOrder yet — keeping the
            // tile entry alive preserves the _CategoryContextMenuState and its
            // long-press GestureDetector so pointer events keep arriving.
            // The tile is invisible because opacity is 0 while _draggingGridKey == key.
            _draggingListCat = key;
            // Raw gap position (list-local) — tracks the finger, not the slot.
            _dragListTopY = listLocal.dy - rowGrabY;
            _dragListGrabOffsetY = rowGrabY;
            _dragGridTopLeft = newTopLeft;
            // Global ghost Y — robust even when list is off-screen.
            _crossListGhostGlobalTop = globalPos.dy - rowGrabY;
          });
        } else {
          setState(() {
            _gridDragCrossingToList = true;
            _dragGridTopLeft = newTopLeft;
          });
        }
        _gridDragOverlayEntry?.markNeedsBuild();
        return;
      } else if (!crossingDown && _gridDragCrossingToList) {
        // ── Exiting list back into grid ───────────────────────────────────
        final tw =
            _dragGridTileWidth ??
            (box.size.width - _AnimatedCategoryGrid._colGap) / 2;
        final cx = newTopLeft.dx + tw / 2;
        final cy = newTopLeft.dy + _AnimatedCategoryGrid._rowHeight / 2;
        final reCol = (cx / (tw + _AnimatedCategoryGrid._colGap)).round().clamp(
          0,
          1,
        );
        final reRow =
            (cy /
                    (_AnimatedCategoryGrid._rowHeight +
                        _AnimatedCategoryGrid._rowGap))
                .floor()
                .clamp(0, 999);
        final reSlot = (reRow * 2 + reCol).clamp(
          0,
          _gridCombinedOrder.length - 1,
        );
        setState(() {
          _gridDragCrossingToList = false;
          _crossListTargetIdx = null;
          _crossListGhostGlobalTop = null;
          _listTopOrder.remove(key.id);
          // Cat was never removed from _gridCombinedOrder — just reposition it.
          final currentGridIdx = _gridCombinedOrder.indexOf(key);
          if (currentGridIdx != -1) {
            _gridCombinedOrder.removeAt(currentGridIdx);
            _gridCombinedOrder.insert(
              reSlot.clamp(0, _gridCombinedOrder.length),
              key,
            );
          }
          _draggingListCat = null;
          _dragListTopY = null;
          _dragListGrabOffsetY = null;
        });
        // fall through to normal grid reorder below
      } else if (crossingDown && _gridDragCrossingToList) {
        // ── Live reorder + dwell/group within the list while crossing ─────
        // Delegate all list ordering, dwell detection, and group-creation
        // logic to the same handler used by a native list drag.  It reads
        // _dragListGrabOffsetY and computes list-local coordinates itself.
        final rowGrabY =
            _dragListGrabOffsetY ??
            (_eventsCategoryListRowHeight(
                  context,
                  item: _FlatItem.solo(key as _UserCategory),
                  liveEventCounts: _liveEventCounts,
                ) /
                2);
        final ghostGlobalY = globalPos.dy - rowGrabY;
        _onListReorderUpdate(key as _UserCategory, globalPos);
        // Additionally update the grid-overlay position variables that the
        // list handler doesn't know about.
        setState(() {
          _crossListGhostGlobalTop = ghostGlobalY;
          _dragGridTopLeft = newTopLeft;
        });
        _gridDragOverlayEntry?.markNeedsBuild();
        return;
      }
    }

    final tw =
        _dragGridTileWidth ??
        (box.size.width - _AnimatedCategoryGrid._colGap) / 2;

    final cx = newTopLeft.dx + tw / 2;
    final cy = newTopLeft.dy + _AnimatedCategoryGrid._rowHeight / 2;
    final col = (cx / (tw + _AnimatedCategoryGrid._colGap)).round().clamp(0, 1);
    final row =
        (cy /
                (_AnimatedCategoryGrid._rowHeight +
                    _AnimatedCategoryGrid._rowGap))
            .floor()
            .clamp(0, 999);

    final absoluteSlot = row * 2 + col;

    setState(() {
      // Move item directly in the unified order list.
      // _gridCombinedOrder contains only non-archived items, so it IS the
      // visible combined list — no filtering needed.
      final totalCount = _gridCombinedOrder.length;
      if (totalCount == 0) return;
      final Object item = key is String ? key.substring(6) : key as Object;
      final currentIdx = _gridCombinedOrder.indexOf(item);
      final targetIdx = absoluteSlot.clamp(0, totalCount - 1);
      _dragGridFullWidth = totalCount.isOdd && targetIdx == totalCount - 1;
      _dragGridTopLeft = Offset(
        _dragGridFullWidth ? 0.0 : newTopLeft.dx,
        newTopLeft.dy,
      );
      if (currentIdx != -1 && targetIdx != currentIdx) {
        _gridCombinedOrder
          ..removeAt(currentIdx)
          ..insert(targetIdx, item);
      }
    });
    _gridDragOverlayEntry?.markNeedsBuild();
  }

  // Splices [newVisibleOrder] back into _smartCategoryOrder, keeping archived
  // labels at their existing relative positions (same pattern as pinned tiles).
  void _applyReorderedVisibleSmart(List<String> newVisibleOrder) {
    var vi = 0;
    for (var i = 0; i < _smartCategoryOrder.length; i++) {
      if (!_archivedSmartCategories.contains(_smartCategoryOrder[i])) {
        _smartCategoryOrder[i] = newVisibleOrder[vi++];
      }
    }
  }

  // Splices [newVisibleOrder] back into _pinnedUserCategories, preserving
  // archived entries in their original positions.
  void _applyReorderedVisiblePinned(List<_UserCategory> newVisibleOrder) {
    var vi = 0;
    for (var i = 0; i < _pinnedUserCategories.length; i++) {
      if (!_pinnedUserCategories[i].archived) {
        _pinnedUserCategories[i] = newVisibleOrder[vi++];
      }
    }
  }

  void _onGridReorderEnd(Object key) {
    if (_draggingGridKey != key) return;
    // ── Cross-section unpin: tile dragged below the grid into the list ────────
    if (_gridDragCrossingToList && key is _UserCategory) {
      // cat.id is already in _listTopOrder at _crossListTargetIdx.
      // Now remove cat from the grid (deferred from first-entry-into-list)
      // and migrate the data records; animate the list row appearing.

      // Cancel any in-flight dwell timers accumulated during the list crossing.
      _groupDetectionTimer?.cancel();
      _groupDetectionTimer = null;
      _joinGroupDwellTimer?.cancel();
      _joinGroupDwellTimer = null;
      _collapsedGroupDwellTimer?.cancel();
      _collapsedGroupDwellTimer = null;

      // Capture dwell state BEFORE clearing so we can act on it after.
      final groupTarget = _dragGroupTargetCat;
      final confirmedJoinGroupId = _confirmedCollapsedGroupId;

      _gridDragOverlayEntry?.remove();
      _gridDragOverlayEntry = null;
      setState(() {
        _draggingGridKey = null;
        _dragGridTopLeft = null;
        _dragGridGrabOffset = null;
        _dragGridTileWidth = null;
        _dragGridFullWidth = false;
        _gridDragCrossingToList = false;
        _crossListTargetIdx = null;
        _crossListGhostGlobalTop = null;
        _draggingListCat = null;
        _dragListTopY = null;
        _dragListGrabOffsetY = null;
        _dragGroupTargetCat = null;
        _dragGroupHapticFired = false;
        _confirmedGroupY = null;
        _pendingGroupTarget = null;
        _dwellStartPhysicalY = null;
        _collapsedGroupDwellId = null;
        _confirmedCollapsedGroupId = null;
        _collapsedGroupDwellStartY = null;
        _gridCombinedOrder.remove(
          key,
        ); // deferred removal — tile was kept alive during drag
        _pinnedUserCategories.remove(key);
        _userCategories.add(key);
        _newInList.add(key);
      });
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) setState(() => _newInList.remove(key));
      });
      if (groupTarget != null) {
        // User released while in confirmed solo-to-solo dwell mode → New Group sheet.
        _openNewGroupSheet(key, groupTarget);
      } else if (confirmedJoinGroupId != null) {
        // User released after dwelling over a collapsed group → join it.
        final grpIdx = _categoryGroups.indexWhere(
          (g) => g.id == confirmedJoinGroupId,
        );
        if (grpIdx != -1) {
          final grp = _categoryGroups[grpIdx];
          setState(() {
            _listTopOrder.remove(key.id);
            _categoryGroups[grpIdx] = grp.copyWith(
              memberIds: [...grp.memberIds, key.id],
            );
            _expandedGroupIds.add(confirmedJoinGroupId);
            _expandingGroupIds.add(confirmedJoinGroupId);
            _collapsingGroupIds.remove(confirmedJoinGroupId);
          });
          Future.delayed(const Duration(milliseconds: 60), () {
            if (mounted)
              setState(() => _expandingGroupIds.remove(confirmedJoinGroupId));
          });
        }
        _saveCategories();
      } else {
        _saveCategories();
      }
      return;
    }
    _gridDragOverlayEntry?.remove();
    _gridDragOverlayEntry = null;
    setState(() {
      _draggingGridKey = null;
      _dragGridTopLeft = null;
      _dragGridGrabOffset = null;
      _dragGridTileWidth = null;
      _dragGridFullWidth = false;
    });
    _saveCategories();
  }

  void _onGridReorderCancel(Object key) {
    if (_draggingGridKey != key) return;
    _gridDragOverlayEntry?.remove();
    _gridDragOverlayEntry = null;
    if (_gridDragCrossingToList && key is _UserCategory) {
      // Restore: remove the list placeholder.
      // Cat was never removed from _gridCombinedOrder, so no re-add needed.
      _listTopOrder.remove(key.id);
    }
    setState(() {
      _draggingGridKey = null;
      _dragGridTopLeft = null;
      _dragGridGrabOffset = null;
      _dragGridTileWidth = null;
      _gridDragCrossingToList = false;
      _crossListTargetIdx = null;
      _crossListGhostGlobalTop = null;
      _draggingListCat = null;
      _dragListTopY = null;
      _dragListGrabOffsetY = null;
    });
  }

  // ── List drag-reorder ─────────────────────────────────────────────────────

  void _onListReorderStart(_UserCategory cat, Offset globalPos) {
    final box = _listStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final flatList = _buildFlatDisplayList();
    // Find this category's slot index in the flat display list.
    int idx = flatList.indexWhere(
      (item) => item.isCategory && item.category == cat,
    );
    if (idx == -1) return;
    // Detect whether the dragged tile is currently a group member.
    final draggingItem = flatList[idx];
    final memberGroupId = draggingItem.isGroupMember
        ? draggingItem.groupId
        : null;
    final slotTopY = _eventsCategoryListTopY(
      context,
      flatList,
      idx,
      _liveEventCounts,
    );
    final localPos = box.globalToLocal(globalPos);
    _joinGroupDwellTimer?.cancel();
    _joinGroupDwellTimer = null;
    _pendingJoinGroupId = null;
    _memberJoinGroupDwellTimer?.cancel();
    _memberJoinGroupDwellTimer = null;
    _pendingMemberJoinGroupId = null;
    _collapsedGroupDwellTimer?.cancel();
    _collapsedGroupDwellTimer = null;
    _collapsedGroupDwellId = null;
    _confirmedCollapsedGroupId = null;
    _collapsedGroupDwellStartY = null;
    setState(() {
      _draggingListCat = cat;
      _draggingListGroupId = memberGroupId;
      _dragListTopY = slotTopY;
      _dragListGrabOffsetY = localPos.dy - slotTopY;
      _dragGroupTargetCat = null;
      _dragGroupHapticFired = false;
      _confirmedGroupY = null;
    });
    // Insert drag ghost into the global Overlay so it floats above every
    // sliver (CATEGORIES header, Add Category button, etc.) in the scroll view.
    _listDragOverlayEntry?.remove();
    _listDragOverlayEntry = OverlayEntry(builder: _buildListDragOverlay);
    Overlay.of(context).insert(_listDragOverlayEntry!);
  }

  void _onListReorderUpdate(_UserCategory cat, Offset globalPos) {
    final box = _listStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || _draggingListCat != cat) return;
    final localPos = box.globalToLocal(globalPos);
    final rawTopY = localPos.dy - (_dragListGrabOffsetY ?? 0);
    final flatListForGeometry = _buildFlatDisplayList();
    final draggingIndex = flatListForGeometry.indexWhere(
      (item) => item.isCategory && item.category == cat,
    );
    final draggingItem = draggingIndex == -1
        ? _FlatItem.solo(cat)
        : flatListForGeometry[draggingIndex];
    final rowHeight = _eventsCategoryListRowHeight(
      context,
      item: draggingItem,
      liveEventCounts: _liveEventCounts,
    );

    // ── Cross-section (pin) detection ─────────────────────────────────────────
    // Only solo categories (not group members, not while in group-creation
    // mode) can be dragged up into the pinned grid.  Crossing is confirmed
    // when the ghost center climbs more than half a row above the list top.
    final eligibleForPin =
        _draggingListGroupId == null && _dragGroupTargetCat == null;
    if (eligibleForPin) {
      final crossingUp = localPos.dy < -(rowHeight * 0.5);
      if (crossingUp && !_listDragCrossingToGrid) {
        // ── First entry into grid ─────────────────────────────────────────
        HapticFeedback.selectionClick();
        final gridBox =
            _gridStackKey.currentContext?.findRenderObject() as RenderBox?;
        if (gridBox != null) {
          final tileW =
              (gridBox.size.width - _AnimatedCategoryGrid._colGap) / 2;
          // Centre-grab: treat the cat as entering the tile at its midpoint so
          // the ghost is always centred on the finger (no inherited list grab).
          final grab = Offset(tileW / 2, _AnimatedCategoryGrid._rowHeight / 2);
          final gridLocal = gridBox.globalToLocal(globalPos);
          final rawTopLeft = gridLocal - grab;
          // Slot from ghost centre (same formula as normal grid reorder).
          final cx = rawTopLeft.dx + tileW / 2;
          final cy = rawTopLeft.dy + _AnimatedCategoryGrid._rowHeight / 2;
          final col = (cx / (tileW + _AnimatedCategoryGrid._colGap))
              .round()
              .clamp(0, 1);
          final row =
              (cy /
                      (_AnimatedCategoryGrid._rowHeight +
                          _AnimatedCategoryGrid._rowGap))
                  .floor()
                  .clamp(0, 999);
          final slot = (row * 2 + col).clamp(0, _gridCombinedOrder.length);
          setState(() {
            _listDragCrossingToGrid = true;
            _crossGridTargetSlot = slot;
            _gridCombinedOrder.insert(slot, cat);
            _draggingGridKey = cat;
            _dragGridTileWidth = tileW;
            _dragGridGrabOffset = grab; // ← centre-grab for smooth tracking
            _dragGridFullWidth =
                _gridCombinedOrder.length.isOdd &&
                slot == _gridCombinedOrder.length - 1;
            _dragGridTopLeft = Offset(
              _dragGridFullWidth ? 0.0 : rawTopLeft.dx,
              rawTopLeft.dy,
            ); // ← raw finger position, not slot
          });
        } else {
          setState(() => _listDragCrossingToGrid = true);
        }
      } else if (!crossingUp && _listDragCrossingToGrid) {
        // ── Exiting grid back into list ───────────────────────────────────
        setState(() {
          _listDragCrossingToGrid = false;
          _gridCombinedOrder.remove(cat);
          _crossGridTargetSlot = null;
          _draggingGridKey = null;
          _dragGridTopLeft = null;
          _dragGridTileWidth = null;
        });
        // fall through to normal list reorder
      }
      if (crossingUp) {
        // ── Live reorder within the grid while crossing ───────────────────
        final gridBox =
            _gridStackKey.currentContext?.findRenderObject() as RenderBox?;
        if (gridBox != null) {
          final tileW =
              (gridBox.size.width - _AnimatedCategoryGrid._colGap) / 2;
          final grab =
              _dragGridGrabOffset ??
              Offset(tileW / 2, _AnimatedCategoryGrid._rowHeight / 2);
          final gridLocal = gridBox.globalToLocal(globalPos);
          // Ghost top-left tracks the finger every frame (identical to a
          // normal grid drag — localPos − grab, fully continuous).
          final rawTopLeft = gridLocal - grab;
          // Slot from ghost centre — only mutates the data list when it changes.
          final cx = rawTopLeft.dx + tileW / 2;
          final cy = rawTopLeft.dy + _AnimatedCategoryGrid._rowHeight / 2;
          final col = (cx / (tileW + _AnimatedCategoryGrid._colGap))
              .round()
              .clamp(0, 1);
          final row =
              (cy /
                      (_AnimatedCategoryGrid._rowHeight +
                          _AnimatedCategoryGrid._rowGap))
                  .floor()
                  .clamp(0, 999);
          final newSlot = (row * 2 + col).clamp(
            0,
            _gridCombinedOrder.length - 1,
          );
          final currentIdx = _gridCombinedOrder.indexOf(cat);
          if (currentIdx != -1 && newSlot != currentIdx) {
            _gridCombinedOrder.removeAt(currentIdx);
            _gridCombinedOrder.insert(newSlot, cat);
            _crossGridTargetSlot = newSlot;
          }
          // Always update ghost position so it follows the finger smoothly.
          setState(() {
            _dragGridFullWidth =
                _gridCombinedOrder.length.isOdd &&
                newSlot == _gridCombinedOrder.length - 1;
            _dragGridTopLeft = Offset(
              _dragGridFullWidth ? 0.0 : rawTopLeft.dx,
              rawTopLeft.dy,
            );
          });
        }
        _listDragOverlayEntry?.markNeedsBuild();
        return;
      }
    }

    final slotPitch = rowHeight + _CategoryCard._kRowGap;
    final centerY = rawTopY + rowHeight / 2;

    // ── Confirmed group mode ──────────────────────────────────────────────────
    // Dwell timer has fired; list is frozen — only ghost position + target switch.
    if (_dragGroupTargetCat != null) {
      final flatList = _buildFlatDisplayList();
      final targetIdx = _eventsCategoryListIndexAtY(
        context,
        flatList,
        centerY,
        _liveEventCounts,
      ).clamp(0, flatList.length - 1);
      final targetItem = flatList[targetIdx];
      final draggedItem = flatList.firstWhere(
        (it) => it.isCategory && it.category == cat,
        orElse: () => _FlatItem.solo(cat),
      );
      if (draggedItem.isSolo &&
          targetItem.isSolo &&
          targetItem.category != cat) {
        // Ghost is over a different solo — allow switching the target and
        // re-anchor the confirmed position.
        final newTarget = targetItem.category!;
        if (newTarget != _dragGroupTargetCat) {
          HapticFeedback.selectionClick();
          setState(() {
            _dragGroupTargetCat = newTarget;
            _confirmedGroupY = rawTopY;
            _dragListTopY = rawTopY;
          });
        } else {
          setState(() => _dragListTopY = rawTopY);
        }
      } else {
        // Ghost is not directly over a distinct solo (could be its own slot,
        // a group row, or between items).  Only cancel the glow if the finger
        // has moved a significant distance from where the glow was confirmed —
        // small wobble or the momentary slip when lifting should not break it.
        final moved = _confirmedGroupY != null
            ? (rawTopY - _confirmedGroupY!).abs()
            : 0.0;
        if (moved > slotPitch * 1.5) {
          _groupDetectionTimer?.cancel();
          _groupDetectionTimer = null;
          _pendingGroupTarget = null;
          _dwellStartPhysicalY = null;
          _confirmedGroupY = null;
          setState(() {
            _dragGroupTargetCat = null;
            _dragGroupHapticFired = false;
            _dragListTopY = rawTopY;
          });
        } else {
          setState(() => _dragListTopY = rawTopY);
        }
      }
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }

    // ── Group member drag ─────────────────────────────────────────────────────
    if (_draggingListGroupId != null) {
      _handleGroupMemberDrag(cat, rawTopY, centerY);
      return;
    }

    // ── Solo drag ─────────────────────────────────────────────────────────────
    final flatList = _buildFlatDisplayList();
    final currentIdx = flatList.indexWhere(
      (item) => item.isCategory && item.category == cat,
    );
    if (currentIdx == -1) return;

    final targetIdx = _eventsCategoryListIndexAtY(
      context,
      flatList,
      centerY,
      _liveEventCounts,
    ).clamp(0, flatList.length - 1);
    final targetItem = flatList[targetIdx];
    final draggedItem = flatList[currentIdx];

    // Dwell-to-group detection — runs in parallel with live reorder.
    //
    // Key design: the dwell timer is started when the ghost first hovers over a
    // new solo target.  The timer is cancelled only if the ghost PHYSICALLY moves
    // far enough to leave the dwell zone (> 70 % of a row height).  It is NOT
    // cancelled merely because a reorder swap changed the logical slot index
    // (which would make targetIdx == currentIdx, breaking the old approach).
    final hoveringOverDistinctSolo =
        draggedItem.isSolo &&
        targetItem.isSolo &&
        targetItem.category != cat &&
        targetIdx != currentIdx;

    if (hoveringOverDistinctSolo) {
      final hoverTarget = targetItem.category!;
      if (_pendingGroupTarget != hoverTarget) {
        // New target — restart timer and record where the ghost is physically.
        _groupDetectionTimer?.cancel();
        _pendingGroupTarget = hoverTarget;
        _dwellStartPhysicalY = rawTopY;
        _groupDetectionTimer = Timer(
          const Duration(milliseconds: _kGroupDwellMs),
          () {
            _groupDetectionTimer = null;
            if (!mounted ||
                _draggingListCat != cat ||
                _draggingListGroupId != null)
              return;
            final fl = _buildFlatDisplayList();
            final pendingCat = _pendingGroupTarget;
            if (pendingCat == null) return;
            // Dragging cat must still be solo, target must still be solo.
            final draggingNow = fl.firstWhere(
              (it) => it.isCategory && it.category == cat,
              orElse: () => _FlatItem.solo(cat),
            );
            if (!draggingNow.isSolo) return;
            final pendingIdx = fl.indexWhere(
              (it) => it.isSolo && it.category == pendingCat,
            );
            if (pendingIdx == -1) return;
            // Don't snap the ghost — keep it at the finger's current position.
            HapticFeedback.selectionClick();
            setState(() {
              _dragGroupTargetCat = pendingCat;
              _dragGroupHapticFired = true;
              _confirmedGroupY = _dwellStartPhysicalY ?? _dragListTopY;
            });
            _listDragOverlayEntry?.markNeedsBuild();
          },
        );
      }
      // Same target — timer already running.  No action needed here.
    } else if (_pendingGroupTarget != null) {
      // Not visibly hovering over a distinct solo target — could be because a
      // reorder swap placed the dragged cat in the target's old slot (making
      // targetIdx == currentIdx).  Cancel only if the ghost physically moved.
      final physicallyLeft =
          _dwellStartPhysicalY != null &&
          (rawTopY - _dwellStartPhysicalY!).abs() > slotPitch * 0.7;
      if (physicallyLeft) {
        _groupDetectionTimer?.cancel();
        _groupDetectionTimer = null;
        _pendingGroupTarget = null;
        _dwellStartPhysicalY = null;
      }
      // else: ghost is stationary; reorder swap happened beneath it — keep timer.
    }

    // Solo dragged over a group member slot — use a 400 ms join-dwell rather
    // than joining immediately.  While the timer counts down, the group is
    // treated as a single reorder block so the cat can slide past expanded
    // groups that are at the top or bottom of the list.
    if (draggedItem.isSolo &&
        targetItem.isGroupMember &&
        targetItem.groupId != null &&
        targetIdx != currentIdx) {
      final joinGroupId = targetItem.groupId!;
      if (_pendingJoinGroupId != joinGroupId) {
        _joinGroupDwellTimer?.cancel();
        _pendingJoinGroupId = joinGroupId;
        _joinGroupDwellTimer = Timer(const Duration(milliseconds: 400), () {
          _joinGroupDwellTimer = null;
          if (!mounted || _draggingListCat != cat) return;
          final fl = _buildFlatDisplayList();
          final cIdx = fl.indexWhere(
            (it) => it.isCategory && it.category == cat,
          );
          if (cIdx == -1) return;
          final cy =
              (_dragListTopY ?? 0.0) +
              _eventsCategoryListRowHeight(
                    context,
                    item: draggingItem,
                    liveEventCounts: _liveEventCounts,
                  ) /
                  2;
          final ti = _eventsCategoryListIndexAtY(
            context,
            fl,
            cy,
            _liveEventCounts,
          ).clamp(0, fl.length - 1);
          final tItem = fl[ti];
          if (tItem.isGroupMember && tItem.groupId == joinGroupId) {
            _handleSoloDragIntoGroup(
              cat,
              _dragListTopY ?? 0.0,
              fl,
              cIdx,
              ti,
              tItem,
            );
          }
        });
      }
      // While waiting: reorder the solo cat around the group as a block.
      setState(() {
        _dragListTopY = rawTopY;
        final dragToken = cat.id;
        if (_listTopOrder.contains(dragToken)) {
          _listTopOrder.remove(dragToken);
          final groupToken = 'grp-$joinGroupId';
          final tokIdx = _listTopOrder.indexOf(groupToken);
          if (tokIdx != -1) {
            final at = targetIdx > currentIdx ? tokIdx + 1 : tokIdx;
            _listTopOrder.insert(at.clamp(0, _listTopOrder.length), dragToken);
          } else {
            _listTopOrder.add(dragToken);
          }
        }
      });
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }
    // Ghost left the group member area — cancel any pending join.
    if (_pendingJoinGroupId != null &&
        !(targetItem.isGroupMember &&
            targetItem.groupId == _pendingJoinGroupId)) {
      _joinGroupDwellTimer?.cancel();
      _joinGroupDwellTimer = null;
      _pendingJoinGroupId = null;
    }

    // Solo dragged over a COLLAPSED group header.
    // Two sub-cases based on how much the finger has physically moved since
    // first entering the group's slot:
    //   (a) Nearly stationary (< 0.5 row height) → dwell-to-join countdown,
    //       reorder blocked so the cat doesn't slip past.
    //   (b) Actively dragging through (≥ 0.5 row height) → dwell cancelled,
    //       live reorder runs and the cat passes through normally.
    if (draggedItem.isSolo &&
        targetItem.isGroupHeader &&
        targetItem.group != null &&
        !_expandedGroupIds.contains(targetItem.group!.id)) {
      final headerGroupId = targetItem.group!.id;
      if (_collapsedGroupDwellId != headerGroupId) {
        // First frame in this group's zone — start timer and record Y.
        _collapsedGroupDwellTimer?.cancel();
        _collapsedGroupDwellStartY = rawTopY;
        _collapsedGroupDwellTimer = Timer(
          const Duration(milliseconds: _kGroupDwellMs),
          () {
            _collapsedGroupDwellTimer = null;
            if (!mounted || _draggingListCat != cat) return;
            HapticFeedback.selectionClick();
            setState(() => _confirmedCollapsedGroupId = headerGroupId);
            _listDragOverlayEntry?.markNeedsBuild();
          },
        );
        setState(() => _collapsedGroupDwellId = headerGroupId);
      }
      // Detect pass-through intent from physical movement since zone entry.
      final passingThrough =
          _collapsedGroupDwellStartY != null &&
          (rawTopY - _collapsedGroupDwellStartY!).abs() > slotPitch * 0.5;
      if (passingThrough) {
        // Finger moving fast — cancel dwell and fall through to live reorder.
        _collapsedGroupDwellTimer?.cancel();
        _collapsedGroupDwellTimer = null;
        setState(() {
          _collapsedGroupDwellId = null;
          _confirmedCollapsedGroupId = null;
          _collapsedGroupDwellStartY = null;
        });
        // No return — falls through to live reorder below.
      } else {
        // Finger nearly stationary — maintain dwell, block reorder.
        setState(() => _dragListTopY = rawTopY);
        _listDragOverlayEntry?.markNeedsBuild();
        return;
      }
    }
    // Ghost left the collapsed group header — cancel glow, timer, and intent.
    if (_collapsedGroupDwellId != null) {
      _collapsedGroupDwellTimer?.cancel();
      _collapsedGroupDwellTimer = null;
      setState(() {
        _collapsedGroupDwellId = null;
        _confirmedCollapsedGroupId = null;
        _collapsedGroupDwellStartY = null;
      });
    }

    // Live reorder — always runs for solo cats (reorder is the primary gesture).
    setState(() {
      _dragListTopY = rawTopY;
      if (targetIdx != currentIdx) {
        final dragToken = cat.id;
        final inOrder = _listTopOrder.contains(dragToken);
        if (inOrder) {
          _listTopOrder.remove(dragToken);
          final targetToken = _flatItemToToken(targetItem);
          if (targetToken != null) {
            final tokIdx = _listTopOrder.indexOf(targetToken);
            if (tokIdx != -1) {
              final insertAt = targetIdx > currentIdx ? tokIdx + 1 : tokIdx;
              _listTopOrder.insert(
                insertAt.clamp(0, _listTopOrder.length),
                dragToken,
              );
            } else {
              _listTopOrder.add(dragToken);
            }
          } else {
            _listTopOrder.add(dragToken);
          }
        }
      }
    });
    _listDragOverlayEntry?.markNeedsBuild();
  }

  /// Handles all drag-update logic when _draggingListGroupId is non-null
  /// (i.e. the dragged tile is currently a group member).
  void _handleGroupMemberDrag(
    _UserCategory cat,
    double rawTopY,
    double centerY,
  ) {
    final groupId = _draggingListGroupId!;
    final flatList = _buildFlatDisplayList();
    final currentIdx = flatList.indexWhere(
      (item) => item.isCategory && item.category == cat,
    );
    if (currentIdx == -1) {
      setState(() => _dragListTopY = rawTopY);
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }

    final groupIdx = _categoryGroups.indexWhere((g) => g.id == groupId);
    if (groupIdx == -1) {
      // Group was already dissolved; just track the ghost.
      setState(() => _dragListTopY = rawTopY);
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }
    final group = _categoryGroups[groupIdx];

    final rawTargetIdx = _eventsCategoryListIndexAtY(
      context,
      flatList,
      centerY,
      _liveEventCounts,
    );

    // Allow exit when dragged above the list top or below the list bottom.
    // This is the only escape route when all categories are inside one group.
    if (rawTargetIdx < 0 || rawTargetIdx >= flatList.length) {
      final newIds = List<String>.from(group.memberIds)..remove(cat.id);
      final grpToken = 'grp-$groupId';
      final grpPos = _listTopOrder.indexOf(grpToken);
      setState(() {
        if (newIds.length < 2) {
          if (grpPos != -1) {
            _listTopOrder.removeAt(grpPos);
            _listTopOrder.insertAll(grpPos, newIds);
          }
          _categoryGroups.removeAt(groupIdx);
          _expandedGroupIds.remove(groupId);
          _expandingGroupIds.remove(groupId);
          _collapsingGroupIds.remove(groupId);
        } else {
          _categoryGroups[groupIdx] = group.copyWith(memberIds: newIds);
        }
        if (rawTargetIdx < 0) {
          _listTopOrder.insert(0, cat.id);
        } else {
          _listTopOrder.add(cat.id);
        }
        _draggingListGroupId = null;
        _dragListTopY = rawTopY;
      });
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }

    final targetIdx = rawTargetIdx.clamp(0, flatList.length - 1);
    final targetItem = flatList[targetIdx];

    // Is the target still within the same group (header or member)?
    final inSameGroup =
        (targetItem.isGroupMember && targetItem.groupId == groupId) ||
        (targetItem.isGroupHeader && targetItem.group?.id == groupId);

    if (inSameGroup && targetIdx != currentIdx) {
      // Reorder the member within the group's memberIds.
      final newIds = List<String>.from(group.memberIds);
      final fromPos = newIds.indexOf(cat.id);
      int toPos = targetItem.isGroupHeader
          ? 0
          : newIds.indexOf(targetItem.category!.id);
      if (fromPos != -1 && toPos != -1 && fromPos != toPos) {
        newIds.removeAt(fromPos);
        newIds.insert(toPos.clamp(0, newIds.length), cat.id);
        setState(() {
          _categoryGroups[groupIdx] = group.copyWith(memberIds: newIds);
          _dragListTopY = rawTopY;
        });
      } else {
        setState(() => _dragListTopY = rawTopY);
      }
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }

    if (!inSameGroup && targetIdx != currentIdx) {
      if (targetItem.isGroupHeader ||
          (targetItem.isGroupMember && targetItem.groupId != groupId)) {
        // Different group — start a dwell timer to join it.
        final targetGroupId = targetItem.isGroupHeader
            ? targetItem.group!.id
            : targetItem.groupId!;
        if (_pendingMemberJoinGroupId != targetGroupId) {
          _memberJoinGroupDwellTimer?.cancel();
          _pendingMemberJoinGroupId = targetGroupId;
          _memberJoinGroupDwellTimer = Timer(
            const Duration(milliseconds: 400),
            () {
              _memberJoinGroupDwellTimer = null;
              _pendingMemberJoinGroupId = null;
              if (!mounted || _draggingListGroupId != groupId) return;
              final srcIdx = _categoryGroups.indexWhere((g) => g.id == groupId);
              if (srcIdx == -1) return;
              final dstIdx = _categoryGroups.indexWhere(
                (g) => g.id == targetGroupId,
              );
              if (dstIdx == -1) return;
              final srcGrp = _categoryGroups[srcIdx];
              final dstGrp = _categoryGroups[dstIdx];
              final newSrcIds = List<String>.from(srcGrp.memberIds)
                ..remove(cat.id);
              final newDstIds = [...dstGrp.memberIds, cat.id];
              HapticFeedback.selectionClick();
              setState(() {
                if (newSrcIds.length < 2) {
                  // Dissolve source group.
                  final grpToken = 'grp-$groupId';
                  final grpPos = _listTopOrder.indexOf(grpToken);
                  if (grpPos != -1) {
                    _listTopOrder.removeAt(grpPos);
                    _listTopOrder.insertAll(grpPos, newSrcIds);
                  }
                  _categoryGroups.removeAt(srcIdx);
                  _expandedGroupIds.remove(groupId);
                  _expandingGroupIds.remove(groupId);
                  _collapsingGroupIds.remove(groupId);
                  // Re-find destination after removal (index may have shifted).
                  final newDstIdx = _categoryGroups.indexWhere(
                    (g) => g.id == targetGroupId,
                  );
                  if (newDstIdx != -1) {
                    _categoryGroups[newDstIdx] = _categoryGroups[newDstIdx]
                        .copyWith(memberIds: newDstIds);
                  }
                } else {
                  _categoryGroups[srcIdx] = srcGrp.copyWith(
                    memberIds: newSrcIds,
                  );
                  _categoryGroups[dstIdx] = dstGrp.copyWith(
                    memberIds: newDstIds,
                  );
                }
                _draggingListGroupId = targetGroupId;
              });
              _listDragOverlayEntry?.markNeedsBuild();
            },
          );
        }
        setState(() => _dragListTopY = rawTopY);
        _listDragOverlayEntry?.markNeedsBuild();
        return;
      }
      // No longer over a foreign group — cancel any pending member-join.
      if (_pendingMemberJoinGroupId != null) {
        _memberJoinGroupDwellTimer?.cancel();
        _memberJoinGroupDwellTimer = null;
        _pendingMemberJoinGroupId = null;
      }
      // Target is a solo position → exit current group.
      final newIds = List<String>.from(group.memberIds)..remove(cat.id);
      setState(() {
        if (newIds.length < 2) {
          // Only one member left → dissolve the group.
          final grpToken = 'grp-$groupId';
          final grpPos = _listTopOrder.indexOf(grpToken);
          if (grpPos != -1) {
            _listTopOrder.removeAt(grpPos);
            _listTopOrder.insertAll(grpPos, newIds);
          }
          _categoryGroups.removeAt(groupIdx);
          _expandedGroupIds.remove(groupId);
          _expandingGroupIds.remove(groupId);
          _collapsingGroupIds.remove(groupId);
        } else {
          _categoryGroups[groupIdx] = group.copyWith(memberIds: newIds);
        }
        // Determine insertion token — group members have no direct top-order
        // token, so fall back to their parent group header token.
        final insertToken =
            targetItem.isGroupMember && targetItem.groupId != null
            ? 'grp-${targetItem.groupId}'
            : _flatItemToToken(targetItem);
        final insertPos = insertToken != null
            ? _listTopOrder.indexOf(insertToken)
            : -1;
        if (insertPos != -1) {
          final at = targetIdx > currentIdx ? insertPos + 1 : insertPos;
          _listTopOrder.insert(at.clamp(0, _listTopOrder.length), cat.id);
        } else {
          _listTopOrder.add(cat.id);
        }
        _draggingListGroupId = null; // now a solo cat
        _dragListTopY = rawTopY;
      });
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }

    // No position change — just move the ghost.
    setState(() => _dragListTopY = rawTopY);
    _listDragOverlayEntry?.markNeedsBuild();
  }

  /// Handles a solo cat being dragged into an expanded group's member area.
  /// Removes it from _listTopOrder and inserts it into that group's memberIds.
  void _handleSoloDragIntoGroup(
    _UserCategory cat,
    double rawTopY,
    List<_FlatItem> flatList,
    int currentIdx,
    int targetIdx,
    _FlatItem targetItem,
  ) {
    final groupId = targetItem.groupId!;
    final groupIdx = _categoryGroups.indexWhere((g) => g.id == groupId);
    if (groupIdx == -1) return;
    final group = _categoryGroups[groupIdx];

    final targetMemberId = targetItem.category?.id;
    final targetMemberPos = targetMemberId != null
        ? group.memberIds.indexOf(targetMemberId)
        : -1;

    setState(() {
      _listTopOrder.remove(cat.id);
      final newIds = List<String>.from(group.memberIds);
      if (targetMemberPos != -1) {
        final insertAt = targetIdx > currentIdx
            ? (targetMemberPos + 1).clamp(0, newIds.length)
            : targetMemberPos.clamp(0, newIds.length);
        newIds.insert(insertAt, cat.id);
      } else {
        newIds.add(cat.id);
      }
      _categoryGroups[groupIdx] = group.copyWith(memberIds: newIds);
      _draggingListGroupId = groupId; // now a member
      _dragListTopY = rawTopY;
    });
    _listDragOverlayEntry?.markNeedsBuild();
  }

  /// Maps a _FlatItem back to its canonical _listTopOrder token string.
  String? _flatItemToToken(_FlatItem item) {
    if (item.isGroupHeader) return 'grp-${item.group!.id}';
    if (item.isSolo) return item.category?.id;
    // Group members don't have a direct top-order token (they live inside
    // their group's token), so return null — callers handle null gracefully.
    return null;
  }

  void _onListReorderEnd(_UserCategory cat) {
    if (_draggingListCat != cat) return;
    _groupDetectionTimer?.cancel();
    _groupDetectionTimer = null;
    _joinGroupDwellTimer?.cancel();
    _joinGroupDwellTimer = null;
    _pendingJoinGroupId = null;
    _memberJoinGroupDwellTimer?.cancel();
    _memberJoinGroupDwellTimer = null;
    _pendingMemberJoinGroupId = null;
    _collapsedGroupDwellTimer?.cancel();
    _collapsedGroupDwellTimer = null;

    // ── Cross-section pin: cat was dragged above the list into the grid ───────
    if (_listDragCrossingToGrid) {
      // Placeholder is live in _gridCombinedOrder at _crossGridTargetSlot.
      // Remove it; we will re-insert the real cat after data migration.
      final targetSlot = _crossGridTargetSlot;
      _gridCombinedOrder.remove(cat);
      _removeFromGroupById(cat.id);
      _listTopOrder.remove(cat.id);
      _listDragOverlayEntry?.remove();
      _listDragOverlayEntry = null;
      final scrollBase = _scrollController.hasClients
          ? _scrollController.offset
          : 0.0;
      setState(() {
        _draggingListCat = null;
        _draggingGridKey = null;
        _dragGridTopLeft = null;
        _dragGridGrabOffset = null;
        _dragGridTileWidth = null;
        _dragGridFullWidth = false;
        _dragListTopY = null;
        _dragListGrabOffsetY = null;
        _dragGroupTargetCat = null;
        _dragGroupHapticFired = false;
        _confirmedGroupY = null;
        _pendingGroupTarget = null;
        _dwellStartPhysicalY = null;
        _collapsedGroupDwellId = null;
        _confirmedCollapsedGroupId = null;
        _collapsedGroupDwellStartY = null;
        _listDragCrossingToGrid = false;
        _crossGridTargetSlot = null;
      });
      // Skip phase-1 list-row collapse (the row was already in ghost/gap state
      // during the drag).  Go straight to phase-2: reveal the grid tile.
      _startGridResizeTracking(scrollBase);
      setState(() {
        _userCategories.remove(cat);
        _pinnedUserCategories.add(cat);
        _gridCombinedOrder.insert(
          (targetSlot ?? _gridCombinedOrder.length).clamp(
            0,
            _gridCombinedOrder.length,
          ),
          cat,
        );
        _newInGrid.add(cat);
      });
      _saveCategories();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _newInGrid.remove(cat));
      });
      return;
    }

    final confirmedJoinGroupId = _confirmedCollapsedGroupId;
    final groupTarget = _dragGroupTargetCat;
    // Remove overlay first — the tile in the Stack becomes visible on the
    // same frame and AnimatedPositioned animates it from drag position back
    // to its logical slot (the "drop" animation).
    _listDragOverlayEntry?.remove();
    _listDragOverlayEntry = null;
    setState(() {
      _draggingListCat = null;
      _dragListTopY = null;
      _dragListGrabOffsetY = null;
      _dragGroupTargetCat = null;
      _dragGroupHapticFired = false;
      _confirmedGroupY = null;
      _pendingGroupTarget = null;
      _dwellStartPhysicalY = null;
      _collapsedGroupDwellId = null;
      _confirmedCollapsedGroupId = null;
      _collapsedGroupDwellStartY = null;
    });
    if (groupTarget != null) {
      // User released while in confirmed solo-to-solo mode → New Group sheet.
      _openNewGroupSheet(cat, groupTarget);
    } else if (confirmedJoinGroupId != null) {
      // User released while hovering over a collapsed group after dwell →
      // join the group and expand it now that the drag is fully over.
      final grpIdx = _categoryGroups.indexWhere(
        (g) => g.id == confirmedJoinGroupId,
      );
      if (grpIdx != -1) {
        final grp = _categoryGroups[grpIdx];
        setState(() {
          _listTopOrder.remove(cat.id);
          _categoryGroups[grpIdx] = grp.copyWith(
            memberIds: [...grp.memberIds, cat.id],
          );
          _expandedGroupIds.add(confirmedJoinGroupId);
          _expandingGroupIds.add(confirmedJoinGroupId);
          _collapsingGroupIds.remove(confirmedJoinGroupId);
        });
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted)
            setState(() => _expandingGroupIds.remove(confirmedJoinGroupId));
        });
      }
      _saveCategories();
    } else {
      _saveCategories();
    }
  }

  void _onListReorderCancel(_UserCategory cat) {
    if (_draggingListCat != cat) return;
    _groupDetectionTimer?.cancel();
    _groupDetectionTimer = null;
    _joinGroupDwellTimer?.cancel();
    _joinGroupDwellTimer = null;
    _pendingJoinGroupId = null;
    _memberJoinGroupDwellTimer?.cancel();
    _memberJoinGroupDwellTimer = null;
    _pendingMemberJoinGroupId = null;
    _collapsedGroupDwellTimer?.cancel();
    _collapsedGroupDwellTimer = null;
    _collapsedGroupDwellId = null;
    _confirmedCollapsedGroupId = null;
    _collapsedGroupDwellStartY = null;
    if (_listDragCrossingToGrid) {
      // Remove live grid placeholder before clearing state.
      _gridCombinedOrder.remove(cat);
    }
    _listDragOverlayEntry?.remove();
    _listDragOverlayEntry = null;
    setState(() {
      _draggingListCat = null;
      _dragListTopY = null;
      _dragListGrabOffsetY = null;
      _dragGroupTargetCat = null;
      _dragGroupHapticFired = false;
      _confirmedGroupY = null;
      _pendingGroupTarget = null;
      _dwellStartPhysicalY = null;
      _listDragCrossingToGrid = false;
      _crossGridTargetSlot = null;
      _draggingGridKey = null;
      _dragGridTopLeft = null;
      _dragGridGrabOffset = null;
      _dragGridTileWidth = null;
      _dragGridFullWidth = false;
    });
  }

  // ── Group header drag-reorder ─────────────────────────────────────────────

  void _onGroupHeaderReorderStart(_CategoryGroup group, Offset globalPos) {
    final box = _listStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final flatList = _buildFlatDisplayList();
    final idx = flatList.indexWhere(
      (item) => item.isGroupHeader && item.group?.id == group.id,
    );
    if (idx == -1) return;
    final localPos = box.globalToLocal(globalPos);
    setState(() {
      _draggingGroupHeader = group;
      final slotTopY = _eventsCategoryListTopY(
        context,
        flatList,
        idx,
        _liveEventCounts,
      );
      _dragListTopY = slotTopY;
      _dragListGrabOffsetY = localPos.dy - slotTopY;
    });
    _listDragOverlayEntry?.remove();
    _listDragOverlayEntry = OverlayEntry(builder: _buildListDragOverlay);
    Overlay.of(context).insert(_listDragOverlayEntry!);
  }

  void _onGroupHeaderReorderUpdate(_CategoryGroup group, Offset globalPos) {
    final box = _listStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || _draggingGroupHeader?.id != group.id) {
      return;
    }
    final localPos = box.globalToLocal(globalPos);
    final rawTopY = localPos.dy - (_dragListGrabOffsetY ?? 0);
    final flatList = _buildFlatDisplayList();
    final currentIdx = flatList.indexWhere(
      (item) => item.isGroupHeader && item.group?.id == group.id,
    );
    final draggingItem = currentIdx == -1
        ? _FlatItem.groupHeader(group)
        : flatList[currentIdx];
    final rowHeight = _eventsCategoryListRowHeight(
      context,
      item: draggingItem,
      liveEventCounts: _liveEventCounts,
    );
    final centerY = rawTopY + rowHeight / 2;

    if (currentIdx == -1) {
      setState(() => _dragListTopY = rawTopY);
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }
    final targetIdx = _eventsCategoryListIndexAtY(
      context,
      flatList,
      centerY,
      _liveEventCounts,
    ).clamp(0, flatList.length - 1);
    final targetItem = flatList[targetIdx];

    // Don't reorder while hovering over own member slots.
    if (targetItem.isGroupMember && targetItem.groupId == group.id) {
      setState(() => _dragListTopY = rawTopY);
      _listDragOverlayEntry?.markNeedsBuild();
      return;
    }

    setState(() {
      _dragListTopY = rawTopY;
      if (targetIdx != currentIdx) {
        final grpToken = 'grp-${group.id}';
        // Map the target flat slot to a _listTopOrder token.
        String? targetToken;
        if (targetItem.isSolo) {
          targetToken = targetItem.category!.id;
        } else if (targetItem.isGroupHeader) {
          targetToken = 'grp-${targetItem.group!.id}';
        } else if (targetItem.isGroupMember) {
          // Member of another group — use that group's header token.
          targetToken = 'grp-${targetItem.groupId}';
        }
        if (targetToken != null && targetToken != grpToken) {
          final grpPos = _listTopOrder.indexOf(grpToken);
          if (grpPos != -1) {
            _listTopOrder.removeAt(grpPos);
            final adjustedTokIdx = _listTopOrder.indexOf(targetToken);
            if (adjustedTokIdx != -1) {
              final at = targetIdx > currentIdx
                  ? adjustedTokIdx + 1
                  : adjustedTokIdx;
              _listTopOrder.insert(at.clamp(0, _listTopOrder.length), grpToken);
            } else {
              _listTopOrder.add(grpToken);
            }
          }
        }
      }
    });
    _listDragOverlayEntry?.markNeedsBuild();
  }

  void _onGroupHeaderReorderEnd(_CategoryGroup group) {
    if (_draggingGroupHeader?.id != group.id) return;
    _listDragOverlayEntry?.remove();
    _listDragOverlayEntry = null;
    setState(() {
      _draggingGroupHeader = null;
      _dragListTopY = null;
      _dragListGrabOffsetY = null;
    });
    _saveCategories();
  }

  void _onGroupHeaderReorderCancel(_CategoryGroup group) {
    if (_draggingGroupHeader?.id != group.id) return;
    _listDragOverlayEntry?.remove();
    _listDragOverlayEntry = null;
    setState(() {
      _draggingGroupHeader = null;
      _dragListTopY = null;
      _dragListGrabOffsetY = null;
    });
  }

  // ── List drag overlay builders ─────────────────────────────────────────────

  Widget _buildListDragOverlay(BuildContext context) {
    final cat = _draggingListCat;
    final grp = _draggingGroupHeader;
    if (cat == null && grp == null) return const SizedBox.shrink();
    final box = _listStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const SizedBox.shrink();
    final stackGlobal = box.localToGlobal(Offset.zero);
    final tileWidth = box.size.width;
    final globalTopY = stackGlobal.dy + (_dragListTopY ?? 0.0);
    final flatItems = _buildFlatDisplayList();
    final ghostItem = cat != null
        ? flatItems.firstWhere(
            (item) => item.isCategory && item.category == cat,
            orElse: () => _FlatItem.solo(cat),
          )
        : flatItems.firstWhere(
            (item) => item.isGroupHeader && item.group?.id == grp!.id,
            orElse: () => _FlatItem.groupHeader(grp!),
          );
    final ghostHeight = _eventsCategoryListRowHeight(
      context,
      item: ghostItem,
      liveEventCounts: _liveEventCounts,
    );

    // ── Crossing up into pinned grid: tile ghost snapped to the live slot ─────
    if (_listDragCrossingToGrid && cat != null) {
      final gridBox =
          _gridStackKey.currentContext?.findRenderObject() as RenderBox?;
      final gridGlobal = gridBox?.localToGlobal(Offset.zero);
      final tileW = _dragGridFullWidth
          ? (gridBox?.size.width ?? tileWidth)
          : (_dragGridTileWidth ??
                (gridBox != null
                    ? (gridBox.size.width - _AnimatedCategoryGrid._colGap) / 2
                    : 120.0));
      const tileH = _AnimatedCategoryGrid._rowHeight;
      final tl = _dragGridTopLeft;
      final ghostLeft = (gridGlobal?.dx ?? 0) + (tl?.dx ?? 0);
      final ghostTop = (gridGlobal?.dy ?? 0) + (tl?.dy ?? 0);
      const shadow = BoxShadow(
        color: Color(0x3A000000),
        blurRadius: 18,
        offset: Offset(0, 6),
      );
      return IgnorePointer(
        child: Stack(
          children: [
            // Tile ghost at the live grid slot (no drop-zone glow).
            // Animate width growing/shrinking as the ghost crosses the odd
            // full-width slot boundary. Position (left/top) follows the raw
            // finger continuously and must not be animated (would lag behind
            // the touch).
            Positioned(
              left: ghostLeft,
              top: ghostTop,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: tileW,
                height: tileH,
                clipBehavior: Clip.none,
                child: Transform.scale(
                  scale: 1.05,
                  child: _buildPinnedTileGhostCard(
                    cat,
                    shadow,
                    // A category-row drag has entered the pinned-grid reorder
                    // path, so the lifted tile must not receive the Dark Mode
                    // ghost hairline.
                    suppressDarkModeOutline: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // In group-creation mode, apply a slight accent-tinted glow to the ghost
    // so the user can see they're about to form a group.
    final inGroupMode = _dragGroupTargetCat != null;
    final groupingColor =
        _dragGroupTargetCat?.color ?? _draggingListCat?.color ?? kCatBlue;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    // IgnorePointer on the outer Stack is CRITICAL — without it the overlay
    // absorbs all pointer events and blocks drag-update / drag-end from
    // reaching the GestureDetector that won the arena (which is underneath).
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: stackGlobal.dx,
            top: globalTopY,
            width: tileWidth,
            height: ghostHeight,
            child: Transform.scale(
              scale: inGroupMode ? 1.02 : 1.05,
              child: Container(
                decoration: inGroupMode
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(_kCornerRadius),
                        // This is a deliberate grouping affordance, not an
                        // elevation shadow, so it remains visible in Dark
                        // Mode where normal card shadows are suppressed.
                        boxShadow: [
                          BoxShadow(
                            color: renderCategoryColor(
                              groupingColor,
                              context,
                            ).withValues(alpha: isDark ? 0.42 : 0.28),
                            blurRadius: isDark ? 18 : 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                    : null,
                child: cat != null
                    ? _buildListDragGhost(
                        cat,
                        suppressDarkModeOutline: _listDragCrossingToGrid,
                      )
                    : _buildListDragGroupHeaderGhost(grp!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Standalone card rendered in the global Overlay while a list row is
  /// being dragged.  Mirrors _CategoryRow._buildRowContent with full corner
  /// radius and an explicit drop shadow (the outer _CategoryCard's shared
  /// shadow is not in scope for the Overlay).
  Widget _buildListDragGhost(
    _UserCategory cat, {
    bool suppressDarkModeOutline = false,
  }) {
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    return Container(
      decoration: ShapeDecoration(
        color: resolveThemeColor(kSbSurface, context),
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
          side: _darkModeGhostBorder(
            context,
            suppress: suppressDarkModeOutline,
          ),
        ),
        shadows: resolveThemeShadows(const [
          BoxShadow(
            color: Color(0x3A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ], context),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _categoryIconCircleColor(
                  cat.iconOrSvg,
                  renderCategoryColor(cat.color, context),
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Transform.translate(
                  offset: const {'Unnamed', 'Uncategorized'}.contains(cat.name)
                      ? Offset(0, -1)
                      : Offset.zero,
                  child: const {'Unnamed', 'Uncategorized'}.contains(cat.name)
                      ? _ThickFolderIcon()
                      : _renderCatIcon(
                          cat.iconOrSvg,
                          34,
                          CupertinoColors.white,
                          emojiOffsetY: 1,
                        ),
                ),
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: cat.description.isEmpty
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Text(
                    cat.name,
                    style: TextStyle(
                      inherit: false,
                      color: resolveThemeColor(kPrimaryLabel, context),
                      fontSize: 16,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      letterSpacing: kTracking16,
                      height: kLineHeight,
                    ),
                  ),
                  if (cat.description.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      cat.description,
                      style: TextStyle(
                        inherit: false,
                        color: resolveThemeColor(kSecondaryLabel, context),
                        fontSize: 13,
                        fontFamily: kSFProText,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.normal,
                        letterSpacing: -0.08,
                        height: kLineHeight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_liveEventCounts[cat.id] ?? 0}',
                  style: TextStyle(
                    inherit: false,
                    color: secondaryLabel,
                    fontSize: 16,
                    fontFamily: kSFProText,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                    letterSpacing: kTracking16,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: secondaryLabel,
                  size: MediaQuery.textScalerOf(context).scale(14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Ghost rendered in the Overlay while a group header is being dragged.
  Widget _buildListDragGroupHeaderGhost(_CategoryGroup group) {
    return Container(
      decoration: ShapeDecoration(
        color: resolveThemeColor(kSbSurface, context),
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
          side: _darkModeGhostBorder(context),
        ),
        shadows: resolveThemeShadows(const [
          BoxShadow(
            color: Color(0x3A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ], context),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -1),
                  child: FixedSFIcon(
                    SFIcons.sf_rectangle_stack,
                    fontSize: 22,
                    color: resolveThemeColor(kSecondaryLabel, context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(
                  inherit: false,
                  color: resolveThemeColor(kPrimaryLabel, context),
                  fontSize: 16,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking16,
                  height: kLineHeight,
                ),
              ),
            ),
            SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${group.memberIds.length}',
                  style: TextStyle(
                    inherit: false,
                    color: resolveThemeColor(kSecondaryLabel, context),
                    fontSize: 16,
                    fontFamily: kSFProText,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                    letterSpacing: kTracking16,
                  ),
                ),
                const SizedBox(width: 4),
                FixedSFIcon(
                  SFIcons.sf_chevron_right,
                  fontSize: MediaQuery.textScalerOf(context).scale(13),
                  color: resolveAccentColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid drag overlay builders ─────────────────────────────────────────────

  Widget _buildGridDragOverlay(BuildContext context) {
    final key = _draggingGridKey;
    if (key == null) return const SizedBox.shrink();
    final box = _gridStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const SizedBox.shrink();
    final topLeft = _dragGridTopLeft;
    if (topLeft == null) return const SizedBox.shrink();
    final stackGlobal = box.localToGlobal(Offset.zero);
    final tileWidth = _dragGridFullWidth
        ? box.size.width
        : (_dragGridTileWidth ??
              (box.size.width - _AnimatedCategoryGrid._colGap) / 2);
    final globalPos = stackGlobal + topLeft;

    // ── Crossing down into list: row ghost follows finger freely ─────────────
    if (_gridDragCrossingToList && key is _UserCategory) {
      final listBox =
          _listStackKey.currentContext?.findRenderObject() as RenderBox?;
      final listGlobal = listBox?.localToGlobal(Offset.zero);
      final rowH = _eventsCategoryListRowHeight(
        context,
        item: _FlatItem.solo(key),
        liveEventCounts: _liveEventCounts,
      );
      final rowW = listBox?.size.width ?? box.size.width;
      final rowLeft = listGlobal?.dx ?? stackGlobal.dx;
      // Use pre-computed global ghost Y — valid even when the list RenderBox
      // is off-screen / lazily unmounted (avoids the "frozen above app" bug).
      final rowTop =
          _crossListGhostGlobalTop ??
          (listGlobal != null
              ? listGlobal.dy + (_dragListTopY ?? 0.0)
              : _dragListTopY ?? 0.0);
      final inGroupMode = _dragGroupTargetCat != null;
      final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
      return IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: rowLeft,
              top: rowTop,
              width: rowW,
              height: rowH,
              child: Transform.scale(
                scale: inGroupMode ? 1.02 : 1.05,
                child: Container(
                  decoration: inGroupMode
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(_kCornerRadius),
                          // Grouping glow is an intentional accent affordance,
                          // not an elevation shadow; keep it visible in Dark
                          // Mode where normal card shadows are suppressed.
                          boxShadow: [
                            BoxShadow(
                              color: renderCategoryColor(
                                (key as _UserCategory).color,
                                context,
                              ).withValues(alpha: isDark ? 0.42 : 0.28),
                              blurRadius: isDark ? 18 : 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        )
                      : null,
                  child: _buildListDragGhost(key),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Position follows the raw finger (no animation — AnimatedPositioned on a
    // per-frame value causes 200 ms of permanent lag).  Only the WIDTH is
    // animated so the grow/shrink when crossing the odd full-width slot feels
    // smooth while the card itself stays 1:1 with the finger.
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: globalPos.dx,
            top: globalPos.dy,
            height: _AnimatedCategoryGrid._rowHeight,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: tileWidth,
              height: _AnimatedCategoryGrid._rowHeight,
              child: Transform.scale(
                scale: 1.05,
                child: _buildGridDragGhost(key, suppressDarkModeOutline: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ghost card rendered in the global Overlay while a grid tile is being
  /// dragged.  Uses a single elevation shadow since kCardShadow is on the
  /// in-Stack tile which is now hidden with Opacity(0).
  Widget _buildGridDragGhost(
    Object key, {
    bool suppressDarkModeOutline = false,
  }) {
    const shadow = BoxShadow(
      color: Color(0x3A000000),
      blurRadius: 18,
      offset: Offset(0, 6),
    );
    if (key is String) {
      final label = key.substring(6);
      final allTiles = _buildSmartTiles();
      final tile = allTiles.firstWhere(
        (t) => t.label == label,
        orElse: () => allTiles.first,
      );
      final color = _smartCategoryColors[label] ?? resolveAccentColor(context);
      return _buildSmartTileGhostCard(
        tile,
        color,
        shadow,
        suppressDarkModeOutline: suppressDarkModeOutline,
      );
    } else if (key is _UserCategory) {
      return _buildPinnedTileGhostCard(
        key,
        shadow,
        suppressDarkModeOutline: suppressDarkModeOutline,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSmartTileGhostCard(
    _TileData tile,
    Color color,
    BoxShadow shadow, {
    bool suppressDarkModeOutline = false,
  }) {
    // Replicate the exact icon layout from _CategoryTile._buildCard() so the
    // ghost matches the static tile pixel-for-pixel.
    //
    // Calendar tiles (Today / Tomorrow / This Week / Next Week):
    //   • SVG calendar frame centred in the circle
    //   • Day number overlaid at top:14 via a Positioned, same scale+scaleY
    //
    // Icon tiles with special offsets:
    //   • tray_fill (All Events): translate (0, -1) — matches _buildIconContent
    //   • clock (Unscheduled):    translate (0, -1)
    //   • Others: plain Icon
    final Widget circleContent;
    if (tile.isCalendar) {
      circleContent = Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: SvgPicture.asset(
                'assets/icons/calendar_frame.svg',
                colorFilter: const ColorFilter.mode(
                  Color(0xFFFFFFFF),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          if (tile.day != null)
            Positioned(
              top: 14.6,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.scale(
                  scale: 1.05,
                  scaleY: 1.3,
                  child: Text(
                    '${tile.day}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      inherit: false,
                      color: Color(0xFFFFFFFF),
                      fontSize: 9.5,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      height: 1.0,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      final icon = tile.icon!;
      final Widget inner;
      if (icon == CupertinoIcons.tray_fill) {
        inner = Transform.translate(
          offset: const Offset(0, -1),
          child: Icon(icon, color: CupertinoColors.white, size: tile.iconSize),
        );
      } else if (icon == CupertinoIcons.clock) {
        inner = Transform.translate(
          offset: const Offset(0, -1),
          child: Icon(icon, color: CupertinoColors.white, size: tile.iconSize),
        );
      } else {
        inner = Icon(icon, color: CupertinoColors.white, size: tile.iconSize);
      }
      circleContent = Center(child: inner);
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: ShapeDecoration(
        color: resolveThemeColor(kSbSurface, context),
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
          side: _darkModeGhostBorder(
            context,
            suppress: suppressDarkModeOutline,
          ),
        ),
        shadows: resolveThemeShadows([shadow], context),
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -2,
            left: 0,
            child: Container(
              width: 35.5,
              height: 35.5,
              decoration: BoxDecoration(
                color: renderCategoryColor(color, context),
                shape: BoxShape.circle,
              ),
              child: circleContent,
            ),
          ),
          Positioned(
            top: -2,
            right: 0,
            child: SizedBox(
              height: 35.5,
              child: Center(
                child: Text(
                  '${tile.count}',
                  style: TextStyle(
                    inherit: false,
                    color: resolveThemeColor(kPrimaryLabel, context),
                    fontSize: 32,
                    fontFamily: kSFProDisplay,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Transform.translate(
              offset: const Offset(0, 1.5),
              child: Text(
                tile.label,
                style: TextStyle(
                  inherit: false,
                  color: resolveThemeColor(kSecondaryLabel, context),
                  fontSize: 17,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: kTracking17,
                  height: kLineHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedTileGhostCard(
    _UserCategory cat,
    BoxShadow shadow, {
    bool suppressDarkModeOutline = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: ShapeDecoration(
        color: resolveThemeColor(kSbSurface, context),
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
          side: _darkModeGhostBorder(
            context,
            suppress: suppressDarkModeOutline,
          ),
        ),
        shadows: resolveThemeShadows([shadow], context),
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -2,
            left: 0,
            child: Container(
              width: 35.5,
              height: 35.5,
              decoration: BoxDecoration(
                color: _categoryIconCircleColor(
                  cat.iconOrSvg,
                  renderCategoryColor(cat.color, context),
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: const {'Unnamed', 'Uncategorized'}.contains(cat.name)
                    ? _ThickFolderIcon()
                    : _renderCatIcon(
                        cat.iconOrSvg,
                        35.5,
                        CupertinoColors.white,
                        emojiOffsetY: 1,
                        ctx: context,
                      ),
              ),
            ),
          ),
          Positioned(
            top: -2,
            right: 0,
            child: SizedBox(
              height: 35.5,
              child: Center(
                child: Text(
                  '${_liveEventCounts[cat.id] ?? 0}',
                  style: TextStyle(
                    inherit: false,
                    color: resolveThemeColor(kPrimaryLabel, context),
                    fontSize: 32,
                    fontFamily: kSFProDisplay,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Transform.translate(
              offset: const Offset(0, 1.5),
              child: Text(
                cat.name,
                style: TextStyle(
                  inherit: false,
                  color: resolveThemeColor(kSecondaryLabel, context),
                  fontSize: 17,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: kTracking17,
                  height: kLineHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Flags [cat] as archived so it's hidden from the grid/list without
  /// deleting it. No reveal/unarchive UI exists yet — tracked as follow-up.
  /// Phase 1 plays a soft slide+fade+collapse; phase 2 flips the archived
  /// flag once that finishes (row/tile is already invisible by then).
  void _archiveCategory(_UserCategory cat) {
    final inGrid = _pinnedUserCategories.contains(cat);
    setState(() {
      if (inGrid) {
        _archivingFromGrid.add(cat);
      } else {
        _archivingFromList.add(cat);
      }
    });
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final archived = cat.copyWith(archived: true);
      setState(() {
        _archivingFromList.remove(cat);
        _archivingFromGrid.remove(cat);
        final i = _userCategories.indexOf(cat);
        if (i != -1) {
          _userCategories[i] = archived;
          // Remove from group (dissolves if < 2 remain) and from solo slot.
          // The archived category stays in _userCategories but is hidden.
          _removeFromGroupById(cat.id);
          _listTopOrder.remove(cat.id);
        } else {
          final j = _pinnedUserCategories.indexOf(cat);
          if (j != -1) {
            _pinnedUserCategories[j] = archived;
            // Archived pinned tiles leave the grid entirely.
            _gridCombinedOrder.remove(cat);
          }
        }
      });
      _saveCategories();
    });
  }

  /// Builds one pinned-user-category grid tile, wrapped in whichever
  /// animation matches its current lifecycle action:
  ///  - unpin: shrink+fade out (existing _removingFromGrid path)
  ///  - pin (arriving from the list): spring scale+fade in (_newInGrid)
  ///  - archive: soft fade + gentle scale-down, no bounce
  ///  - delete: sharper fade + scale-down with a destructive-red flash
  /// ObjectKey keeps Flutter tracking the tile by identity across mutations.
  Widget _buildPinnedGridTile(_UserCategory c) {
    final tile = RepaintBoundary(
      child: _PinnedUserTile(
        category: c,
        liveCount: _liveEventCounts[c.id] ?? 0,
        onUnpin: () => _unpinCategory(c),
        onEdit: () => _editCategory(c),
        onArchive: () => _archiveCategory(c),
        onDelete: () => _deletePinnedCategory(c),
        onReorderStart: (p) => _onGridReorderStart(c, p),
        onReorderUpdate: (p) => _onGridReorderUpdate(c, p),
        onReorderEnd: () => _onGridReorderEnd(c),
        onReorderCancel: () => _onGridReorderCancel(c),
      ),
    );

    final isArchiving = _archivingFromGrid.contains(c);
    final isDeleting = _deletingFromGrid.contains(c);
    final isRemoving =
        _removingFromGrid.contains(c) || isArchiving || isDeleting;
    final isNew = _newInGrid.contains(c);
    final hidden = isRemoving || isNew;

    Widget wrapped = AnimatedOpacity(
      duration: Duration(milliseconds: isDeleting ? 200 : 180),
      curve: hidden && !isNew ? Curves.easeIn : Curves.easeOut,
      opacity: hidden ? 0.0 : 1.0,
      child: AnimatedScale(
        duration: Duration(milliseconds: isDeleting ? 200 : 180),
        curve: isNew
            ? Curves
                  .easeOutBack // pin: spring in
            : (isArchiving || isDeleting)
            ? Curves
                  .easeInCubic // archive/delete: settle down, no bounce
            : Curves.easeIn, // unpin: plain shrink
        scale: !hidden
            ? 1.0
            : isDeleting
            ? 0.7
            : isArchiving
            ? 0.8
            : 0.75,
        child: tile,
      ),
    );

    if (isDeleting) {
      wrapped = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.16, end: 0.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        builder: (context, flashAlpha, child) => Container(
          decoration: BoxDecoration(
            color: CupertinoColors.destructiveRed.withValues(alpha: flashAlpha),
            borderRadius: BorderRadius.circular(_kCornerRadius),
          ),
          child: child,
        ),
        child: wrapped,
      );
    }

    // When dragging, the ghost is in the global Overlay — visually hide the
    // in-Stack placeholder.  IMPORTANT: Opacity must be present in the tree
    // at ALL times (both dragging and not), only its value changes.  If the
    // wrapper is introduced conditionally on drag-start, Flutter tears down
    // the element and destroys the GestureDetector, killing the live gesture
    // recognizer before _onLongPressEnd can fire.  By keeping the structure
    // identical, the recognizer continues tracking the pointer through the
    // opacity change and fires end/cancel correctly.
    final Widget child = Opacity(
      opacity: c == _draggingGridKey ? 0.0 : 1.0,
      child: wrapped,
    );
    return KeyedSubtree(key: ObjectKey(c), child: child);
  }

  /// Builds the 8 fixed smart tiles.  Shared by the grid build() and by
  /// [editCategory] (which needs to look one up by label without a full
  /// rebuild).  [allCount] may be omitted when only label/icon/isCalendar
  /// matter (e.g. opening the editor) — the count itself isn't shown there.
  List<_TileData> _buildSmartTiles({
    int todayCount = 0,
    int tomorrowCount = 0,
    int thisWeekCount = 0,
    int nextWeekCount = 0,
    int scheduledCount = 0,
    int unscheduledCount = 0,
    int allCount = 0,
    int completedCount = 0,
  }) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final thisMonday = now.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    final nextMonday = thisMonday.add(const Duration(days: 7));

    return [
      _TileData.calendar(label: 'Today', count: todayCount, day: now.day),
      _TileData.calendar(
        label: 'Tomorrow',
        count: tomorrowCount,
        day: tomorrow.day,
      ),
      _TileData.calendar(
        label: 'This Week',
        count: thisWeekCount,
        day: _isoWeekNumber(thisMonday),
      ),
      _TileData.calendar(
        label: 'Next Week',
        count: nextWeekCount,
        day: _isoWeekNumber(nextMonday),
      ),
      _TileData.icon(
        label: 'Scheduled',
        count: scheduledCount,
        icon: CupertinoIcons.calendar,
        iconSize: 24.4,
      ),
      _TileData.icon(
        label: 'Unscheduled',
        count: unscheduledCount,
        icon: CupertinoIcons.clock,
        iconSize: 23.3,
      ),
      _TileData.icon(
        label: 'All Events',
        count: allCount,
        icon: CupertinoIcons.tray_fill,
        iconSize: 22.2,
      ),
      _TileData.icon(
        label: 'Completed',
        count: completedCount,
        icon: CupertinoIcons.checkmark,
        iconSize: 22.2,
      ),
    ];
  }

  /// Opens the category editor pre-filled with [cat]'s current info.
  /// Replaces [cat] in whichever list currently holds it once saved.
  void _editCategory(_UserCategory cat) {
    showRoundedCupertinoSheet<void>(
      context: context,
      pageBuilder: (context) => _AddCategorySheet(
        initial: cat,
        onSave: (updated) => _updateCategory(cat, updated),
      ),
    );
  }

  /// Opens the category editor for a fixed smart tile. Title/description are
  /// locked and there's no icon picker — only the color swatch is editable.
  void _editSmartCategory(_TileData data) {
    showRoundedCupertinoSheet<void>(
      context: context,
      pageBuilder: (context) => _AddCategorySheet(
        smartData: data,
        smartColor:
            _smartCategoryColors[data.label] ?? resolveAccentColor(context),
        onSaveColor: (color) => _updateSmartCategoryColor(data.label, color),
      ),
    );
  }

  void _updateCategory(_UserCategory oldCat, _UserCategory updated) {
    setState(() {
      final i = _userCategories.indexOf(oldCat);
      if (i != -1) {
        _userCategories[i] = updated;
      } else {
        final j = _pinnedUserCategories.indexOf(oldCat);
        if (j != -1) {
          _pinnedUserCategories[j] = updated;
          // Keep the unified order's reference current.
          final gi = _gridCombinedOrder.indexOf(oldCat);
          if (gi != -1) _gridCombinedOrder[gi] = updated;
        }
      }
    });
    _saveCategories();

    // Propagate the updated preset values to every event in this category.
    // Serialise the custom repeat config if present.
    Map<String, dynamic>? customCfg;
    if (updated.presetCustomRepeatConfig != null) {
      customCfg = updated.presetCustomRepeatConfig;
    }
    EventStore.instance.updateCategoryPresets(
      categoryId: updated.id,
      location: updated.presetLocation,
      destination: updated.presetDestination,
      travelTime: updated.presetTravelTime,
      travelMode: updated.presetTravelMode,
      repeat: updated.presetRepeat,
      repeatEndType: updated.presetRepeatEndType,
      repeatEndDate: updated.presetRepeatEndDate,
      customRepeatConfig: customCfg,
      alert: updated.presetAlert ?? 'At time of event',
      secondAlert: updated.presetSecondAlert,
    );
    // Keep the Smart Category AI parse cache consistent when the rule changes.
    // Evict the old description so a revert to the previous text gets a fresh
    // Gemini parse rather than the cached result from before the edit.
    if (updated.categoryType == 'Smart Category') {
      final oldDesc = oldCat.smartDescription;
      final newDesc = updated.smartDescription;
      if (oldDesc != newDesc && oldDesc.isNotEmpty) {
        AIServices.evictRule(oldDesc);
      }
      if (newDesc.isNotEmpty) {
        AIServices.embedCategory(updated.name, newDesc);
        AIServices.parseAndRegisterRule(newDesc);
      }
    }

    // If this category's DCV happens to be open right now, tell AppShell so
    // it can refresh its cached header accent colour immediately instead of
    // leaving it stale until the user leaves and re-enters the DCV.
    if (widget.activeDCV == updated.name) {
      // Resolve before forwarding: if the category still carries the kCatBlue
      // sentinel, pass the live accent so AppShell refreshes correctly.
      widget.onActiveDCVCategoryChanged?.call(
        updated.name,
        renderCategoryColor(updated.color, context),
      );
    }
  }

  /// Called by AppShell when the user taps "Edit Category Info" in the DCV
  /// ellipsis action panel.  Looks [name] up among the smart tiles and the
  /// user categories and opens the matching editor sheet.
  void editCategory(String name) {
    if (_kDCVLabels.contains(name)) {
      final tile = _buildSmartTiles().cast<_TileData?>().firstWhere(
        (t) => t?.label == name,
        orElse: () => null,
      );
      if (tile != null) _editSmartCategory(tile);
      return;
    }
    final cat = [..._userCategories, ..._pinnedUserCategories]
        .cast<_UserCategory?>()
        .firstWhere((c) => c?.name == name, orElse: () => null);
    if (cat != null) _editCategory(cat);
  }

  /// Adds an editable section to the currently open DCV.
  void addDcvSection(String label) {
    if (label.trim().isEmpty) return;
    setState(() {
      final names = _dcvCustomSectionNames[label] ??= <String>[];
      names.add('');
      final eventSections = _dcvCustomSectionEventIds[label] ??=
          <List<String>>[];
      while (eventSections.length < names.length) {
        eventSections.add(<String>[]);
      }
    });
    _saveCategories();
  }

  /// Opens the section-order editor for the currently visible DCV.
  void editDcvSections(String label, Color accentColor) {
    final names = _dcvCustomSectionNames[label];
    if (names == null || names.isEmpty) return;
    showRoundedCupertinoSheet<void>(
      context: context,
      pageBuilder: (_) => _EditDcvSectionsSheet(
        sectionNames: [
          for (final name in names)
            name.trim().isEmpty ? 'New Section' : name.trim(),
        ],
        accentColor: accentColor,
        onSave: (order, editedNames) =>
            reorderDcvSections(label, order, editedNames: editedNames),
      ),
    );
  }

  /// Applies section names/order to both the visible headers and their event
  /// membership. The editor returns original indexes rather than names so
  /// duplicate section titles remain unambiguous. Missing indexes represent
  /// sections deleted in the editor.
  void reorderDcvSections(
    String label,
    List<int> order, {
    List<String>? editedNames,
  }) {
    final names = _dcvCustomSectionNames[label];
    if (names == null) return;
    final sourceNames =
        editedNames != null && editedNames.length == names.length
        ? <String>[for (final name in editedNames) name.trim()]
        : List<String>.of(names);

    final eventIds = _dcvCustomSectionEventIds[label] ?? const <List<String>>[];
    final normalizedEventIds = List<List<String>>.generate(
      names.length,
      (index) => index < eventIds.length
          ? List<String>.of(eventIds[index])
          : <String>[],
    );
    // A newly-created event is initially assigned to the first visible
    // section by _CategoryDetailView.  That local assignment may not have
    // reached the parent map before the user opens Edit Sections.  Reconcile
    // those events before applying the header permutation, otherwise the
    // event is considered unassigned after the old first section moves.
    final visibleEventIds = _visibleDcvEventIds(label);
    final assignedEventIds = {
      for (final section in normalizedEventIds) ...section,
    };
    final unassignedVisibleEventIds = visibleEventIds
        .where((id) => assignedEventIds.add(id))
        .toList();
    if (unassignedVisibleEventIds.isNotEmpty) {
      normalizedEventIds.first.addAll(unassignedVisibleEventIds);
    }
    final validOrder =
        order.toSet().length == order.length &&
        order.every((index) => index >= 0 && index < names.length);
    if (!validOrder) return;

    final removedEventIds = <String>[
      for (var index = 0; index < names.length; index++)
        if (!order.contains(index)) ...normalizedEventIds[index],
    ];
    final reorderedNames = <String>[
      for (final index in order) sourceNames[index],
    ];
    final reorderedEventIds = <List<String>>[
      for (final index in order) List<String>.of(normalizedEventIds[index]),
    ];

    // Events from a deleted section must remain grouped rather than silently
    // joining an unrelated section.  Keep a single generated "Others" bucket
    // at the end whenever deletion leaves events without a home.  If an
    // Others bucket already exists, move it to the end and append the newly
    // orphaned events to it.
    if (removedEventIds.isNotEmpty) {
      final existingOthersIndex = reorderedNames.indexWhere(
        (name) => name.trim() == 'Others',
      );
      final othersEventIds = <String>[];
      if (existingOthersIndex != -1) {
        othersEventIds.addAll(reorderedEventIds.removeAt(existingOthersIndex));
        reorderedNames.removeAt(existingOthersIndex);
      }
      othersEventIds.addAll(removedEventIds);
      reorderedNames.add('Others');
      reorderedEventIds.add(othersEventIds);
    }

    setState(() {
      _dcvCustomSectionNames[label] = reorderedNames;
      _dcvCustomSectionEventIds[label] = reorderedEventIds;
    });
    _saveCategories();
  }

  /// Returns the event IDs currently visible in a DCV.
  ///
  /// This deliberately mirrors the filtering used when building the DCV.
  /// It is used only to repair the parent-side section membership map before
  /// a section edit, so events created immediately before the edit cannot be
  /// mistaken for belonging to the newly-first section.
  List<String> _visibleDcvEventIds(String label) {
    final allEvents = EventStore.instance.events.value;
    final cat = [..._userCategories, ..._pinnedUserCategories]
        .cast<_UserCategory?>()
        .firstWhere((category) => category?.name == label, orElse: () => null);

    const builtIns = {
      'Today',
      'Tomorrow',
      'This Week',
      'Next Week',
      'Scheduled',
      'Unscheduled',
      'All Events',
      'Completed',
    };
    if (cat?.categoryType == 'Smart Category' &&
        cat!.smartDescription.isNotEmpty) {
      return AIServices.matcher
          .match(
            candidates: allEvents,
            rule: cat.smartDescription,
            categoryName: cat.name,
            now: DateTime.now(),
          )
          .map((event) => event.id)
          .toList();
    }
    if (builtIns.contains(label)) {
      return AIServices.matcher
          .match(
            candidates: allEvents,
            rule: label,
            builtInLabel: label,
            now: DateTime.now(),
          )
          .map((event) => event.id)
          .toList();
    }

    final categoryId = cat?.id;
    if (categoryId == null) return const <String>[];
    const uncategorizedIds = {'sys-uncategorized', 'uncategorized', ''};
    final isUncategorized = uncategorizedIds.contains(categoryId);
    final knownCategoryIds = {
      ..._userCategories,
      ..._pinnedUserCategories,
    }.map((category) => category.id).toSet();
    return allEvents
        .where(
          (event) => isUncategorized
              ? uncategorizedIds.contains(event.categoryId) ||
                    !knownCategoryIds.contains(event.categoryId)
              : event.categoryId == categoryId,
        )
        .map((event) => event.id)
        .toList();
  }

  /// Deletes a section immediately from the DCV header's swipe action.
  void deleteDcvSection(String label, int index) {
    final names = _dcvCustomSectionNames[label];
    if (names == null || index < 0 || index >= names.length) return;
    reorderDcvSections(label, [
      for (var i = 0; i < names.length; i++)
        if (i != index) i,
    ]);
  }

  void _reorderDcvSections(String label, List<List<String>> sectionEventIds) {
    setState(() {
      _dcvCustomSectionEventIds[label] = sectionEventIds
          .map(List<String>.of)
          .toList();
    });
    _saveCategories();
  }

  void _renameDcvSection(
    String label,
    int index,
    String title, {
    bool persist = true,
  }) {
    final sections = _dcvCustomSectionNames[label];
    if (sections == null || index < 0 || index >= sections.length) return;
    final normalized = title.trim();
    if (sections[index] == normalized) return;
    setState(() => sections[index] = normalized);
    if (persist) _saveCategories();
  }

  /// Opens the same Add Category sheet used by the inline button so the
  /// Events header can provide a quick-create shortcut.
  void addCategory() {
    showRoundedCupertinoSheet<void>(
      context: context,
      pageBuilder: (context) => _AddCategorySheet(onSave: _handleNewCategory),
    );
  }

  void _handleNewCategory(_UserCategory cat) {
    setState(() {
      _userCategories.add(cat);
      _listTopOrder.add(cat.id); // new categories appear at end of list
      _poppingInList.add(cat);
    });
    _saveCategories();
    // Embed Smart Category descriptions for semantic matching and parse
    // any compound temporal rules (e.g. "weekday lunches in September").
    if (cat.categoryType == 'Smart Category' &&
        cat.smartDescription.isNotEmpty) {
      AIServices.embedCategory(cat.name, cat.smartDescription);
      AIServices.parseAndRegisterRule(cat.smartDescription);
    }
    // Keep the same one-shot pop-in timing as the inline Add Category button.
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _poppingInList.remove(cat));
    });
  }

  /// Called by AppShell when the user taps "Delete Category" in the DCV
  /// ellipsis action panel.  Looks the category up by name and routes
  /// through the same animated delete used by the list/grid context menus.
  void deleteCategory(String name) {
    final cat = [..._userCategories, ..._pinnedUserCategories]
        .cast<_UserCategory?>()
        .firstWhere((c) => c?.name == name, orElse: () => null);
    if (cat == null) return;
    if (_pinnedUserCategories.contains(cat)) {
      _deletePinnedCategory(cat);
    } else {
      _deleteUserCategory(cat);
    }
  }

  /// Called by AppShell when the user taps "Archive Category" in the DCV
  /// ellipsis action panel. Built-in smart DCVs and user categories share the
  /// same archive behavior used by their grid/list context menus.
  void archiveCategory(String name) {
    if (_kDCVLabels.contains(name)) {
      _archiveSmartCategory(name);
      return;
    }
    final cat = [..._userCategories, ..._pinnedUserCategories]
        .cast<_UserCategory?>()
        .firstWhere((c) => c?.name == name, orElse: () => null);
    if (cat != null) _archiveCategory(cat);
  }

  /// Exposed so AppShell can check whether the search bar is on-screen.
  ScrollController get scrollController => _scrollController;

  /// Called by AppShell when the user taps the header search icon.
  void focusSearch() => NativeTextInput.focus(_searchController);

  // Drift guard: called on every scroll notification of the main scroll view.
  // While the off-screen overlay is active the main scroll view must stay
  // exactly at _savedScrollOffset.  Any deviation (keyboard-induced resize,
  // Flutter primary-scroll-controller magic, etc.) is immediately corrected
  // with a synchronous jumpTo.  The _lockingScrollDrift flag prevents the
  // jumpTo itself from re-entering and looping.
  void _enforceScrollLock() {
    if (!_activatedFromOffScreen) return;
    if (_lockingScrollDrift) return;
    if (!_scrollController.hasClients) return;
    final current = _scrollController.offset;
    if (current == _savedScrollOffset) return;
    _lockingScrollDrift = true;
    _scrollController.jumpTo(_savedScrollOffset);
    _lockingScrollDrift = false;
  }

  void activateSearchMode() {
    if (_searchFocused) return;
    _activatedFromOffScreen = true;
    _greyActive = true;
    _greyFadeIn = true;
    _savedScrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
    // Do NOT scroll to 0.  The SliverPersistentHeader is pinned so it stays
    // visible at the viewport top regardless of scroll offset.  The
    // SliverFillRemaining grey fill covers the rest of the viewport, making
    // the search bar appear as an overlay without disturbing the scroll position.
    setState(() => _searchFocused = true);
    // Set sbSearchModeActive immediately — _onSearchFocusChanged(true) returns
    // early in this path (because _searchFocused is already true by the time
    // the NativeTextInput fires onFocusChanged), so we must set it here.
    sbSearchModeActive = true;
    // One post-frame is enough: the rebuild switches to SliverPersistentHeader
    // (pinned), so the bar is in the viewport by the time the frame paints.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NativeTextInput.focus(_searchController);
        // Lock after focus to prevent iOS from implicitly resigning first
        // responder (tap-outside / scroll-drag) during the search session.
        NativeTextInput.lockFocus(_searchController);
      }
    });
  }

  Timer? _midnightTimer;
  Timer? _clockTimer;

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (mounted) setState(() {});
      _scheduleMidnightRefresh();
    });
  }

  bool get _appIsBackgrounded {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
  }

  // ── EventStore listener ───────────────────────────────────────────────────
  void _onEventsChanged() {
    if (mounted) setState(() {});
    _reloadPersistedDcvSections();
  }

  Future<void> _reloadPersistedDcvSections() async {
    final prefs = await SharedPreferences.getInstance();
    final rawNames = prefs.getString(_kPrefsDcvCustomSections);
    final rawEventIds = prefs.getString(_kPrefsDcvCustomSectionEventIds);
    if (!mounted || (rawNames == null && rawEventIds == null)) return;

    final names = <String, List<String>>{};
    final eventIds = <String, List<List<String>>>{};
    try {
      final decoded = rawNames == null ? null : jsonDecode(rawNames);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          names[entry.key.toString()] = entry.value is List
              ? [for (final name in entry.value as List) name.toString()]
              : <String>[];
        }
      }
    } catch (_) {}
    try {
      final decoded = rawEventIds == null ? null : jsonDecode(rawEventIds);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          eventIds[entry.key.toString()] = entry.value is List
              ? [
                  for (final section in entry.value as List)
                    section is List
                        ? [for (final id in section) id.toString()]
                        : <String>[],
                ]
              : <List<String>>[];
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _dcvCustomSectionNames
        ..clear()
        ..addAll(names);
      _dcvCustomSectionEventIds
        ..clear()
        ..addAll(eventIds);
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
    // Per-second clock so date numbers (today/tomorrow/week) update live
    // without requiring tab switches.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    EventStore.instance.events.addListener(_onEventsChanged);
    _scrollController.addListener(_enforceScrollLock);
    // Seed smart category display order from the fixed tile list.
    // _loadCategories() will override this from persisted prefs if they exist.
    _smartCategoryOrder.addAll(_buildSmartTiles().map((t) => t.label));
    // Seed unified grid order from smart labels; _loadCategories() will
    // override this (and interleave any pinned user categories).
    _gridCombinedOrder.addAll(_smartCategoryOrder);
    // Seed _listTopOrder from the default user categories.
    // _loadCategories() will override this from persisted prefs if they exist.
    _listTopOrder.addAll(_userCategories.map((c) => c.id));
    _loadCategories();
  }

  @override
  void didUpdateWidget(covariant EventsTab old) {
    super.didUpdateWidget(old);
    // The active section editor can still have focus when the DCV closes, so
    // its final onSubmitted callback is not guaranteed to run. Persist the
    // live in-memory section names before the detail view is left.
    if (old.activeDCV != widget.activeDCV) {
      _saveCategories();
    }
    // Sort settings live in _AppState but propagate deep inside a
    // SlideTransition → Builder chain. Without an explicit rebuild here,
    // Flutter may skip calling build() when only the sort props change
    // (DCV already open, no events change, slide animation not playing).
    // Forcing a rebuild guarantees _CategoryDetailView always receives the
    // latest sortBy/sortDir, making the sort setting truly global.
    if (old.dcvSortBy != widget.dcvSortBy ||
        old.dcvSortDir != widget.dcvSortDir) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _clockTimer?.cancel();
    _searchDebounce?.cancel();
    _listDragOverlayEntry?.remove();
    _listDragOverlayEntry = null;
    _gridDragOverlayEntry?.remove();
    _gridDragOverlayEntry = null;
    EventStore.instance.events.removeListener(_onEventsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchTextChanged);
    _scrollController.dispose();
    _searchController.dispose();
    // dcvSlideController is owned and disposed by AppShell — do NOT dispose here.
    super.dispose();
  }

  // ── SharedPreferences persistence ─────────────────────────────────────────

  static const _kPrefsUserCats = 'events_user_categories';
  static const _kPrefsPinnedCats = 'events_pinned_categories';
  static const _kPrefsSmartColors = 'events_smart_category_colors';
  static const _kPrefsArchivedSmart = 'events_archived_smart_categories';
  static const _kPrefsSmartOrder = 'events_smart_category_order';
  static const _kPrefsGridCombinedOrder = 'events_grid_combined_order';
  static const _kPrefsCategoryGroups = 'events_category_groups';
  static const _kPrefsListTopOrder = 'events_list_top_order';
  static const _kPrefsDcvCustomSections = 'events_dcv_custom_sections';
  static const _kPrefsDcvCustomSectionEventIds =
      'events_dcv_custom_section_event_ids';

  // True while the "couldn't save" banner is visible — prevents duplicate
  // overlays if _saveCategories() is called several times in quick succession
  // while storage is still full.
  bool _saveBannerVisible = false;

  void _saveCategories() {
    SharedPreferences.getInstance()
        .then((prefs) async {
          try {
            final results = await Future.wait<bool>([
              prefs.setStringList(
                _kPrefsUserCats,
                _userCategories.map((c) => jsonEncode(c.toJson())).toList(),
              ),
              prefs.setStringList(
                _kPrefsPinnedCats,
                _pinnedUserCategories
                    .map((c) => jsonEncode(c.toJson()))
                    .toList(),
              ),
              prefs.setString(
                _kPrefsSmartColors,
                jsonEncode(
                  _smartCategoryColors.map((k, v) => MapEntry(k, v.value)),
                ),
              ),
              prefs.setStringList(
                _kPrefsArchivedSmart,
                _archivedSmartCategories.toList(),
              ),
              prefs.setStringList(_kPrefsSmartOrder, _smartCategoryOrder),
              prefs.setStringList(
                _kPrefsGridCombinedOrder,
                _gridCombinedOrder
                    .map(
                      (e) => e is String
                          ? 'smart_$e'
                          : 'pinned_${(e as _UserCategory).id}',
                    )
                    .toList(),
              ),
              // Persist groups and list order.
              prefs.setStringList(
                _kPrefsCategoryGroups,
                _categoryGroups.map((g) => jsonEncode(g.toJson())).toList(),
              ),
              prefs.setStringList(_kPrefsListTopOrder, _listTopOrder),
              prefs.setString(
                _kPrefsDcvCustomSections,
                jsonEncode(_dcvCustomSectionNames),
              ),
              prefs.setString(
                _kPrefsDcvCustomSectionEventIds,
                jsonEncode(_dcvCustomSectionEventIds),
              ),
            ]);
            if (results.any((ok) => !ok) && mounted) {
              _showCategorySaveError();
            }
          } catch (_) {
            if (mounted) _showCategorySaveError();
          }
        })
        .catchError((_) {
          if (mounted) _showCategorySaveError();
        });
  }

  /// Shows a non-intrusive banner at the bottom of the screen when category
  /// persistence fails (e.g. device storage is full).  The banner auto-
  /// dismisses after 4 seconds.  At most one copy is shown at a time.
  void _showCategorySaveError() {
    if (_saveBannerVisible) return;
    _saveBannerVisible = true;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _StorageFullBanner(
        onDismissed: () {
          entry.remove();
          if (mounted) setState(() => _saveBannerVisible = false);
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  void _loadCategories() {
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final rawUser = prefs.getStringList(_kPrefsUserCats);
      final rawPinned = prefs.getStringList(_kPrefsPinnedCats);
      final rawSmartColors = prefs.getString(_kPrefsSmartColors);
      final rawArchivedSmart = prefs.getStringList(_kPrefsArchivedSmart);
      final rawSmartOrder = prefs.getStringList(_kPrefsSmartOrder);
      final rawGridCombined = prefs.getStringList(_kPrefsGridCombinedOrder);
      final rawGroups = prefs.getStringList(_kPrefsCategoryGroups);
      final rawListOrder = prefs.getStringList(_kPrefsListTopOrder);
      final rawDcvSections = prefs.getString(_kPrefsDcvCustomSections);
      final rawDcvSectionEventIds = prefs.getString(
        _kPrefsDcvCustomSectionEventIds,
      );
      if (rawUser == null &&
          rawPinned == null &&
          rawSmartColors == null &&
          rawArchivedSmart == null &&
          rawSmartOrder == null &&
          rawDcvSections == null &&
          rawDcvSectionEventIds == null) {
        return; // first launch — keep defaults
      }
      setState(() {
        if (rawDcvSections != null) {
          final decoded = jsonDecode(rawDcvSections);
          if (decoded is Map) {
            _dcvCustomSectionNames
              ..clear()
              ..addAll(
                decoded.map(
                  (key, value) => MapEntry(
                    key.toString(),
                    value is List
                        ? value.map((name) => name.toString()).toList()
                        : <String>[],
                  ),
                ),
              );
          }
        }
        if (rawDcvSectionEventIds != null) {
          final decoded = jsonDecode(rawDcvSectionEventIds);
          if (decoded is Map) {
            _dcvCustomSectionEventIds
              ..clear()
              ..addAll(
                decoded.map(
                  (key, value) => MapEntry(
                    key.toString(),
                    value is List
                        ? [
                            for (final section in value)
                              section is List
                                  ? section.map((id) => id.toString()).toList()
                                  : <String>[],
                          ]
                        : <List<String>>[],
                  ),
                ),
              );
          }
        }
        if (rawUser != null) {
          _userCategories
            ..clear()
            ..addAll(
              rawUser.map(
                (s) => _UserCategory.fromJson(
                  jsonDecode(s) as Map<String, dynamic>,
                ),
              ),
            );
        }
        if (rawPinned != null) {
          _pinnedUserCategories
            ..clear()
            ..addAll(
              rawPinned.map(
                (s) => _UserCategory.fromJson(
                  jsonDecode(s) as Map<String, dynamic>,
                ),
              ),
            );
        }
        if (rawSmartColors != null) {
          final decoded = jsonDecode(rawSmartColors) as Map<String, dynamic>;
          _smartCategoryColors
            ..clear()
            ..addAll(
              decoded.map(
                (k, v) => MapEntry(k, resolveCategorySwatch(Color(v as int))),
              ),
            );
        }
        if (rawArchivedSmart != null) {
          _archivedSmartCategories
            ..clear()
            ..addAll(rawArchivedSmart);
        }
        if (rawSmartOrder != null && rawSmartOrder.isNotEmpty) {
          _smartCategoryOrder
            ..clear()
            ..addAll(rawSmartOrder);
        }
        // Rebuild the unified grid order from the saved token list.
        // Tokens: "smart_<label>" or "pinned_<id>".
        // Legacy saves used "pinned_<name>" — fall back to name lookup so
        // existing installs migrate transparently on first load.
        final pinnedById = {for (final c in _pinnedUserCategories) c.id: c};
        final pinnedByName = {for (final c in _pinnedUserCategories) c.name: c};
        if (rawGridCombined != null && rawGridCombined.isNotEmpty) {
          _gridCombinedOrder.clear();
          for (final token in rawGridCombined) {
            if (token.startsWith('smart_')) {
              final label = token.substring(6);
              if (_smartCategoryOrder.contains(label) &&
                  !_archivedSmartCategories.contains(label)) {
                _gridCombinedOrder.add(label);
              }
            } else if (token.startsWith('pinned_')) {
              final key = token.substring(7);
              final cat = pinnedById[key] ?? pinnedByName[key];
              if (cat != null && !cat.archived) _gridCombinedOrder.add(cat);
            }
          }
          // Append any smart labels that appeared after the prefs were saved.
          for (final label in _smartCategoryOrder) {
            if (!_archivedSmartCategories.contains(label) &&
                !_gridCombinedOrder.contains(label)) {
              _gridCombinedOrder.add(label);
            }
          }
          // Append any pinned categories not yet in the saved order.
          for (final cat in _pinnedUserCategories) {
            if (!cat.archived && !_gridCombinedOrder.contains(cat)) {
              _gridCombinedOrder.add(cat);
            }
          }
        } else {
          // No saved combined order — build from section-local orders.
          _gridCombinedOrder
            ..clear()
            ..addAll(
              _smartCategoryOrder.where(
                (l) => !_archivedSmartCategories.contains(l),
              ),
            )
            ..addAll(_pinnedUserCategories.where((c) => !c.archived));
        }

        // Restore groups.
        if (rawGroups != null) {
          _categoryGroups
            ..clear()
            ..addAll(
              rawGroups.map(
                (s) => _CategoryGroup.fromJson(
                  jsonDecode(s) as Map<String, dynamic>,
                ),
              ),
            );
        }
        // Restore list top order.
        if (rawListOrder != null && rawListOrder.isNotEmpty) {
          _listTopOrder
            ..clear()
            ..addAll(rawListOrder);
          // Validate: remove tokens for categories that no longer exist or
          // groups that no longer exist.
          final validCatIds = {for (final c in _userCategories) c.id};
          final validGroupIds = {
            for (final g in _categoryGroups) 'grp-${g.id}',
          };
          _listTopOrder.removeWhere(
            (t) => !validCatIds.contains(t) && !validGroupIds.contains(t),
          );
        } else if (rawUser != null) {
          // Migrate: no saved list order — build from current user categories.
          _listTopOrder
            ..clear()
            ..addAll(
              _userCategories.where((c) => !c.archived).map((c) => c.id),
            );
        }
      });

      // Refresh CategoryRegistry so search results display accurate names+colours.
      _updateCategoryRegistry();

      // Embed Smart Category descriptions and parse compound temporal rules
      // for all persisted categories so the HybridMatcher is warmed up on
      // startup.  Both calls are fire-and-forget.
      for (final cat in [..._userCategories, ..._pinnedUserCategories]) {
        if (cat.categoryType == 'Smart Category' &&
            cat.smartDescription.isNotEmpty) {
          AIServices.embedCategory(cat.name, cat.smartDescription);
          AIServices.parseAndRegisterRule(cat.smartDescription);
        }
      }
    });
  }

  void _updateSmartCategoryColor(String label, Color color) {
    setState(() => _smartCategoryColors[label] = color);
    _saveCategories();
    if (widget.activeDCV == label) {
      widget.onActiveDCVCategoryChanged?.call(label, color);
    }
  }

  /// Hides a fixed smart tile from the grid. Mirrors user-category
  /// archiving — no reveal/unarchive UI exists yet. Plays the same soft
  /// fade+scale-down treatment as list/grid archiving before the tile is
  /// actually removed from the grid.
  void _archiveSmartCategory(String label) {
    setState(() => _archivingSmartLabels.add(label));
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() {
        _archivingSmartLabels.remove(label);
        _archivedSmartCategories.add(label);
        _gridCombinedOrder.remove(label); // archived smart tiles leave the grid
      });
      _saveCategories();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_searchFocused) _wasSearchFocusedBeforePause = true;
    } else if (state == AppLifecycleState.resumed) {
      final wasFocused = _wasSearchFocusedBeforePause;
      _wasSearchFocusedBeforePause = false;
      if (wasFocused) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!_searchFocused) _onSearchFocusChanged(true);
          NativeTextInput.focus(_searchController);
        });
      }
    }
  }

  void _onSearchTextChanged() {
    if (_searchController.text == _searchText) return;
    setState(() {
      _searchText = _searchController.text;
      // Search is local, but semantic matching still completes asynchronously.
      // Clear the previous query's hits immediately instead of showing stale
      // results or presenting a network-style loading indicator.
      _searchPrimary = [];
      _searchOverflow = [];
      _searchAll = [];
      _searchSuggestion = null;
    });
    _scheduleSearch();
  }

  /// Resolves the category ID of the currently open DCV, or null for system
  /// smart tiles (Today / Tomorrow / This Week / …) which show events from
  /// many categories.
  String? _activeDcvCategoryId() {
    final name = widget.activeDCV;
    if (name == null) return null;
    // System smart tiles are not in _userCategories / _pinnedUserCategories.
    for (final c in [..._userCategories, ..._pinnedUserCategories]) {
      if (c.name == name) return c.id;
    }
    return null;
  }

  /// Returns the active Standard Category's ID for the header's add-event
  /// action. Smart Categories and built-in DCVs intentionally return null.
  String? get activeStandardDcvCategoryId {
    final name = widget.activeDCV;
    if (name == null || name.isEmpty) return null;
    for (final category in [..._userCategories, ..._pinnedUserCategories]) {
      if (category.name == name && category.categoryType == 'Standard') {
        return category.id;
      }
    }
    return null;
  }

  /// Resolves the active DCV's colour for every category-backed surface,
  /// including the search field's selection affordances.
  Color _activeDcvColor(BuildContext context) {
    final label = widget.activeDCV;
    if (label == null || label.isEmpty) return resolveAccentColor(context);

    final category = [..._userCategories, ..._pinnedUserCategories]
        .cast<_UserCategory?>()
        .firstWhere((c) => c?.name == label, orElse: () => null);
    if (category != null) {
      return renderCategoryColor(category.color, context);
    }
    return _smartCategoryColors[label] ?? resolveAccentColor(context);
  }

  /// Resolve the active DCV's membership over the exact corpus used by search.
  ///
  /// Standard categories use persisted category IDs. Smart Categories use
  /// their rule matcher instead, because an event can be in-scope without
  /// carrying the category's ID. Built-in date tiles intentionally return null:
  /// they are global scopes rather than a category, so search results remain
  /// one flat ranked list there.
  Set<String>? _activeDcvScopeIds(List<ScheduledEvent> allEvents) {
    final name = widget.activeDCV;
    if (name == null || name.isEmpty) return null;

    const builtInLabels = {
      'Today',
      'Tomorrow',
      'This Week',
      'Next Week',
      'Scheduled',
      'Unscheduled',
      'All Events',
      'Completed',
    };
    if (builtInLabels.contains(name)) {
      return AIServices.matcher
          .match(
            candidates: allEvents,
            rule: name,
            builtInLabel: name,
            now: DateTime.now(),
          )
          .map((event) => event.id)
          .toSet();
    }

    final category = [..._userCategories, ..._pinnedUserCategories]
        .cast<_UserCategory?>()
        .firstWhere((c) => c?.name == name, orElse: () => null);
    if (category == null) return null;

    if (category.categoryType == 'Smart Category' &&
        category.smartDescription.trim().isNotEmpty) {
      return AIServices.matcher
          .match(
            candidates: allEvents,
            rule: category.smartDescription,
            categoryName: category.name,
            now: DateTime.now(),
          )
          .map((event) => event.id)
          .toSet();
    }

    const uncatIds = {'sys-uncategorized', 'uncategorized', ''};
    final isUncategorized = uncatIds.contains(category.id);
    final knownCategoryIds = {
      ..._userCategories,
      ..._pinnedUserCategories,
    }.map((category) => category.id).toSet();
    return {
      for (final event in allEvents)
        if (isUncategorized
            ? (uncatIds.contains(event.categoryId) ||
                  !knownCategoryIds.contains(event.categoryId))
            : event.categoryId == category.id)
          event.id,
    };
  }

  /// Rebuild [CategoryRegistry] from the current in-memory category lists.
  /// Called after load and after any category mutation.
  void _updateCategoryRegistry() {
    CategoryRegistry.update({
      for (final c in [..._userCategories, ..._pinnedUserCategories])
        c.id: CategoryMeta(name: c.name, rawColor: c.color),
    });
  }

  /// Debounced 150 ms search trigger.  Clears results immediately when the
  /// query is empty so the overlay shows a blank state, not stale hits.
  void _scheduleSearch() {
    _searchDebounce?.cancel();
    final q = _searchText.trim();
    if (q.isEmpty) {
      if (_searchPrimary.isNotEmpty || _searchAll.isNotEmpty) {
        setState(() {
          _searchPrimary = [];
          _searchOverflow = [];
          _searchAll = [];
          _searchSuggestion = null;
        });
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 150), () async {
      // Search is global in every tab and every DCV. Recurring events are
      // expanded so a query for a concrete occurrence date can find it.
      final all = EventStore.instance.expandedEvents();
      final scopeIds = _activeDcvScopeIds(all);
      final results = await SearchService().query(
        q,
        all,
        scopeEventIds: scopeIds,
      );
      if (!mounted || _searchText.trim() != q) return;
      setState(() {
        _searchPrimary = results.primary;
        _searchOverflow = results.overflow;
        _searchAll = results.all;
        _searchSuggestion = results.suggestedQuery;
      });
    });
  }

  void _applySearchSuggestion(String suggestion) {
    _searchController.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    NativeTextInput.focus(_searchController);
  }

  Widget _wrapSearchEventTile(
    SearchHit hit,
    Widget child,
    WidgetBuilder previewBuilder,
  ) {
    return wrapSearchEventTileWithActions(
      child: child,
      previewBuilder: previewBuilder,
      hit: hit,
      onEdit: widget.onEditEvent == null
          ? null
          : () => widget.onEditEvent!(hit.event),
    );
  }

  void _onSearchFocusChanged(bool focused) {
    if (_searchFocused == focused) return;

    if (focused) {
      setState(() => _searchFocused = true);
      // The sliver type changed (SliverToBoxAdapter → SliverPersistentHeader),
      // which remounts AppSearchBar and its NativeTextInput platform view.
      // Defer focus to the post-frame callback so it targets the NEW instance
      // that exists after the rebuild, not the old one being disposed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchFocused) {
          NativeTextInput.focus(_searchController);
          // Lock after focus so iOS textFieldShouldEndEditing returns false,
          // blocking implicit resigns (tap-outside, scroll-drag) for the
          // duration of the search session.
          NativeTextInput.lockFocus(_searchController);
        }
      });
      sbSearchModeActive = true;
      widget.onSearchFocusChanged?.call(true);
      return;
    }

    if (_appIsBackgrounded) {
      _wasSearchFocusedBeforePause = true;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_searchFocused != true) {
        if (_appIsBackgrounded) {
          _wasSearchFocusedBeforePause = true;
          return;
        }
        setState(() => _searchFocused = false);
        sbSearchModeActive = false;
        widget.onSearchFocusChanged?.call(false);
      }
    });
  }

  @override
  void deactivate() {
    // Preserve an in-progress section title when the Events tab is removed
    // before the focused editor gets a chance to submit.
    _saveCategories();
    super.deactivate();
    if (_searchFocused || _searchText.isNotEmpty || _greyActive) {
      _searchFocused = false;
      _activatedFromOffScreen = false;
      _greyActive = false;
      _greyFadeIn = false;
      _searchText = '';
      sbSearchModeActive = false;
      _searchController.clear();
      // Unlock before blur so the iOS UITextField can resign cleanly.
      NativeTextInput.unlockFocus(_searchController);
      NativeTextInput.unfocusAll();
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onSearchFocusChanged?.call(false);
    }
  }

  /// True while a category long-press context menu is open.
  bool get hasOpenContextMenu => sbContextMenuActive.value;

  /// Dismisses the active category context menu via the OS back gesture.
  void dismissContextMenu() => sbContextMenuDismiss.value?.call();

  /// Public hook for AppShell to cancel search via OS back gesture.
  void cancelSearch() => _cancelSearch();

  void _cancelSearch() {
    // Stop any active mic session before clearing the search bar.
    _searchBarKey.currentState?.cancelMic();
    final wasFocused = _searchFocused;
    final wasOffScreen = _activatedFromOffScreen;
    sbSearchModeActive = false;
    _searchController.clear();
    // Unlock before blur so the "blur" channel call finds isLocked=false and
    // the native UITextField can resign first responder cleanly.
    NativeTextInput.unlockFocus(_searchController);
    NativeTextInput.unfocusAll();
    FocusManager.instance.primaryFocus?.unfocus();
    if (wasOffScreen) {
      // Snap BEFORE removing the overlay — overlay still covers scroll view
      // so the jump is invisible, and any keyboard-induced drift is gone.
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_savedScrollOffset);
      }
      // Remove the overlay but intentionally keep _activatedFromOffScreen=true
      // so the _enforceScrollLock listener stays active throughout the 250 ms
      // header re-expansion animation.  During that animation the viewport
      // height changes each frame and BouncingScrollPhysics can silently
      // correct the position away from _savedScrollOffset — the listener
      // prevents that correction from ever taking effect.  The main sliver
      // stays as SizedBox(height:58) while the lock is held; because the
      // user has scrolled past the search bar, that placeholder is off-screen
      // and completely invisible.
      setState(() {
        _searchFocused = false;
        _searchText = '';
        _greyFadeIn = false;
        _greyActive = false;
        // _activatedFromOffScreen intentionally NOT cleared here.
      });
      // Release the lock once the header animation finishes reversing.
      // At that point the viewport is stable, the position is exactly
      // _savedScrollOffset, and no further correction is needed.
      void Function(AnimationStatus)? animListener;
      animListener = (AnimationStatus status) {
        if (status == AnimationStatus.dismissed) {
          if (mounted) setState(() => _activatedFromOffScreen = false);
          widget.searchModeAnimation?.removeStatusListener(animListener!);
        }
      };
      widget.searchModeAnimation?.addStatusListener(animListener!);
      // Safety valve: release lock at most 400 ms later even if the animation
      // is interrupted (e.g. user immediately re-enters search mode).
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _activatedFromOffScreen && !_greyActive) {
          setState(() => _activatedFromOffScreen = false);
          widget.searchModeAnimation?.removeStatusListener(animListener!);
        }
      });
    } else {
      setState(() {
        _searchFocused = false;
        _activatedFromOffScreen = false;
        _greyActive = false;
        _greyFadeIn = false;
        _searchText = '';
      });
    }
    if (wasFocused) widget.onSearchFocusChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final bool showResults = _searchFocused && _searchText.isNotEmpty;

    // ── Smart tile data (always 8, always in the grid) ─────────────────────
    // baseEvents — the raw list of user-created events (used for "All Events"
    // count so the number reflects distinct events, not expanded occurrences).
    // allEvents  — recurring events expanded into concrete occurrences over a
    // rolling 1-year window; used for date-based tile counts and all matching.
    final baseEvents = EventStore.instance.events.value;
    final allEvents = EventStore.instance.expandedEvents();
    final now = DateTime.now();

    // Recompute live counts per user category so list rows and pinned grid
    // tiles always show the real event count rather than the persisted
    // _UserCategory.count field (which is never updated after creation).
    // Events with no categoryId or the legacy 'uncategorized' sentinel are
    // counted under 'sys-uncategorized' so the Uncategorized tile is correct.
    {
      const _uncatIds = {'sys-uncategorized', 'uncategorized', ''};
      final knownCategoryIds = {
        ..._userCategories,
        ..._pinnedUserCategories,
      }.map((category) => category.id).toSet();
      final counts = <String, int>{};
      for (final e in allEvents) {
        final id =
            (_uncatIds.contains(e.categoryId) ||
                !knownCategoryIds.contains(e.categoryId))
            ? 'sys-uncategorized'
            : e.categoryId;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      // Smart user categories match events by rule (not by categoryId), so run
      // the AI matcher for each Smart Category and store the count separately.
      for (final cat in [..._userCategories, ..._pinnedUserCategories]) {
        if (cat.categoryType == 'Smart Category' &&
            cat.smartDescription.isNotEmpty) {
          counts[cat.id] = AIServices.matcher
              .match(
                candidates: allEvents,
                rule: cat.smartDescription,
                now: now,
              )
              .length;
        }
      }
      _liveEventCounts = counts;
    }

    // Compute smart tile counts from real ParsedDate metadata.
    int todayCount = 0,
        tomorrowCount = 0,
        thisWeekCount = 0,
        nextWeekCount = 0,
        scheduledCount = 0,
        unscheduledCount = 0;
    for (final e in allEvents) {
      final pd = e.parsedDate;
      if (pd == null || !pd.isScheduled) {
        unscheduledCount++;
      } else {
        scheduledCount++;
        if (pd.isToday(now)) todayCount++;
        if (pd.isTomorrow(now)) tomorrowCount++;
        if (pd.isThisWeek(now)) thisWeekCount++;
        if (pd.isNextWeek(now)) nextWeekCount++;
      }
    }

    // Build smart tiles in the user's preferred display order.
    // allCount uses baseEvents so "All Events" shows distinct events, not
    // the inflated count from recurring expansion.
    final allSmartTiles = _buildSmartTiles(
      todayCount: todayCount,
      tomorrowCount: tomorrowCount,
      thisWeekCount: thisWeekCount,
      nextWeekCount: nextWeekCount,
      scheduledCount: scheduledCount,
      unscheduledCount: unscheduledCount,
      allCount: baseEvents.length,
    );
    final smartTiles = _smartCategoryOrder.isNotEmpty
        ? _smartCategoryOrder
              .where((label) => !_archivedSmartCategories.contains(label))
              .map(
                (label) => allSmartTiles.firstWhere(
                  (t) => t.label == label,
                  orElse: () => allSmartTiles.first,
                ),
              )
              .toList()
        : allSmartTiles
              .where((t) => !_archivedSmartCategories.contains(t.label))
              .toList();

    // ── Grid: unified ordering across smart tiles and pinned user categories ─
    // _gridCombinedOrder is the single source of truth for cross-section slot
    // positions.  Each entry carries a stable identity key (prefixed label for
    // smart tiles, the category object for pinned ones) so AnimatedPositioned
    // tiles keep their Element/State and animate correctly when neighbours move.
    final smartTileByLabel = {for (final t in smartTiles) t.label: t};
    final gridItems = <_GridEntry>[
      for (final item in _gridCombinedOrder)
        if (item is String && smartTileByLabel.containsKey(item))
          _GridEntry(
            key: 'smart_$item',
            // Smart tiles only support Archive (no Delete/Pin) — fade+scale
            // down softly, mirroring the list/grid archive treatment.
            // When dragging, the ghost is in the Overlay — hide placeholder.
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeIn,
              opacity: _archivingSmartLabels.contains(item) ? 0.0 : 1.0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInCubic,
                scale: _archivingSmartLabels.contains(item) ? 0.82 : 1.0,
                child: RepaintBoundary(
                  child: Opacity(
                    opacity: _draggingGridKey == 'smart_$item' ? 0.0 : 1.0,
                    child: _CategoryTile(
                      data: smartTileByLabel[item]!,
                      color:
                          _smartCategoryColors[item] ??
                          resolveAccentColor(context),
                      onEdit: () => _editSmartCategory(smartTileByLabel[item]!),
                      onArchive: () => _archiveSmartCategory(item),
                      reorderable: true,
                      onReorderStart: (p) =>
                          _onGridReorderStart('smart_$item', p),
                      onReorderUpdate: (p) =>
                          _onGridReorderUpdate('smart_$item', p),
                      onReorderEnd: () => _onGridReorderEnd('smart_$item'),
                      onReorderCancel: () =>
                          _onGridReorderCancel('smart_$item'),
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (item is _UserCategory)
          _GridEntry(key: item, child: _buildPinnedGridTile(item)),
    ];

    // Shared search-bar row — used by both layout paths below.
    final searchBarRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: AppSearchBar(
              key: _searchBarKey,
              controller: _searchController,
              onFocusChanged: _onSearchFocusChanged,
              placeholder: 'Search',
            ),
          ),
          SearchCancelButton(
            animation: widget.searchModeAnimation,
            searchFocused: _searchFocused,
            onTap: _cancelSearch,
          ),
        ],
      ),
    );

    // searchBarRow carries _searchBarKey.  When off-screen search activates
    // (_activatedFromOffScreen) the key lives in the Stack overlay so the
    // gridView scroll position is never disturbed.
    final Widget gridView = CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      slivers: [
        // ── Search bar sliver ─────────────────────────────────────────────
        // Off-screen active : _searchBarKey lives in the Stack overlay;
        //   height placeholder keeps all content in position.
        // Inline search     : SliverPersistentHeader (pinned) locks bar.
        // Normal            : SliverToBoxAdapter scrolls with content.
        if (_activatedFromOffScreen)
          const SliverToBoxAdapter(child: SizedBox(height: 58.0))
        else if (_searchFocused)
          SliverPersistentHeader(
            pinned: true,
            floating: true,
            delegate: _SearchHeaderDelegate(
              searchBarRow: searchBarRow,
              extent: 76.5,
              showSeparator: true,
            ),
          )
        else
          SliverToBoxAdapter(child: searchBarRow),

        // ── Inline search results ─────────────────────────────────────────
        if (showResults && !_activatedFromOffScreen) ...[
          SmartSearchResultsSliver(
            hits: _searchAll,
            suggestedQuery: _searchSuggestion,
            onSuggestionTap: _applySearchSuggestion,
            eventTopPadding: 18,
            eventTileWrapper: _wrapSearchEventTile,
            eventTilePressWrapper: (child) => _TilePressScale(child: child),
          ),
        ]
        // ── Normal grid (also shown behind the overlay when off-screen) ───
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _AnimatedCategoryGrid(
                entries: gridItems,
                gridStackKey: _gridStackKey,
                draggingKey: _draggingGridKey,
                dragLocalTopLeft: _dragGridTopLeft,
                dragFullWidth: _dragGridFullWidth,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Text(
                'CATEGORIES',
                style: TextStyle(
                  inherit: false,
                  color: resolveThemeColor(kPrimaryLabel, context),
                  fontSize: 17,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking17,
                  height: kLineHeight,
                ),
              ),
            ),
          ),

          Builder(
            builder: (context) {
              final flatItems = _buildFlatDisplayList();
              if (flatItems.isEmpty) return const SliverToBoxAdapter();
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _CategoryCard(
                    items: flatItems,
                    liveEventCounts: _liveEventCounts,
                    removingCategories: _removingFromList,
                    newCategories: _newInList,
                    archivingCategories: _archivingFromList,
                    deletingCategories: _deletingFromList,
                    poppingInCategories: _poppingInList,
                    expandedGroupIds: _expandedGroupIds,
                    expandingGroupIds: _expandingGroupIds,
                    collapsingGroupIds: _collapsingGroupIds,
                    dragGroupTargetCat: _dragGroupTargetCat,
                    collapsedGroupDwellId: _collapsedGroupDwellId,
                    onPin: _pinCategory,
                    onEdit: _editCategory,
                    onArchive: _archiveCategory,
                    onDelete: _deleteUserCategory,
                    onEditGroup: _editGroupSheet,
                    onDeleteGroup: _openDeleteGroupSheet,
                    onToggleExpand: _toggleGroupExpanded,
                    listStackKey: _listStackKey,
                    draggingCat: _draggingListCat,
                    dragLocalTopY: _dragListTopY,
                    onReorderStart: _onListReorderStart,
                    onReorderUpdate: _onListReorderUpdate,
                    onReorderEnd: _onListReorderEnd,
                    onReorderCancel: _onListReorderCancel,
                    draggingGroup: _draggingGroupHeader,
                    onGroupHeaderReorderStart: _onGroupHeaderReorderStart,
                    onGroupHeaderReorderUpdate: _onGroupHeaderReorderUpdate,
                    onGroupHeaderReorderEnd: _onGroupHeaderReorderEnd,
                    onGroupHeaderReorderCancel: _onGroupHeaderReorderCancel,
                  ),
                ),
              );
            },
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              _buildFlatDisplayList().isEmpty ? 0.0 : 18.0,
              16,
              28,
            ),
            sliver: SliverToBoxAdapter(
              child: _AddCategoryButton(onCategorySaved: _handleNewCategory),
            ),
          ),
        ],
      ],
    );
    // Both SlideTransitions read from the SAME AnimationController as the
    // header AnimatedBuilder in AppShell.  Flutter rebuilds and paints all
    // listeners in one frame — physically impossible to desync on
    // Impeller/Skia, which was the root cause of the 1-frame flicker.
    // No PageView means no separate GPU compositor layers per page, so there
    // is also no layer-promotion flash when content changes.
    final slideCurve = CurveTween(
      curve: Curves.easeInOutCubic,
    ).animate(widget.dcvSlideController);
    return _CategoryTapCallback(
      onTileTapped: widget.onTileTapped,
      child: Stack(
        children: [
          // Grid slides out to the left as DCV enters from the right.
          SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-1.0, 0.0),
            ).animate(slideCurve),
            child: gridView,
          ),
          // DCV slides in from the right.
          // IgnorePointer excludes the DCV content from Flutter's gesture
          // arena whenever it is off-screen (controller < 0.5).  Without
          // this, _CategoryDetailView's own CustomScrollView participates in
          // gesture detection even when invisible, which lets it win scroll
          // events and call primaryFocus?.unfocus() via its default
          // keyboardDismissBehavior:onDrag — dismissing the keyboard on the
          // grid's off-screen search overlay even though nothing is visually
          // on screen.
          AnimatedBuilder(
            animation: widget.dcvSlideController,
            builder: (context, child) => IgnorePointer(
              ignoring: widget.dcvSlideController.value < 0.5,
              child: child,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(slideCurve),
              child: Builder(
                builder: (_) {
                  final cat = widget.activeDCV == null
                      ? null
                      : [
                          ..._userCategories,
                          ..._pinnedUserCategories,
                        ].cast<_UserCategory?>().firstWhere(
                          (c) => c?.name == widget.activeDCV,
                          orElse: () => null,
                        );
                  // Compute filtered events for this DCV using the AI matcher.
                  final List<ScheduledEvent> dcvEvents;
                  final dcvLabel = widget.activeDCV;
                  if (dcvLabel == null || dcvLabel.isEmpty) {
                    dcvEvents = const [];
                  } else if (cat?.categoryType == 'Smart Category' &&
                      cat!.smartDescription.isNotEmpty) {
                    // User Smart Category — semantic + keyword matching.
                    dcvEvents = AIServices.matcher.match(
                      candidates: allEvents,
                      rule: cat.smartDescription,
                      categoryName: cat.name,
                      now: now,
                    );
                  } else {
                    // Built-in smart tile — date-range filtering.
                    const builtIns = {
                      'Today',
                      'Tomorrow',
                      'This Week',
                      'Next Week',
                      'Scheduled',
                      'Unscheduled',
                      'All Events',
                      'Completed',
                    };
                    if (builtIns.contains(dcvLabel)) {
                      dcvEvents = AIServices.matcher.match(
                        candidates: allEvents,
                        rule: dcvLabel,
                        builtInLabel: dcvLabel,
                        now: now,
                      );
                    } else {
                      // Standard user category — filter allEvents by categoryId.
                      final catId = cat?.id;
                      if (catId == null) {
                        dcvEvents = const [];
                      } else {
                        // Both 'sys-uncategorized' and the legacy 'uncategorized'
                        // sentinel are treated as Uncategorized membership.
                        const _uncatIds = {
                          'sys-uncategorized',
                          'uncategorized',
                          '',
                        };
                        final isUncat = _uncatIds.contains(catId);
                        final knownCategoryIds = {
                          ..._userCategories,
                          ..._pinnedUserCategories,
                        }.map((category) => category.id).toSet();
                        dcvEvents = allEvents.where((e) {
                          if (isUncat) {
                            return _uncatIds.contains(e.categoryId) ||
                                !knownCategoryIds.contains(e.categoryId);
                          }
                          return e.categoryId == catId;
                        }).toList();
                      }
                    }
                  }
                  // Resolve the category accent colour so section-header
                  // chevrons match the tile colour the user sees in the grid.
                  // User categories use renderCategoryColor (handles the
                  // kCatBlue sentinel → live accent fallback); built-in smart
                  // tiles fall back to _smartCategoryColors, then accent.
                  final dcvColor = _activeDcvColor(context);
                  return _CategoryDetailView(
                    key: ValueKey(widget.activeDCV ?? '_none'),
                    label: widget.activeDCV ?? '',
                    icon: cat?.iconOrSvg,
                    categoryType: cat?.categoryType ?? 'Standard',
                    events: dcvEvents,
                    sortBy: widget.dcvSortBy ?? 'Manual',
                    sortDir: widget.dcvSortDir ?? '',
                    showManualDateSections: widget.dcvShowManualDateSections,
                    customSectionNames: List<String>.of(
                      _dcvCustomSectionNames[dcvLabel] ?? const <String>[],
                    ),
                    customSectionEventIds: _dcvCustomSectionEventIds[dcvLabel]
                        ?.map(List<String>.of)
                        .toList(),
                    onCustomSectionRenamed: (index, title) {
                      if (dcvLabel != null) {
                        _renameDcvSection(dcvLabel, index, title);
                      }
                    },
                    onCustomSectionEditingChanged: (index, title) {
                      if (dcvLabel != null) {
                        _renameDcvSection(
                          dcvLabel,
                          index,
                          title,
                          persist: false,
                        );
                      }
                    },
                    onCustomSectionDeleted: (index) {
                      if (dcvLabel != null) {
                        deleteDcvSection(dcvLabel, index);
                      }
                    },
                    onCustomSectionReordered: (sectionEventIds) {
                      if (dcvLabel != null) {
                        _reorderDcvSections(dcvLabel, sectionEventIds);
                      }
                    },
                    onEditEvent: widget.onEditEvent,
                    color: dcvColor,
                  );
                },
              ),
            ),
          ),
          // Grid search overlay — covers the grid when off-screen search is
          // active on the main Events view (not inside DCV).  The gridView
          // scroll position is completely untouched throughout.
          if (widget.activeDCV == null && _greyActive)
            _buildGridSearchOverlay(searchBarRow, showResults),
          // DCV search overlay — floats above the DCV content when active.
          if (widget.activeDCV != null && _greyActive)
            _buildDcvSearchOverlay(showResults),
        ],
      ),
    );
  }

  Widget _buildGridSearchOverlay(Widget searchBarRow, bool showResults) {
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _greyFadeIn ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        // No onEnd: exit is instant (overlay removed directly in
        // _cancelSearch), so there is no fade-out to wait for.
        child: ColoredBox(
          color: backgroundColor,
          // CustomScrollView gives the overlay its own rubber-band
          // physics, matching the grid scroll view it sits above.
          // primary:false prevents Flutter from adopting the
          // PrimaryScrollController (which in a CupertinoTabScaffold is
          // the tab's own scroll controller) — that would reset the tab's
          // scroll offset to 0 the moment this overlay appears.
          child: CustomScrollView(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchHeaderDelegate(
                  searchBarRow: searchBarRow,
                  extent: 76.5,
                  showSeparator: true,
                ),
              ),
              if (showResults)
                SmartSearchResultsSliver(
                  hits: _searchAll,
                  suggestedQuery: _searchSuggestion,
                  onSuggestionTap: _applySearchSuggestion,
                  eventTopPadding: 18,
                  eventTileWrapper: _wrapSearchEventTile,
                  eventTilePressWrapper: (child) =>
                      _TilePressScale(child: child),
                )
              else
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SizedBox.expand(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDcvSearchOverlay(bool showResults) {
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _greyFadeIn ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        onEnd: () {
          if (!_greyFadeIn && mounted) {
            setState(() {
              _greyActive = false;
              _activatedFromOffScreen = false;
            });
          }
        },
        child: ColoredBox(
          color: backgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Fixed search header (immune to rubber-band) ────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: AppSearchBar(
                        controller: _searchController,
                        onFocusChanged: _onSearchFocusChanged,
                        placeholder: 'Search ${widget.activeDCV ?? ''}',
                        selectionTint: _activeDcvColor(context),
                      ),
                    ),
                    SearchCancelButton(
                      animation: widget.searchModeAnimation,
                      searchFocused: _searchFocused,
                      onTap: _cancelSearch,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 0.5,
                color: resolveThemeColor(kSeparatorColor, context),
              ),
              // ── Scrollable content area (rubber-band stays here) ───────
              if (showResults)
                Expanded(
                  child: SmartDcvSearchResults(
                    primary: _searchPrimary,
                    overflow: _searchOverflow,
                    suggestedQuery: _searchSuggestion,
                    onSuggestionTap: _applySearchSuggestion,
                    hidePrimaryCategoryName:
                        activeStandardDcvCategoryId != null,
                    eventTopPadding: 18,
                    eventTileWrapper: _wrapSearchEventTile,
                    eventTilePressWrapper: (child) =>
                        _TilePressScale(child: child),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adds the standard event long-press action panel to a search result tile.
///
/// Search results are rendered by a shared widget used by all three tabs.  The
/// menu itself lives here alongside the regular Events-tab event card so both
/// paths keep the same Edit Event / Delete Event actions and overlay behavior.
Widget wrapSearchEventTileWithActions({
  required SearchHit hit,
  required Widget child,
  required WidgetBuilder previewBuilder,
  VoidCallback? onEdit,
}) {
  return _EventContextMenu(
    child: child,
    previewBuilder: previewBuilder,
    onEdit: onEdit,
    onDelete: () => EventStore.instance.remove(hit.event.id),
  );
}

/// Adds the same inner-content press scale used by DCV event tiles.
///
/// Kept next to [_TilePressScale] so search results in the other tabs can use
/// the exact same inherited press animation without duplicating its private
/// implementation.
Widget wrapSearchEventTileWithPressScale(Widget child) =>
    _TilePressScale(child: child);

// ══════════════════════════════════════════════════════════════════════════════
// SMART CATEGORY TILES
// ══════════════════════════════════════════════════════════════════════════════

class _TileData {
  final String label;
  final int count;
  final bool isCalendar;
  final int? day;
  final IconData? icon;
  final double iconSize;

  const _TileData.calendar({
    required this.label,
    required this.count,
    required this.day,
  }) : isCalendar = true,
       icon = null,
       iconSize = 22;

  const _TileData.icon({
    required this.label,
    required this.count,
    required this.icon,
    this.iconSize = 22,
  }) : isCalendar = false,
       day = null;
}

// ── Grid entry: pairs a stable identity key with its tile widget ──────────────
// Smart tiles are keyed by label (String); pinned user categories are keyed
// by the _UserCategory object itself (identity), matching the ObjectKey
// convention used elsewhere in this file for the same lists.
class _GridEntry {
  final Object key;
  final Widget child;
  const _GridEntry({required this.key, required this.child});
}

// ── Animated grid: smart tiles + pinned user categories ────────────────────
// Positions every tile with AnimatedPositioned instead of laying rows out
// with a Row/SliverList index-builder. Because each tile carries a stable
// ValueKey(entry.key) in the Stack's children list, Flutter's key-based
// child reconciliation keeps its Element/State alive when its index shifts
// (a sibling was pinned, unpinned, archived, or deleted) — so the tile
// smoothly slides to its new row/column instead of snapping there on the
// next frame. The outer AnimatedContainer height animates in lock-step so
// content below the grid reflows smoothly too, rather than jumping.
class _AnimatedCategoryGrid extends StatelessWidget {
  final List<_GridEntry> entries;

  /// Attached to the inner Stack so EventsTabState can call
  /// renderObject.globalToLocal() during drag updates.
  final GlobalKey? gridStackKey;

  /// The identity key of the tile currently being dragged (null when idle).
  final Object? draggingKey;

  /// Top-left of the dragged tile in Stack-local coordinates (null when idle).
  final Offset? dragLocalTopLeft;

  /// Whether the lifted tile is currently targeting the solitary final slot.
  /// This is separate from the resting layout so the tile can expand while
  /// still being dragged, including when it entered the grid from the list.
  final bool dragFullWidth;

  const _AnimatedCategoryGrid({
    required this.entries,
    this.gridStackKey,
    this.draggingKey,
    this.dragLocalTopLeft,
    this.dragFullWidth = false,
  });

  static const _rowHeight = 89.0;
  static const _rowGap = 18.0;
  static const _colGap = 16.0;
  static const _duration = Duration(milliseconds: 280);
  static const _curve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final rowCount = (entries.length / 2).ceil();
    final totalHeight = rowCount == 0
        ? 0.0
        : rowCount * _rowHeight + (rowCount - 1) * _rowGap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - _colGap) / 2;

        // When the total tile count is odd, the last tile spans both columns
        // so it fills the row instead of sitting alone on the left half.
        // AnimatedPositioned carries the stable ValueKey for each tile, so
        // when parity flips (a tile is pinned or unpinned/archived/deleted)
        // it automatically animates the affected tile's left+width change:
        //   • even → odd  (tile removed): new last tile expands to full width.
        //   • odd  → even (tile added):   previously full-width tile shrinks.
        final isOdd = entries.length.isOdd;
        final lastIdx = entries.length - 1;

        // Left offset: for the full-width tile col is always 0, which the
        // normal formula already produces (lastIdx % 2 == 0 when count is odd
        // because odd-1 is even), so no special-casing needed in dx.
        Offset logicalOffset(int i) => Offset(
          (i % 2) * (tileWidth + _colGap),
          (i ~/ 2) * (_rowHeight + _rowGap),
        );

        // Width: full-width for the solitary last tile, half-width otherwise.
        double logicalWidth(int i) =>
            (isOdd && i == lastIdx) ? constraints.maxWidth : tileWidth;

        return AnimatedContainer(
          duration: _duration,
          curve: _curve,
          height: totalHeight,
          child: Stack(
            key: gridStackKey,
            clipBehavior: Clip.none,
            children: [
              // ── Non-dragging tiles: standard AnimatedPositioned reflow ──
              for (int i = 0; i < entries.length; i++)
                if (entries[i].key != draggingKey)
                  AnimatedPositioned(
                    key: ValueKey(entries[i].key),
                    duration: _duration,
                    curve: _curve,
                    left: logicalOffset(i).dx,
                    top: logicalOffset(i).dy,
                    width: logicalWidth(i),
                    height: _rowHeight,
                    child: entries[i].child,
                  ),
              // ── Dragging tile: instant positioning ────────────────────────
              // Rendered last so it paints above all siblings.
              // The tile's own _CategoryContextMenuState._liftCtrl provides
              // scale-1.05 + drop shadow — no wrapper needed here.
              // IMPORTANT: child must be structurally identical to the
              // non-dragging branch so Flutter updates rather than tears down
              // the element (and its GestureDetector) on drag start.
              // The dragging ghost (in the Overlay) always renders at tileWidth
              // so the ghost is half-wide regardless of the tile's resting state.
              if (draggingKey != null && dragLocalTopLeft != null)
                for (int i = 0; i < entries.length; i++)
                  if (entries[i].key == draggingKey)
                    AnimatedPositioned(
                      key: ValueKey(entries[i].key),
                      duration: Duration.zero,
                      curve: Curves.linear,
                      left: dragLocalTopLeft!.dx,
                      top: dragLocalTopLeft!.dy,
                      width: dragFullWidth ? constraints.maxWidth : tileWidth,
                      height: _rowHeight,
                      child: entries[i].child,
                    ),
            ],
          ),
        );
      },
    );
  }
}

// ── Smart category tile (grid) ────────────────────────────────────────────────
// isSmartCategory = true → context menu shows Edit + Show Info only.
// reorderable = true → enables long-press-drag reordering within the smart
//   tile section of the grid (set from EventsTabState build()).
class _CategoryTile extends StatelessWidget {
  final _TileData data;
  final Color color;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final bool reorderable;
  final void Function(Offset)? onReorderStart;
  final void Function(Offset)? onReorderUpdate;
  final VoidCallback? onReorderEnd;
  final VoidCallback? onReorderCancel;
  const _CategoryTile({
    super.key,
    required this.data,
    this.color = kAccentColor,
    this.onEdit,
    this.onArchive,
    this.reorderable = false,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
  });
  @override
  Widget build(BuildContext context) {
    final onTap = _CategoryTapCallback.of(context)?.onTileTapped;
    return _CategoryContextMenu(
      isSmartCategory: true,
      onEdit: onEdit,
      onArchive: onArchive,
      // renderCategoryColor: if `color` is the kCatBlue sentinel (stored when
      // the category was created with the default accent), resolve it to the
      // live accent so the DCV header always reflects the current user setting.
      onTap: onTap != null
          ? () => onTap(data.label, renderCategoryColor(color, context))
          : null,
      reorderable: reorderable,
      onReorderStart: onReorderStart,
      onReorderUpdate: onReorderUpdate,
      onReorderEnd: onReorderEnd,
      onReorderCancel: onReorderCancel,
      child: _buildCard(context),
      previewBuilder: (ctx) => _buildCard(ctx),
    );
  }

  Widget _buildCard(BuildContext context) {
    final surfaceColor = resolveThemeColor(kSbSurface, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: ShapeDecoration(
        color: surfaceColor,
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
        ),
        shadows: shadows,
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -2,
            left: 0,
            child: Container(
              width: 35.5,
              height: 35.5,
              decoration: BoxDecoration(
                color: renderCategoryColor(color, context),
                shape: BoxShape.circle,
              ),
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Center(child: _buildIconContent()),
                  if (data.day != null)
                    Positioned(
                      top: 14.6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Transform.scale(
                          scale: 1.05,
                          scaleY: 1.3,
                          child: Text(
                            '${data.day}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              inherit: false,
                              color: Color(0xFFFFFFFF),
                              fontSize: 9.5,
                              fontFamily: kSFProText,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.normal,
                              height: 1.0,
                              letterSpacing: 0,
                            ),
                            textScaler: TextScaler.noScaling,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -2,
            right: 0,
            child: SizedBox(
              height: 35.5,
              child: Center(
                child: Text(
                  '${data.count}',
                  style: TextStyle(
                    inherit: false,
                    color: resolveThemeColor(kPrimaryLabel, context),
                    fontSize: 32,
                    fontFamily: kSFProDisplay,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.normal,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Transform.translate(
              offset: const Offset(0, 1.5),
              child: Text(
                data.label,
                style: TextStyle(
                  inherit: false,
                  color: resolveThemeColor(kSecondaryLabel, context),
                  fontSize: 17,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking17,
                  height: kLineHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconContent() {
    const white = Color(0xFFFFFFFF);

    if (data.isCalendar) {
      return SizedBox(
        width: 24,
        height: 24,
        child: SvgPicture.asset(
          'assets/icons/calendar_frame.svg',
          colorFilter: const ColorFilter.mode(
            Color(0xFFFFFFFF),
            BlendMode.srcIn,
          ),
        ),
      );
    }

    final icon = data.icon!;
    if (icon == SFIcons.sf_music_note) {
      return _BeamedNoteIcon(size: data.iconSize, color: white);
    }
    if (icon == CupertinoIcons.tray_fill) {
      return Transform.translate(
        offset: const Offset(0, -1),
        child: Icon(icon, color: white, size: data.iconSize),
      );
    }
    if (icon == CupertinoIcons.clock) {
      return Transform.translate(
        offset: const Offset(0, -1),
        child: SearchWeightedIcon(
          icon,
          size: data.iconSize,
          color: white,
          weight: 0.25,
        ),
      );
    }
    if (icon == CupertinoIcons.checkmark) {
      return SearchWeightedIcon(
        icon,
        size: data.iconSize,
        color: white,
        weight: 0.25,
      );
    }
    return Icon(icon, color: white, size: data.iconSize);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// USER CATEGORIES
// ══════════════════════════════════════════════════════════════════════════════

class _UserCategory {
  /// Stable unique identifier — never changes after creation, even if the
  /// user renames, recolors, or changes the icon.
  ///
  /// Well-known system values (never reused by user categories):
  ///   'sys-unnamed'       → the built-in Unnamed category
  ///   'sys-uncategorized' → the built-in Uncategorized category
  ///
  /// User categories receive 'usr-<ms-since-epoch>' generated at first save.
  /// Old persisted categories that pre-date this field receive a legacy ID
  /// derived from their name + color so the value is at least stable across
  /// reloads of the same data.
  final String id;
  final String name;
  final String description;
  final int count;
  final Color color;
  final IconData icon;

  /// When non-null, the icon is rendered from this SVG asset path rather than
  /// from [icon]. Use [iconOrSvg] everywhere you need to render the icon.
  final String? svgAsset;
  // Archived categories are hidden from the grid/list but not deleted —
  // no reveal/unarchive UI exists yet (tracked as follow-up work).
  final bool archived;

  /// Category type chosen in the Add/Edit sheet — 'Standard', 'Groceries',
  /// or 'Smart Category'.  Drives the DCV empty-state appearance.
  final String categoryType;

  /// The matching rule text entered for a user-created Smart Category.
  /// Kept separate from [description], which is the category subtitle shown
  /// in the category list.
  final String smartDescription;

  // ── Preset values — auto-fill the New Event sheet when this category is picked
  /// Starting location preset (future Maps API).
  final String? presetLocation;

  /// Destination preset.
  final String? presetDestination;

  /// Travel time preset, e.g. "1 hour", "30 minutes". Null / "None" = unset.
  final String? presetTravelTime;

  /// Travel mode preset, e.g. "Car", "Walking".
  final String? presetTravelMode;

  /// Repeat rule preset, e.g. "Every Week", custom label. Null = no repeat.
  final String? presetRepeat;

  /// Repeat end type preset: "Never" or "On Date".
  final String? presetRepeatEndType;

  /// Repeat end date preset formatted as human-readable string.
  final String? presetRepeatEndDate;

  /// Serialised custom repeat config (Map). Non-null only when presetRepeat is
  /// a custom label.
  final Map<String, dynamic>? presetCustomRepeatConfig;

  /// First alert preset, e.g. "At time of event", "30 minutes before".
  final String? presetAlert;

  /// Second alert preset.
  final String? presetSecondAlert;

  const _UserCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.count,
    this.color = kAccentColor,
    this.icon = SFIcons.sf_list_bullet,
    this.svgAsset,
    this.archived = false,
    this.categoryType = 'Standard',
    this.smartDescription = '',
    this.presetLocation,
    this.presetDestination,
    this.presetTravelTime,
    this.presetTravelMode,
    this.presetRepeat,
    this.presetRepeatEndType,
    this.presetRepeatEndDate,
    this.presetCustomRepeatConfig,
    this.presetAlert,
    this.presetSecondAlert,
  });

  /// Returns the SVG asset path (String) when one is set, otherwise the
  /// IconData. Pass this to [_renderCatIcon] at every render site.
  Object get iconOrSvg => svgAsset ?? icon;

  _UserCategory copyWith({bool? archived}) => _UserCategory(
    id: id,
    name: name,
    description: description,
    count: count,
    color: color,
    icon: icon,
    svgAsset: svgAsset,
    archived: archived ?? this.archived,
    categoryType: categoryType,
    smartDescription: smartDescription,
    presetLocation: presetLocation,
    presetDestination: presetDestination,
    presetTravelTime: presetTravelTime,
    presetTravelMode: presetTravelMode,
    presetRepeat: presetRepeat,
    presetRepeatEndType: presetRepeatEndType,
    presetRepeatEndDate: presetRepeatEndDate,
    presetCustomRepeatConfig: presetCustomRepeatConfig,
    presetAlert: presetAlert,
    presetSecondAlert: presetSecondAlert,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'count': count,
    'colorValue': color.value,
    'iconCodePoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily ?? '',
    'iconFontPackage': icon.fontPackage ?? '',
    if (svgAsset != null) 'svgAsset': svgAsset,
    'archived': archived,
    'categoryType': categoryType,
    'smartDescription': smartDescription,
    // Preset fields (omit when null/None to keep storage lean)
    if (presetLocation != null && presetLocation!.isNotEmpty)
      'presetLocation': presetLocation,
    if (presetDestination != null && presetDestination!.isNotEmpty)
      'presetDestination': presetDestination,
    if (presetTravelTime != null && presetTravelTime != 'None')
      'presetTravelTime': presetTravelTime,
    if (presetTravelMode != null && presetTravelMode != 'None')
      'presetTravelMode': presetTravelMode,
    if (presetRepeat != null && presetRepeat != 'Never')
      'presetRepeat': presetRepeat,
    if (presetRepeatEndType != null && presetRepeatEndType != 'Never')
      'presetRepeatEndType': presetRepeatEndType,
    if (presetRepeatEndDate != null) 'presetRepeatEndDate': presetRepeatEndDate,
    if (presetCustomRepeatConfig != null)
      'presetCustomRepeatConfig': presetCustomRepeatConfig,
    if (presetAlert != null && presetAlert != 'None')
      'presetAlert': presetAlert,
    if (presetSecondAlert != null && presetSecondAlert != 'None')
      'presetSecondAlert': presetSecondAlert,
  };

  factory _UserCategory.fromJson(Map<String, dynamic> json) {
    final fam = (json['iconFontFamily'] as String?) ?? '';
    final pkg = (json['iconFontPackage'] as String?) ?? '';
    final name = (json['name'] as String?) ?? '';
    // Legacy records saved before the id field was introduced get a stable
    // derived ID so they survive reloads without changing identity.
    final id =
        (json['id'] as String?) ??
        'usr-legacy-$name-${json['colorValue'] ?? 0}';
    final rawCrc = json['presetCustomRepeatConfig'];
    return _UserCategory(
      id: id,
      name: name,
      description: (json['description'] as String?) ?? '',
      count: (json['count'] as int?) ?? 0,
      color: resolveCategorySwatch(
        Color((json['colorValue'] as int?) ?? kAccentColor.value),
      ),
      icon: IconData(
        (json['iconCodePoint'] as int?) ?? SFIcons.sf_list_bullet.codePoint,
        fontFamily: fam.isEmpty ? null : fam,
        fontPackage: pkg.isEmpty ? null : pkg,
      ),
      svgAsset: json['svgAsset'] as String?,
      archived: (json['archived'] as bool?) ?? false,
      categoryType: (json['categoryType'] as String?) ?? 'Standard',
      smartDescription: (json['smartDescription'] as String?) ?? '',
      presetLocation: json['presetLocation'] as String?,
      presetDestination: json['presetDestination'] as String?,
      presetTravelTime: json['presetTravelTime'] as String?,
      presetTravelMode: json['presetTravelMode'] as String?,
      presetRepeat: json['presetRepeat'] as String?,
      presetRepeatEndType: json['presetRepeatEndType'] as String?,
      presetRepeatEndDate: json['presetRepeatEndDate'] as String?,
      presetCustomRepeatConfig: rawCrc is Map<String, dynamic> ? rawCrc : null,
      presetAlert: json['presetAlert'] as String?,
      presetSecondAlert: json['presetSecondAlert'] as String?,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CATEGORY GROUP
// ══════════════════════════════════════════════════════════════════════════════

/// A named group of user categories in the CATEGORIES list.
/// Rendered as a single collapsible row; tapping the expand chevron reveals
/// the member category rows indented below the group header.
class _CategoryGroup {
  final String id;
  final String name;

  /// Ordered list of member category IDs (references into _userCategories).
  final List<String> memberIds;

  const _CategoryGroup({
    required this.id,
    required this.name,
    required this.memberIds,
  });

  _CategoryGroup copyWith({String? name, List<String>? memberIds}) =>
      _CategoryGroup(
        id: id,
        name: name ?? this.name,
        memberIds: memberIds ?? List<String>.from(this.memberIds),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'memberIds': memberIds,
  };

  factory _CategoryGroup.fromJson(Map<String, dynamic> json) => _CategoryGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    memberIds: (json['memberIds'] as List<dynamic>).cast<String>(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// FLAT DISPLAY ITEM
// ══════════════════════════════════════════════════════════════════════════════

/// Describes the kind of one visible slot in the CATEGORIES list.
enum _FlatItemKind { solo, groupHeader, groupMember }

/// One visible slot in the CATEGORIES section flat display list.
/// Passed to _CategoryCard so it can render different row types:
///   solo       — a standalone category row
///   groupHeader — a group header row with expand/collapse chevron
///   groupMember — an indented category row inside an expanded group
class _FlatItem {
  final _FlatItemKind kind;

  /// Non-null for solo and groupMember rows.
  final _UserCategory? category;

  /// Non-null for groupHeader rows.
  final _CategoryGroup? group;

  /// Non-null for groupMember rows — the parent group's ID.
  final String? groupId;

  bool get isSolo => kind == _FlatItemKind.solo;
  bool get isGroupHeader => kind == _FlatItemKind.groupHeader;
  bool get isGroupMember => kind == _FlatItemKind.groupMember;
  bool get isCategory => isSolo || isGroupMember;

  const _FlatItem.solo(this.category)
    : kind = _FlatItemKind.solo,
      group = null,
      groupId = null;

  const _FlatItem.groupHeader(this.group)
    : kind = _FlatItemKind.groupHeader,
      category = null,
      groupId = null;

  const _FlatItem.groupMember(this.category, this.groupId)
    : kind = _FlatItemKind.groupMember,
      group = null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _FlatItem || kind != other.kind) return false;
    if (isGroupHeader) return group?.id == other.group?.id;
    return category?.id == other.category?.id;
  }

  @override
  int get hashCode => Object.hash(kind, category?.id, group?.id);
}

// ── Well-known system category IDs ───────────────────────────────────────────
// These are permanent — they must never be reassigned or reused by user cats.
const _kIdSysUnnamed = 'sys-unnamed';
const _kIdSysUncategorized = 'sys-uncategorized';

const _kUserCategories = [
  _UserCategory(
    id: _kIdSysUnnamed,
    name: 'Unnamed',
    description: 'Default category for general use',
    count: 0,
    icon: CupertinoIcons.folder,
  ),
  _UserCategory(
    id: _kIdSysUncategorized,
    name: 'Uncategorized',
    description: 'For events without a specific category',
    count: 0,
    icon: CupertinoIcons.folder,
  ),
];

// One-sentence explanation of what each fixed smart tile does — shown as a
// locked description in its "Edit Category Info" sheet.
const _kSmartCategoryDescriptions = <String, String>{
  'Today': 'Shows events scheduled for today.',
  'Tomorrow': 'Shows events scheduled for tomorrow.',
  'This Week': 'Shows events scheduled during the current week.',
  'Next Week': 'Shows events scheduled during the upcoming week.',
  'Scheduled': 'Groups events that already have a set date and time.',
  'Unscheduled': 'Groups events that don\'t yet have a date or time.',
  'All Events': 'Shows every event you\'ve created.',
  'Completed': 'Shows events you\'ve marked as done.',
};

// ══════════════════════════════════════════════════════════════════════════════
// PINNED USER TILE (user category promoted to the grid)
// ══════════════════════════════════════════════════════════════════════════════

// Looks like a smart tile but shows user category data.
// isSmartCategory = false → context menu shows Unpin, Edit, Show Info, Delete.
class _PinnedUserTile extends StatelessWidget {
  final _UserCategory category;

  /// Live event count injected from the parent build — replaces the stale
  /// persisted [_UserCategory.count] so the tile number updates immediately.
  final int liveCount;
  final VoidCallback? onUnpin;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final void Function(Offset)? onReorderStart;
  final void Function(Offset)? onReorderUpdate;
  final VoidCallback? onReorderEnd;
  final VoidCallback? onReorderCancel;

  const _PinnedUserTile({
    super.key,
    required this.category,
    this.liveCount = 0,
    this.onUnpin,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
  });

  @override
  Widget build(BuildContext context) {
    final onTap = _CategoryTapCallback.of(context)?.onTileTapped;
    return _CategoryContextMenu(
      isSmartCategory: false,
      isPinned: true,
      reorderable: true,
      onUnpin: onUnpin,
      onEdit: onEdit,
      onArchive: onArchive,
      onDelete: onDelete,
      onTap: onTap != null
          ? () => onTap(
              category.name,
              renderCategoryColor(category.color, context),
            )
          : null,
      onReorderStart: onReorderStart,
      onReorderUpdate: onReorderUpdate,
      onReorderEnd: onReorderEnd,
      onReorderCancel: onReorderCancel,
      child: _buildCard(context),
      previewBuilder: (ctx) => _buildCard(ctx),
    );
  }

  Widget _buildCard(BuildContext context) {
    final resolvedSurface = resolveThemeColor(kSbSurface, context);
    final resolvedShadows = resolveThemeShadows(kCardShadow, context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: ShapeDecoration(
        color: resolvedSurface,
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
        ),
        shadows: resolvedShadows,
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -2,
            left: 0,
            child: Container(
              width: 35.5,
              height: 35.5,
              decoration: BoxDecoration(
                color: _categoryIconCircleColor(
                  category.iconOrSvg,
                  renderCategoryColor(category.color, context),
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _renderCatIcon(
                  category.iconOrSvg,
                  35.5,
                  CupertinoColors.white,
                  emojiOffsetY: 1,
                ),
              ),
            ),
          ),
          Positioned(
            top: -2,
            right: 0,
            child: SizedBox(
              height: 35.5,
              child: Center(
                child: Text(
                  '$liveCount',
                  style: TextStyle(
                    inherit: false,
                    color: resolveThemeColor(kPrimaryLabel, context),
                    fontSize: 32,
                    fontFamily: kSFProDisplay,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.normal,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Transform.translate(
              offset: const Offset(0, 1.5),
              child: Text(
                category.name,
                style: TextStyle(
                  inherit: false,
                  color: resolveThemeColor(kSecondaryLabel, context),
                  fontSize: 17,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking17,
                  height: kLineHeight,
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
// USER CATEGORY LIST
// ══════════════════════════════════════════════════════════════════════════════

TextStyle _eventsCategoryListTextStyle(
  double fontSize, {
  FontWeight fontWeight = FontWeight.w400,
  double letterSpacing = 0,
}) => TextStyle(
  inherit: false,
  fontFamily: kSFProText,
  fontSize: fontSize,
  fontWeight: fontWeight,
  letterSpacing: letterSpacing,
  height: kLineHeight,
);

double _eventsMeasuredTextHeight(
  String text,
  TextStyle style,
  TextScaler scaler,
  double maxWidth,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout(maxWidth: maxWidth);
  return painter.height;
}

double _eventsMeasuredTextWidth(
  String text,
  TextStyle style,
  TextScaler scaler,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  return painter.width;
}

/// Row height for the main Events tab category list.
///
/// Measure the actual visible labels. The Stack can use a different height for
/// each slot; title-only rows stay compact while wrapped titles/subtitles grow
/// only their own row.
double _eventsCategoryListRowHeight(
  BuildContext context, {
  Iterable<_FlatItem>? items,
  _FlatItem? item,
  Map<String, int>? liveEventCounts,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final viewportWidth = MediaQuery.sizeOf(context).width;
  final cardWidth = max(0.0, viewportWidth - 32.0);
  final categoryTitleStyle = _eventsCategoryListTextStyle(
    16,
    letterSpacing: kTracking16,
  );
  final groupTitleStyle = _eventsCategoryListTextStyle(
    16,
    fontWeight: FontWeight.w600,
    letterSpacing: kTracking16,
  );
  final subtitleStyle = _eventsCategoryListTextStyle(13, letterSpacing: -0.08);
  final countStyle = _eventsCategoryListTextStyle(
    16,
    letterSpacing: kTracking16,
  );
  const verticalPadding = 26.0; // 13 px top + 13 px bottom
  const subtitleGap = 2.0;
  const iconHeight = 34.0;
  double measure(_FlatItem current) {
    final label = current.category?.name ?? current.group?.name;
    if (label == null) return 64.0;

    // Measure the same trailing label that the row actually renders. Using a
    // fixed "999" width here makes rows with counts such as 0 or 7 reserve
    // extra width, causing their subtitles to wrap earlier than the widget.
    final trailingLabel = current.isGroupHeader
        ? '${current.group?.memberIds.length ?? 0}'
        : '${liveEventCounts?[current.category!.id] ?? 0}';
    final trailingWidth =
        _eventsMeasuredTextWidth(trailingLabel, countStyle, scaler) +
        8 +
        6 +
        scaler.scale(14) +
        16;
    final leftPad = current.isGroupMember ? 36.0 : 16.0;
    final textWidth = max(
      80.0,
      cardWidth - leftPad - iconHeight - 13 - trailingWidth,
    );
    var textHeight = _eventsMeasuredTextHeight(
      label,
      current.isGroupHeader ? groupTitleStyle : categoryTitleStyle,
      scaler,
      textWidth,
    );
    final description = current.category?.description;
    if (description != null && description.isNotEmpty) {
      textHeight +=
          subtitleGap +
          _eventsMeasuredTextHeight(
            description,
            subtitleStyle,
            scaler,
            textWidth,
          );
    }
    return max(64.0, max(iconHeight, textHeight) + verticalPadding);
  }

  if (item != null) {
    return measure(item);
  }
  var tallest = 64.0;
  for (final current in items ?? const <_FlatItem>[]) {
    tallest = max(tallest, measure(current));
  }

  return tallest;
}

double _eventsCategoryListTopY(
  BuildContext context,
  List<_FlatItem> items,
  int index,
  Map<String, int>? liveEventCounts,
) {
  var top = 0.0;
  for (var i = 0; i < index && i < items.length; i++) {
    top += _eventsCategoryListRowHeight(
      context,
      item: items[i],
      liveEventCounts: liveEventCounts,
    );
  }
  return top;
}

/// Returns the slot containing [y], or [items.length] when it is below the
/// final slot. The list has no inter-row gap, so each row's measured bounds are
/// the hit regions used by drag-reorder.
int _eventsCategoryListIndexAtY(
  BuildContext context,
  List<_FlatItem> items,
  double y,
  Map<String, int>? liveEventCounts,
) {
  if (y < 0) return -1;
  var top = 0.0;
  for (var i = 0; i < items.length; i++) {
    top += _eventsCategoryListRowHeight(
      context,
      item: items[i],
      liveEventCounts: liveEventCounts,
    );
    if (y < top) return i;
  }
  return items.length;
}

// ── Category list card (clips all rows to the squircle shape) ─────────────────
//
// Uses Stack + AnimatedPositioned so every row can slide smoothly to its
// new Y position both during lifecycle animations (archive/delete/pin/unpin)
// and during drag-to-reorder — the same AnimatedPositioned infrastructure
// that drives the pinned-category grid.
//
// Each row slot uses its own measured wrapped-content height for the current
// text scale. Collapsed rows animate their height to 0 via AnimatedPositioned;
// all subsequent rows animate their top-Y upward in lock-step, giving a smooth
// height-collapse + reflow effect. The dragging row uses Duration.zero so it
// follows the finger with zero lag while siblings animate to their new
// positions around it.
class _CategoryCard extends StatelessWidget {
  /// Compact baseline row height. Runtime layout uses
  /// [_eventsCategoryListRowHeight] so accessibility text sizes can expand
  /// only the rows that need it.
  static const _kListRowH = 64.0;

  // Gap between row slots. Zero = grouped card look; rows butt flush and the
  // outer card provides the single shared shadow + squircle clip.
  static const _kRowGap = 0.0;
  static const _kAnimMs = 270;
  static const _kAnimCurve = Curves.easeInOutCubic;

  /// Live event count per user category id (categoryId → count).  Passed from
  /// [_EventsTabState.build] so each row shows a real-time count.
  final Map<String, int> liveEventCounts;

  /// The flat ordered display list (solo, groupHeader, groupMember items).
  final List<_FlatItem> items;
  final Set<_UserCategory> removingCategories;
  final Set<_UserCategory> newCategories;
  final Set<_UserCategory> archivingCategories;
  final Set<_UserCategory> deletingCategories;
  final Set<_UserCategory> poppingInCategories;
  final Set<String> expandedGroupIds;
  final Set<String> expandingGroupIds;
  final Set<String> collapsingGroupIds;

  /// When non-null, this solo category is highlighted as the drag-group target.
  final _UserCategory? dragGroupTargetCat;

  /// When non-null, this group header is highlighted as a dwell-join target
  /// (the dragged cat is hovering over a collapsed group and counting down).
  final String? collapsedGroupDwellId;
  final void Function(_UserCategory)? onPin;
  final void Function(_UserCategory)? onEdit;
  final void Function(_UserCategory)? onArchive;
  final void Function(_UserCategory)? onDelete;
  final void Function(_CategoryGroup)? onEditGroup;
  final void Function(_CategoryGroup)? onDeleteGroup;
  final void Function(String groupId)? onToggleExpand;
  // Category drag-reorder wiring
  final GlobalKey? listStackKey;
  final _UserCategory? draggingCat;
  final double? dragLocalTopY;
  final void Function(_UserCategory, Offset)? onReorderStart;
  final void Function(_UserCategory, Offset)? onReorderUpdate;
  final void Function(_UserCategory)? onReorderEnd;
  final void Function(_UserCategory)? onReorderCancel;
  // Group-header drag-reorder wiring
  final _CategoryGroup? draggingGroup;
  final void Function(_CategoryGroup, Offset)? onGroupHeaderReorderStart;
  final void Function(_CategoryGroup, Offset)? onGroupHeaderReorderUpdate;
  final void Function(_CategoryGroup)? onGroupHeaderReorderEnd;
  final void Function(_CategoryGroup)? onGroupHeaderReorderCancel;

  const _CategoryCard({
    required this.items,
    required this.removingCategories,
    required this.newCategories,
    this.liveEventCounts = const {},
    this.archivingCategories = const {},
    this.deletingCategories = const {},
    this.poppingInCategories = const {},
    this.expandedGroupIds = const {},
    this.expandingGroupIds = const {},
    this.collapsingGroupIds = const {},
    this.dragGroupTargetCat,
    this.collapsedGroupDwellId,
    this.onPin,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    this.onEditGroup,
    this.onDeleteGroup,
    this.onToggleExpand,
    this.listStackKey,
    this.draggingCat,
    this.dragLocalTopY,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
    this.draggingGroup,
    this.onGroupHeaderReorderStart,
    this.onGroupHeaderReorderUpdate,
    this.onGroupHeaderReorderEnd,
    this.onGroupHeaderReorderCancel,
  });

  // A row is "collapsed" if it's mid-animation toward zero height.
  bool _isCatCollapsed(_UserCategory cat) =>
      removingCategories.contains(cat) ||
      newCategories.contains(cat) ||
      archivingCategories.contains(cat) ||
      deletingCategories.contains(cat);

  // ── Slot-height helpers ────────────────────────────────────────────────────

  /// Height the AnimatedPositioned slot will occupy.
  ///
  /// The outer AnimatedContainer target height is the sum of each row's own
  /// measured height, *excluding* collapsing members (they are going to zero)
  /// but *including* expanding members (they are going to full height). That makes the outer
  /// card grow/shrink in sync with the inner row animations.
  ///
  /// Group headers are never affected by accordion lifecycle sets.
  double _slotTargetH(_FlatItem item, BuildContext context) {
    // Category lifecycle animation (remove / archive / delete / new pop-in).
    final cat = item.category;
    if (cat != null && _isCatCollapsed(cat)) return 0.0;

    // Accordion collapse: member is shrinking to zero.
    if (item.isGroupMember &&
        item.groupId != null &&
        collapsingGroupIds.contains(item.groupId)) {
      return 0.0;
    }

    return _eventsCategoryListRowHeight(
      context,
      item: item,
      liveEventCounts: liveEventCounts,
    );
  }

  /// Height used by AnimatedPositioned for the current slot.
  ///
  /// Identical to [_slotTargetH] except that expanding members start at 0 and
  /// grow to their own measured height when [expandingGroupIds] is cleared — the outer card
  /// already has the full expanded height as its target so the clip reveals
  /// the member rows as they animate upward.
  double _slotCurrentH(_FlatItem item, BuildContext context) {
    if (_slotTargetH(item, context) == 0.0) return 0.0;
    // Expanding members: slot starts collapsed; outer card already at full
    // target height, so the card stays still while the slots grow into it.
    if (item.isGroupMember &&
        item.groupId != null &&
        expandingGroupIds.contains(item.groupId)) {
      return 0.0;
    }
    return _eventsCategoryListRowHeight(
      context,
      item: item,
      liveEventCounts: liveEventCounts,
    );
  }

  /// Whether the isFirst/isLast corner flags should treat this slot as hidden
  /// (accordion members mid-transition, or lifecycle-collapsed rows).
  bool _isSlotHidden(_FlatItem item, BuildContext context) =>
      _slotCurrentH(item, context) == 0.0;

  // Top-Y of slot [idx], accounting for rows above it that are mid-collapse.
  double _slotTopY(int idx, BuildContext context) {
    var y = 0.0;
    for (var i = 0; i < idx; i++) {
      y += _slotCurrentH(items[i], context) + _kRowGap;
    }
    return y;
  }

  @override
  Widget build(BuildContext context) {
    // Target height: every slot that will be at full height after the current
    // animation finishes. Each slot contributes its own measured height.
    // Lifecycle-collapsed and collapsing-accordion rows are excluded;
    // expanding-accordion rows are included because they animate *into* the
    // space the outer container is already opening.
    final totalH = items.fold<double>(
      0.0,
      (h, item) => h + _slotTargetH(item, context),
    );
    final resolvedSurface = resolveThemeColor(kSbSurface, context);
    final resolvedShadows = resolveThemeShadows(kCardShadow, context);
    // The outer CATEGORIES surface uses a single stable shape. Its clip rect
    // height changes as the accordion animates, but the requested corner
    // radius is constant (24 px) and the outer card is always tall enough
    // (minimum one full row) that BoundedContinuousRectangleBorder never has
    // to constrain that radius vertically. Individual row shapes paint their
    // own surfaces but rely on this outer clip for the shared outer boundary.
    const outerCardShape = BoundedContinuousRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: _kAnimMs),
      curve: _kAnimCurve,
      height: totalH,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: resolvedSurface,
        shadows: resolvedShadows,
        shape: outerCardShape,
      ),
      child: Stack(
        key: listStackKey,
        clipBehavior: Clip.none,
        children: [
          // ── Non-dragging row slots ──────────────────────────────────────
          for (int i = 0; i < items.length; i++)
            if (!(items[i].isCategory && items[i].category == draggingCat) &&
                !(items[i].isGroupHeader &&
                    items[i].group?.id == draggingGroup?.id))
              _buildSlot(items[i], i, context),
          // ── Dragging slots — invisible placeholders rendered last ────────
          // Move the null-guard into the for-loop condition to avoid
          // 3-level if->for->if collection nesting (Dart 3.9 compat).
          for (int i = 0; draggingCat != null && i < items.length; i++)
            if (items[i].isCategory && items[i].category == draggingCat)
              _buildSlot(items[i], i, context),
          for (int i = 0; draggingGroup != null && i < items.length; i++)
            if (items[i].isGroupHeader &&
                items[i].group?.id == draggingGroup!.id)
              _buildSlot(items[i], i, context),
        ],
      ),
    );
  }

  Widget _buildSlot(_FlatItem item, int idx, BuildContext context) {
    final cat = item.category;
    final group = item.group;
    final isDragging =
        (item.isCategory && cat == draggingCat) ||
        (item.isGroupHeader && group != null && group.id == draggingGroup?.id);
    final isNew = cat != null && newCategories.contains(cat);
    final isArchiving = cat != null && archivingCategories.contains(cat);
    final isDeleting = cat != null && deletingCategories.contains(cat);
    final isGroupTarget = cat != null && cat == dragGroupTargetCat;

    final topY = isDragging && dragLocalTopY != null
        ? dragLocalTopY!
        : _slotTopY(idx, context);

    final itemHeight = _eventsCategoryListRowHeight(
      context,
      item: item,
      liveEventCounts: liveEventCounts,
    );
    // Dragging row always occupies its own full slot so the gap stays visible.
    final slotH = isDragging ? itemHeight : _slotCurrentH(item, context);

    // Determine position within the shared card for corner radii / divider.
    // Accordion-transitioning members and lifecycle-collapsed rows are hidden;
    // the dragging placeholder is always treated as visible so neighbours keep
    // their correct isFirst/isLast assignment during the drag.
    final visibleItems = items
        .where(
          (it) =>
              !_isSlotHidden(it, context) ||
              (it.isCategory && it.category == draggingCat),
        )
        .toList();
    final visIdx = visibleItems.indexOf(item);
    final isFirst = visIdx == 0;
    final isLast = visIdx == visibleItems.length - 1;
    final stadium = visibleItems.length == 1;
    final prevItem = visIdx > 0 ? visibleItems[visIdx - 1] : null;
    final hasGapAbove =
        prevItem != null &&
        ((prevItem.isCategory && prevItem.category == draggingCat) ||
            (prevItem.isGroupHeader &&
                prevItem.group?.id == draggingGroup?.id));

    // Build the appropriate row widget for this slot.
    Widget row;
    final glowColor = draggingCat?.color ?? resolveAccentColor(context);
    if (item.isGroupHeader && group != null) {
      row = _GroupRow(
        group: group,
        isExpanded: expandedGroupIds.contains(group.id),
        isFirst: isFirst,
        isLast: isLast,
        hasGapAbove: hasGapAbove,
        isCollapseTarget: collapsedGroupDwellId == group.id,
        glowColor: glowColor,
        onTap: onToggleExpand != null ? () => onToggleExpand!(group.id) : null,
        onEditGroup: onEditGroup != null ? () => onEditGroup!(group) : null,
        onDeleteGroup: onDeleteGroup != null
            ? () => onDeleteGroup!(group)
            : null,
        onReorderStart: onGroupHeaderReorderStart != null
            ? (p) => onGroupHeaderReorderStart!(group, p)
            : null,
        onReorderUpdate: onGroupHeaderReorderUpdate != null
            ? (p) => onGroupHeaderReorderUpdate!(group, p)
            : null,
        onReorderEnd: onGroupHeaderReorderEnd != null
            ? () => onGroupHeaderReorderEnd!(group)
            : null,
        onReorderCancel: onGroupHeaderReorderCancel != null
            ? () => onGroupHeaderReorderCancel!(group)
            : null,
      );
    } else if (cat != null) {
      row = _CategoryRow(
        category: cat,
        liveCount: liveEventCounts[cat.id] ?? 0,
        isFirst: isFirst,
        isLast: isLast,
        hasGapAbove: hasGapAbove,
        indented: item.isGroupMember,
        isGroupTarget: isGroupTarget,
        stadium: stadium,
        onPin: item.isSolo && onPin != null ? () => onPin!(cat) : null,
        onEdit: onEdit != null ? () => onEdit!(cat) : null,
        onArchive: onArchive != null ? () => onArchive!(cat) : null,
        onDelete: onDelete != null ? () => onDelete!(cat) : null,
        onReorderStart: onReorderStart != null
            ? (p) => onReorderStart!(cat, p)
            : null,
        onReorderUpdate: onReorderUpdate != null
            ? (p) => onReorderUpdate!(cat, p)
            : null,
        onReorderEnd: onReorderEnd != null ? () => onReorderEnd!(cat) : null,
        onReorderCancel: onReorderCancel != null
            ? () => onReorderCancel!(cat)
            : null,
      );
    } else {
      row = const SizedBox.shrink();
    }

    Widget slotContent;

    if (cat != null && poppingInCategories.contains(cat)) {
      slotContent = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        ),
        child: row,
      );
    } else {
      Widget content = AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isSlotHidden(item, context) ? 0.0 : 1.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInCubic,
          scale: isDeleting ? 0.92 : 1.0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeIn,
            offset: isArchiving ? const Offset(-0.05, 0) : Offset.zero,
            child: row,
          ),
        ),
      );
      if (isDeleting && cat != null) {
        content = TweenAnimationBuilder<double>(
          key: ValueKey('del_flash_${cat.name}'),
          tween: Tween(begin: 0.16, end: 0.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, alpha, child) => ColoredBox(
            color: CupertinoColors.destructiveRed.withValues(alpha: alpha),
            child: child,
          ),
          child: content,
        );
      }
      slotContent = ClipRect(
        clipBehavior: isDragging ? Clip.none : Clip.hardEdge,
        child: Opacity(opacity: isDragging ? 0.0 : 1.0, child: content),
      );
    }

    // Use a stable ID-based key so Flutter reconciles by identity, not position.
    // If we used ValueKey(item), a solo↔member transition changes the key
    // (kind is part of _FlatItem.hashCode), disposing the _CategoryContextMenu
    // and killing the in-flight gesture — leaving the overlay ghost frozen.
    final slotKey = item.isGroupHeader
        ? ValueKey('grp-${item.group!.id}')
        : ValueKey(item.category!.id);
    return AnimatedPositioned(
      key: slotKey,
      duration: isDragging
          ? Duration.zero
          : Duration(milliseconds: isDeleting || isNew ? 230 : _kAnimMs),
      curve: isNew
          ? Curves.easeOut
          : isDeleting
          ? Curves.easeInCubic
          : _kAnimCurve,
      top: topY,
      left: 0,
      right: 0,
      height: slotH,
      child: slotContent,
    );
  }
}

// ── Single user-category row ──────────────────────────────────────────────────
class _CategoryRow extends StatelessWidget {
  final _UserCategory category;

  /// Live event count injected from [_CategoryCard.liveEventCounts] — replaces
  /// the stale persisted [_UserCategory.count] so the row chevron number
  /// updates immediately when events are added, edited, or removed.
  final int liveCount;

  /// Position within the shared grouped card.  isFirst → top corners rounded;
  /// isLast → bottom corners rounded; both true → fully rounded (single row).
  final bool isFirst;
  final bool isLast;

  /// True when the slot directly above this one is the invisible dragged
  /// placeholder.  In that case a top separator must be shown even though
  /// isFirst is false, so the card below the drag-gap is properly framed.
  final bool hasGapAbove;

  /// When true, this row is a group member — rendered with extra left indent.
  final bool indented;

  /// When true, this category is currently the drag-to-group target — rendered
  /// with a subtle blue tint to indicate the impending group merge.
  final bool isGroupTarget;
  final bool stadium;

  final VoidCallback? onPin;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final void Function(Offset)? onReorderStart;
  final void Function(Offset)? onReorderUpdate;
  final VoidCallback? onReorderEnd;
  final VoidCallback? onReorderCancel;

  const _CategoryRow({
    super.key,
    required this.category,
    this.liveCount = 0,
    this.isFirst = true,
    this.isLast = true,
    this.hasGapAbove = false,
    this.indented = false,
    this.isGroupTarget = false,
    this.stadium = false,
    this.onPin,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
  });

  @override
  Widget build(BuildContext context) {
    final onTap = _CategoryTapCallback.of(context)?.onTileTapped;
    Widget content = _CategoryContextMenu(
      isSmartCategory: false,
      isPinned: false,
      reorderable: true, // group members are now individually reorderable
      onPin: onPin,
      onEdit: onEdit,
      onArchive: onArchive,
      onDelete: onDelete,
      onTap: onTap != null
          ? () => onTap(
              category.name,
              renderCategoryColor(category.color, context),
            )
          : null,
      onReorderStart: onReorderStart,
      onReorderUpdate: onReorderUpdate,
      onReorderEnd: onReorderEnd,
      onReorderCancel: onReorderCancel,
      // The preview is shown in isolation (full card), so pass isFirst/isLast
      // both true so it gets fully rounded corners and no hairline divider.
      child: _buildRowContent(
        isFirst: isFirst,
        isLast: isLast,
        context: context,
      ),
      previewBuilder: (ctx) =>
          _buildRowContent(isFirst: true, isLast: true, context: ctx),
    );
    if (isGroupTarget) {
      content = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        color: renderCategoryColor(
          category.color,
          context,
        ).withValues(alpha: 0.06),
        child: content,
      );
    }
    return content;
  }

  /// Build the row content with corner radii appropriate to its position in
  /// the shared grouped card.  No card shadow here — the outer DecoratedBox in
  /// _CategoryCard provides the single shared shadow for the whole group.
  Widget _buildRowContent({
    required bool isFirst,
    required bool isLast,
    required BuildContext context,
  }) {
    final radius = Radius.circular(_kCornerRadius);
    final borderRadius = BorderRadius.only(
      topLeft: isFirst ? radius : Radius.zero,
      topRight: isFirst ? radius : Radius.zero,
      bottomLeft: isLast ? radius : Radius.zero,
      bottomRight: isLast ? radius : Radius.zero,
    );
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);

    // Indent group member rows with extra left padding.
    final leftPad = indented ? 36.0 : 16.0;

    return Column(
      children: [
        if (hasGapAbove) Container(height: 0.5, color: separatorColor),
        Expanded(
          child: Container(
            decoration: ShapeDecoration(
              color: resolveThemeColor(kSbSurface, context),
              shape: BoundedContinuousRectangleBorder(
                borderRadius: stadium
                    ? BorderRadius.circular(1000.0)
                    : borderRadius,
              ),
            ),
            child: _TilePressScale(
              child: Padding(
                padding: EdgeInsets.only(
                  left: leftPad,
                  right: 16,
                  top: 13,
                  bottom: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _categoryIconCircleColor(
                          category.iconOrSvg,
                          renderCategoryColor(category.color, context),
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _renderCatIcon(
                          category.iconOrSvg,
                          34,
                          CupertinoColors.white,
                          emojiOffsetY: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: category.description.isEmpty
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              inherit: false,
                              color: primaryLabel,
                              fontSize: 16,
                              fontFamily: kSFProText,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.normal,
                              letterSpacing: kTracking16,
                              height: kLineHeight,
                            ),
                          ),
                          if (category.description.isNotEmpty) ...[
                            SizedBox(height: 2),
                            Text(
                              category.description,
                              style: TextStyle(
                                inherit: false,
                                color: secondaryLabel,
                                fontSize: 13,
                                fontFamily: kSFProText,
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.normal,
                                letterSpacing: -0.08,
                                height: kLineHeight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$liveCount',
                          style: TextStyle(
                            inherit: false,
                            color: secondaryLabel,
                            fontSize: 16,
                            fontFamily: kSFProText,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.normal,
                            letterSpacing: kTracking16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.chevron_right,
                          color: secondaryLabel,
                          size: MediaQuery.textScalerOf(context).scale(14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isLast) Container(height: 0.5, color: separatorColor),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GROUP ROW
// ══════════════════════════════════════════════════════════════════════════════

/// One group header row in the CATEGORIES list.
/// Shows the stack icon, group name, member count, and an expand/collapse
/// chevron. Long-press opens the group context menu (Edit Group Info, Delete
/// Group).
class _GroupRow extends StatelessWidget {
  final _CategoryGroup group;
  final bool isExpanded;
  final bool isFirst;
  final bool isLast;
  final bool hasGapAbove;

  /// When true this group header glows to indicate a pending dwell-join.
  final bool isCollapseTarget;

  /// Glow tint — used when [isCollapseTarget] is true.
  final Color glowColor;
  final VoidCallback? onTap;
  final VoidCallback? onEditGroup;
  final VoidCallback? onDeleteGroup;
  // Drag-reorder callbacks (same signature as _CategoryContextMenu expects).
  final void Function(Offset)? onReorderStart;
  final void Function(Offset)? onReorderUpdate;
  final VoidCallback? onReorderEnd;
  final VoidCallback? onReorderCancel;

  const _GroupRow({
    super.key,
    required this.group,
    required this.isExpanded,
    this.isFirst = true,
    this.isLast = true,
    this.hasGapAbove = false,
    this.isCollapseTarget = false,
    this.glowColor = kAccentColor,
    this.onTap,
    this.onEditGroup,
    this.onDeleteGroup,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = _CategoryContextMenu(
      isGroup: true,
      isSmartCategory: false,
      isPinned: false,
      reorderable: true,
      onEditGroup: onEditGroup,
      onDeleteGroup: onDeleteGroup,
      onTap: onTap,
      onReorderStart: onReorderStart,
      onReorderUpdate: onReorderUpdate,
      onReorderEnd: onReorderEnd,
      onReorderCancel: onReorderCancel,
      child: _buildRowContent(
        isFirst: isFirst,
        isLast: isLast,
        context: context,
      ),
      previewBuilder: (ctx) =>
          _buildRowContent(isFirst: true, isLast: true, context: ctx),
    );
    if (isCollapseTarget) {
      content = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        color: glowColor.withValues(alpha: 0.06),
        child: content,
      );
    }
    return content;
  }

  Widget _buildRowContent({
    required bool isFirst,
    required bool isLast,
    required BuildContext context,
  }) {
    final radius = Radius.circular(_kCornerRadius);
    final borderRadius = BorderRadius.only(
      topLeft: isFirst ? radius : Radius.zero,
      topRight: isFirst ? radius : Radius.zero,
      bottomLeft: isLast ? radius : Radius.zero,
      bottomRight: isLast ? radius : Radius.zero,
    );
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);
    final textScaler = MediaQuery.textScalerOf(context);

    return Column(
      children: [
        if (hasGapAbove) Container(height: 0.5, color: separatorColor),
        Expanded(
          child: Container(
            decoration: ShapeDecoration(
              color: resolveThemeColor(kSbSurface, context),
              shape: BoundedContinuousRectangleBorder(
                borderRadius: borderRadius,
              ),
            ),
            child: _TilePressScale(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    // Stack icon — no colored container; icon is kSecondaryLabel.
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, -1),
                          child: FixedSFIcon(
                            SFIcons.sf_rectangle_stack,
                            fontSize: 22,
                            color: secondaryLabel,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        group.name,
                        style: TextStyle(
                          inherit: false,
                          color: primaryLabel,
                          fontSize: 16,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.normal,
                          letterSpacing: kTracking16,
                          height: kLineHeight,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Member count (replaces event count for groups)
                        Text(
                          '${group.memberIds.length}',
                          style: TextStyle(
                            inherit: false,
                            color: secondaryLabel,
                            fontSize: 16,
                            fontFamily: kSFProText,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.normal,
                            letterSpacing: kTracking16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Expand/collapse chevron — constrained to same 14px
                        // width as the category row's Icon(size:14) so the
                        // member-count text aligns with solo category rows.
                        SizedBox(
                          width: textScaler.scale(14),
                          child: Center(
                            child: AnimatedRotation(
                              turns: isExpanded ? 0.25 : 0.0,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeInOutCubic,
                              child: FixedSFIcon(
                                SFIcons.sf_chevron_right,
                                fontSize: textScaler.scale(13),
                                color: resolveAccentColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isLast) Container(height: 0.5, color: separatorColor),
      ],
    );
  }
}

enum _DeleteGroupChoice { only, withCategories }

/// Overlay confirmation sheet for group deletion.
///
/// This intentionally follows the same overlay-based presentation as the
/// microphone access sheet: the card blooms in place and the scrim remains in
/// the same compositing layer as the Events Tab behind it.
class _DeleteGroupSheet {
  static Future<_DeleteGroupChoice?> show(
    BuildContext context, {
    required String groupName,
  }) async {
    final completer = Completer<_DeleteGroupChoice?>();
    late final OverlayEntry entry;
    final overlay = Overlay.of(context, rootOverlay: true);

    void close(_DeleteGroupChoice? result) {
      if (completer.isCompleted) return;
      entry.remove();
      completer.complete(result);
    }

    entry = OverlayEntry(
      builder: (_) =>
          _DeleteGroupSheetOverlay(groupName: groupName, onResult: close),
    );
    overlay.insert(entry);
    return completer.future;
  }
}

class _DeleteGroupSheetOverlay extends StatelessWidget {
  final String groupName;
  final void Function(_DeleteGroupChoice?) onResult;

  const _DeleteGroupSheetOverlay({
    required this.groupName,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final primary = resolveThemeColor(kPrimaryLabel, context);
    final secondary = resolveThemeColor(kSecondaryLabel, context);
    final buttonDecor = ShapeDecoration(
      color: resolveThemeColor(kModalButtonBackground, context),
      shape: const SquircleStadiumBorder(),
      shadows: resolveThemeShadows(kCardShadow, context),
    );
    final sheetBorder = CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? BorderSide(
            color: resolveThemeColor(kTertiaryLabel, context),
            width: 0.5,
          )
        : null;

    Widget button({
      required String label,
      required Color labelColor,
      required VoidCallback onTap,
    }) {
      return GelBloomButton(
        peakScale: 1.06,
        tapDelay: const Duration(milliseconds: 120),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: buttonDecor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                inherit: false,
                fontSize: 17,
                fontFamily: 'SFProDisplay',
                fontWeight: FontWeight.w500,
                color: labelColor,
                letterSpacing: kTracking17,
                height: kLineHeight,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onResult(null),
          child: const ColoredBox(
            color: Color(0x44000000),
            child: SizedBox.expand(),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GelBloomCard(
                scaleOrigin: Alignment.center,
                fillOpacity: 0.82,
                shadowOpacity: 0.26,
                border: sheetBorder,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Delete the group "$groupName"?',
                        style: TextStyle(
                          inherit: false,
                          fontSize: 18,
                          fontFamily: 'SFProDisplay',
                          fontWeight: FontWeight.w600,
                          color: primary,
                          letterSpacing: kTracking16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Choose whether to keep or delete categories and their events.',
                        style: TextStyle(
                          inherit: false,
                          fontSize: 15,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w400,
                          color: secondary,
                          height: 1.5,
                          letterSpacing: kTracking16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      button(
                        label: 'Delete Group Only',
                        labelColor: primary,
                        onTap: () => onResult(_DeleteGroupChoice.only),
                      ),
                      const SizedBox(height: 12),
                      button(
                        label: 'Delete Group and Categories',
                        labelColor: CupertinoColors.destructiveRed,
                        onTap: () =>
                            onResult(_DeleteGroupChoice.withCategories),
                      ),
                      const SizedBox(height: 12),
                      button(
                        label: 'Cancel',
                        labelColor: primary,
                        onTap: () => onResult(null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD CATEGORY BUTTON
// ══════════════════════════════════════════════════════════════════════════════

class _AddCategoryButton extends StatefulWidget {
  final void Function(_UserCategory) onCategorySaved;
  const _AddCategoryButton({required this.onCategorySaved});

  @override
  State<_AddCategoryButton> createState() => _AddCategoryButtonState();
}

class _AddCategoryButtonState extends State<_AddCategoryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 120),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openAddCategorySheet() {
    showRoundedCupertinoSheet<void>(
      context: context,
      pageBuilder: (context) =>
          _AddCategorySheet(onSave: widget.onCategorySaved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final cardShadows = resolveThemeShadows(kCardShadow, context);
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: () => _ctrl.forward(from: 0).then((_) {
        if (mounted) _ctrl.reverse();
        _openAddCategorySheet();
      }),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - 0.04 * _ctrl.value,
          child: Opacity(opacity: 1.0 - 0.35 * _ctrl.value, child: child!),
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: resolveThemeColor(kSbSurface, context),
            shape: const SquircleStadiumBorder(),
            shadows: cardShadows,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchWeightedIcon(
                    CupertinoIcons.add,
                    size: 18,
                    color: resolveAccentColor(context),
                    weight: 0.25,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Add Category',
                    style: TextStyle(
                      inherit: false,
                      color: resolveAccentColor(context),
                      fontSize: 17,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.normal,
                      letterSpacing: kTracking17,
                      height: kLineHeight,
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

// ══════════════════════════════════════════════════════════════════════════════
// NEW GROUP SHEET
// ══════════════════════════════════════════════════════════════════════════════

/// Modal sheet for creating or editing a category group.
/// Displays a single card with two rows:
///   1. A text field for the group name.
///   2. An "Include" picker that opens a multi-select category overlay.
///
/// Minimum 2 categories must be checked before saving is allowed.
class _NewGroupSheet extends StatefulWidget {
  /// All non-pinned, non-archived categories available for grouping.
  final List<_UserCategory> allCategories;

  /// All existing groups — used to gray out cats already in another group.
  final List<_CategoryGroup> existingGroups;

  /// IDs pre-checked when the sheet opens (the two drag-merged categories).
  final List<String> initialMemberIds;

  /// Non-null when editing an existing group.
  final _CategoryGroup? initial;

  /// Called when the user taps Save with a valid group.
  final void Function(_CategoryGroup) onSave;

  const _NewGroupSheet({
    required this.allCategories,
    required this.existingGroups,
    required this.initialMemberIds,
    required this.onSave,
    this.initial,
  });

  @override
  State<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends State<_NewGroupSheet> {
  static const double _kHeaderBtnSize = 40.0;
  static const double _kHeaderEdge = 16.0;
  static const double _kHeaderTopShift = 12.5;

  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  final FocusNode _nameFocus = FocusNode();
  late final Set<String> _selectedIds = Set<String>.from(
    widget.initialMemberIds,
  );

  OverlayEntry? _pickerEntry;
  final ValueNotifier<bool> _pickerIsClosing = ValueNotifier(false);
  bool _pickerOpen = false;

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _selectedIds.length >= 2;

  @override
  void initState() {
    super.initState();
    // Focus the group-name field as soon as the sheet is rendered so the
    // keyboard appears immediately — matching the Category sheet behaviour.
    // Only auto-focus on New Group (drag-merge). Edit Group opens without
    // the keyboard so the user can review the existing name first.
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    _dismissPicker(animate: false);
    _pickerIsClosing.dispose();
    super.dispose();
  }

  void _dismissPicker({bool animate = true}) {
    if (!_pickerOpen) return;
    _pickerIsClosing.value = true;
    final delay = animate ? const Duration(milliseconds: 420) : Duration.zero;
    Future.delayed(delay, () {
      _pickerEntry?.remove();
      _pickerEntry = null;
      if (mounted) {
        _pickerIsClosing.value = false;
        setState(() => _pickerOpen = false);
      }
    });
  }

  void _showIncludePicker(BuildContext rowCtx) {
    if (_pickerOpen) _dismissPicker(animate: false);
    FocusManager.instance.primaryFocus?.unfocus();
    final box = rowCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _pickerIsClosing.value = false;
    setState(() => _pickerOpen = true);

    // Build ActionItems for the multi-select overlay.
    // Each category gets a checkmark when selected.
    // Categories already in a DIFFERENT group are grayed out (not selectable).
    final String? editingGroupId = widget.initial?.id;
    List<ActionItem> _buildItems() => widget.allCategories.map((cat) {
      // Is this cat locked inside another group that we're not editing?
      final lockedInOther = widget.existingGroups.any(
        (g) => g.id != editingGroupId && g.memberIds.contains(cat.id),
      );
      return ActionItem(
        label: cat.name,
        icon: SFIcons.sf_circle,
        iconBuilder: (color) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: lockedInOther ? kTertiaryLabel : cat.color,
            shape: BoxShape.circle,
          ),
        ),
        labelColor: lockedInOther ? kTertiaryLabel : null,
        checkmark: _selectedIds.contains(cat.id),
        checkmarkColor: cat.color,
        onTap: lockedInOther
            ? null
            : () {
                setState(() {
                  if (_selectedIds.contains(cat.id)) {
                    if (_selectedIds.length > 2) {
                      _selectedIds.remove(cat.id);
                    }
                    // Silently ignore attempts to deselect below 2.
                  } else {
                    _selectedIds.add(cat.id);
                  }
                });
                // Rebuild the overlay so checkmarks update live.
                _pickerEntry?.markNeedsBuild();
              },
      );
    }).toList();

    _pickerEntry = OverlayEntry(
      builder: (ctx) => ActionMenuOverlay(
        buttonRect: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
        isClosing: _pickerIsClosing,
        onDismiss: _dismissPicker,
        actions: _buildItems(),
        panelWidth: kPickerPanelWidth,
        chevronColumn: true,
        anchorToRight: true,
        labelFontSize: 15,
        bouncingScroll: true,
      ),
    );
    Overlay.of(context).insert(_pickerEntry!);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selectedIds.length < 2) return;
    // Preserve order: use allCategories order filtered to selected IDs.
    final orderedIds = widget.allCategories
        .where((c) => _selectedIds.contains(c.id))
        .map((c) => c.id)
        .toList();
    widget.onSave(
      _CategoryGroup(
        id:
            widget.initial?.id ??
            'grp-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        memberIds: orderedIds,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIds.length;
    final includeValue =
        '$selectedCount ${selectedCount == 1 ? 'Category' : 'Categories'}';

    return PopScope(
      canPop: !_pickerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismissPicker();
      },
      child: CupertinoPageScaffold(
        backgroundColor: kModalBackground,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────────
              SizedBox(height: _kHeaderTopShift),
              RoundedCupertinoSheetHeader(
                child: SizedBox(
                  height: _kHeaderBtnSize,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        widget.initial != null ? 'Edit Group' : 'New Group',
                        style: TextStyle(
                          inherit: false,
                          color: resolveThemeColor(kPrimaryLabel, context),
                          fontSize: 17,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.normal,
                          letterSpacing: kTracking17,
                          height: kLineHeight,
                        ),
                      ),
                      Positioned(
                        left: _kHeaderEdge,
                        child: _ModalCircleButton(
                          icon: CupertinoIcons.xmark,
                          iconColor: resolveThemeColor(kPrimaryLabel, context),
                          tapDelay: const Duration(milliseconds: 130),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        right: _kHeaderEdge,
                        child: AnimatedBuilder(
                          animation: _nameCtrl,
                          builder: (_, __) {
                            final canSave = _canSave;
                            return _ModalCircleButton(
                              icon: CupertinoIcons.checkmark,
                              containerColor: canSave
                                  ? resolveAccentColor(context)
                                  : kTertiaryLabel,
                              iconColor: CupertinoColors.white,
                              tapDelay: const Duration(milliseconds: 130),
                              onTap: canSave ? _save : () {},
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Card ─────────────────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismissModalSheetFocus,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Container(
                      decoration: ShapeDecoration(
                        color: resolveThemeColor(kModalCard, context),
                        shape: BoundedContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            kCardCornerRadius,
                          ),
                        ),
                        shadows: resolveThemeShadows(kCardShadow, context),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Row 1: Name field ─────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                // Animated placeholder: slides 4 px right on
                                // focus, matching the Location field behaviour.
                                AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _nameCtrl,
                                    _nameFocus,
                                  ]),
                                  builder: (_, __) {
                                    if (_nameCtrl.text.isNotEmpty)
                                      return const SizedBox.shrink();
                                    return Positioned.fill(
                                      child: IgnorePointer(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            curve: Curves.easeOut,
                                            transform:
                                                Matrix4.translationValues(
                                                  _nameFocus.hasFocus
                                                      ? 4.0
                                                      : 0.0,
                                                  0,
                                                  0,
                                                ),
                                            child: Text(
                                              'Group Name',
                                              style: TextStyle(
                                                inherit: false,
                                                color: resolveThemeColor(
                                                  kTertiaryLabel,
                                                  context,
                                                ),
                                                fontSize: 17,
                                                fontFamily: kSFProText,
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: kTracking17,
                                                height: kLineHeight,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // CupertinoTheme ensures selection handles
                                // use the current accent, matching the cursor.
                                CupertinoTheme(
                                  data: CupertinoTheme.of(context).copyWith(
                                    primaryColor: resolveAccentColor(context),
                                  ),
                                  child: DefaultSelectionStyle(
                                    selectionColor: resolveAccentColor(
                                      context,
                                    ).withOpacity(0.20),
                                    child: CupertinoTextField(
                                      controller: _nameCtrl,
                                      focusNode: _nameFocus,
                                      placeholder: '',
                                      style: TextStyle(
                                        inherit: false,
                                        color: resolveThemeColor(
                                          kPrimaryLabel,
                                          context,
                                        ),
                                        fontSize: 17,
                                        fontFamily: kSFProText,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: kTracking17,
                                        height: kLineHeight,
                                      ),
                                      cursorColor: resolveAccentColor(context),
                                      // Right padding leaves room for the clear button.
                                      padding: const EdgeInsets.only(right: 30),
                                      decoration: null,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      textInputAction: TextInputAction.done,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ),
                                // Clear button — visible only when text is present.
                                AnimatedBuilder(
                                  animation: _nameCtrl,
                                  builder: (_, __) {
                                    if (_nameCtrl.text.isEmpty)
                                      return const SizedBox.shrink();
                                    return Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          _nameCtrl.clear();
                                          setState(() {});
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Icon(
                                            kSearchClearCircleIcon,
                                            color: kEmptyStateIcon,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          // Hairline separator
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              height: 0.5,
                              color: resolveThemeColor(
                                kSeparatorColor,
                                context,
                              ),
                            ),
                          ),
                          // ── Row 2: Include picker ─────────────────────────
                          Builder(
                            builder: (rowCtx) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showIncludePicker(rowCtx),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: MinGapLabelValueRow(
                                  label: 'Include',
                                  labelStyle: TextStyle(
                                    inherit: false,
                                    color: resolveThemeColor(
                                      kPrimaryLabel,
                                      rowCtx,
                                    ),
                                    fontSize: 17,
                                    fontFamily: kSFProText,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: kTracking17,
                                    height: kLineHeight,
                                  ),
                                  value: includeValue,
                                  valueStyle: TextStyle(
                                    inherit: false,
                                    color: resolveThemeColor(
                                      kSecondaryLabel,
                                      rowCtx,
                                    ),
                                    fontSize: 15,
                                    fontFamily: kSFProText,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: kTracking17,
                                    height: kLineHeight,
                                  ),
                                  trailing: AnimatedBuilder(
                                    animation: _nameCtrl,
                                    builder: (_, __) =>
                                        ModalSheetPickerTrailing(
                                          value: includeValue,
                                          style: TextStyle(
                                            inherit: false,
                                            color: resolveThemeColor(
                                              kSecondaryLabel,
                                              rowCtx,
                                            ),
                                            fontSize: 15,
                                            fontFamily: kSFProText,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: kTracking17,
                                            height: kLineHeight,
                                          ),
                                          chevronColor: resolveThemeColor(
                                            kSecondaryLabel,
                                            rowCtx,
                                          ),
                                        ),
                                  ),
                                  trailingExtraWidth: 16,
                                ),
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD CATEGORY — blank receding-stack sheet (content to be filled in later)
// ══════════════════════════════════════════════════════════════════════════════
class _AddCategorySheet extends StatefulWidget {
  final void Function(_UserCategory)? onSave;

  /// When non-null, the sheet opens in "Edit Category" mode, pre-filled with
  /// this category's current title, description, color, and icon.
  final _UserCategory? initial;

  /// When non-null, this sheet is editing a fixed *smart* tile instead of a
  /// user category: title/description are locked (smart tiles don't have an
  /// editable name or description) and there's no icon picker (their icon is
  /// fixed) — only the color swatch can be changed.
  final _TileData? smartData;
  final Color? smartColor;
  final void Function(Color)? onSaveColor;
  const _AddCategorySheet({
    this.onSave,
    this.initial,
    this.smartData,
    this.smartColor,
    this.onSaveColor,
  });

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet>
    with TickerProviderStateMixin {
  static const double _kHeaderBtnSize = 40.0;
  static const double _kHeaderEdge = 16.0;
  static const double _kHeaderTopShift = 12.5;

  bool get _isSmart => widget.smartData != null;

  Object get _effectiveIcon => _selectedIcon;

  late final _titleCtrl = TextEditingController(
    text: widget.smartData?.label ?? widget.initial?.name ?? '',
  );
  late final _descCtrl = TextEditingController(
    text: widget.smartData != null
        ? (_kSmartCategoryDescriptions[widget.smartData!.label] ?? '')
        : (widget.initial?.description ?? ''),
  );
  late final _smartDescriptionCtrl = TextEditingController(
    text: widget.initial?.smartDescription ?? '',
  );
  final _startLocCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _descScrollCtrl = ScrollController();

  // ── Title / description focus nodes ──────────────────────────────────────
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();

  // ── Selection-handle colour tracking ─────────────────────────────────────
  // A single stable _TintedCupertinoTextSelectionControls instance is shared
  // across all text fields in the sheet.  Its colour is updated via the
  // notifier whenever the user picks a different category swatch, without
  // ever changing the selectionControls reference — so Flutter's selection
  // overlay is never disposed and gesture behaviour (tap-to-move-cursor,
  // double-tap word-select, triple-tap all-select) is preserved correctly.
  late final ValueNotifier<Color> _handleColorNotifier;
  late final TintedCupertinoTextSelectionControls _selectionControls;

  // ── Location field focus nodes (drive placeholder slide animation) ────────
  final _startLocFocus = FocusNode();
  final _destFocus = FocusNode();
  final _smartDescriptionFocus = FocusNode();

  // ── Picker-row state ──────────────────────────────────────────────────────
  late String _categoryType = widget.initial?.categoryType ?? 'Standard';
  String _travelTime = 'None';
  String _travelMode = 'None';
  String _repeat = 'Never';
  _CustomRepeatConfig? _savedCustomConfig;
  String _alert = 'At time of event';
  String _secondAlert = 'None';

  // Overlay management for the mini ActionPanel that opens on picker-row tap.
  // A persistent ValueNotifier lets us reset its value on re-open without
  // re-creating the listener chain inside ActionPanel.
  // _openPickerLabel tracks WHICH row's panel is open so only that row's
  // value+chevron dims; null means no panel is open.
  final _pickerIsClosing = ValueNotifier<bool>(false);
  OverlayEntry? _pickerEntry;
  bool _pickerMenuOpen = false;
  String? _openPickerLabel;
  bool _smartDescriptionSaved = false;

  // ── Cascading-card animation controllers ──────────────────────────────────
  // Each controller drives a SizeTransition that reveals a connected child card.
  // Initial values reflect defaults:
  //   _travelModeCtrl  = 0.0  (Travel Time defaults to 'None' → mode hidden)
  //   _endRepeatCtrl   = 0.0  (Repeat defaults to 'Never')
  //   _endDateCtrl     = 0.0  (End Repeat defaults to 'Never')
  //   _datePickerCtrl  = 0.0  (inline date picker starts closed)
  //   _secondAlertCtrl = 1.0  (Alert defaults to 'At time of event' → shown)
  late final AnimationController _travelModeCtrl;
  late final AnimationController _smartCategoryCtrl;
  late final AnimationController _endRepeatCtrl;
  late final AnimationController _endDateCtrl;
  late final AnimationController _datePickerCtrl;
  late final AnimationController _secondAlertCtrl;

  String _endRepeat = 'Never';
  late DateTime _endDate; // set in initState to today + 1 month
  late DateTime _calendarMonth; // month displayed in the inline calendar
  bool _calendarBarrelMode = false; // month grid ↔ date picker
  double _calendarDragOffset =
      0.0; // live 1:1 horizontal drag offset (also animated)
  double _calPanelWidth =
      0.0; // cached from LayoutBuilder for animation targets
  Tween<double>?
  _monthSlideTween; // non-null while a commit/snap animation runs
  late final AnimationController _monthSlideCtrl;

  // Minutes-before-event for each alert label.  -1 = 'None' (no alert).
  // Used to determine which Second Alert options are valid given the primary Alert.
  static const _kAlertMinutes = <String, int>{
    'None': -1,
    'At time of event': 0,
    '5 minutes before': 5,
    '10 minutes before': 10,
    '15 minutes before': 15,
    '30 minutes before': 30,
    '1 hour before': 60,
    '1 hour, 30 minutes before': 90,
    '2 hours before': 120,
    '1 day before': 1440,
    '2 days before': 2880,
    '1 week before': 10080,
  };

  // ── selection state for color + icon pickers ─────────────────────────────
  late Color _selectedColor =
      widget.smartColor ?? widget.initial?.color ?? kAccentColor;
  // A newly created category starts as the app accent, but an explicit tap on
  // any swatch (including Blue while the accent is Red, for example) must
  // remain that swatch instead of being reinterpreted as the accent sentinel.
  late bool _selectedColorFollowsAccent =
      widget.smartColor == null &&
      (widget.initial == null || widget.initial!.color.value == kCatBlue.value);

  /// Render-time resolved color: follows the live accent when [_selectedColor]
  /// is the default blue swatch (kCatBlue == kAccentColor).
  Color get _resolvedSelectedColor => _selectedColorFollowsAccent
      ? resolveAccentColor(context)
      : resolveThemeColor(_selectedColor, context);

  // Always read the persisted icon from the category object.
  // New categories (widget.initial == null) default to sf_list_bullet.
  // Unnamed/Uncategorized already carry CupertinoIcons.folder in their data.
  late Object _selectedIcon =
      widget.initial?.iconOrSvg ?? SFIcons.sf_list_bullet;

  // 12 swatches — 2 rows of 6. See app_theme.dart for the dynamic light/dark
  // hex pair behind each swatch.
  static const _kColorOptions = kCategorySwatches;

  // 77 icons — 10 rows of 7 + 1 row of 2
  // Entries are either IconData (icon font) or String (SVG asset path).
  // Pass to _renderCatIcon() at every render site — never call Icon() directly.
  static const _kIconOptions = <Object>[
    // Row 1 — General
    'assets/custom_icons/emoji.svg', SFIcons.sf_list_bullet,
    CupertinoIcons.bookmark_fill, SFIcons.sf_mappin,
    CupertinoIcons.gift_fill, 'assets/custom_icons/Cake.svg',
    SFIcons.sf_graduationcap_fill,
    // Row 2 — Work / Study
    'assets/custom_icons/Bag.svg', SFIcons.sf_pencil_and_ruler_fill,
    CupertinoIcons.doc_fill, CupertinoIcons.book_fill,
    'assets/custom_icons/Wallet.svg', CupertinoIcons.creditcard_fill,
    'assets/custom_icons/Banknote.svg',
    // Row 3 — Health / Food
    SFIcons.sf_dumbbell_fill, SFIcons.sf_figure_run,
    SFIcons.sf_fork_knife, 'assets/custom_icons/Wine.svg',
    'assets/custom_icons/Pill.svg', SFIcons.sf_stethoscope,
    'assets/custom_icons/Armchair.svg',
    // Row 4 — Places
    CupertinoIcons.house_fill, 'assets/custom_icons/Building2.svg',
    SFIcons.sf_building_columns_fill, 'assets/custom_icons/Tent.svg',
    SFIcons.sf_tv, 'assets/custom_icons/Music.svg',
    'assets/custom_icons/Laptop.svg',
    // Row 5 — People / Leisure
    CupertinoIcons.gamecontroller_fill, CupertinoIcons.headphones,
    SFIcons.sf_leaf_fill, 'assets/custom_icons/Rocket.svg',
    SFIcons.sf_figure_arms_open, SFIcons.sf_figure_2_left_holdinghands,
    SFIcons.sf_figure_2_and_child_holdinghands,
    // Row 6 — Animals / Shopping
    CupertinoIcons.paw_solid, 'assets/custom_icons/Bear.svg',
    SFIcons.sf_fish_fill, 'assets/custom_icons/ShoppingBasket.svg',
    SFIcons.sf_cart_fill, 'assets/custom_icons/ShoppingBag.svg',
    CupertinoIcons.cube_box_fill,
    // Row 7 — Sports / Transport
    'assets/custom_icons/SoccerBall.svg',
    'assets/custom_icons/PingPongBall.svg',
    SFIcons.sf_basketball_fill, 'assets/custom_icons/FootBall.svg',
    SFIcons.sf_tennis_racket, CupertinoIcons.tram_fill,
    CupertinoIcons.airplane,
    // Row 8 — Weather / Nature
    'assets/custom_icons/Sailboat.svg', SFIcons.sf_car_fill,
    'assets/custom_icons/Umbrella.svg', CupertinoIcons.sun_max_fill,
    CupertinoIcons.moon_fill, SFIcons.sf_drop_fill,
    SFIcons.sf_snowflake,
    // Row 9 — Tools
    CupertinoIcons.flame_fill, 'assets/custom_icons/Briefcase.svg',
    'assets/custom_icons/Wrench.svg', CupertinoIcons.scissors,
    'assets/custom_icons/Compass.svg', SFIcons.sf_curlybraces,
    CupertinoIcons.lightbulb_fill,
    // Row 10 — Symbols
    CupertinoIcons.bubble_left_fill, 'assets/custom_icons/AlertCircle.svg',
    'assets/custom_icons/staroflife.fill.svg', CupertinoIcons.square_fill,
    CupertinoIcons.circle_fill, CupertinoIcons.triangle_fill,
    SFIcons.sf_diamond_fill,
    // Row 11 — Misc
    CupertinoIcons.suit_heart_fill, CupertinoIcons.star_fill,
  ];

  @override
  void initState() {
    super.initState();
    _smartDescriptionSaved =
        widget.initial?.smartDescription.trim().isNotEmpty ?? false;

    // ── Restore preset field values when editing an existing category ────────
    final init = widget.initial;
    if (init != null && !_isSmart) {
      if (init.presetLocation != null) {
        _startLocCtrl.text = init.presetLocation!;
      }
      if (init.presetDestination != null) {
        _destCtrl.text = init.presetDestination!;
      }
      _travelTime = init.presetTravelTime ?? 'None';
      _travelMode = init.presetTravelMode ?? 'None';
      _repeat = init.presetRepeat ?? 'Never';
      _endRepeat = init.presetRepeatEndType ?? 'Never';
      _alert = init.presetAlert ?? 'At time of event';
      _secondAlert = init.presetSecondAlert ?? 'None';
      // Reconstruct custom repeat config if present.
      final crc = init.presetCustomRepeatConfig;
      if (crc != null) {
        _savedCustomConfig = _CustomRepeatConfig(
          frequency: (crc['frequency'] as String?) ?? 'Daily',
          everyCount: (crc['everyCount'] as int?) ?? 1,
          selectedDays: Set<String>.from(
            (crc['selectedDays'] as List?)?.cast<String>() ?? [],
          ),
          monthlyMode: (crc['monthlyMode'] as String?) ?? 'Each',
          selectedDates: Set<int>.from(
            (crc['selectedDates'] as List?)?.cast<int>() ?? [],
          ),
          onThePositionIndex: (crc['onThePositionIndex'] as int?) ?? 0,
          onTheDayIndex: (crc['onTheDayIndex'] as int?) ?? 0,
          selectedMonths: Set<int>.from(
            (crc['selectedMonths'] as List?)?.cast<int>() ?? [],
          ),
          yearlyDaysEnabled: (crc['yearlyDaysEnabled'] as bool?) ?? false,
          yearlyPositionIndex: (crc['yearlyPositionIndex'] as int?) ?? 0,
          yearlyDayIndex: (crc['yearlyDayIndex'] as int?) ?? 0,
        );
      }
    }

    const dur = Duration(milliseconds: 280);
    _travelModeCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: _travelMode != 'None' ? 1.0 : 0.0,
    );
    _smartCategoryCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: _categoryType == 'Smart Category' ? 1.0 : 0.0,
    );
    _endRepeatCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: _repeat != 'Never' ? 1.0 : 0.0,
    );
    _endDateCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: _endRepeat == 'On Date' ? 1.0 : 0.0,
    );
    _datePickerCtrl = AnimationController(vsync: this, duration: dur);
    // Second Alert visible whenever there is a primary alert.
    _secondAlertCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: _alert != 'None' ? 1.0 : 0.0,
    );
    _monthSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _monthSlideCtrl.addListener(_onMonthSlideUpdate);
    // Note: do NOT add a controller listener here. TextEditingController fires
    // its listeners on *both* text changes and selection changes (cursor moves).
    // A setState fired during a selection-change (i.e. mid tap-gesture) causes
    // a widget rebuild that disrupts the TapAndDragGestureRecognizer and makes
    // a single tap look like a drag, selecting from the tap point to the
    // previous cursor position instead of simply moving the cursor.
    // The CupertinoTextField's onChanged: (_) => setState(() {}) callback
    // already covers the text-change case (updates the save-button colour).
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month + 1, now.day);
    _calendarMonth = DateTime(_endDate.year, _endDate.month);
    // Initialise with the raw colour; didChangeDependencies updates it to the
    // fully resolved value (accent sentinel → actual accent) once context is live.
    _handleColorNotifier = ValueNotifier<Color>(_selectedColor);
    _selectionControls = TintedCupertinoTextSelectionControls(
      _handleColorNotifier,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep the handle colour notifier in sync with the resolved accent.
    // Called after initState (when context is first valid) and whenever
    // the inherited theme changes (e.g. dark-mode toggle).
    _handleColorNotifier.value = _resolvedSelectedColor;
  }

  @override
  void dispose() {
    _travelModeCtrl.dispose();
    _endRepeatCtrl.dispose();
    _endDateCtrl.dispose();
    _datePickerCtrl.dispose();
    _secondAlertCtrl.dispose();
    _smartCategoryCtrl.dispose();
    _monthSlideCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _smartDescriptionCtrl.dispose();
    _startLocCtrl.dispose();
    _destCtrl.dispose();

    _descScrollCtrl.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    _startLocFocus.dispose();
    _destFocus.dispose();
    _smartDescriptionFocus.dispose();
    _handleColorNotifier.dispose();
    _dismissPickerOverlay(animate: false);
    _pickerIsClosing.dispose();
    super.dispose();
  }

  // ── Picker-row overlay helpers ────────────────────────────────────────────

  void _dismissPickerOverlay({bool animate = true}) {
    if (!_pickerMenuOpen) return;
    _pickerIsClosing.value = true;
    // Snap value+chevron back to secondary immediately — the user has already
    // selected an option, so there's no need to hold the dim through the close
    // animation.  _pickerMenuOpen stays true until the overlay entry is removed
    // so a second tap cannot re-open the panel during the 420 ms exit animation.
    if (mounted) setState(() => _openPickerLabel = null);
    final delay = animate ? const Duration(milliseconds: 420) : Duration.zero;
    Future.delayed(delay, () {
      _pickerEntry?.remove();
      _pickerEntry = null;
      if (mounted) {
        _pickerIsClosing.value = false;
        setState(() => _pickerMenuOpen = false);
      }
    });
  }

  // rowLabel is the label text of the row that triggered the overlay.
  // It is stored in _openPickerLabel so the row can dim itself while open.
  void _showPickerOverlay(
    BuildContext rowCtx,
    String rowLabel,
    List<ActionItem> items,
  ) {
    if (_pickerMenuOpen) _dismissPickerOverlay(animate: false);
    // Dismiss keyboard and cursor before the picker panel appears.
    FocusManager.instance.primaryFocus?.unfocus();
    final box = rowCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _pickerIsClosing.value = false;
    setState(() {
      _pickerMenuOpen = true;
      _openPickerLabel = rowLabel;
    });
    _pickerEntry = OverlayEntry(
      builder: (ctx) => ActionMenuOverlay(
        buttonRect: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
        isClosing: _pickerIsClosing,
        onDismiss: _dismissPickerOverlay,
        actions: items,
        panelWidth: kPickerPanelWidth,
        chevronColumn: true, // reserves checkmark column on every row
        anchorToRight: true, // right edge of panel aligns to right of row
        labelFontSize: 15, // modal-sheet mini panels use 15 px
        bouncingScroll: true, // modal-sheet mini panels retain rubberband
      ),
    );
    Overlay.of(context).insert(_pickerEntry!);
  }

  // ── Picker items factories ────────────────────────────────────────────────

  // Generic helper: maps a flat option list to ActionItems.
  // Pass [current] to mark the selected item.
  // Pass [groupBreakBefore] labels to insert a group-break separator above them.
  // Pass [checkmarkColor] to tint checkmarks with the category colour.
  List<ActionItem> _makeItems(
    List<String> options,
    String current,
    void Function(String) onSelect, {
    Set<String> groupBreakBefore = const {},
    Color? checkmarkColor,
  }) => options
      .map(
        (label) => ActionItem(
          label: label,
          icon: SFIcons.sf_circle, // suppressed below
          iconBuilder: (_) => const SizedBox.shrink(),
          checkmark: label == current,
          checkmarkColor: checkmarkColor,
          groupBreakAbove: groupBreakBefore.contains(label),
          onTap: () {
            onSelect(label);
            Future.delayed(
              const Duration(milliseconds: 80),
              _dismissPickerOverlay,
            );
          },
        ),
      )
      .toList();

  List<ActionItem> _categoryTypeItems() => _makeItems(
    ['Standard', 'Shopping List', 'Smart Category'],
    _categoryType,
    _setCategoryType,
    groupBreakBefore: {'Smart Category'},
    checkmarkColor: _resolvedSelectedColor,
  );

  void _setCategoryType(String value) {
    setState(() => _categoryType = value);
    _smartCategoryCtrl.animateTo(
      value == 'Smart Category' ? 1.0 : 0.0,
      curve: value == 'Smart Category' ? Curves.easeOut : Curves.easeIn,
    );
  }

  List<ActionItem> _travelTimeItems() => _makeItems(
    [
      'None',
      '5 minutes',
      '10 minutes',
      '15 minutes',
      '30 minutes',
      '1 hour',
      '1 hour, 30 minutes',
      '2 hours',
    ],
    _travelTime,
    _setTravelTime,
    groupBreakBefore: {'5 minutes'},
    checkmarkColor: _resolvedSelectedColor,
  );

  List<ActionItem> _travelModeItems() => _makeItems(
    ['None', 'Motorcycle', 'Car', 'Walking', 'Transit', 'Cycling'],
    _travelMode,
    (v) => setState(() => _travelMode = v),
    groupBreakBefore: {'Motorcycle'},
    checkmarkColor: _resolvedSelectedColor,
  );

  List<ActionItem> _repeatItems() {
    const options = [
      'Never',
      'Every Day',
      'Every Week',
      'Every 2 Weeks',
      'Every Month',
      'Every Year',
      'Custom',
    ];
    // If _repeat is a custom sentence (not one of the standard options),
    // show 'Custom' as checked in the picker.
    final effectiveCurrent = options.contains(_repeat) ? _repeat : 'Custom';
    return _makeItems(
      options,
      effectiveCurrent,
      _setRepeat,
      groupBreakBefore: {'Custom'},
      checkmarkColor: _resolvedSelectedColor,
    );
  }

  List<ActionItem> _endRepeatItems() => _makeItems(
    ['Never', 'On Date'],
    _endRepeat,
    _setEndRepeat,
    checkmarkColor: _resolvedSelectedColor,
  );

  // ── Alert display labels (react to Travel Time) ────────────────────────────

  // When Travel Time ≠ 'None', alert labels transform to "…before travel time"
  // and "At start of travel time".  Base labels (used as state keys) never change.
  String _alertDisplayLabel(String base) {
    if (_travelTime == 'None' || base == 'None') return base;
    if (base == 'At time of event') return 'At start of travel time';
    // 'X before' → 'X before travel time'
    return '$base travel time';
  }

  // Alert-specific items builder: displays transformed labels while storing
  // base labels in state so the _kAlertMinutes map always resolves correctly.
  List<ActionItem> _buildAlertActionItems(
    List<String> visibleBase,
    String current,
    void Function(String base) onSelect, {
    Set<String> groupBreakBefore = const {},
    Color? checkmarkColor,
  }) => visibleBase
      .map(
        (base) => ActionItem(
          label: _alertDisplayLabel(base),
          icon: SFIcons.sf_circle,
          iconBuilder: (_) => const SizedBox.shrink(),
          checkmark: base == current,
          checkmarkColor: checkmarkColor,
          groupBreakAbove: groupBreakBefore.contains(base),
          onTap: () {
            onSelect(base);
            Future.delayed(
              const Duration(milliseconds: 80),
              _dismissPickerOverlay,
            );
          },
        ),
      )
      .toList();

  static const _kAlertAllBase = [
    'None',
    'At time of event',
    '5 minutes before',
    '10 minutes before',
    '15 minutes before',
    '30 minutes before',
    '1 hour before',
    '1 hour, 30 minutes before',
    '2 hours before',
    '1 day before',
    '2 days before',
    '1 week before',
  ];

  List<ActionItem> _alertItems() => _buildAlertActionItems(
    _kAlertAllBase,
    _alert,
    (base) {
      // When alert moves to a tighter time, auto-reset second alert if it
      // would now equal or precede the primary (second must be STRICTLY closer).
      final alertMins = _kAlertMinutes[base] ?? -1;
      final secondMins = _kAlertMinutes[_secondAlert] ?? -1;
      setState(() {
        _alert = base;
        if (base == 'None') {
          // Alert dismissed — reset Second Alert to its default so it starts
          // fresh whenever the card becomes visible again.
          _secondAlert = 'None';
        } else if (alertMins != -1 &&
            secondMins != -1 &&
            secondMins >= alertMins) {
          // Auto-adjust Second Alert to the largest option still strictly
          // closer to the event than the new Alert (not None if avoidable).
          String best = 'None';
          int bestMins = -1;
          for (final entry in _kAlertMinutes.entries) {
            final m = entry.value;
            if (m >= 0 && m < alertMins && m > bestMins) {
              bestMins = m;
              best = entry.key;
            }
          }
          _secondAlert = best;
        }
      });
      // Show / hide Second Alert card based on whether Alert is 'None'.
      if (base == 'None') {
        _secondAlertCtrl.animateTo(0.0, curve: Curves.easeIn);
      } else {
        _secondAlertCtrl.animateTo(1.0, curve: Curves.easeOut);
      }
    },
    groupBreakBefore: {'At time of event'},
    checkmarkColor: _resolvedSelectedColor,
  );

  // Second Alert: only options STRICTLY CLOSER to the event than _alert.
  // The same option as Alert is excluded ("it shouldn't be on Second Alert").
  // 'None' (−1) is always included. When Alert = 'None', no restriction.
  List<ActionItem> _secondAlertItems() {
    final alertMins = _kAlertMinutes[_alert] ?? -1;
    final visible = _kAlertAllBase.where((base) {
      final mins = _kAlertMinutes[base] ?? -1;
      return mins == -1 || alertMins == -1 || mins < alertMins;
    }).toList();
    return _buildAlertActionItems(
      visible,
      _secondAlert,
      (base) => setState(() => _secondAlert = base),
      groupBreakBefore: {'At time of event'},
      checkmarkColor: _resolvedSelectedColor,
    );
  }

  void _save() {
    if (_isSmart) {
      widget.onSaveColor?.call(_selectedColor);
      Navigator.of(context).pop();
      return;
    }
    final name = _titleCtrl.text.trim();
    if (name.isEmpty) return;
    // ── Serialise preset repeat end date ──────────────────────────────────
    String? presetRepeatEndDateStr;
    if (_repeat != 'Never' && _endRepeat == 'On Date') {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      presetRepeatEndDateStr =
          '${months[_endDate.month - 1]} ${_endDate.day}, ${_endDate.year}';
    }

    // ── Serialise custom repeat config ────────────────────────────────────
    Map<String, dynamic>? presetCustomRepeatCfg;
    if (_savedCustomConfig != null) {
      final c = _savedCustomConfig!;
      presetCustomRepeatCfg = {
        'frequency': c.frequency,
        'everyCount': c.everyCount,
        'selectedDays': c.selectedDays.toList(),
        'monthlyMode': c.monthlyMode,
        'selectedDates': c.selectedDates.toList(),
        'onThePositionIndex': c.onThePositionIndex,
        'onTheDayIndex': c.onTheDayIndex,
        'selectedMonths': c.selectedMonths.toList(),
        'yearlyDaysEnabled': c.yearlyDaysEnabled,
        'yearlyPositionIndex': c.yearlyPositionIndex,
        'yearlyDayIndex': c.yearlyDayIndex,
      };
    }

    widget.onSave?.call(
      _UserCategory(
        // Preserve the existing ID on edit; generate a fresh timestamped one
        // for brand-new categories.  IDs are never changed after first save.
        id:
            widget.initial?.id ??
            'usr-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: _descCtrl.text.trim(),
        smartDescription: _categoryType == 'Smart Category'
            ? _smartDescriptionCtrl.text.trim()
            : '',
        count: widget.initial?.count ?? 0,
        color: _selectedColor,
        icon: _selectedIcon is IconData
            ? _selectedIcon as IconData
            : SFIcons.sf_list_bullet,
        svgAsset: _selectedIcon is String ? _selectedIcon as String : null,
        categoryType: _categoryType,
        presetLocation: _startLocCtrl.text.trim().isEmpty
            ? null
            : _startLocCtrl.text.trim(),
        presetDestination: _destCtrl.text.trim().isEmpty
            ? null
            : _destCtrl.text.trim(),
        presetTravelTime: _travelTime == 'None' ? null : _travelTime,
        presetTravelMode: _travelMode == 'None' ? null : _travelMode,
        presetRepeat: _repeat == 'Never' ? null : _repeat,
        presetRepeatEndType: (_repeat != 'Never' && _endRepeat != 'Never')
            ? _endRepeat
            : null,
        presetRepeatEndDate: presetRepeatEndDateStr,
        presetCustomRepeatConfig: presetCustomRepeatCfg,
        presetAlert: _alert == 'None' ? null : _alert,
        presetSecondAlert: _secondAlert == 'None' ? null : _secondAlert,
      ),
    );
    Navigator.of(context).pop();
  }

  // Mirrors _CategoryTile._buildIconContent, scaled up 2x (32px tile circle
  // → 64px sheet circle) including the day-number overlay for the four
  // calendar-type tiles (Today/Tomorrow/This Week/Next Week).
  Widget _smartPreviewIcon(_TileData data) {
    const white = CupertinoColors.white;
    final icon = data.isCalendar
        ? SizedBox(
            width: 38,
            height: 38,
            child: SvgPicture.asset(
              'assets/icons/calendar_frame.svg',
              colorFilter: const ColorFilter.mode(
                Color(0xFFFFFFFF),
                BlendMode.srcIn,
              ),
            ),
          )
        : (data.icon! == SFIcons.sf_music_note
              ? _BeamedNoteIcon(size: 38, color: white)
              : Icon(data.icon!, color: white, size: 38));

    if (data.day == null) return icon;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Center(child: icon),
        Positioned(
          top: 28,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.scale(
              scale: 1.05,
              scaleY: 1.3,
              child: Text(
                '${data.day}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  inherit: false,
                  color: Color(0xFFFFFFFF),
                  fontSize: 18,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.normal,
                  height: 1.0,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openMaps(String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${Uri.encodeComponent(query.isEmpty ? 'location' : query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── text styles ───────────────────────────────────────────────────────────

  TextStyle get _kFieldStyle => TextStyle(
    inherit: false,
    color: resolveThemeColor(kPrimaryLabel, context),
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  TextStyle get _kPlaceholderStyle => TextStyle(
    inherit: false,
    color: resolveThemeColor(kTertiaryLabel, context),
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  TextStyle get _kRowLabelStyle => TextStyle(
    inherit: false,
    color: resolveThemeColor(kPrimaryLabel, context),
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  TextStyle get _kRowValueStyle => TextStyle(
    inherit: false,
    color: resolveThemeColor(kSecondaryLabel, context),
    fontSize: 15,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  // ── card helpers ──────────────────────────────────────────────────────────

  Widget _card(List<Widget> rows, {bool stadium = false}) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    final ShapeBorder shape = stadium
        ? const AdaptiveStadiumBorder()
        : BoundedContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(kCardCornerRadius),
          );
    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: shape,
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  // Hairline separator used between rows inside a card.
  Widget _sep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      height: 0.5,
      color: resolveThemeColor(kSeparatorColor, context),
    ),
  );

  // Row displaying a label on the left and a read-only value + up/down
  // chevron on the right.  All picker rows share this layout.
  //
  // When [items] is non-null the entire row (including the label) is tappable
  // and opens a mini ActionPanel positioned above / below the row.
  // The panel width is [kPickerPanelWidth] — a shared constant so the same
  // width can be reused wherever this pattern appears elsewhere in the app.
  // [leading] — optional widget prepended before the label (e.g. the colored
  // rounded-square icon in the Category Type row).  When present a 12 px gap
  // separates it from the label text.
  Widget _pickerRow(
    String label,
    String value, {
    List<ActionItem>? items,
    Widget? leading,
    double verticalPadding = 14,
  }) {
    // Whether THIS row's panel is currently open (or closing).
    final isOpen = items != null && _openPickerLabel == label;
    // Keep the value/chevron in a fixed trailing slot so every modal-sheet
    // picker row shares the same right edge.
    final dimmedValue = AnimatedOpacity(
      opacity: isOpen ? kPickerRowOpenDimOpacity : 1.0,
      duration: const Duration(milliseconds: 150),
      child: ModalSheetPickerTrailing(
        value: value,
        style: _kRowValueStyle,
        chevronColor: resolveThemeColor(kSecondaryLabel, context),
      ),
    );
    return Builder(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: items != null
            ? () => _showPickerOverlay(ctx, label, items)
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: verticalPadding,
          ),
          child: MinGapLabelValueRow(
            label: label,
            labelStyle: _kRowLabelStyle,
            value: value,
            valueStyle: _kRowValueStyle,
            trailing: dimmedValue,
            leading: leading,
            leadingWidth: leading == null ? 0 : 28,
            trailingExtraWidth: 16,
          ),
        ),
      ),
    );
  }

  // ── Card 1: Identity ──────────────────────────────────────────────────────

  Widget _buildIdentityCard() {
    final previewColor = _isEmojiIcon(_effectiveIcon)
        ? _emojiCircleColor(_resolvedSelectedColor)
        : _resolvedSelectedColor;

    return _card([
      // Static blue circle icon centred above the fields.
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 16),
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: previewColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: previewColor.withOpacity(0.32),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: Offset.zero,
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Emoji circles use only their flat white-blended swatch.
                  // Keep the add-blend highlight for the existing non-emoji
                  // preview treatment.
                  if (!_isEmojiIcon(_effectiveIcon))
                    CustomPaint(
                      painter: _CircleAddHighlightPainter(previewColor),
                    ),
                  Center(
                    child: _isSmart
                        ? _smartPreviewIcon(widget.smartData!)
                        : _renderCatIcon(
                            _effectiveIcon,
                            64,
                            CupertinoColors.white,
                            emojiOffsetY: 2,
                            ctx: context,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      _sep(),
      // Category title — centred on the screen.
      //
      // Layout: Stack with CupertinoTextField (37 px horizontal padding on each
      // side) + Positioned clear button overlay on the right.  Equal padding on
      // both sides keeps TextAlign.center anchored to the true screen centre
      // whether or not the clear button is visible, without using the built-in
      // prefix/suffix slots which interfere with text-selection gesture handling.
      CupertinoTheme(
        data: CupertinoTheme.of(
          context,
        ).copyWith(primaryColor: _resolvedSelectedColor),
        child: DefaultSelectionStyle(
          selectionColor: _resolvedSelectedColor.withOpacity(0.20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CupertinoTextField(
                controller: _titleCtrl,
                focusNode: _titleFocus,
                readOnly: _isSmart,
                showCursor: !_isSmart,
                // New Category (not Edit, not a smart tile) opens with the
                // keyboard already up and focused here.
                autofocus: !_isSmart && widget.initial == null,
                // selectionControls uses a captured colour so handles update live
                // when the user changes the category swatch.
                selectionControls: _selectionControls,
                // No contextMenuBuilder here: _TintedCupertinoTextSelectionControls
                // inherits CupertinoTextSelectionControls.buildToolbar, which always
                // renders the full Cupertino floating-bubble toolbar (Select All,
                // Look Up, Share, etc.) regardless of platform — matching the Notes
                // tab and every other CupertinoTextField in the app.
                placeholder: 'Category Title',
                placeholderStyle: _kPlaceholderStyle,
                style: _isSmart
                    ? _kFieldStyle.copyWith(
                        color: resolveThemeColor(kSecondaryLabel, context),
                      )
                    : _titleCtrl.text.isNotEmpty
                    ? _kFieldStyle.copyWith(
                        color: _resolvedSelectedColor,
                        fontWeight: FontWeight.w600,
                      )
                    : _kFieldStyle,
                textAlign: TextAlign.center,
                cursorColor: _resolvedSelectedColor,
                // 37 px on each side keeps text centred; no prefix/suffix slots.
                padding: const EdgeInsets.symmetric(
                  horizontal: 37,
                  vertical: 14,
                ),
                clearButtonMode: OverlayVisibilityMode.never,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: null,
                textInputAction: TextInputAction.next,
              ),
              // Clear button — Positioned overlay so it never enters the text
              // field's internal layout and cannot block selection gestures.
              if (!_isSmart)
                AnimatedBuilder(
                  animation: _titleCtrl,
                  builder: (_, __) {
                    if (_titleCtrl.text.isEmpty) return const SizedBox.shrink();
                    return Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _titleCtrl.clear();
                          setState(() {});
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(left: 7, right: 12),
                          child: Icon(
                            kSearchClearCircleIcon,
                            color: kEmptyStateIcon,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ), // CupertinoTextField stack + DefaultSelectionStyle + CupertinoTheme
      _sep(),
      // Description — same Stack-based layout as the title field above.
      CupertinoTheme(
        data: CupertinoTheme.of(
          context,
        ).copyWith(primaryColor: _resolvedSelectedColor),
        child: DefaultSelectionStyle(
          selectionColor: _resolvedSelectedColor.withOpacity(0.20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CupertinoTextField(
                controller: _descCtrl,
                focusNode: _descFocus,
                scrollController: _descScrollCtrl,
                readOnly: _isSmart,
                showCursor: !_isSmart,
                selectionControls: _selectionControls,
                placeholder: 'Subtitle',
                placeholderStyle: _kPlaceholderStyle,
                style: _isSmart
                    ? _kFieldStyle.copyWith(
                        color: resolveThemeColor(kSecondaryLabel, context),
                      )
                    : _kFieldStyle,
                textAlign: TextAlign.center,
                cursorColor: _resolvedSelectedColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 37,
                  vertical: 14,
                ),
                clearButtonMode: OverlayVisibilityMode.never,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: null,
                textInputAction: TextInputAction.done,
              ),
              if (!_isSmart)
                AnimatedBuilder(
                  animation: _descCtrl,
                  builder: (_, __) {
                    if (_descCtrl.text.isEmpty) return const SizedBox.shrink();
                    return Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _descCtrl.clear();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_descScrollCtrl.hasClients)
                              _descScrollCtrl.jumpTo(0);
                          });
                          setState(() {});
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(left: 7, right: 12),
                          child: Icon(
                            kSearchClearCircleIcon,
                            color: kEmptyStateIcon,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ), // CupertinoTextField stack + DefaultSelectionStyle + CupertinoTheme
    ]);
  }

  // ── Card 2: Category Type ─────────────────────────────────────────────────

  Widget _buildCategoryTypeCard() {
    // Rounded-square icon — 28 px, fixed per category type (never reflects user icon).
    final IconData _typeIcon;
    if (_categoryType == 'Shopping List') {
      _typeIcon = SFIcons.sf_carrot_fill;
    } else if (_categoryType == 'Smart Category') {
      _typeIcon = SFIcons.sf_line_3_horizontal_decrease_circle_fill;
    } else {
      _typeIcon = SFIcons.sf_list_bullet;
    }
    const double _iconSq = 28;
    final leadingIcon = Container(
      width: _iconSq,
      height: _iconSq,
      decoration: BoxDecoration(
        color: _resolvedSelectedColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: FixedSFIcon(
          _typeIcon,
          fontSize: _categoryType == 'Smart Category' ? 17.5 : 14.5,
          color: CupertinoColors.white,
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _smartCategoryCtrl,
      builder: (context, child) => _card([
        child!,
        SizeTransition(
          sizeFactor: _smartCategoryCtrl,
          axisAlignment: 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_sep(), _buildSmartDescriptionRow()],
          ),
        ),
      ], stadium: _smartCategoryCtrl.value == 0.0),
      child: _pickerRow(
        'Category Type',
        _categoryType,
        items: _categoryTypeItems(),
        leading: leadingIcon,
        // The icon is 28 px tall; 10 px inset on each side gives this row
        // the same 48 px height as the text-only picker rows.
        verticalPadding: 10,
      ),
    );
  }

  Widget _buildSmartDescriptionRow() => LayoutBuilder(
    builder: (context, constraints) {
      // Measure against the actual field width inside the row.  The previous
      // screen-width estimate omitted the 16/12 row insets, the 10 px gap,
      // and the 28 px action button, so wrapped text was under-measured at
      // larger Dynamic Type sizes and could run into the card's end curves.
      final scaler = MediaQuery.textScalerOf(context);
      final inputWidth = max(
        80.0,
        constraints.maxWidth - 16.0 - 12.0 - 10.0 - 28.0,
      );
      final ruleText = _smartDescriptionCtrl.text.isEmpty
          ? 'Describe what belongs here…'
          : _smartDescriptionCtrl.text;
      final contentHeight = _eventsMeasuredTextHeight(
        ruleText,
        _kPlaceholderStyle,
        scaler,
        inputWidth,
      );
      // Keep the authored 48 px row at normal/compact sizes, but let both
      // Dynamic Type and the entered rule text grow the row naturally.
      final rowHeight = max(48.0, contentHeight + 20.0);
      // Dynamic Type can make the empty placeholder two lines while the first
      // entered character measures as one. Animate that height change so the
      // rule row and its trailing action settle instead of snapping.
      return AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: rowHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: rowHeight,
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        // Keep the placeholder in the same top-aligned position
                        // as entered rule text. CupertinoTextField's built-in
                        // placeholder is vertically centred when expands is true,
                        // which pushes wrapped Dynamic Type text down and clips
                        // its second line.
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _smartDescriptionCtrl,
                            _smartDescriptionFocus,
                          ]),
                          builder: (_, __) {
                            if (_smartDescriptionCtrl.text.isNotEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Positioned.fill(
                              child: IgnorePointer(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                      transform: Matrix4.translationValues(
                                        _smartDescriptionFocus.hasFocus
                                            ? 4.0
                                            : 0.0,
                                        0,
                                        0,
                                      ),
                                      child: Text(
                                        'Describe what belongs here…',
                                        style: _kPlaceholderStyle,
                                        softWrap: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        CupertinoTheme(
                          data: CupertinoTheme.of(
                            context,
                          ).copyWith(primaryColor: _resolvedSelectedColor),
                          child: DefaultSelectionStyle(
                            selectionColor: _resolvedSelectedColor.withOpacity(
                              0.20,
                            ),
                            child: CupertinoTextField(
                              controller: _smartDescriptionCtrl,
                              focusNode: _smartDescriptionFocus,
                              // The animated overlay above is the only
                              // placeholder, so it can stay top-aligned and
                              // animate with focus.
                              placeholder: '',
                              placeholderStyle: _kPlaceholderStyle,
                              style: _kFieldStyle,
                              cursorColor: _resolvedSelectedColor,
                              selectionControls: _selectionControls,
                              expands: true,
                              maxLines: null,
                              minLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: null,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(
                                () => _smartDescriptionSaved = false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Crossfades between the save-checkmark (typing / unsaved) and the
                // clear-circle (rule saved), giving clear visual differentiation
                // between the two states.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _smartDescriptionSaved
                      ? GestureDetector(
                          key: const ValueKey('smartdesc-clear'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _smartDescriptionCtrl.clear();
                            _smartDescriptionFocus.requestFocus();
                            setState(() => _smartDescriptionSaved = false);
                          },
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: Icon(
                                kSearchClearCircleIcon,
                                color: kEmptyStateIcon,
                                size: 17,
                              ),
                            ),
                          ),
                        )
                      : GelBloomButton(
                          key: const ValueKey('smartdesc-checkmark'),
                          peakScale: 1.14,
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _smartDescriptionSaved = true);
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _smartDescriptionCtrl.text.trim().isEmpty
                                  ? kTertiaryLabel
                                  : _resolvedSelectedColor,
                              shape: BoxShape.circle,
                              boxShadow: resolveThemeShadows(const [
                                BoxShadow(
                                  color: Color(0x1F000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ], context),
                            ),
                            child: Center(
                              child: Transform.translate(
                                offset: const Offset(-0.5, -0.5),
                                child: SearchWeightedIcon(
                                  SFIcons.sf_checkmark,
                                  size: 13,
                                  color: CupertinoColors.white,
                                  weight: kGelBloomIconWeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  // ── Card 3: Location / Travel ─────────────────────────────────────────────

  Widget _locationRow(
    TextEditingController ctrl,
    String hint,
    FocusNode focusNode,
  ) => Row(
    children: [
      Expanded(
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Animated placeholder: slides 4 px right on focus, matching the
            // NativeTextInput behaviour used everywhere else in the app.
            AnimatedBuilder(
              animation: Listenable.merge([ctrl, focusNode]),
              builder: (_, __) {
                if (ctrl.text.isNotEmpty) return const SizedBox.shrink();
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          transform: Matrix4.translationValues(
                            focusNode.hasFocus ? 4.0 : 0.0,
                            0,
                            0,
                          ),
                          child: Text(hint, style: _kPlaceholderStyle),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // The actual text field with an empty placeholder string so our
            // animated overlay above is the only placeholder the user sees.
            CupertinoTheme(
              data: CupertinoTheme.of(
                context,
              ).copyWith(primaryColor: _resolvedSelectedColor),
              child: DefaultSelectionStyle(
                selectionColor: _resolvedSelectedColor.withOpacity(0.20),
                child: CupertinoTextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  placeholder: '',
                  placeholderStyle: _kPlaceholderStyle,
                  style: _kFieldStyle,
                  cursorColor: _resolvedSelectedColor,
                  selectionControls: _selectionControls,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  clearButtonMode: OverlayVisibilityMode.never,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: null,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ), // CupertinoTextField + DefaultSelectionStyle + CupertinoTheme
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 12),
        child: _buildLocationTrailingAction(ctrl),
      ),
    ],
  );

  /// The location action uses a true fade-through: the map-pin circle and
  /// clear button overlap while one fades out and the other fades in.
  Widget _buildLocationTrailingAction(TextEditingController ctrl) {
    final hasText = ctrl.text.isNotEmpty;
    return SizedBox(
      width: 28,
      height: 28,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.centerRight,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: hasText
            ? SizedBox(
                key: const ValueKey('location-clear'),
                width: 28,
                height: 28,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ctrl.clear();
                    setState(() {});
                  },
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: Icon(
                        kSearchClearCircleIcon,
                        color: kEmptyStateIcon,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              )
            : SizedBox(
                key: const ValueKey('location-pin'),
                width: 28,
                height: 28,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openMaps(ctrl.text),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _resolvedSelectedColor,
                      shape: BoxShape.circle,
                    ),
                    child: _renderCatIcon(
                      SFIcons.sf_mappin,
                      28,
                      CupertinoColors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // Variant of _card that accepts an explicit BorderRadius — used to animate
  // the connecting corners of cascading card groups as children slide in/out.
  Widget _cardWithRadius(
    List<Widget> rows,
    BorderRadius radius, {
    bool stadium = false,
  }) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: stadium
            ? const SquircleStadiumBorder()
            : BoundedContinuousRectangleBorder(borderRadius: radius),
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  // ── Cascading-card state helpers ──────────────────────────────────────────

  void _setTravelTime(String v) {
    setState(() {
      _travelTime = v;
      // Reset Travel Mode to default so the subcard re-opens fresh next time.
      if (v == 'None') _travelMode = 'None';
    });
    if (v == 'None') {
      _travelModeCtrl.animateTo(0.0, curve: Curves.easeIn);
    } else {
      _travelModeCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  Future<void> _setRepeat(String v) async {
    if (v == 'Custom') {
      final result = await showRoundedCupertinoSheet<_CustomRepeatResult?>(
        context: context,
        pageBuilder: (ctx) => _CustomRepeatSheet(
          accentColor: _resolvedSelectedColor,
          config: _savedCustomConfig,
        ),
      );
      if (result != null && mounted) {
        setState(() {
          _repeat = result.label;
          _savedCustomConfig = result.config;
        });
        _endRepeatCtrl.animateTo(1.0, curve: Curves.easeOut);
      }
      return;
    }
    // Any standard option clears the saved custom config.
    _savedCustomConfig = null;
    if (v == 'Never') {
      // Reset all downstream subcard state to defaults so they re-open fresh.
      final now = DateTime.now();
      setState(() {
        _repeat = v;
        _endRepeat = 'Never';
        _endDate = DateTime(now.year, now.month + 1, now.day);
        _calendarMonth = DateTime(now.year, now.month + 1);
        _calendarBarrelMode = false;
        _calendarDragOffset = 0.0;
      });
      _endRepeatCtrl.animateTo(0.0, curve: Curves.easeIn);
      _endDateCtrl.animateTo(0.0, curve: Curves.easeIn);
      _datePickerCtrl.animateTo(0.0, curve: Curves.easeIn);
    } else {
      setState(() => _repeat = v);
      _endRepeatCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  void _setEndRepeat(String v) {
    if (v == 'Never') {
      // Reset End Date state to default so the subcard re-opens fresh.
      final now = DateTime.now();
      setState(() {
        _endRepeat = v;
        _endDate = DateTime(now.year, now.month + 1, now.day);
        _calendarMonth = DateTime(now.year, now.month + 1);
        _calendarBarrelMode = false;
      });
      _endDateCtrl.animateTo(0.0, curve: Curves.easeIn);
      _datePickerCtrl.animateTo(0.0, curve: Curves.easeIn);
    } else {
      setState(() => _endRepeat = v);
      _endDateCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  void _toggleDatePicker() {
    if (_datePickerCtrl.value > 0.5) {
      _datePickerCtrl.animateTo(0.0, curve: Curves.easeIn);
    } else {
      _datePickerCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  // ── Month-slide animation helpers ─────────────────────────────────────────

  // Listener fired by _monthSlideCtrl every frame — drives _calendarDragOffset
  // so the three-panel layout responds to both live drag and programmatic slide.
  void _onMonthSlideUpdate() {
    if (_monthSlideTween == null) return;
    final t = Curves.easeInOut.transform(_monthSlideCtrl.value);
    setState(() {
      _calendarDragOffset =
          _monthSlideTween!.begin! +
          (_monthSlideTween!.end! - _monthSlideTween!.begin!) * t;
    });
  }

  // Animates the offset to ±_calPanelWidth then commits the month change.
  void _commitMonthSlide({required bool next}) {
    if (_monthSlideTween != null) return; // already sliding
    final target = next ? -_calPanelWidth : _calPanelWidth;
    _monthSlideTween = Tween<double>(begin: _calendarDragOffset, end: target);
    _monthSlideCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _calendarMonth = next
            ? DateTime(_calendarMonth.year, _calendarMonth.month + 1)
            : DateTime(_calendarMonth.year, _calendarMonth.month - 1);
        _calendarDragOffset = 0;
        _monthSlideTween = null;
      });
      _monthSlideCtrl.reset();
    });
  }

  // Animates the offset back to 0 without changing the month.
  void _snapBackMonthSlide() {
    _monthSlideTween = Tween<double>(begin: _calendarDragOffset, end: 0);
    _monthSlideCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _calendarDragOffset = 0;
        _monthSlideTween = null;
      });
      _monthSlideCtrl.reset();
    });
  }

  void _prevCalMonth() => _commitMonthSlide(next: false);
  void _nextCalMonth() => _commitMonthSlide(next: true);

  // Toggles between month-grid and CupertinoDatePicker barrel mode.
  void _toggleBarrelMode() {
    setState(() => _calendarBarrelMode = !_calendarBarrelMode);
  }

  static const _kMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  String _formatEndDate(DateTime d) =>
      '${_kMonthNames[d.month - 1]} ${d.day}, ${d.year}';

  Widget _buildEndDateRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: AdaptiveLabelPillRow(
      label: 'End Date',
      labelStyle: _kRowLabelStyle,
      onLabelTap: _toggleDatePicker,
      pills: [
        AdaptivePillSpec(
          text: _formatEndDate(_endDate),
          compactText:
              '${_kMonthNames[_endDate.month - 1].substring(0, 3)} '
              '${_endDate.day}, ${_endDate.year}',
          backgroundColor: resolveThemeColor(kPillColor, context),
          style: TextStyle(
            inherit: false,
            // Accent while picker is open, primary when closed.
            // Safe to read _datePickerCtrl.value because this method is
            // called inside AnimatedBuilder(animation: _datePickerCtrl).
            color: _datePickerCtrl.value > 0
                ? _resolvedSelectedColor
                : resolveThemeColor(kPrimaryLabel, context),
            fontSize: 15,
            fontFamily: kSFProText,
            fontWeight: FontWeight.w500,
            letterSpacing: kTracking17,
          ),
          onTap: _toggleDatePicker,
        ),
      ],
    ),
  );

  // Month-view calendar used in the inline End Date picker.
  // Mon-first 3-letter DOW labels for the inline month picker.
  static const _kDayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // ── Month-grid cell builder ───────────────────────────────────────────────
  // Extracted so AnimatedSwitcher can key on it without keying a closure.
  Widget _buildMonthGrid({
    required int year,
    required int month,
    required DateTime today,
  }) {
    // Monday-first offset: Mon=weekday 1→offset 0, Sun=weekday 7→offset 6
    final startOffset = DateTime(year, month, 1).weekday - 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final isSelectedMonth = _endDate.year == year && _endDate.month == month;
    final isCurrentMonth = today.year == year && today.month == month;

    // Category color at 40% for today indicator — mirrors Calendar tab.
    final Color todayFill = _resolvedSelectedColor.withOpacity(0.40);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Always 6 rows so height is stable across months (no layout jump).
        children: List.generate(
          6,
          (row) => Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 38));
              }
              final selected = isSelectedMonth && _endDate.day == day;
              final isToday = isCurrentMonth && today.day == day;
              // A date is in the past if it's strictly before today's date.
              final isPast = DateTime(
                year,
                month,
                day,
              ).isBefore(DateTime(today.year, today.month, today.day));

              final Widget circle;
              if (selected) {
                circle = Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _resolvedSelectedColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w600,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else if (isToday) {
                circle = Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: todayFill,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w500,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else if (isPast) {
                // Past dates: greyed out, unselectable.
                circle = Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: resolveThemeColor(kTertiaryLabel, context),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w400,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else {
                circle = Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: resolveThemeColor(kPrimaryLabel, context),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w400,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              }

              // Past dates: render non-interactively (no bloom, no tap).
              if (isPast) {
                return Expanded(
                  child: SizedBox(height: 38, child: Center(child: circle)),
                );
              }

              // GelBloom wraps the full cell tap area; Transform.scale doesn't
              // affect layout so the 38 px row height stays stable.
              // Tapping a date selects it and closes the date picker.
              return Expanded(
                child: GelBloomButton(
                  onTap: () {
                    setState(() => _endDate = DateTime(year, month, day));
                    _datePickerCtrl.animateTo(0.0, curve: Curves.easeIn);
                  },
                  peakScale: 1.15,
                  child: SizedBox(height: 38, child: Center(child: circle)),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Inline month-view / barrel date picker ────────────────────────────────

  // Header row for a single month panel.
  // All panels render the same chrome (barrel-toggle chevron + nav arrows) so
  // that nothing "pops in" when an adjacent panel slides into the center slot.
  // isCenter controls interactivity only — taps are a no-op on adjacent panels
  // (and IgnorePointer on the adjacent SizedBox blocks them anyway).
  Widget _buildMonthPanelHeader(
    DateTime month,
    DateTime today, {
    required bool isCenter,
  }) {
    final isCurrent = month.year == today.year && month.month == today.month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isCenter ? _toggleBarrelMode : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_kMonthNames[month.month - 1]} ${month.year}',
                  style: TextStyle(
                    inherit: false,
                    color: isCurrent
                        ? _resolvedSelectedColor
                        : resolveThemeColor(kPrimaryLabel, context),
                    fontSize: 16,
                    fontFamily: kSFProText,
                    fontWeight: FontWeight.w600,
                    letterSpacing: kTracking17,
                  ),
                ),
                const SizedBox(width: 5),
                // Barrel-toggle chevron — always rendered on every panel so
                // it is already visible when an adjacent panel lands center.
                AnimatedRotation(
                  turns: _calendarBarrelMode ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: _resolvedSelectedColor,
                    shadows: resolveThemeTextShadows([
                      Shadow(color: _resolvedSelectedColor, blurRadius: 0.8),
                    ], context),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Nav chevrons — always rendered; hidden only in barrel mode.
          // Adjacent panels have them pre-rendered so they land without pop-in.
          Visibility(
            visible: !_calendarBarrelMode,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isCenter ? _prevCalMonth : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      CupertinoIcons.chevron_left,
                      size: 16,
                      color: _resolvedSelectedColor,
                      shadows: resolveThemeTextShadows([
                        Shadow(color: _resolvedSelectedColor, blurRadius: 0.8),
                      ], context),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isCenter ? _nextCalMonth : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: _resolvedSelectedColor,
                      shadows: resolveThemeTextShadows([
                        Shadow(color: _resolvedSelectedColor, blurRadius: 0.8),
                      ], context),
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

  // Full panel: DOW labels + month grid (header is always rendered above).
  // showHeader is kept for the adjacent panels which still need their own
  // header so that nothing pops in when they slide into the centre slot;
  // for the centre slot the persistent top header is used instead.
  Widget _buildMonthPanel(
    DateTime month,
    DateTime today, {
    required bool isCenter,
    bool showHeader = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader)
          _buildMonthPanelHeader(month, today, isCenter: isCenter),
        // DOW labels row (Mon first, 3-letter).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _kDayLabels
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          inherit: false,
                          color: resolveThemeColor(kSecondaryLabel, context),
                          fontSize: 11,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w500,
                          letterSpacing: kTracking17,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 2),
        _buildMonthGrid(year: month.year, month: month.month, today: today),
      ],
    );
  }

  Widget _buildInlineMonthPicker() {
    final today = DateTime.now();
    final prevMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
    final nextMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Persistent header ─────────────────────────────────────────────
          // Rendered once, outside the barrel/month switch, so the title and
          // chevron never shift or jump when the user toggles between modes.
          _buildMonthPanelHeader(_calendarMonth, today, isCenter: true),
          // ── Body — animates between barrel picker and sliding month grid ──
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _calendarBarrelMode
                // ── CupertinoDatePicker barrel ────────────────────────────
                ? SizedBox(
                    height: cupertinoDatePickerHeight(context),
                    child: CupertinoTheme(
                      data: CupertinoTheme.of(context).copyWith(
                        primaryColor: _resolvedSelectedColor,
                        textTheme: CupertinoTheme.of(context).textTheme
                            .copyWith(
                              dateTimePickerTextStyle: TextStyle(
                                inherit: false,
                                fontFamily: kSFProText,
                                fontSize: cupertinoDatePickerFontSize(context),
                                color: resolveThemeColor(
                                  kPrimaryLabel,
                                  context,
                                ),
                                letterSpacing: kTracking17,
                              ),
                            ),
                      ),
                      child: CupertinoDatePicker(
                        itemExtent: cupertinoDatePickerItemExtent(context),
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _endDate,
                        minimumDate: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                        onDateTimeChanged: (dt) => setState(() {
                          _endDate = dt;
                          _calendarMonth = DateTime(dt.year, dt.month);
                        }),
                      ),
                    ),
                  )
                // ── 3-panel sliding month grid ────────────────────────────
                // Prev / current / next panels sit side-by-side. Each panel
                // shows its own header so nothing pops in when it lands as
                // centre; the centre slot also has the persistent header above
                // so it skips rendering one via showHeader: false.
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) {
                      if (_monthSlideTween != null) return;
                      setState(() => _calendarDragOffset = 0.0);
                    },
                    onHorizontalDragUpdate: (d) {
                      if (_monthSlideTween != null) return;
                      setState(() => _calendarDragOffset += d.delta.dx);
                    },
                    onHorizontalDragEnd: (d) {
                      if (_monthSlideTween != null) return;
                      final v = d.primaryVelocity ?? 0;
                      if (v < -200 || _calendarDragOffset < -40) {
                        _commitMonthSlide(next: true);
                      } else if (v > 200 || _calendarDragOffset > 40) {
                        _commitMonthSlide(next: false);
                      } else {
                        _snapBackMonthSlide();
                      }
                    },
                    // LayoutBuilder provides the single-panel width so we can
                    // compute absolute pixel offsets for each panel.
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        _calPanelWidth = constraints.maxWidth;
                        // Stack-based approach: each panel is Transform.translate'd
                        // so it "orbits" around _calendarDragOffset without
                        // affecting layout.  Stack size = single-panel size.
                        // ClipRect hides the off-screen panels.
                        // Prev + next panels are Positioned.fill + OverflowBox so
                        // they never contribute to the Stack's intrinsic height —
                        // only the current panel does, keeping the card exactly the
                        // right height for the visible month.  ClipRect hides any
                        // vertical overflow from adjacent months with more rows.
                        return ClipRect(
                          child: Stack(
                            children: [
                              // Prev panel — out of layout flow, can overflow vertically.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: OverflowBox(
                                    alignment: Alignment.topLeft,
                                    maxHeight: double.infinity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        -_calPanelWidth + _calendarDragOffset,
                                        0,
                                      ),
                                      child: SizedBox(
                                        width: _calPanelWidth,
                                        child: _buildMonthPanel(
                                          prevMonth,
                                          today,
                                          isCenter: false,
                                          showHeader: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Next panel — same approach.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: OverflowBox(
                                    alignment: Alignment.topLeft,
                                    maxHeight: double.infinity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        _calPanelWidth + _calendarDragOffset,
                                        0,
                                      ),
                                      child: SizedBox(
                                        width: _calPanelWidth,
                                        child: _buildMonthPanel(
                                          nextMonth,
                                          today,
                                          isCenter: false,
                                          showHeader: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Current panel — non-positioned, determines Stack height.
                              // Rendered last so it paints on top of any adjacent overflow.
                              Transform.translate(
                                offset: Offset(_calendarDragOffset, 0),
                                child: SizedBox(
                                  width: _calPanelWidth,
                                  child: _buildMonthPanel(
                                    _calendarMonth,
                                    today,
                                    isCenter: true,
                                    showHeader: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ), // GestureDetector
          ), // AnimatedSize
        ], // Column children
      ), // Column
    ); // Padding
  }

  // ── Card 3: Location / Travel ─────────────────────────────────────────────

  Widget _buildLocationSection() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Location + Travel Time. Bottom radius collapses to 0 as Travel Mode
      // slides in below, then restores when Travel Mode slides away.
      AnimatedBuilder(
        animation: _travelModeCtrl,
        builder: (ctx, _) => _cardWithRadius(
          [
            _locationRow(_startLocCtrl, 'Starting Location', _startLocFocus),
            _sep(),
            _locationRow(_destCtrl, 'Destination', _destFocus),
            _sep(),
            _pickerRow('Travel Time', _travelTime, items: _travelTimeItems()),
          ],
          BorderRadius.only(
            topLeft: Radius.circular(kCardCornerRadius),
            topRight: Radius.circular(kCardCornerRadius),
            bottomLeft: Radius.circular(
              _travelModeCtrl.value > 0 ? 0.0 : kCardCornerRadius,
            ),
            bottomRight: Radius.circular(
              _travelModeCtrl.value > 0 ? 0.0 : kCardCornerRadius,
            ),
          ),
        ),
      ),
      // Travel Mode card — slides out from under Travel Time when TT ≠ 'None'.
      SizeTransition(
        sizeFactor: _travelModeCtrl,
        axisAlignment: 1.0,
        child: _cardWithRadius(
          [
            _sep(),
            _pickerRow('Travel Mode', _travelMode, items: _travelModeItems()),
          ],
          const BorderRadius.only(
            bottomLeft: Radius.circular(kCardCornerRadius),
            bottomRight: Radius.circular(kCardCornerRadius),
          ),
        ),
      ),
    ],
  );

  // ── Card 4: Repeat ────────────────────────────────────────────────────────

  Widget _buildRepeatSection() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Repeat. Bottom radius collapses as End Repeat slides in below.
      AnimatedBuilder(
        animation: _endRepeatCtrl,
        builder: (ctx, _) => _cardWithRadius(
          [_pickerRow('Repeat', _repeat, items: _repeatItems())],
          BorderRadius.only(
            topLeft: Radius.circular(kCardCornerRadius),
            topRight: Radius.circular(kCardCornerRadius),
            bottomLeft: Radius.circular(
              _endRepeatCtrl.value > 0 ? 0.0 : kCardCornerRadius,
            ),
            bottomRight: Radius.circular(
              _endRepeatCtrl.value > 0 ? 0.0 : kCardCornerRadius,
            ),
          ),
          stadium: _endRepeatCtrl.value == 0.0,
        ),
      ),
      // End Repeat card — slides in when Repeat is any 'Every…' option.
      SizeTransition(
        sizeFactor: _endRepeatCtrl,
        axisAlignment: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // End Repeat. Bottom radius collapses as End Date slides in.
            AnimatedBuilder(
              animation: _endDateCtrl,
              builder: (ctx, _) => _cardWithRadius(
                [
                  _sep(),
                  _pickerRow(
                    'End Repeat',
                    _endRepeat,
                    items: _endRepeatItems(),
                  ),
                ],
                BorderRadius.only(
                  bottomLeft: Radius.circular(
                    _endDateCtrl.value > 0 ? 0.0 : kCardCornerRadius,
                  ),
                  bottomRight: Radius.circular(
                    _endDateCtrl.value > 0 ? 0.0 : kCardCornerRadius,
                  ),
                ),
              ),
            ),
            // End Date card — slides in when End Repeat = 'On Date'.
            SizeTransition(
              sizeFactor: _endDateCtrl,
              axisAlignment: 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // End Date. Bottom radius collapses as calendar slides in.
                  AnimatedBuilder(
                    animation: _datePickerCtrl,
                    builder: (ctx, _) => _cardWithRadius(
                      [_sep(), _buildEndDateRow()],
                      BorderRadius.only(
                        bottomLeft: Radius.circular(
                          _datePickerCtrl.value > 0 ? 0.0 : kCardCornerRadius,
                        ),
                        bottomRight: Radius.circular(
                          _datePickerCtrl.value > 0 ? 0.0 : kCardCornerRadius,
                        ),
                      ),
                    ),
                  ),
                  // Inline month-view calendar — slides in when date pill tapped.
                  SizeTransition(
                    sizeFactor: _datePickerCtrl,
                    axisAlignment: 1.0,
                    child: _cardWithRadius(
                      [_sep(), _buildInlineMonthPicker()],
                      const BorderRadius.only(
                        bottomLeft: Radius.circular(kCardCornerRadius),
                        bottomRight: Radius.circular(kCardCornerRadius),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  // ── Card 5: Alerts ────────────────────────────────────────────────────────

  Widget _buildAlertsSection() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Alert. Bottom radius collapses as Second Alert slides in below.
      AnimatedBuilder(
        animation: _secondAlertCtrl,
        builder: (ctx, _) => _cardWithRadius(
          [
            _pickerRow(
              'Alert',
              _alertDisplayLabel(_alert),
              items: _alertItems(),
            ),
          ],
          BorderRadius.only(
            topLeft: Radius.circular(kCardCornerRadius),
            topRight: Radius.circular(kCardCornerRadius),
            bottomLeft: Radius.circular(
              _secondAlertCtrl.value > 0 ? 0.0 : kCardCornerRadius,
            ),
            bottomRight: Radius.circular(
              _secondAlertCtrl.value > 0 ? 0.0 : kCardCornerRadius,
            ),
          ),
          stadium: _secondAlertCtrl.value == 0.0,
        ),
      ),
      // Second Alert — slides in when Alert ≠ 'None'.
      SizeTransition(
        sizeFactor: _secondAlertCtrl,
        axisAlignment: 1.0,
        child: _cardWithRadius(
          [
            _sep(),
            _pickerRow(
              'Second Alert',
              _alertDisplayLabel(_secondAlert),
              items: _secondAlertItems(),
            ),
          ],
          const BorderRadius.only(
            bottomLeft: Radius.circular(kCardCornerRadius),
            bottomRight: Radius.circular(kCardCornerRadius),
          ),
        ),
      ),
    ],
  );

  // ── Card 6: Color picker ──────────────────────────────────────────────────

  Widget _colorSwatch(Color c) {
    // Resolve both colours to the current brightness before comparing so that
    // the ring correctly tracks the live accent even when _selectedColor is
    // still stored as kCatBlue (the default-accent sentinel value).
    final resolvedC = c is CupertinoDynamicColor
        ? CupertinoDynamicColor.resolve(c, context)
        : c;
    final selected = resolvedC.value == _resolvedSelectedColor.value;
    // Ring colour = empty-state icon colour at 50 % opacity — local only,
    // does not affect any other kEmptyStateIcon usage in the app.
    final ringColor = CupertinoDynamicColor.resolve(
      kEmptyStateIcon,
      context,
    ).withOpacity(0.50);
    return GelBloomButton(
      onTap: () {
        setState(() {
          _selectedColor = c;
          _selectedColorFollowsAccent = false;
        });
        // Push the resolved colour into the notifier so existing selection
        // handles repaint without the overlay being disposed/recreated.
        _handleColorNotifier.value = renderCategoryColor(c, context);
      },
      peakScale: 1.10,
      child: AspectRatio(
        aspectRatio: 1,
        child: selected
            // Ring sits outside the circle. Values are doubled from the
            // initial design: 1.0 outer + 4.0 ring + 4.0 gap each side.
            ? Padding(
                padding: const EdgeInsets.all(1.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 3.0),
                  ),
                  padding: const EdgeInsets.all(3.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: resolveThemeColor(c, context),
                    ),
                  ),
                ),
              )
            // Unselected: plain circle with 4.5 px breathing room.
            : Padding(
                padding: const EdgeInsets.all(4.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: resolveThemeColor(c, context),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildColorCard() => _card([
    Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        // Use explicit SizedBox gaps so every Expanded column gets equal width
        // and AspectRatio(1) produces identical circle diameters.
        children: [
          for (int col = 0; col < 6; col++) ...[
            if (col > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  _colorSwatch(_kColorOptions[col]),
                  const SizedBox(height: 8),
                  _colorSwatch(_kColorOptions[col + 6]),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  ]);

  // ── Card 7: Icon picker ───────────────────────────────────────────────────

  static const _kIconCircle = 40.0; // icon circle diameter
  static const _kIconGlyph = 20.0; // icon glyph size

  // ── Icon-grid pinch-to-resize state ───────────────────────────────────────
  // Three discrete tiers: 6 | 7 | 8 icons per row.
  // Pinch open (spread) → fewer columns; pinch close (squeeze) → more columns.
  // From an edge tier the only gesture available is the one that returns to 7.
  int _iconColumns = 7;
  bool _pinchHandled = false; // only one tier-change per gesture

  void _onIconPinchStart(ScaleStartDetails _) => _pinchHandled = false;

  void _onIconPinchUpdate(ScaleUpdateDetails d) {
    if (_pinchHandled) return;
    if (d.pointerCount < 2) return; // require a true two-finger pinch
    if (d.scale > 1.18 && _iconColumns > 6) {
      // Pinch open → zoom in → fewer per row
      setState(() => _iconColumns -= 1);
      _pinchHandled = true;
    } else if (d.scale < 0.84 && _iconColumns < 8) {
      // Pinch close → zoom out → more per row
      setState(() => _iconColumns += 1);
      _pinchHandled = true;
    }
  }

  Widget _buildIconCard() {
    const spacing = 6.0;
    const duration = Duration(milliseconds: 280);
    const curve = Curves.easeInOut;
    return RawGestureDetector(
      gestures: {
        ScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
              () => ScaleGestureRecognizer(debugOwner: this),
              (r) => r
                ..onStart = _onIconPinchStart
                ..onUpdate = _onIconPinchUpdate
                ..onEnd = (_) => _pinchHandled = false,
            ),
      },
      child: _card([
        Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cols = _iconColumns;
              final itemSize =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              final rowCount = (_kIconOptions.length / cols).ceil();
              // Height of the Stack: rows × cell + gaps between rows.
              // AnimatedContainer animates this smoothly so the card stretches
              // or shrinks without a hard jump.
              final stackH = rowCount * itemSize + (rowCount - 1) * spacing;
              return AnimatedContainer(
                duration: duration,
                curve: curve,
                height: stackH,
                // Stack + AnimatedPositioned: every icon travels from its old
                // grid slot to its new one (e.g. row-1 icon-7 flows down to
                // row-2 icon-1 when columns drop from 7 → 6).
                child: Builder(
                  builder: (context) {
                    final brightness = CupertinoTheme.brightnessOf(context);
                    final iconBackground = resolveThemeColor(
                      kPillColor,
                      context,
                    );
                    final primaryLabel = resolveThemeColor(
                      kPrimaryLabel,
                      context,
                    );
                    return Stack(
                      children: List.generate(_kIconOptions.length, (i) {
                        final icon = _kIconOptions[i];
                        // Row-1 Icon-1 is the emoji button, not a selectable icon.
                        final isEmojiTile = icon == _kEmojiLightSvg;
                        // Selected when an emoji has been chosen (emoji tile) or
                        // the icon path matches the current selection (others).
                        final selected = isEmojiTile
                            ? _isEmojiIcon(_selectedIcon)
                            : icon == _selectedIcon;

                        // Emoji tile always shows the brightness-resolved generic
                        // emoji SVG — never the picked emoji character.  Other
                        // tiles always show their own SVG / IconData.
                        final displayIcon = isEmojiTile
                            ? _resolveIconSvg(_kEmojiLightSvg, brightness)
                            : icon;

                        // Emoji tile: icon is always category colour (both modes).
                        //   Unselected → resolved pill-color container.
                        //   Selected   → 40 % category colour container.
                        // Other tiles: unselected → kPrimaryLabel icon, pill-color bg.
                        //              selected   → white icon, solid category colour bg.
                        final iconColor = isEmojiTile
                            ? _resolvedSelectedColor
                            : (selected ? CupertinoColors.white : primaryLabel);
                        final circleBg = isEmojiTile
                            ? (selected
                                  ? _resolvedSelectedColor.withOpacity(0.30)
                                  : iconBackground)
                            : (selected
                                  ? _resolvedSelectedColor
                                  : iconBackground);

                        return AnimatedPositioned(
                          key: ValueKey(i),
                          duration: duration,
                          curve: curve,
                          left: (i % cols) * (itemSize + spacing),
                          top: (i ~/ cols) * (itemSize + spacing),
                          width: itemSize,
                          height: itemSize,
                          // LayoutBuilder reads the actual animated cell width
                          // each frame so the glyph scale tracks the circle as
                          // it grows or shrinks — not just the target size.
                          child: LayoutBuilder(
                            builder: (_, cellConstraints) {
                              final glyphScale =
                                  cellConstraints.maxWidth / _kIconCircle;

                              // Selection shown via category-colour circle fill;
                              // no ring indicator anywhere in the picker grid.
                              final circle = Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: circleBg,
                                ),
                                child: Center(
                                  child: Transform.scale(
                                    scale: glyphScale,
                                    child: _buildPickerIcon(
                                      displayIcon,
                                      iconColor,
                                      ctx: context,
                                    ),
                                  ),
                                ),
                              );

                              return GelBloomButton(
                                onTap: isEmojiTile
                                    ? () => _openEmojiPicker(context)
                                    : () =>
                                          setState(() => _selectedIcon = icon),
                                peakScale: 1.12,
                                child: circle,
                              );
                            },
                          ),
                        );
                      }),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  /// Opens the [EmojiPickerSheet] as a stacked rounded sheet so the parent
  /// category sheet scales back into the sheet stack behind it.
  void _openEmojiPicker(BuildContext context) {
    showRoundedCupertinoSheet<void>(
      context: context,
      pageBuilder: (_) => EmojiPickerSheet(
        onEmojiSelected: (emoji) => setState(() => _selectedIcon = emoji),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // While a picker overlay is open, intercept the OS back gesture to
      // dismiss the picker instead of closing the sheet.
      canPop: !_pickerMenuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismissPickerOverlay();
      },
      child: CupertinoPageScaffold(
        backgroundColor: kModalBackground,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header (layout unchanged from original) ───────────────────
              SizedBox(height: _kHeaderTopShift),
              RoundedCupertinoSheetHeader(
                child: SizedBox(
                  height: _kHeaderBtnSize,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        (widget.initial != null || _isSmart)
                            ? 'Edit Category'
                            : 'New Category',
                        style: TextStyle(
                          inherit: false,
                          color: resolveThemeColor(kPrimaryLabel, context),
                          fontSize: 17,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.normal,
                          letterSpacing: kTracking17,
                          height: kLineHeight,
                        ),
                      ),
                      Positioned(
                        left: _kHeaderEdge,
                        child: _ModalCircleButton(
                          icon: CupertinoIcons.xmark,
                          iconColor: resolveThemeColor(kPrimaryLabel, context),
                          tapDelay: const Duration(milliseconds: 130),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        right: _kHeaderEdge,
                        child: _ModalCircleButton(
                          icon: CupertinoIcons.checkmark,
                          containerColor: _titleCtrl.text.trim().isEmpty
                              ? kTertiaryLabel
                              : _resolvedSelectedColor,
                          iconColor: CupertinoColors.white,
                          tapDelay: const Duration(milliseconds: 130),
                          onTap: _titleCtrl.text.trim().isEmpty ? () {} : _save,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom breathing room for the sticky header: when content scrolls
              // under the header this gap ensures the card edge never sits flush
              // against the button row above it.
              const SizedBox(height: 12),
              // ── Scrollable cards ──────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismissModalSheetFocus,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      children: [
                        _buildIdentityCard(),
                        if (!_isSmart) ...[
                          const SizedBox(height: 18),
                          _buildCategoryTypeCard(),
                          // Dynamic context footer — AnimatedSize clips from the
                          // top so it follows the Category Type card naturally.
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child:
                                (_categoryType == 'Shopping List' ||
                                    _categoryType == 'Smart Category')
                                ? SizedBox(
                                    width: double.infinity,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        left: 16,
                                      ),
                                      child: Text(
                                        _categoryType == 'Shopping List'
                                            ? _kFooterGroceries
                                            : _kFooterSmartCategory,
                                        style: _kContextFooterStyle(context),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    width: double.infinity,
                                    height: 0,
                                  ),
                          ),
                          SizeTransition(
                            sizeFactor: ReverseAnimation(_smartCategoryCtrl),
                            axisAlignment: -1.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 18),
                                _buildLocationSection(),
                                const SizedBox(height: 18),
                                _buildRepeatSection(),
                                const SizedBox(height: 18),
                                _buildAlertsSection(),
                              ],
                            ),
                          ),
                        ],
                        // The built-in fixed smart tiles intentionally stop
                        // after Identity and Color. User-created Smart
                        // Categories still show Category Type and their rule
                        // row, but omit Location, Repeat, and Alerts.
                        const SizedBox(height: 18),
                        _buildColorCard(),
                        if (!_isSmart) ...[
                          const SizedBox(height: 18),
                          _buildIconCard(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Beamed eighth-note icon ───────────────────────────────────────────────────
// Drawn via CustomPainter so it honours the same color parameter as Icon() and
// renders identically in the picker, category tile, preview header, and the
// detail-view empty state.
// ── Icon renderer ─────────────────────────────────────────────────────────────
// Accepts either a String (SVG asset path from custom_icons/) or an IconData.
// All category-icon render sites should call this instead of Icon() directly.
// Renders a category icon at [size] for use in tiles, header previews, and
// picker-row thumbnails.  For the icon-picker grid itself use _buildPickerIcon,
// which renders each icon at its true visual target size without the
// constraining SizedBox that would cancel any scale override here.
// ── Shared picker-tuning helpers ──────────────────────────────────────────────
//
// These helpers centralise per-icon adjustments (size, weight, offset) that
// were calibrated in the icon-picker grid.  Both _buildPickerIcon (the picker
// itself) and _renderCatIcon (every other occurrence of a category icon) call
// them so the look is always in sync — just scaled to the container.
//
// Reference diameter: _kIconCircle = 40 px.
// scale = containerDiameter / _kIconCircle.

// Canonical picker circle diameter — used by all top-level icon helpers.
const double _kIconCircle = 40.0;
// Unicode emoji have fuller visual bounds than SF Symbols, so they use a
// smaller reference glyph while keeping the picker circle itself unchanged.
const double _kEmojiGlyphSize = 20.0;

// SVG asset paths for the light/dark emoji icon pair.
const _kEmojiLightSvg = 'assets/custom_icons/emoji.svg';
const _kEmojiDarkSvg = 'assets/custom_icons/emoji_fill.svg';

// Returns the brightness-appropriate SVG path.
// Currently switches the emoji outline↔filled pair; all other paths pass through.
String _resolveIconSvg(String path, Brightness brightness) {
  if (path == _kEmojiLightSvg && brightness == Brightness.dark) {
    return _kEmojiDarkSvg;
  }
  return path;
}

/// True when [o] is a raw Unicode emoji character (not an SVG asset path or
/// IconData).  All SVG asset paths start with 'assets/'; emoji strings do not.
bool _isEmojiIcon(Object o) =>
    o is String && !(o as String).startsWith('assets/');

// Category icon circles use a deliberately quiet backdrop when the icon is a
// native emoji. Blend each resolved swatch independently with 60% white and
// 40% of the original color so every swatch keeps its own hue. This is
// render-only and never changes the stored swatch or the icon-picker colors.
Color _emojiCircleColor(Color color) =>
    Color.lerp(const Color(0xFFFFFFFF), color, 0.40)!;

/// Resolves the background for a saved category's icon circle.
///
/// Native emoji need a pale, per-swatch backdrop so the emoji remains legible.
/// All other category icons retain the resolved category swatch unchanged.
/// Picker swatches intentionally do not call this helper.
Color _categoryIconCircleColor(Object iconOrSvg, Color color) =>
    _isEmojiIcon(iconOrSvg) ? _emojiCircleColor(color) : color;

// Visual size of an icon at the picker reference scale (_kIconCircle = 40 px).
double _pickerIconBaseSize(Object iconOrSvg) {
  if (iconOrSvg is String) {
    if (_isEmojiIcon(iconOrSvg)) return _kEmojiGlyphSize;
    if (iconOrSvg.contains('Banknote')) return 18;
    if (iconOrSvg.contains('ShoppingBag')) return 21;
    if (iconOrSvg.contains('Bag') && !iconOrSvg.contains('Shopping')) return 21;
    if (iconOrSvg.contains('PingPongBall')) return 22;
    if (iconOrSvg.contains('Compass')) return 24;
    if (iconOrSvg.contains('Wallet')) return 18;
    if (iconOrSvg.contains('Briefcase')) return 18;
    return 20;
  }
  final icon = iconOrSvg as IconData;
  if (icon == CupertinoIcons.headphones) return 23;
  if (icon.fontPackage == 'flutter_sficon') {
    return _pickerSfGlyphSize(icon);
  }
  return 20;
}

// The actual SF Symbol font sizes used by the icon picker. Keeping this in a
// shared helper makes the Card 1 preview scale from the picker's real glyph
// proportions instead of an older, larger reference table.
double _pickerSfGlyphSize(IconData icon) {
  if (icon == SFIcons.sf_snowflake) return 22;
  if (icon == SFIcons.sf_mappin) return 21;
  if (icon == SFIcons.sf_tennis_racket) return 20;
  if (icon == SFIcons.sf_stethoscope) return 18;
  if (icon == SFIcons.sf_fish_fill) return 16;
  if (_kPickerSF24.contains(icon)) return 21;
  if (_kPickerSF22.contains(icon)) return 19;
  return 17;
}

// Font weight for SF icons — shared by both picker and all render sites.
FontWeight _pickerSfFontWeight(IconData icon) => icon == SFIcons.sf_tv
    ? FontWeight.w600
    : icon == SFIcons.sf_list_bullet
    ? FontWeight.w600
    : icon == SFIcons.sf_cart_fill
    ? FontWeight.w500
    : icon == SFIcons.sf_stethoscope
    ? FontWeight.w500
    : icon == SFIcons.sf_curlybraces
    ? FontWeight.w500
    : FontWeight.normal;

// Renders a category icon scaled to [containerSize] (the circle/square diameter)
// with the same per-icon size, weight, and positional offset used in the picker.
Widget _renderCatIcon(
  Object iconOrSvg,
  double containerSize,
  Color color, {
  BuildContext? ctx,
  double emojiOffsetY = 0,
}) {
  final double scale = containerSize / _kIconCircle;
  final double iconSz = _pickerIconBaseSize(iconOrSvg) * scale;
  var offset = _pickerIconOffset(iconOrSvg) * scale;
  if (_isEmojiIcon(iconOrSvg)) {
    offset += Offset(0, emojiOffsetY);
  }

  Widget inner;
  if (_isEmojiIcon(iconOrSvg)) {
    // Emoji: render as native Unicode text — no color tint, fills circle naturally.
    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Center(
        child: Transform.translate(
          offset: offset,
          child: Text(
            iconOrSvg as String,
            style: TextStyle(fontSize: iconSz, height: 1.0),
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    );
  }
  if (iconOrSvg is String) {
    final String path = ctx != null
        ? _resolveIconSvg(iconOrSvg, CupertinoTheme.brightnessOf(ctx))
        : iconOrSvg;
    inner = SvgPicture.asset(
      path,
      width: iconSz,
      height: iconSz,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  } else {
    final icon = iconOrSvg as IconData;
    if (icon == SFIcons.sf_music_note) {
      inner = _BeamedNoteIcon(size: iconSz, color: color);
    } else if (icon.fontPackage == 'flutter_sficon') {
      inner = FixedSFIcon(
        icon,
        fontSize: iconSz,
        color: color,
        fontWeight: _pickerSfFontWeight(icon),
      );
    } else {
      inner = Icon(icon, size: iconSz, color: color);
    }
  }

  if (offset != Offset.zero) {
    inner = Transform.translate(offset: offset, child: inner);
  }

  return SizedBox(
    width: containerSize,
    height: containerSize,
    child: Center(child: inner),
  );
}

// Renders a user-category icon for the DCV "No Events" placeholder.
//
// Unlike _renderCatIcon, this does NOT wrap in a bounding SizedBox — the
// widget's layout footprint equals the actual visual icon size (~65 px for an
// average icon at the 130-unit scale).  This matches SearchWeightedIcon(size:64)
// used by built-in categories so both paths centre identically in the Column.
Widget _buildDcvCatIcon(Object iconOrSvg, Color color, {BuildContext? ctx}) {
  const double scale = 130.0 / _kIconCircle; // same scale as before
  final double iconSz = _pickerIconBaseSize(iconOrSvg) * scale;
  final Offset offset = _pickerIconOffset(iconOrSvg) * scale;

  Widget inner;
  if (_isEmojiIcon(iconOrSvg)) {
    // Emoji: render as native Unicode text without colour tint.
    return Text(
      iconOrSvg as String,
      style: TextStyle(fontSize: iconSz, height: 1.0),
      textScaler: TextScaler.noScaling,
    );
  }
  if (iconOrSvg is String) {
    final String path = ctx != null
        ? _resolveIconSvg(iconOrSvg, CupertinoTheme.brightnessOf(ctx))
        : iconOrSvg;
    inner = SvgPicture.asset(
      path,
      width: iconSz,
      height: iconSz,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  } else {
    final IconData icon = iconOrSvg as IconData;
    if (icon == SFIcons.sf_music_note) {
      return _BeamedNoteIcon(size: iconSz, color: color);
    } else if (icon.fontPackage == 'flutter_sficon') {
      inner = FixedSFIcon(
        icon,
        fontSize: iconSz,
        color: color,
        fontWeight: _pickerSfFontWeight(icon),
      );
    } else {
      inner = Icon(icon, size: iconSz, color: color);
    }
  }
  if (offset != Offset.zero) {
    inner = Transform.translate(offset: offset, child: inner);
  }
  return inner;
}

// Used exclusively by _buildIconCard (the icon picker grid).
//
// Why a separate function instead of _renderCatIcon?
// _renderCatIcon wraps every icon in SizedBox(size×size).  For SVGs, that
// SizedBox overrides the SvgPicture width/height params, capping the render
// at `size` regardless of any scale multiplier.  For SF icons, the inner
// FittedBox(scaleDown) clips any fontSize larger than `size` back down to
// `size`, making the scale multiplier a no-op.  The picker grid cells are
// ~50 px wide so there is plenty of room to render icons at their real target
// size — no constraining box is needed.
//
// Icon target sizes (base = _kIconGlyph = 20 px):
//   SF thin/small (mappin, snowflake)       → 23 px
//   SF undersized group                     → 21 px
//   SF medium group                         → 19 px
//   SF default                              → 17 px
//   CupertinoIcons.headphones               → 23 px
//   Banknote.svg  (landscape 1.57:1)        → 30 px square → 30×19 visual
//   Tent.svg      (landscape 1.24:1)        → 24 px
//   PingPongBall.svg                        → 22 px
//   Compass.svg   (portrait  0.66:1)        → 26 px square → 17×26 visual
//   Wrench.svg    (viewBox x=40.94 clips
//                  left edge of content)    → allowDrawingOutsideViewBox
Widget _buildPickerIcon(Object iconOrSvg, Color color, {BuildContext? ctx}) {
  Widget child = _buildPickerIconRaw(iconOrSvg, color, ctx: ctx);
  final offset = _pickerIconOffset(iconOrSvg);
  if (offset != Offset.zero)
    child = Transform.translate(offset: offset, child: child);
  return child;
}

// Raw icon widget — no positional offset applied.
Widget _buildPickerIconRaw(Object iconOrSvg, Color color, {BuildContext? ctx}) {
  if (_isEmojiIcon(iconOrSvg)) {
    // Emoji: render as native Unicode text at the shared reference size.
    return Text(
      iconOrSvg as String,
      style: const TextStyle(fontSize: _kEmojiGlyphSize, height: 1.0),
      textScaler: TextScaler.noScaling,
    );
  }
  if (iconOrSvg is String) {
    final double sz = iconOrSvg.contains('Banknote')
        ? 18
        : iconOrSvg.contains('ShoppingBag')
        ? 21 // before generic 'Bag'
        : iconOrSvg.contains('Bag') && !iconOrSvg.contains('Shopping')
        ? 21 // Bag.svg
        : iconOrSvg.contains('Tent')
        ? 20
        : iconOrSvg.contains('PingPongBall')
        ? 22
        : iconOrSvg.contains('Compass')
        ? 24
        : iconOrSvg.contains('Wallet')
        ? 18
        : iconOrSvg.contains('Briefcase')
        ? 18
        : 20;
    final String path = ctx != null
        ? _resolveIconSvg(iconOrSvg, CupertinoTheme.brightnessOf(ctx))
        : iconOrSvg;
    return SvgPicture.asset(
      path,
      width: sz,
      height: sz,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
  final icon = iconOrSvg as IconData;
  if (icon == SFIcons.sf_music_note) {
    return _BeamedNoteIcon(size: 20, color: color);
  }
  if (icon == CupertinoIcons.headphones) {
    return Icon(icon, size: 23, color: color);
  }
  if (icon.fontPackage == 'flutter_sficon') {
    // Rendered without FittedBox so the fontSize is the actual visual budget.
    // SF glyph visuals are ~80 % of fontSize; picker cells are ~50 px so
    // even 23 px here (→ ~18 px visual) stays comfortably inside the circle.
    final double sz = _pickerSfGlyphSize(icon);
    return FixedSFIcon(
      icon,
      fontSize: sz,
      color: color,
      fontWeight: _pickerSfFontWeight(icon),
    );
  }
  return Icon(icon, size: 20, color: color);
}

// Per-icon positional nudges for the picker grid.
// Positive x → right, positive y → down (Flutter screen coords).
Offset _pickerIconOffset(Object iconOrSvg) {
  if (iconOrSvg is String) {
    if (iconOrSvg.contains('Cake')) return const Offset(0, -2);
    if (iconOrSvg.contains('ShoppingBasket')) return const Offset(0, -2);
    if (iconOrSvg.contains('Banknote')) return const Offset(2, 0);
    if (iconOrSvg.contains('PingPongBall')) return const Offset(-1, 0);
    // 'Bag.svg' only (not ShoppingBag / ShoppingBasket)
    if (iconOrSvg.contains('Bag') && !iconOrSvg.contains('Shopping'))
      return const Offset(0, -1);
    if (iconOrSvg.contains('ShoppingBag')) return const Offset(0, -1);
    if (iconOrSvg.contains('Pill')) return const Offset(0, -1);
    if (iconOrSvg.contains('Building2')) return const Offset(0, -1);
    if (iconOrSvg.contains('Tent')) return const Offset(0, -1);
    if (iconOrSvg.contains('Sailboat')) return const Offset(0, -1);
    if (iconOrSvg.contains('Music')) return const Offset(-1, 0);
    if (iconOrSvg.contains('Armchair')) return const Offset(1, 0);
    return Offset.zero;
  }
  final icon = iconOrSvg as IconData;
  // ── 2 px up ──────────────────────────────────────────────────────────────
  if (icon == CupertinoIcons.gamecontroller_fill) return const Offset(0, -2);
  // ── 1 px up ──────────────────────────────────────────────────────────────
  if (icon == CupertinoIcons.bookmark_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.gift_fill) return const Offset(0, -1);
  if (icon == SFIcons.sf_graduationcap_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.doc_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.book_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.creditcard_fill) return const Offset(0, -1);
  if (icon == SFIcons.sf_building_columns_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.headphones) return const Offset(0, -1);
  if (icon == SFIcons.sf_figure_arms_open) return const Offset(0, -1);
  if (icon == SFIcons.sf_figure_2_left_holdinghands) return const Offset(0, -1);
  if (icon == CupertinoIcons.paw_solid) return const Offset(0, -1);
  if (icon == CupertinoIcons.cube_box_fill) return const Offset(0, -1);
  if (icon == SFIcons.sf_car_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.sun_max_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.moon_fill) return const Offset(0, -1);
  if (icon == SFIcons.sf_drop_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.lightbulb_fill) return const Offset(0, -1);
  if (icon == CupertinoIcons.triangle_fill) return const Offset(0, -1);
  // ── 1 px up + 1 px right ─────────────────────────────────────────────────
  if (icon == CupertinoIcons.scissors) return const Offset(1, -1);
  // ── 1 px up ──────────────────────────────────────────────────────────────
  if (icon == SFIcons.sf_basketball_fill) return const Offset(0, -1);
  if (icon == SFIcons.sf_tennis_racket) return const Offset(0, -1);
  if (icon == SFIcons.sf_curlybraces) return const Offset(0, -1);
  // ── 1 px right ───────────────────────────────────────────────────────────
  if (icon == SFIcons.sf_fish_fill) return const Offset(1, 0);
  if (icon == CupertinoIcons.airplane) return const Offset(1, 0);
  // ── 1 px left ────────────────────────────────────────────────────────────
  return Offset.zero;
}

// SF icons that need 24 px in the picker (exact-size special cases are handled
// inline in _buildPickerIcon above these tiers).
const _kPickerSF24 = <IconData>[];

// SF icons that need 22 px in the picker.
const _kPickerSF22 = <IconData>[
  SFIcons.sf_figure_run,
  SFIcons.sf_building_columns_fill,
  SFIcons.sf_figure_arms_open,
  SFIcons.sf_basketball_fill,
  SFIcons.sf_drop_fill,
  SFIcons.sf_curlybraces,
];

class _BeamedNoteIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _BeamedNoteIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size),
    painter: _BeamedNotePainter(color: color),
  );
}

class _BeamedNotePainter extends CustomPainter {
  final Color color;
  const _BeamedNotePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // Note heads — ovals rotated ~20°
    void drawHead(double cx, double cy) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(-0.35);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.40, height: h * 0.25),
        fill,
      );
      canvas.restore();
    }

    drawHead(w * 0.25, h * 0.80); // left
    drawHead(w * 0.69, h * 0.72); // right

    // Stems
    final stem = Paint()
      ..color = color
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.40, h * 0.76),
      Offset(w * 0.40, h * 0.17),
      stem,
    );
    canvas.drawLine(
      Offset(w * 0.84, h * 0.66),
      Offset(w * 0.84, h * 0.07),
      stem,
    );

    // Beam — filled parallelogram connecting both stem tops
    final beam = Path()
      ..moveTo(w * 0.40, h * 0.17)
      ..lineTo(w * 0.84, h * 0.07)
      ..lineTo(w * 0.84, h * 0.24)
      ..lineTo(w * 0.40, h * 0.34)
      ..close();
    canvas.drawPath(beam, fill);
  }

  @override
  bool shouldRepaint(_BeamedNotePainter old) => old.color != color;
}

// Top-to-bottom Add-blend highlight for non-emoji Card 1 previews. It brightens
// the top of the circle using BlendMode.plus while preserving the swatch hue.
// Light colors (Yellow, Teal, Sand) get a lower peak opacity so they are not
// over-brightened; all other colors use the standard peak.
class _CircleAddHighlightPainter extends CustomPainter {
  final Color color;
  const _CircleAddHighlightPainter(this.color);

  // ARGB values for the three light swatches — both light-mode and dark-mode
  // variants — that need reduced highlight intensity.
  static const _kLightColorValues = <int>{
    0xFFFFCC00, 0xFFFFD60A, // Yellow
    0xFF5AC8FA, 0xFF64D2FF, // Teal / Light Blue
    0xFFD7C0AE, 0xFFE8D5C3, // Sand (last swatch)
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Resolve dynamic color to its concrete ARGB before checking.
    final argb = color.value;
    final isLight = _kLightColorValues.contains(argb);
    final topOpacity = isLight
        ? const Color(0x18FFFFFF) // ~9 % — subtle for already-bright hues
        : const Color(0x38FFFFFF); // ~22 % — standard for mid/dark hues
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topOpacity, const Color(0x00FFFFFF)],
      ).createShader(rect);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(_CircleAddHighlightPainter old) => old.color != color;
}

// Same circular "gel bloom" button used by the Notes-tab attachment viewer's
// dismiss (×) / confirm (✓) buttons, reused here for the Add Category sheet.
// tapDelay mirrors the Notes-tab convention: ~130 ms for dismiss buttons so
// the bloom peak is visible before the screen closes.
class _ModalCircleButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;

  /// Background color of the circle container.  Defaults to [kModalCard] for
  /// dismiss/close buttons.  Pass the category/accent color for save-ready
  /// checkmark buttons and [kTertiaryLabel] for save-unready ones.
  final Color containerColor;
  final VoidCallback onTap;
  final Duration tapDelay;

  /// Fine pixel offset applied to the icon glyph only (not the circle).
  /// Use [Offset(-2, 0)] for [CupertinoIcons.chevron_left] to optically
  /// centre the asymmetric glyph within the circle.
  final Offset iconOffset;
  const _ModalCircleButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.containerColor = kModalCard,
    this.tapDelay = Duration.zero,
    this.iconOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    final fontFamily = icon.fontPackage != null
        ? 'packages/${icon.fontPackage}/${icon.fontFamily}'
        : (icon.fontFamily ?? '');

    final resolvedContainerColor = resolveThemeColor(containerColor, context);
    final resolvedIconColor = resolveThemeColor(iconColor, context);
    final shadows = resolveThemeShadows(kCardShadow, context);

    return GelBloomButton(
      peakScale: 1.15,
      tapDelay: tapDelay,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: ShapeDecoration(
          color: resolvedContainerColor,
          shape: const CircleBorder(),
          shadows: shadows,
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: Transform.translate(
                offset: iconOffset,
                child: RichText(
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  text: TextSpan(
                    text: String.fromCharCode(icon.codePoint),
                    style: TextStyle(
                      inherit: false,
                      color: resolvedIconColor,
                      fontSize: 20,
                      fontFamily: fontFamily,
                      fontStyle: FontStyle.normal,
                      shadows: resolveThemeTextShadows([
                        Shadow(
                          color: resolvedIconColor,
                          blurRadius: kGelBloomIconWeight,
                        ),
                      ], context),
                    ),
                  ),
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
// EDIT DCV SECTIONS SHEET
// ══════════════════════════════════════════════════════════════════════════════

/// Modal editor for the user-created sections in a DCV.
///
/// The state is intentionally local to the sheet.  Reordering only changes the
/// preview order; the DCV and persistence are updated once the always-enabled
/// checkmark is tapped.
class _EditDcvSectionsSheet extends StatefulWidget {
  final List<String> sectionNames;
  final Color accentColor;
  final void Function(List<int> order, List<String> editedNames) onSave;

  const _EditDcvSectionsSheet({
    required this.sectionNames,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<_EditDcvSectionsSheet> createState() => _EditDcvSectionsSheetState();
}

class _EditDcvSectionsSheetState extends State<_EditDcvSectionsSheet> {
  late List<int> _sectionOrder;
  final Set<int> _deletingSections = <int>{};
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};
  int? _draggingOriginalIndex;
  int? _dragGapIndex;

  static const double _kHeaderEdge = 16.0;
  static const double _kHeaderTopShift = 12.5;
  static const double _kHeaderButtonSize = 40.0;

  @override
  void initState() {
    super.initState();
    _sectionOrder = List<int>.generate(widget.sectionNames.length, (i) => i);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _sectionOrder.removeAt(oldIndex);
      _sectionOrder.insert(newIndex, moved);
      _draggingOriginalIndex = null;
      _dragGapIndex = null;
    });
  }

  List<int> get _stationaryOrder {
    final dragging = _draggingOriginalIndex;
    if (dragging == null) return List<int>.of(_sectionOrder);
    return [
      for (final originalIndex in _sectionOrder)
        if (originalIndex != dragging) originalIndex,
    ];
  }

  void _updateDragGap(double globalY) {
    if (_draggingOriginalIndex == null) return;
    final positionedRows = <({int originalIndex, double top, double bottom})>[];
    for (final originalIndex in _stationaryOrder) {
      final box =
          _rowKeys[originalIndex]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      positionedRows.add((
        originalIndex: originalIndex,
        top: top,
        bottom: top + box.size.height,
      ));
    }
    positionedRows.sort((a, b) => a.top.compareTo(b.top));

    var gapIndex = positionedRows.length;
    for (var index = 0; index < positionedRows.length; index++) {
      final row = positionedRows[index];
      if (globalY < (row.top + row.bottom) / 2) {
        gapIndex = index;
        break;
      }
    }
    if (_dragGapIndex != gapIndex && mounted) {
      setState(() => _dragGapIndex = gapIndex);
    }
  }

  void _save() {
    widget.onSave(
      [
        for (final originalIndex in _sectionOrder)
          if (!_deletingSections.contains(originalIndex)) originalIndex,
      ],
      [
        for (final name in widget.sectionNames)
          name.trim().isEmpty ? 'New Section' : name,
      ],
    );
    Navigator.of(context).pop();
  }

  void _deleteSection(int originalIndex) {
    if (!_sectionOrder.contains(originalIndex) ||
        _deletingSections.contains(originalIndex)) {
      return;
    }
    setState(() => _deletingSections.add(originalIndex));
    // Keep the keyed row in the ReorderableListView while its AnimatedSize
    // collapses.  Removing it immediately would make the card snap closed.
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() {
        _deletingSections.remove(originalIndex);
        _sectionOrder.remove(originalIndex);
      });
    });
  }

  Widget _sectionReorderProxy(
    Widget _child,
    int index,
    Animation<double> animation,
  ) {
    // Match the event-tile reorder ghost: lift the complete standalone card,
    // including its larger shadow and dark-mode hairline.  The only
    // intentional difference is the Edit Sections card surface colour.
    final shadows = resolveThemeShadows(const [
      BoxShadow(color: Color(0x3A000000), blurRadius: 18, offset: Offset(0, 6)),
    ], context);
    final safeIndex = index.clamp(0, _sectionOrder.length - 1);
    final originalIndex = _sectionOrder[safeIndex];
    return Transform.scale(
      scale: 1.05,
      child: _DarkModeGhostOutline(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: resolveThemeColor(kModalCard, context),
            shape: BoundedContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(_kCornerRadius),
            ),
            shadows: shadows,
          ),
          child: IgnorePointer(
            child: _buildSectionRowSurface(
              context,
              originalIndex,
              rowIndex: safeIndex,
              handleColor: widget.accentColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionDragHandle(int rowIndex, Color handleColor) {
    return ReorderableDragStartListener(
      index: rowIndex,
      child: SizedBox(
        width: 52,
        child: Center(
          child: Icon(
            CupertinoIcons.line_horizontal_3,
            size: 21,
            color: handleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionRowSurface(
    BuildContext context,
    int originalIndex, {
    required int rowIndex,
    required Color handleColor,
  }) {
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final sectionTextStyle = TextStyle(
      inherit: false,
      color: primaryLabel,
      fontFamily: kSFProText,
      fontSize: 17,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );
    return IntrinsicHeight(
      child: Container(
        color: resolveThemeColor(kModalCard, context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                child: Text(
                  widget.sectionNames[originalIndex].trim().isEmpty
                      ? 'New Section'
                      : widget.sectionNames[originalIndex],
                  style: sectionTextStyle,
                ),
              ),
            ),
            _sectionDragHandle(rowIndex, handleColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);
    final handleColor = widget.accentColor;
    return CupertinoPageScaffold(
      backgroundColor: kModalBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: _kHeaderTopShift),
            RoundedCupertinoSheetHeader(
              child: SizedBox(
                height: _kHeaderButtonSize,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Edit Sections',
                      style: TextStyle(
                        inherit: false,
                        color: primaryLabel,
                        fontSize: 17,
                        fontFamily: kSFProText,
                        fontWeight: FontWeight.w600,
                        letterSpacing: kTracking17,
                        height: kLineHeight,
                      ),
                    ),
                    Positioned(
                      left: _kHeaderEdge,
                      child: _ModalCircleButton(
                        icon: CupertinoIcons.xmark,
                        iconColor: primaryLabel,
                        tapDelay: const Duration(milliseconds: 130),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Positioned(
                      right: _kHeaderEdge,
                      child: _ModalCircleButton(
                        icon: CupertinoIcons.checkmark,
                        containerColor: widget.accentColor,
                        iconColor: CupertinoColors.white,
                        tapDelay: const Duration(milliseconds: 130),
                        onTap: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: resolveThemeColor(kModalCard, context),
                      shape: BoundedContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(kSbCornerRadius),
                      ),
                      shadows: resolveThemeShadows(kCardShadow, context),
                    ),
                    child: Listener(
                      onPointerMove: (details) =>
                          _updateDragGap(details.position.dy),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _sectionOrder.length,
                        onReorder: _reorder,
                        onReorderStart: (rowIndex) => setState(() {
                          _draggingOriginalIndex = _sectionOrder[rowIndex];
                          _dragGapIndex = rowIndex;
                        }),
                        onReorderEnd: (_) => setState(() {
                          _draggingOriginalIndex = null;
                          _dragGapIndex = null;
                        }),
                        proxyDecorator: _sectionReorderProxy,
                        itemBuilder: (context, rowIndex) {
                          final originalIndex = _sectionOrder[rowIndex];
                          final isDragging =
                              originalIndex == _draggingOriginalIndex;
                          final stationaryOrder = _stationaryOrder;
                          final stationaryIndex = stationaryOrder.indexOf(
                            originalIndex,
                          );
                          final gapIndex = _dragGapIndex;
                          // This is the same rule used by event tiles:
                          // separators belong to the stationary rows, not to
                          // the lifted ghost.  A top separator appears only
                          // on the row immediately below the live gap.
                          final showSeparatorAbove =
                              !isDragging &&
                              _draggingOriginalIndex != null &&
                              stationaryIndex >= 0 &&
                              gapIndex != null &&
                              gapIndex == stationaryIndex &&
                              gapIndex < stationaryOrder.length;
                          final showSeparatorBelow =
                              !isDragging &&
                              stationaryIndex >= 0 &&
                              (gapIndex == null
                                  ? stationaryIndex < stationaryOrder.length - 1
                                  : stationaryIndex <
                                            stationaryOrder.length - 1 ||
                                        gapIndex == stationaryOrder.length);
                          return KeyedSubtree(
                            key: ValueKey(originalIndex),
                            child: Container(
                              key: _rowKeys.putIfAbsent(
                                originalIndex,
                                GlobalKey.new,
                              ),
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOut,
                                child: _deletingSections.contains(originalIndex)
                                    ? const SizedBox(
                                        width: double.infinity,
                                        height: 0,
                                      )
                                    : _SwipeToRevealDelete(
                                        iconSize: MediaQuery.textScalerOf(
                                          context,
                                        ).scale(17),
                                        dismissOnTap: false,
                                        onDelete: () =>
                                            _deleteSection(originalIndex),
                                        child: Column(
                                          children: [
                                            if (showSeparatorAbove)
                                              Container(
                                                height: 0.5,
                                                color: separatorColor,
                                              ),
                                            _buildSectionRowSurface(
                                              context,
                                              originalIndex,
                                              rowIndex: rowIndex,
                                              handleColor: handleColor,
                                            ),
                                            if (showSeparatorBelow)
                                              Container(
                                                height: 0.5,
                                                color: separatorColor,
                                              ),
                                          ],
                                        ),
                                      ),
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
          ],
        ),
      ),
    );
  }
}

/// Reveals a raw destructive trash SF Symbol when the row is swiped from
/// either direction. The child remains the reorderable/tappable surface; the
/// action is only committed when its revealed icon is tapped.
class _SwipeToRevealDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final double iconSize;
  final double deleteIconVerticalOffset;
  final bool dismissOnTap;

  const _SwipeToRevealDelete({
    super.key,
    required this.child,
    required this.onDelete,
    required this.iconSize,
    this.deleteIconVerticalOffset = 0,
    this.dismissOnTap = true,
  });

  @override
  State<_SwipeToRevealDelete> createState() => _SwipeToRevealDeleteState();
}

class _SwipeToRevealDeleteState extends State<_SwipeToRevealDelete>
    with SingleTickerProviderStateMixin {
  static const _kActionWidth = 52.0;
  static const _kAnimationDuration = Duration(milliseconds: 220);
  static const _kRubberBandResistance = 0.15;
  static const _kReverseCloseDistance = 8.0;
  static _SwipeToRevealDeleteState? _openState;

  late final AnimationController _settleController;
  double _offset = 0.0;
  double _animationStart = 0.0;
  double _animationEnd = 0.0;
  double _dragStartOffset = 0.0;
  double _dragDistance = 0.0;

  double get _renderOffset {
    if (!_settleController.isAnimating) return _offset;
    final t = Curves.easeOutCubic.transform(_settleController.value);
    return _animationStart + (_animationEnd - _animationStart) * t;
  }

  @override
  void initState() {
    super.initState();
    _settleController =
        AnimationController(vsync: this, duration: _kAnimationDuration)
          ..addListener(() => setState(() {}))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed &&
                _animationEnd == 0 &&
                identical(_openState, this)) {
              _openState = null;
            }
          });
  }

  @override
  void dispose() {
    if (identical(_openState, this)) _openState = null;
    _settleController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    final current = _renderOffset;
    final previousOpen = _openState;
    if (previousOpen != null && !identical(previousOpen, this)) {
      previousOpen._closeFromPeer();
    }
    _settleController.stop();
    _offset = current;
    _dragStartOffset = current;
    _dragDistance = 0.0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dx;
    final rawOffset = _dragStartOffset + _dragDistance;
    setState(() {
      _offset = _rubberBand(rawOffset);
    });
  }

  double _rubberBand(double rawOffset) {
    if (rawOffset > _kActionWidth) {
      return _kActionWidth +
          (rawOffset - _kActionWidth) * _kRubberBandResistance;
    }
    if (rawOffset < -_kActionWidth) {
      return -_kActionWidth +
          (rawOffset + _kActionWidth) * _kRubberBandResistance;
    }
    return rawOffset;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    final current = _offset;
    final startedRevealed = _dragStartOffset.abs() >= _kActionWidth * 0.5;
    final reversedByDistance =
        startedRevealed &&
        _dragDistance.abs() >= _kReverseCloseDistance &&
        _dragDistance.sign != _dragStartOffset.sign;
    final reversedByVelocity =
        startedRevealed &&
        velocity.abs() >= 150 &&
        velocity.sign != _dragStartOffset.sign;
    final velocityDirection = velocity == 0 ? 0 : velocity.sign;
    final currentDirection = current == 0 ? 0 : current.sign;
    final direction = currentDirection != 0
        ? currentDirection
        : velocityDirection;
    final shouldClose = reversedByDistance || reversedByVelocity;
    final shouldReveal =
        !shouldClose &&
        (current.abs() >= _kActionWidth * 0.5 || velocity.abs() >= 300);
    _animateTo(shouldReveal && direction != 0 ? direction * _kActionWidth : 0);
    if (shouldReveal && direction != 0) {
      _openState = this;
    }
  }

  void _animateTo(double target) {
    final current = _renderOffset;
    _settleController.stop();
    _animationStart = current;
    _animationEnd = target;
    _offset = target;
    if ((_animationStart - _animationEnd).abs() < 0.5) {
      if (target == 0 && identical(_openState, this)) {
        _openState = null;
      }
      setState(() {});
      return;
    }
    setState(() {});
    _settleController.forward(from: 0);
  }

  void _closeFromPeer() {
    if (mounted) _animateTo(0);
  }

  void _onTap() {
    if (_offset.abs() > 0.5) {
      _animateTo(0);
    }
  }

  Widget _deleteAction({required bool left, required double rowOffset}) {
    // Start the icon outside the viewport and translate it by the same amount
    // as the header.  The old implementation left it fixed in the reveal slot,
    // so it popped directly into place instead of following the swipe.
    final iconTravel = rowOffset - (left ? _kActionWidth : -_kActionWidth);
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: SizedBox(
        width: _kActionWidth,
        height: double.infinity,
        child: Semantics(
          button: true,
          label: 'Delete section',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDelete,
            child: Center(
              child: Transform.translate(
                offset: Offset(iconTravel, widget.deleteIconVerticalOffset),
                child: FixedSFIcon(
                  SFIcons.sf_trash,
                  fontSize: widget.iconSize,
                  color: CupertinoColors.destructiveRed,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offset = _renderOffset;
    final revealLeft = offset > 0;
    final revealRight = offset < 0;
    return GestureDetector(
      // Let editable descendants receive their own tap and selection
      // gestures. The row still fills the hit-test path, so horizontal swipes
      // can reveal delete without making the text field feel locked.
      behavior: HitTestBehavior.deferToChild,
      onTap: widget.dismissOnTap ? _onTap : null,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                if (revealLeft) _deleteAction(left: true, rowOffset: offset),
                if (revealRight) _deleteAction(left: false, rowOffset: offset),
              ],
            ),
          ),
          Transform.translate(offset: Offset(offset, 0), child: widget.child),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DETAILED CELL VIEW
// ══════════════════════════════════════════════════════════════════════════════

// ── DCV list-item union type ──────────────────────────────────────────────────
// _CategoryDetailViewState._buildDisplayItems() returns a flat list of these.
// The SliverList.builder switches on the runtime type to render either a
// section header or an event card.
/// One logical section in the Category Detail View: an optional collapsible
/// header and the events that belong to it.  Sections render as a single
/// grouped card (shared surface + shadow + hairline separators), matching the
/// Categories list card on the main Events tab.
class _DcvSection {
  final String? headerText; // null → no header (flat Manual / Unscheduled)
  final List<ScheduledEvent> events;
  final String? collapseKey;
  final bool isEditable;
  final int? customSectionIndex;

  const _DcvSection({
    this.headerText,
    required this.events,
    this.collapseKey,
    this.isEditable = false,
    this.customSectionIndex,
  });
}

class _DcvDragRowTarget {
  final int sectionIndex;
  final int eventIndex;
  final double top;
  final double bottom;

  const _DcvDragRowTarget({
    required this.sectionIndex,
    required this.eventIndex,
    required this.top,
    required this.bottom,
  });

  double get midpoint => top + (bottom - top) / 2;
}

// ── DCV section label (matches Settings Panel header geometry) ────────────────
class _DcvSectionLabel extends StatelessWidget {
  final String text;

  /// True for the very first item: its 17.5 px top inset comes from the
  /// enclosing SliverPadding, matching the Settings Panel's first section.
  final bool isFirst;

  /// Whether this section is currently collapsed.
  final bool isCollapsed;

  /// Category accent colour used to tint the collapse chevron.
  final Color accentColor;

  /// Fired when the user taps the header or chevron.
  final VoidCallback? onTap;

  const _DcvSectionLabel({
    required this.text,
    required this.isFirst,
    required this.accentColor,
    this.isCollapsed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const baseFontSize = 15.0;
    final chevronFontSize = MediaQuery.textScalerOf(
      context,
    ).scale(baseFontSize);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Settings geometry: 15 px between section cards, 10 px from the label
        // to the card it introduces, and 16 px of label inset inside the 16 px
        // card/list inset (32 px from the viewport edge).
        padding: EdgeInsets.only(left: 16, top: isFirst ? 0 : 15, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  inherit: false,
                  fontFamily: kSFProText,
                  fontSize: baseFontSize,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  color: resolveThemeColor(kSecondaryLabel, context),
                  letterSpacing: 0.0,
                ),
                softWrap: true,
              ),
            ),
            // Chevron: points down (∨, expanded) or right (>, collapsed).
            // -0.25 turns = 90° counter-clockwise: ∨ → >
            // FixedSFIcon disables inherited scaling, so apply the system
            // text scaler explicitly to keep it aligned with the label.
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedRotation(
                turns: isCollapsed ? -0.25 : 0.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: FixedSFIcon(
                  SFIcons.sf_chevron_down,
                  fontSize: chevronFontSize,
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editable header used for user-created Manual-view sections.
///
/// The field uses the platform "Done" action, which becomes the return/check
/// key on the phone keyboard.  Submitting from that key commits the title and
/// dismisses the keyboard.
class _DcvEditableSectionLabel extends StatefulWidget {
  final String initialText;
  final bool isFirst;
  final bool isCollapsed;
  final Color accentColor;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String> onSubmitted;

  const _DcvEditableSectionLabel({
    required this.initialText,
    required this.isFirst,
    required this.isCollapsed,
    required this.accentColor,
    required this.onToggle,
    this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_DcvEditableSectionLabel> createState() =>
      _DcvEditableSectionLabelState();
}

class _DcvEditableSectionLabelState extends State<_DcvEditableSectionLabel>
    with WidgetsBindingObserver {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  // Keep the selection controls stable while the category colour changes so
  // Flutter does not tear down the active selection overlay mid-gesture.
  late final ValueNotifier<Color> _handleColorNotifier;
  late final TintedCupertinoTextSelectionControls _selectionControls;
  bool _ensureVisibleScheduled = false;
  late String _lastCommittedText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController(
      text: widget.initialText == 'New Section' ? '' : widget.initialText,
    );
    _lastCommittedText = _controller.text;
    _focusNode = FocusNode();
    _handleColorNotifier = ValueNotifier<Color>(widget.accentColor);
    _selectionControls = TintedCupertinoTextSelectionControls(
      _handleColorNotifier,
    );
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialText == 'New Section') {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeMetrics() {
    // The first focus callback often runs before the keyboard has resized the
    // viewport.  Run the reveal again after the insets change so a newly
    // created section near the bottom of the DCV is not covered by the IME.
    if (_focusNode.hasFocus) _scheduleEnsureVisible();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _scheduleEnsureVisible();
    } else {
      _commitText();
    }
  }

  void _scheduleEnsureVisible() {
    if (_ensureVisibleScheduled) return;
    _ensureVisibleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisibleScheduled = false;
      if (!mounted || !_focusNode.hasFocus) return;
      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.28,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _DcvEditableSectionLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accentColor != widget.accentColor) {
      _handleColorNotifier.value = widget.accentColor;
    }
    if (!_focusNode.hasFocus && oldWidget.initialText != widget.initialText) {
      _controller.text = widget.initialText == 'New Section'
          ? ''
          : widget.initialText;
      _lastCommittedText = _controller.text;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    _handleColorNotifier.dispose();
    super.dispose();
  }

  void _commitText() {
    final text = _controller.text.trim();
    if (text == _lastCommittedText) return;
    _lastCommittedText = text;
    widget.onSubmitted(text);
  }

  void _submit() {
    _commitText();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    const baseFontSize = 15.0;
    final labelColor = resolveThemeColor(kSecondaryLabel, context);
    final placeholderColor = resolveThemeColor(kTertiaryLabel, context);
    final chevronFontSize = MediaQuery.textScalerOf(
      context,
    ).scale(baseFontSize);
    final labelStyle = TextStyle(
      inherit: false,
      fontFamily: kSFProText,
      fontSize: baseFontSize,
      fontWeight: FontWeight.w600,
      color: labelColor,
      letterSpacing: 0.0,
    );
    final placeholderStyle = TextStyle(
      inherit: false,
      fontFamily: kSFProText,
      fontSize: baseFontSize,
      fontWeight: FontWeight.w600,
      color: placeholderColor,
      letterSpacing: 0.0,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        top: widget.isFirst ? 0 : 15,
        bottom: 10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = _controller.text.isEmpty
              ? 'New Section'
              : _controller.text;
          final measureStyle = _controller.text.isEmpty
              ? placeholderStyle
              : labelStyle;
          final painter = TextPainter(
            text: TextSpan(text: text, style: measureStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();

          // The editable hit target follows the rendered title instead of
          // expanding across the whole header.  The small buffer keeps the
          // final glyph comfortable to tap without claiming the empty space.
          const editableTrailingBuffer = 8.0;
          const chevronZoneWidth = 12.0 + 16.0 + 18.0;
          final maxEditableWidth = max(
            1.0,
            constraints.maxWidth - chevronZoneWidth,
          );
          final editableWidth = min(
            maxEditableWidth,
            max(1.0, painter.width + editableTrailingBuffer),
          );

          return Row(
            children: [
              SizedBox(
                width: editableWidth,
                child: CupertinoTheme(
                  data: CupertinoTheme.of(
                    context,
                  ).copyWith(primaryColor: widget.accentColor),
                  child: DefaultSelectionStyle(
                    selectionColor: widget.accentColor.withOpacity(0.20),
                    child: CupertinoTextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: false,
                      decoration: null,
                      padding: EdgeInsets.zero,
                      minLines: 1,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      selectionControls: _selectionControls,
                      placeholder: 'New Section',
                      placeholderStyle: placeholderStyle,
                      style: labelStyle,
                      cursorColor: widget.accentColor,
                      onTap: _scheduleEnsureVisible,
                      onChanged: (_) {
                        setState(() {});
                        widget.onChanged?.call(_controller.text.trim());
                        _scheduleEnsureVisible();
                      },
                      // Some phone keyboards deliver their check/Done key
                      // through editingComplete rather than submitted.
                      // Commit through the same path in either case so the
                      // saved name is ready when Edit Sections is opened.
                      onEditingComplete: _submit,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onToggle,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 16),
                        child: AnimatedRotation(
                          turns: widget.isCollapsed ? -0.25 : 0.0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          child: FixedSFIcon(
                            SFIcons.sf_chevron_down,
                            fontSize: chevronFontSize,
                            color: widget.accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryDetailView extends StatefulWidget {
  final String label;

  /// Icon override for user-created categories; null → built-in switch logic.
  /// Either an [IconData] or a String SVG asset path — pass to [_renderCatIcon].
  final Object? icon;

  /// Category type — 'Standard', 'Groceries', or 'Smart Category'.
  /// Drives the empty-state icon, title, and subtitle copy.
  final String categoryType;

  /// Filtered events for this view.  Empty list → show empty state.
  /// Populated by SmartCategoryMatcher for smart tiles and Smart Categories.
  final List<ScheduledEvent> events;

  /// Active sort mode.  'Manual' = chronological pre-sort + drag-reorder +
  /// date section headers.  Any other value = flat sorted list, no headers,
  /// no drag-reorder.
  final String sortBy;

  /// Direction string for the active sort, e.g. 'Soonest First', 'A → Z'.
  final String sortDir;

  /// Whether Manual mode should group events under date-based headers.
  /// Built-in date Smart Categories keep their existing grouping; the
  /// section-enabled category views open as one flat list.
  final bool showManualDateSections;

  /// Names for user-created Manual-view sections. An empty name renders the
  /// editable "New Section" placeholder.
  final List<String> customSectionNames;

  /// Event IDs grouped by custom section. A null value means the first
  /// section owns the current events by default.
  final List<List<String>>? customSectionEventIds;

  /// Saves a submitted custom section title.
  final void Function(int index, String title)? onCustomSectionRenamed;

  /// Updates the visible title while typing without persisting every
  /// keystroke. [onCustomSectionRenamed] performs the durable save on submit.
  final void Function(int index, String title)? onCustomSectionEditingChanged;

  /// Deletes a user-created section from the DCV.
  final ValueChanged<int>? onCustomSectionDeleted;

  /// Saves event ordering and section membership after a drag completes.
  final ValueChanged<List<List<String>>>? onCustomSectionReordered;

  /// Optional callback to open the event-edit sheet for a given event.
  /// Passed from [EventsTab.onEditEvent] so DCV event cards show a pencil icon.
  final void Function(ScheduledEvent event)? onEditEvent;

  /// Category accent colour — used to tint the collapse chevron on section
  /// headers.  Defaults to [kAccentColor] when not supplied.
  final Color color;

  const _CategoryDetailView({
    super.key,
    required this.label,
    this.icon,
    this.categoryType = 'Standard',
    this.events = const [],
    this.sortBy = 'Manual',
    this.sortDir = '',
    this.showManualDateSections = true,
    this.customSectionNames = const [],
    this.customSectionEventIds,
    this.onCustomSectionRenamed,
    this.onCustomSectionEditingChanged,
    this.onCustomSectionDeleted,
    this.onCustomSectionReordered,
    this.onEditEvent,
    this.color = kAccentColor,
  });

  @override
  State<_CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends State<_CategoryDetailView>
    with SingleTickerProviderStateMixin {
  // ── Local event ordering (survives within one DCV session) ────────────────
  late List<ScheduledEvent> _items;

  // ── Drag-reorder state ────────────────────────────────────────────────────
  int? _draggingIndex;
  ScheduledEvent? _dragEvent; // captured at drag start, shown in ghost
  OverlayEntry? _dragOverlay;
  double _dragGlobalY = 0;

  // The persisted membership/order of custom sections.  [_items] remains the
  // flattened display order so the existing FLIP animation can be reused,
  // while this list is the source of truth for section membership during a
  // cross-section drag.
  late List<List<String>> _sectionEventIds;

  // One GlobalKey per event ID — lets us read screen rects during drag without
  // needing to know the scroll offset.  Keys survive list reorders because they
  // are looked up by event ID, not by list position.
  final Map<String, GlobalKey> _itemKeys = {};
  final Map<int, GlobalKey> _sectionKeys = {};

  // ── Collapse state ────────────────────────────────────────────────────────
  /// Section keys (header text) that are currently collapsed.  Empty by
  /// default — all sections are expanded when the DCV first opens.
  final Set<String> _collapsedSections = {};

  void _toggleSection(String key) {
    setState(() {
      if (_collapsedSections.contains(key)) {
        _collapsedSections.remove(key);
      } else {
        _collapsedSections.add(key);
      }
    });
  }

  // ── Sort animation (FLIP) ─────────────────────────────────────────────────
  late final AnimationController _sortAnimCtrl;
  // Per-event starting Y offset when the animation begins.
  // Each card transforms by offset * (1 - ctrl.value), sliding from its old
  // position to its new one as ctrl goes 0 → 1.
  final Map<String, double> _sortAnimFromY = {};
  // True during the one invisible layout frame used to measure new positions.
  bool _sortMeasuring = false;

  // Live drag swaps use the same per-row FLIP renderer as sort changes, but
  // intentionally do not use [_sortMeasuring].  Sort changes can hide the
  // complete view for one measurement frame because they are discrete state
  // changes; a drag is continuous and hiding the page while the finger moves
  // reads as a flicker.  The generation invalidates a stale post-frame
  // measurement when the finger crosses another row or the drag ends.
  int _dragReflowGeneration = 0;
  static const _kDragReflowDuration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _sortAnimCtrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed && mounted) {
            setState(() => _sortAnimFromY.clear());
          }
        });
    _items = List.of(widget.events);
    _sortItems();
    _sectionEventIds = _normaliseSectionEventIds(widget.customSectionEventIds);
    _syncItemsToSections();
  }

  @override
  void didUpdateWidget(covariant _CategoryDetailView old) {
    super.didUpdateWidget(old);
    if (_draggingIndex != null) return;

    final sortChanged =
        old.sortBy != widget.sortBy || old.sortDir != widget.sortDir;

    final oldIds = old.events.map((e) => e.id).toSet();
    final newIds = widget.events.map((e) => e.id).toSet();
    final idsChanged =
        oldIds.length != newIds.length || !oldIds.containsAll(newIds);

    // Also detect property changes (e.g. AI-assigned priorities) where the set
    // of IDs is unchanged but event objects have been replaced by copyWith*.
    // ScheduledEvent is immutable, so a changed event always has a new identity.
    final oldMap = {for (final e in old.events) e.id: e};
    final contentChanged =
        !idsChanged && widget.events.any((e) => !identical(e, oldMap[e.id]));
    final eventsChanged = idsChanged || contentChanged;

    // Sync _items from widget.events whenever the event list or the sort mode
    // changes. This ensures sorting always operates on the latest event objects
    // (e.g. freshly AI-assigned priorities), not stale copies from a prior
    // rebuild where only IDs were compared.
    final sectionNamesChanged =
        old.customSectionNames.length != widget.customSectionNames.length ||
        !_sameStrings(old.customSectionNames, widget.customSectionNames);
    final sectionIdsChanged = !_sameNestedStrings(
      old.customSectionEventIds,
      widget.customSectionEventIds,
    );

    if (eventsChanged ||
        sortChanged ||
        sectionNamesChanged ||
        sectionIdsChanged) {
      _items = List.of(widget.events);
      _itemKeys.removeWhere((id, _) => !_items.any((e) => e.id == id));
    }

    if (sortChanged) {
      // New sort mode means new section keys — any persisted collapse state
      // would no longer match the new headers, so clear it.
      _collapsedSections.clear();
      // Animate each card to its new position.
      _animateSortChange();
    } else if (eventsChanged || sectionNamesChanged || sectionIdsChanged) {
      _sectionEventIds = _normaliseSectionEventIds(
        widget.customSectionEventIds,
      );
      if (widget.customSectionNames.isNotEmpty) {
        _syncItemsToSections();
      } else {
        _sortItems();
      }
    }
  }

  @override
  void dispose() {
    _sortAnimCtrl.dispose();
    _dragOverlay?.remove();
    _dragOverlay = null;
    super.dispose();
  }

  // ── Sort helpers ──────────────────────────────────────────────────────────

  static bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameNestedStrings(List<List<String>>? a, List<List<String>>? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameStrings(a[i], b[i])) return false;
    }
    return true;
  }

  /// Normalises persisted section membership against the events currently
  /// visible in this DCV.  Old saves did not have membership data, so those
  /// events are migrated into the first section in their current order.
  List<List<String>> _normaliseSectionEventIds(List<List<String>>? persisted) {
    final sectionCount = widget.customSectionNames.length;
    if (sectionCount == 0) return <List<String>>[];

    final knownIds = _items.map((event) => event.id).toSet();
    final result = List<List<String>>.generate(sectionCount, (_) => <String>[]);
    final assigned = <String>{};

    if (persisted != null) {
      for (
        var sectionIndex = 0;
        sectionIndex < persisted.length && sectionIndex < sectionCount;
        sectionIndex++
      ) {
        for (final id in persisted[sectionIndex]) {
          if (knownIds.contains(id) && assigned.add(id)) {
            result[sectionIndex].add(id);
          }
        }
      }
    }

    // Preserve legacy/unassigned events in the first section rather than
    // dropping them when a category's event set changes.
    for (final event in _items) {
      if (assigned.add(event.id)) result.first.add(event.id);
    }
    return result;
  }

  /// Rebuilds the flattened list in the same order as the custom sections.
  void _syncItemsToSections() {
    if (_sectionEventIds.isEmpty) return;
    final eventsById = {for (final event in _items) event.id: event};
    final ordered = <ScheduledEvent>[];
    final added = <String>{};
    for (final section in _sectionEventIds) {
      for (final id in section) {
        final event = eventsById[id];
        if (event != null && added.add(id)) ordered.add(event);
      }
    }
    // This is defensive for a just-added event arriving in the same frame as
    // the persisted section map.
    for (final event in _items) {
      if (added.add(event.id)) ordered.add(event);
    }
    _items = ordered;
  }

  /// Sorts [_items] in-place according to [widget.sortBy] / [widget.sortDir].
  /// Called from [initState] and [didUpdateWidget] (when not mid-drag).
  /// For Manual the chronological order is the pre-sort baseline; drag-reorder
  /// then overrides it within the session without re-sorting.
  void _sortItems() {
    switch (widget.sortBy) {
      case 'Deadline':
        final asc = widget.sortDir != 'Latest First';
        _items.sort((a, b) {
          final aAbs = a.parsedDate?.absoluteDate;
          final bAbs = b.parsedDate?.absoluteDate;
          if (aAbs == null && bAbs == null) return 0;
          if (aAbs == null) return 1; // no date → end
          if (bAbs == null) return -1;
          final dc = aAbs.compareTo(bAbs);
          if (dc != 0) return asc ? dc : -dc;
          if (a.time != null && b.time != null) {
            final tc = _timeToMinutes(a.time!) - _timeToMinutes(b.time!);
            return asc ? tc : -tc;
          }
          return 0;
        });
      case 'Priority':
        final asc = widget.sortDir != 'Highest First';
        _items.sort((a, b) {
          final c = a.priority.compareTo(b.priority);
          return asc ? c : -c;
        });
      case 'Creation Date':
        final asc = widget.sortDir != 'Newest First';
        _items.sort((a, b) {
          final ac = a.createdAt;
          final bc = b.createdAt;
          // Legacy events with no createdAt go to the end regardless of direction.
          if (ac == null && bc == null) return 0;
          if (ac == null) return 1;
          if (bc == null) return -1;
          final c = ac.compareTo(
            bc,
          ); // ISO strings sort lexicographically = chronologically
          return asc ? c : -c;
        });
      case 'Title':
        final asc = widget.sortDir != 'Descending';
        _items.sort((a, b) {
          final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return asc ? c : -c;
        });
      default: // Manual — chronological pre-sort; drag-reorder preserves this.
        _items.sort((a, b) {
          final aAbs = a.parsedDate?.absoluteDate;
          final bAbs = b.parsedDate?.absoluteDate;
          if (aAbs == null && bAbs == null) return 0;
          if (aAbs == null) return 1; // unscheduled → end
          if (bAbs == null) return -1;
          final dc = aAbs.compareTo(bAbs);
          if (dc != 0) return dc;
          if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
          if (a.time != null && b.time != null) {
            return _timeToMinutes(a.time!) - _timeToMinutes(b.time!);
          }
          return 0;
        });
    }
  }

  // ── Sort animation ────────────────────────────────────────────────────────

  /// FLIP-animates each event card to its new position when the sort criteria
  /// change.  Steps:
  ///   1. Snapshot current Y positions of all rendered cards via their GlobalKeys.
  ///   2. Apply the new sort order.
  ///   3. Rebuild invisibly so the list lays out at new positions.
  ///   4. In the post-frame callback, measure new positions, compute per-card
  ///      deltas, and start a single AnimationController that drives all cards
  ///      from their old visual positions to their new ones simultaneously.
  void _animateSortChange() {
    // A live manual drag owns the layout.  Sort changes are discrete parent
    // updates, but a stale didUpdateWidget/post-frame callback must never
    // replace a drag swap with a hidden measurement pass.
    if (_draggingIndex != null) return;

    // 1. Snapshot current (pre-sort) Y positions of every rendered card.
    final preY = <String, double>{};
    for (final e in _itemKeys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        preY[e.key] = box.localToGlobal(Offset.zero).dy;
      }
    }

    // 2. Apply the new sort order.
    _sortAnimCtrl.stop();
    _sortItems();

    // 3. Rebuild invisibly so Flutter lays out the new order without the user
    //    seeing a one-frame flash at the final positions.
    setState(() => _sortMeasuring = true);

    // 4. After the invisible layout pass, measure new positions and animate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The user may have started dragging during the measurement frame.
      // Abort the sort FLIP rather than hiding or translating live drag rows.
      if (_draggingIndex != null) {
        if (_sortMeasuring) {
          setState(() => _sortMeasuring = false);
        }
        return;
      }
      final offsets = <String, double>{};
      for (final e in _itemKeys.entries) {
        final box = e.value.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) continue;
        final oldY = preY[e.key];
        if (oldY == null) continue;
        final newY = box.localToGlobal(Offset.zero).dy;
        final delta = oldY - newY;
        if (delta.abs() > 0.5) offsets[e.key] = delta;
      }

      // Make the list visible again and inject starting offsets.
      setState(() {
        _sortMeasuring = false;
        _sortAnimFromY
          ..clear()
          ..addAll(offsets);
      });

      if (offsets.isEmpty) return;

      // Run the animation: ctrl 0 → 1 means offset → 0 (old position → new).
      _sortAnimCtrl.value = 0.0;
      _sortAnimCtrl.animateTo(1.0, curve: Curves.easeInOut);
    });
  }

  // ── Reorder helpers ───────────────────────────────────────────────────────

  void _startReorder(String eventId, Offset globalPos) {
    // Drag-reorder only available in Manual mode.
    if (widget.sortBy != 'Manual') return;
    if (_draggingIndex != null) return;
    final idx = _items.indexWhere((e) => e.id == eventId);
    if (idx < 0) return;
    _dragEvent = _items[idx];
    _dragGlobalY = globalPos.dy;
    _dragReflowGeneration++;
    // A drag should never inherit a partially completed sort animation.  The
    // sort FLIP is for discrete sort-mode changes, while drag updates are
    // applied directly so the list never enters its hidden measuring frame.
    _sortAnimCtrl.stop();
    _sortAnimCtrl.value = 0.0;
    setState(() {
      _sortAnimFromY.clear();
      _sortMeasuring = false;
      _draggingIndex = idx;
    });

    final ghostEvent = _dragEvent!;
    _dragOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        // Centre the ghost card vertically on the finger.
        top: _dragGlobalY - 36,
        left: 16,
        right: 16,
        child: IgnorePointer(
          child: Transform.scale(
            scale: 1.05,
            child: _DarkModeGhostOutline(
              child: _ScheduledEventCard(
                event: ghostEvent,
                dotColor: _resolveEventDotColor(ctx, ghostEvent),
                elevatedShadow: true,
              ),
            ),
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dragOverlay != null) {
        Overlay.of(context).insert(_dragOverlay!);
      }
    });
  }

  /// Event dots belong to the event's assigned standard category, not to the
  /// DCV currently being viewed. This keeps the dot color stable in Smart
  /// Categories, date-based smart tiles, All Events, and search results.
  Color _resolveEventDotColor(BuildContext context, ScheduledEvent event) {
    const uncategorizedIds = {'', 'uncategorized', 'sys-uncategorized'};
    final categoryId = uncategorizedIds.contains(event.categoryId)
        ? 'sys-uncategorized'
        : event.categoryId;
    final meta = CategoryRegistry.get(categoryId);
    return meta == null
        ? resolveAccentColor(context)
        : renderCategoryColor(meta.rawColor, context);
  }

  void _updateReorder(Offset globalPos) {
    _dragGlobalY = globalPos.dy;
    _dragOverlay?.markNeedsBuild();

    final dragId = _dragEvent?.id;
    if (_draggingIndex == null || dragId == null) return;

    // A DCV with custom sections needs insertion semantics rather than a
    // simple swap: the dragged event moves into the destination section while
    // the destination event stays there.  This also gives empty sections a
    // real drop target via their header/section bounds.
    if (_sectionEventIds.isNotEmpty) {
      final rowTargets = <_DcvDragRowTarget>[];
      for (
        var sectionIndex = 0;
        sectionIndex < _sectionEventIds.length;
        sectionIndex++
      ) {
        for (
          var eventIndex = 0;
          eventIndex < _sectionEventIds[sectionIndex].length;
          eventIndex++
        ) {
          final id = _sectionEventIds[sectionIndex][eventIndex];
          if (id == dragId) continue;
          final box =
              _itemKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.attached) continue;
          final top = box.localToGlobal(Offset.zero).dy;
          rowTargets.add(
            _DcvDragRowTarget(
              sectionIndex: sectionIndex,
              eventIndex: eventIndex,
              top: top,
              bottom: top + box.size.height,
            ),
          );
        }
      }
      rowTargets.sort((a, b) => a.top.compareTo(b.top));

      int? targetSection;
      int? targetIndex;
      _DcvDragRowTarget? rowUnderFinger;
      for (final row in rowTargets) {
        if (globalPos.dy >= row.top && globalPos.dy <= row.bottom) {
          rowUnderFinger = row;
          break;
        }
      }
      if (rowUnderFinger != null) {
        targetSection = rowUnderFinger.sectionIndex;
        targetIndex =
            rowUnderFinger.eventIndex +
            (globalPos.dy > rowUnderFinger.midpoint ? 1 : 0);
      } else {
        // Headers, empty sections, and the gaps between cards are all valid
        // destinations.  Prefer the section whose complete rendered bounds
        // contain the finger.
        for (var i = 0; i < _sectionEventIds.length; i++) {
          final key = _sectionKeys[i];
          final box = key?.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.attached) continue;
          final top = box.localToGlobal(Offset.zero).dy;
          final bottom = top + box.size.height;
          if (globalPos.dy >= top && globalPos.dy <= bottom) {
            targetSection = i;
            final sectionRows = rowTargets
                .where((row) => row.sectionIndex == i)
                .toList();
            if (sectionRows.isEmpty || globalPos.dy < sectionRows.first.top) {
              targetIndex = 0;
            } else {
              targetIndex = _sectionEventIds[i].length;
              for (final row in sectionRows) {
                if (globalPos.dy < row.top) {
                  targetIndex = row.eventIndex;
                  break;
                }
              }
            }
            break;
          }
        }
      }

      final destinationSection = targetSection;
      final destinationIndex = targetIndex;
      if (destinationSection != null && destinationIndex != null) {
        final sourceSection = _sectionEventIds.indexWhere(
          (section) => section.contains(dragId),
        );
        if (sourceSection < 0) return;
        final sourceIndex = _sectionEventIds[sourceSection].indexOf(dragId);
        var insertionIndex =
            destinationIndex.clamp(
                  0,
                  _sectionEventIds[destinationSection].length,
                )
                as int;
        if (sourceSection == destinationSection &&
            sourceIndex < insertionIndex) {
          insertionIndex--;
        }
        if (sourceSection != destinationSection ||
            sourceIndex != insertionIndex) {
          _applyDragSwap(() {
            final source = _sectionEventIds[sourceSection];
            final target = _sectionEventIds[destinationSection];
            source.removeAt(sourceIndex);
            target.insert(insertionIndex.clamp(0, target.length), dragId);
            _syncItemsToSections();
            _draggingIndex = _items.indexWhere((event) => event.id == dragId);
          });
        }
      }
      return;
    }

    // Section-less Manual DCVs retain the original fast adjacent-swap
    // behaviour.
    final currentIdx = _draggingIndex!;
    if (currentIdx > 0) {
      final key = _itemKeys[_items[currentIdx - 1].id];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final top = box.localToGlobal(Offset.zero).dy;
        if (globalPos.dy < top + box.size.height / 2) {
          _applyDragSwap(() {
            final item = _items.removeAt(currentIdx);
            _items.insert(currentIdx - 1, item);
            _draggingIndex = currentIdx - 1;
          });
          return;
        }
      }
    }

    if (currentIdx < _items.length - 1) {
      final key = _itemKeys[_items[currentIdx + 1].id];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final top = box.localToGlobal(Offset.zero).dy;
        if (globalPos.dy > top + box.size.height / 2) {
          _applyDragSwap(() {
            final item = _items.removeAt(currentIdx);
            _items.insert(currentIdx + 1, item);
            _draggingIndex = currentIdx + 1;
          });
        }
      }
    }
  }

  /// Applies one live drag reorder update.
  ///
  /// [doSwap] mutates [_items] and [_draggingIndex] in place.  The mutation is
  /// followed by one rebuild that includes the predicted row offsets, so the
  /// new order never paints without its starting transform.
  ///
  void _applyDragSwap(VoidCallback doSwap) {
    // Keep every live swap independent from the sort FLIP controller.  This
    // also handles a swap that happens immediately after a sort-mode change,
    // before its post-frame measurement callback has completed.
    final beforeY = <String, double>{};
    final beforeHeight = <String, double>{};
    for (final entry in _itemKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        // RenderBox's global transform includes the row's current FLIP
        // transform, so a second rapid swap starts from what is actually on
        // screen rather than from the stale logical slot.
        beforeY[entry.key] = box.localToGlobal(Offset.zero).dy;
        beforeHeight[entry.key] = box.size.height;
      }
    }

    final oldSections = _buildDisplaySections();
    final activeTransform = 1.0 - _sortAnimCtrl.value;
    final logicalY = <String, double>{
      for (final entry in beforeY.entries)
        entry.key:
            entry.value - (_sortAnimFromY[entry.key] ?? 0.0) * activeTransform,
    };

    // Mutate before the rebuild so same-section target slots can be computed
    // synchronously.  This avoids the one-frame "new order, no transform"
    // state that made stationary tiles flash before the post-frame FLIP pass.
    doSwap();

    final newSections = _buildDisplaySections();
    final predictedOffsets = <String, double>{};
    final oldSectionById = <String, int>{};
    final newSectionById = <String, int>{};
    for (
      var sectionIndex = 0;
      sectionIndex < oldSections.length;
      sectionIndex++
    ) {
      for (final event in oldSections[sectionIndex].events) {
        oldSectionById[event.id] = sectionIndex;
      }
    }
    for (
      var sectionIndex = 0;
      sectionIndex < newSections.length;
      sectionIndex++
    ) {
      for (final event in newSections[sectionIndex].events) {
        newSectionById[event.id] = sectionIndex;
      }
    }

    // Direct prediction is safe when the drag stays within one grouped card:
    // section origins do not move, and each row's measured height gives the
    // exact target slot.  Cross-section moves still use the measured fallback
    // below because AnimatedSize may be changing the neighbouring card heights.
    final sameSectionMove =
        oldSections.length == newSections.length &&
        newSectionById.entries.every(
          (entry) => oldSectionById[entry.key] == entry.value,
        );
    if (sameSectionMove) {
      for (
        var sectionIndex = 0;
        sectionIndex < newSections.length;
        sectionIndex++
      ) {
        final oldEvents = oldSections[sectionIndex].events;
        final newEvents = newSections[sectionIndex].events;
        if (oldEvents.isEmpty || newEvents.isEmpty) continue;
        final firstId = oldEvents.first.id;
        final sectionOrigin = logicalY[firstId];
        if (sectionOrigin == null) continue;

        var targetY = sectionOrigin;
        for (final event in newEvents) {
          final visualY = beforeY[event.id];
          if (visualY != null && event.id != _dragEvent?.id) {
            final delta = visualY - targetY;
            if (delta.abs() > 0.5) predictedOffsets[event.id] = delta;
          }
          targetY += beforeHeight[event.id] ?? 0.0;
        }
      }
    }

    // Commit the new order, starting offsets, and animation reset as one
    // visual state change.  In particular, do not clear _sortAnimFromY before
    // resetting the controller: AnimationController notifies its
    // AnimatedBuilders synchronously, and that ordering used to let the newly
    // reordered column paint once with no FLIP transform.
    _sortAnimCtrl.stop();
    setState(() {
      _sortAnimFromY
        ..clear()
        ..addAll(predictedOffsets);
      _sortAnimCtrl.value = 0.0;
    });

    if (predictedOffsets.isNotEmpty) {
      _sortAnimCtrl
          .animateTo(
            1.0,
            duration: _kDragReflowDuration,
            curve: Curves.easeInOutCubic,
          )
          .ignore();
      return;
    }

    if (beforeY.isEmpty) return;

    final generation = ++_dragReflowGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _draggingIndex == null ||
          generation != _dragReflowGeneration) {
        return;
      }

      final offsets = <String, double>{};
      for (final entry in _itemKeys.entries) {
        // The dragged event is rendered in the separate finger-following
        // overlay.  Its in-list placeholder stays hidden; only stationary
        // event tiles should slide around it.
        if (entry.key == _dragEvent?.id) continue;
        final oldY = beforeY[entry.key];
        final box =
            entry.value.currentContext?.findRenderObject() as RenderBox?;
        if (oldY == null || box == null || !box.attached) continue;
        final delta = oldY - box.localToGlobal(Offset.zero).dy;
        if (delta.abs() > 0.5) offsets[entry.key] = delta;
      }

      if (offsets.isEmpty) return;
      setState(() {
        _sortAnimFromY
          ..clear()
          ..addAll(offsets);
      });
      _sortAnimCtrl
          .animateTo(
            1.0,
            duration: _kDragReflowDuration,
            curve: Curves.easeInOutCubic,
          )
          .ignore();
    });
  }

  void _endReorder() {
    _dragReflowGeneration++;
    _sortAnimCtrl.stop();
    _sortAnimCtrl.value = 0.0;
    _sortAnimFromY.clear();
    _dragOverlay?.remove();
    _dragOverlay = null;
    _dragEvent = null;
    setState(() => _draggingIndex = null);
    if (_sectionEventIds.isNotEmpty) {
      widget.onCustomSectionReordered?.call(
        _sectionEventIds.map(List<String>.of).toList(),
      );
    }
  }

  // ── Display-item grouping helpers ────────────────────────────────────────────

  static const _kWeekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _kShortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _kLongMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Priority-level labels indexed by [ScheduledEvent.priority] (0–3).
  static const _kPriorityLabels = [
    'None',
    'Low Priority',
    'Medium Priority',
    'High Priority',
  ];

  /// "Sunday - Aug 9, 2026" from the event's absoluteDate.  Null when there is
  /// no absoluteDate (unscheduled).
  static String? _eventDateLabel(ScheduledEvent e) {
    final abs = e.parsedDate?.absoluteDate;
    if (abs == null) return null;
    return '${_kWeekdays[abs.weekday - 1]} - '
        '${_kShortMonths[abs.month - 1]} ${abs.day}, ${abs.year}';
  }

  /// "August 12, 2026" — date-only header used by Deadline and Creation Date
  /// sort modes.  Returns null when [date] is null.
  static String? _dateOnlyLabel(DateTime? date) {
    if (date == null) return null;
    return '${_kLongMonths[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// "3:00 PM" → minutes since midnight, used for chronological sort.
  static int _timeToMinutes(String t) {
    final sp = t.trim().split(' ');
    if (sp.length < 2) return 0;
    final hm = sp[0].split(':');
    int h = int.tryParse(hm[0]) ?? 0;
    final m = hm.length > 1 ? (int.tryParse(hm[1]) ?? 0) : 0;
    final isPm = sp[1].toUpperCase() == 'PM';
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;
    return h * 60 + m;
  }

  /// Builds the list of [_DcvSection]s for the current sort mode and category.
  ///
  /// Rules:
  ///   • Non-Manual sorts → one section per sort key (date / priority / letter).
  ///   • Unscheduled DCV → single section, no header, user-reorderable.
  ///   • Today / Tomorrow → "All-day" section first, then one per time string.
  ///   • All others (Manual) → optional "Unscheduled" section first, then one
  ///     per calendar day (chronological, all-day events first in day).
  List<_DcvSection> _buildCustomManualSections() {
    final names = widget.customSectionNames;
    final eventsById = {for (final event in _items) event.id: event};
    return [
      for (var i = 0; i < names.length; i++)
        _DcvSection(
          headerText: names[i].trim().isEmpty ? 'New Section' : names[i],
          collapseKey: 'custom-$i',
          isEditable: true,
          customSectionIndex: i,
          events: [
            for (final id
                in _sectionEventIds.length > i
                    ? _sectionEventIds[i]
                    : const <String>[])
              if (eventsById[id] != null) eventsById[id]!,
          ],
        ),
    ];
  }

  List<_DcvSection> _buildDisplaySections() {
    final label = widget.label;

    // ── Non-Manual sorts ──────────────────────────────────────────────────────
    if (widget.sortBy != 'Manual') return _buildSortedDisplaySections();

    // ── Unscheduled: flat single section, no header ───────────────────────────
    if (!widget.showManualDateSections) {
      if (widget.customSectionNames.isNotEmpty) {
        return _buildCustomManualSections();
      }
      return [_DcvSection(events: List.of(_items))];
    }

    if (label == 'Unscheduled') {
      return [_DcvSection(events: List.of(_items))];
    }

    // ── Today / Tomorrow: time-grouped sections ───────────────────────────────
    if (label == 'Today' || label == 'Tomorrow') {
      final allDay = <ScheduledEvent>[];
      final timed = <ScheduledEvent>[];
      for (final e in _items) {
        (e.isAllDay || e.time == null ? allDay : timed).add(e);
      }
      timed.sort((a, b) => _timeToMinutes(a.time!) - _timeToMinutes(b.time!));
      final groups = <String, List<ScheduledEvent>>{};
      for (final e in timed) {
        (groups[e.time!] ??= []).add(e);
      }
      return [
        if (allDay.isNotEmpty)
          _DcvSection(headerText: 'All-day', events: allDay),
        for (final kv in groups.entries)
          _DcvSection(headerText: kv.key, events: kv.value),
      ];
    }

    // ── All other DCVs: date-grouped sections ─────────────────────────────────
    const _noUnscheduled = {
      'Scheduled',
      'Today',
      'Tomorrow',
      'This Week',
      'Next Week',
      'Unscheduled',
    };
    final showUnscheduledSection = !_noUnscheduled.contains(label);

    final unscheduled = <ScheduledEvent>[];
    final scheduled = <ScheduledEvent>[];
    for (final e in _items) {
      (e.parsedDate?.absoluteDate == null ? unscheduled : scheduled).add(e);
    }
    final groups = <String, List<ScheduledEvent>>{};
    for (final e in scheduled) {
      final key = _eventDateLabel(e) ?? e.date ?? 'Unknown';
      (groups[key] ??= []).add(e);
    }
    return [
      if (showUnscheduledSection && unscheduled.isNotEmpty)
        _DcvSection(headerText: 'Unscheduled', events: unscheduled),
      for (final kv in groups.entries)
        _DcvSection(headerText: kv.key, events: kv.value),
    ];
  }

  // ── Non-Manual sort sections ──────────────────────────────────────────────────

  List<_DcvSection> _buildSortedDisplaySections() {
    switch (widget.sortBy) {
      case 'Deadline':
        return _buildGroupedSections(
          keyOf: (e) => _dateOnlyLabel(e.parsedDate?.absoluteDate),
          fallbackLabel: 'No Date',
          fallbackAtEnd: true,
        );
      case 'Creation Date':
        return _buildGroupedSections(
          keyOf: (e) {
            if (e.createdAt == null) return null;
            return _dateOnlyLabel(DateTime.tryParse(e.createdAt!));
          },
          fallbackLabel: 'No Date',
          fallbackAtEnd: true,
        );
      case 'Priority':
        return _buildGroupedSections(
          keyOf: (e) => _kPriorityLabels[e.priority.clamp(0, 3)],
          fallbackLabel: 'None',
          fallbackAtEnd: false,
        );
      case 'Title':
        return _buildGroupedSections(
          keyOf: (e) {
            final trimmed = e.title.trim();
            if (trimmed.isEmpty) return null;
            final ch = trimmed[0].toUpperCase();
            return RegExp(r'^[A-Z]$').hasMatch(ch) ? ch : null;
          },
          fallbackLabel: '#',
          fallbackAtEnd: true,
        );
      default:
        return [_DcvSection(events: List.of(_items))];
    }
  }

  /// Groups [_items] (already in sort order) into [_DcvSection]s.
  /// [keyOf] returns the section key for each event, or null for the fallback.
  /// [fallbackAtEnd] controls whether null-key events go last (true) or inline.
  List<_DcvSection> _buildGroupedSections({
    required String? Function(ScheduledEvent) keyOf,
    required String fallbackLabel,
    bool fallbackAtEnd = true,
  }) {
    final mainSections = <_DcvSection>[];
    final fallbackEvents = <ScheduledEvent>[];

    String? currentKey;
    List<ScheduledEvent>? currentEvents;

    void flushCurrent() {
      if (currentKey != null &&
          currentEvents != null &&
          currentEvents!.isNotEmpty) {
        mainSections.add(
          _DcvSection(headerText: currentKey, events: currentEvents!),
        );
      }
    }

    for (final e in _items) {
      final key = keyOf(e);
      if (key == null) {
        if (fallbackAtEnd) {
          fallbackEvents.add(e);
          continue;
        }
        // Inline fallback: consecutive null-key items share one section.
        if (fallbackLabel != currentKey) {
          flushCurrent();
          currentKey = fallbackLabel;
          currentEvents = [];
        }
        currentEvents!.add(e);
        continue;
      }
      if (key != currentKey) {
        flushCurrent();
        currentKey = key;
        currentEvents = [];
      }
      currentEvents!.add(e);
    }
    flushCurrent();

    if (fallbackEvents.isEmpty) return mainSections;
    return [
      ...mainSections,
      _DcvSection(headerText: fallbackLabel, events: fallbackEvents),
    ];
  }

  // ── Empty-state helpers ───────────────────────────────────────────────────────

  String get _emptyStateSubtitle {
    if (widget.categoryType == 'Shopping List') {
      return 'Items added to this category are automatically\n'
          'categorized into sections.';
    }
    switch (widget.label) {
      case 'Today':
        return 'Events due today will appear here.';
      case 'Tomorrow':
        return 'Events due tomorrow will appear here.';
      case 'This Week':
        return 'Events due this week will appear here.';
      case 'Next Week':
        return 'Events due next week will appear here.';
      case 'Scheduled':
        return 'Events with a date or time will appear here.';
      case 'Unscheduled':
        return 'Events without a date will appear here.';
      case 'All Events':
        return 'All of your events will appear here.';
      case 'Completed':
        return 'Completed events will appear here.';
      default:
        return 'Add a new event by tapping + button';
    }
  }

  // Builds the large icon for the empty-state, matching the icon shown in
  // the tile's blue circle (scaled up, tinted kTertiaryLabel instead of white).
  Widget _buildIcon() {
    // Groceries category type — fixed carrot icon regardless of user's icon.
    if (widget.categoryType == 'Groceries') {
      return FixedSFIcon(
        SFIcons.sf_carrot_fill,
        fontSize: 64,
        color: kEmptyStateIcon,
      );
    }
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final thisMonday = now.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    final nextMonday = thisMonday.add(const Duration(days: 7));

    int? dayNum;
    switch (widget.label) {
      case 'Today':
        dayNum = now.day;
        break;
      case 'Tomorrow':
        dayNum = tomorrow.day;
        break;
      case 'This Week':
        dayNum = _isoWeekNumber(thisMonday);
        break;
      case 'Next Week':
        dayNum = _isoWeekNumber(nextMonday);
        break;
    }

    if (dayNum != null) {
      // Calendar frame + day/week number — mirrors tile layout scaled to 64 px.
      // In the tile: 22 px SVG centred in a 32 px circle, number at top:14
      // in the circle → top:9 within SVG → 9/22 = 40.9 % → top:26 at 64 px.
      return SizedBox(
        key: ValueKey('icon_${widget.label}'),
        width: 64,
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            SvgPicture.asset(
              'assets/icons/calendar_frame.svg',
              colorFilter: const ColorFilter.mode(
                kEmptyStateIcon,
                BlendMode.srcIn,
              ),
            ),
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.scale(
                  scale: 1.05,
                  scaleY: 1.3,
                  child: Text(
                    '$dayNum',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      inherit: false,
                      color: kEmptyStateIcon,
                      fontSize: 27.6, // 9.5 × (64/22) — proportional to tile
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      height: 1.0,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // User category — SVG asset: raw visual icon, no bounding SizedBox.
    if (widget.icon is String) {
      return KeyedSubtree(
        key: ValueKey('icon_${widget.label}'),
        child: _buildDcvCatIcon(widget.icon!, kEmptyStateIcon),
      );
    }
    final IconData iconData;
    bool isUserCategory = false;
    switch (widget.label) {
      case 'Scheduled':
        iconData = CupertinoIcons.calendar;
        break;
      case 'Unscheduled':
        iconData = CupertinoIcons.clock;
        break;
      case 'All Events':
        iconData = CupertinoIcons.tray_fill;
        break;
      case 'Completed':
        iconData = CupertinoIcons.checkmark;
        break;
      default:
        iconData = (widget.icon as IconData?) ?? SFIcons.sf_list_bullet;
        isUserCategory = true;
        break;
    }
    // User category — IconData: raw visual icon, no bounding SizedBox.
    if (isUserCategory) {
      return KeyedSubtree(
        key: ValueKey('icon_${widget.label}'),
        child: _buildDcvCatIcon(iconData, kEmptyStateIcon),
      );
    }
    if (iconData == SFIcons.sf_music_note) {
      return _BeamedNoteIcon(
        key: ValueKey('icon_${widget.label}'),
        size: 64,
        color: kEmptyStateIcon,
      );
    }
    return SearchWeightedIcon(
      key: ValueKey('icon_${widget.label}'),
      iconData,
      size: 64,
      color: kEmptyStateIcon,
    );
  }

  /// Builds one event row inside a grouped section card.
  ///
  /// The [AnimatedBuilder] applies the FLIP sort-animation translation.
  /// [itemKey] is the stable [GlobalKey] used by both the FLIP measurement
  /// pass and the drag-reorder system to read each row's screen position.
  Widget _buildEventRow(
    BuildContext context,
    ScheduledEvent event,
    int index,
    int total,
    bool isReorderable,
    ScheduledEvent? previousEvent,
  ) {
    final itemKey = _itemKeys.putIfAbsent(event.id, () => GlobalKey());
    final isDragging =
        _draggingIndex != null &&
        _items.indexWhere((e) => e.id == event.id) == _draggingIndex;
    // Show a top separator only when the invisible dragging placeholder sits
    // directly above this row inside the same section.  A section boundary is
    // already represented by its header and outer spacing, so the last event
    // in one section must not create a separator above the first event in the
    // next section.
    final hasGapAbove =
        !isDragging &&
        _draggingIndex != null &&
        _dragEvent?.id == previousEvent?.id;

    return AnimatedBuilder(
      animation: _sortAnimCtrl,
      // child is cached by AnimatedBuilder; the GlobalKey lives here so that
      // FLIP position reads work even while the animation is in flight.
      child: KeyedSubtree(
        key: itemKey,
        child: Opacity(
          opacity: isDragging ? 0.0 : 1.0,
          child: _ScheduledEventCard(
            event: event,
            dotColor: _resolveEventDotColor(context, event),
            isGrouped: true,
            isFirst: index == 0,
            isLast: index == total - 1,
            hasGapAbove: hasGapAbove,
            onEdit: widget.onEditEvent != null
                ? () => widget.onEditEvent!(event)
                : null,
            reorderable: isReorderable,
            onReorderStart: isReorderable
                ? (gp) => _startReorder(event.id, gp)
                : null,
            onReorderUpdate: isReorderable ? _updateReorder : null,
            onReorderEnd: isReorderable ? _endReorder : null,
            onReorderCancel: isReorderable ? _endReorder : null,
          ),
        ),
      ),
      builder: (ctx, child) {
        final dy =
            (_sortAnimFromY[event.id] ?? 0.0) * (1.0 - _sortAnimCtrl.value);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    // ── Events/sections present — render section headers + grouped cards ────
    if (_items.isNotEmpty || widget.customSectionNames.isNotEmpty) {
      final displaySections = _buildDisplaySections();
      // Keep the previous visible event within each section.  The drag-gap
      // separator belongs to an in-section gap; carrying the previous event
      // across a section boundary would incorrectly draw a line above every
      // section's first tile while the prior section's last tile is dragged.
      final previousEventById = <String, ScheduledEvent?>{};
      for (final section in displaySections) {
        ScheduledEvent? previousSectionEvent;
        for (final event in section.events) {
          previousEventById[event.id] = previousSectionEvent;
          previousSectionEvent = event;
        }
      }
      // Drag-to-reorder is only available in Manual sort mode.
      final isReorderable = widget.sortBy == 'Manual';
      // During the one invisible layout frame of the FLIP animation, render
      // the list at opacity 0 so the user doesn't see items snap to their new
      // positions before the animation has started. Never apply that
      // measurement frame to a live drag: drag swaps update the list directly.
      final hideForSortMeasurement = _sortMeasuring && _draggingIndex == null;
      return Opacity(
        opacity: hideForSortMeasurement ? 0.0 : 1.0,
        child: CustomScrollView(
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          slivers: [
            SliverPadding(
              // 17.5 px top mirrors the Settings Panel first-section inset;
              // 16 px sides give each card its edge margin; bottom 16 px plus
              // each section's own 16 px bottom padding → 32 px total at end.
              padding: const EdgeInsets.fromLTRB(16, 17.5, 16, 16),
              sliver: SliverList.builder(
                itemCount: displaySections.length,
                itemBuilder: (context, sectionIdx) {
                  final section = displaySections[sectionIdx];
                  final sectionKey = section.collapseKey ?? section.headerText;
                  final isCollapsed =
                      section.headerText != null &&
                      _collapsedSections.contains(sectionKey);
                  final sectionKeyWidget = _sectionKeys.putIfAbsent(
                    sectionIdx,
                    () => GlobalKey(),
                  );

                  return KeyedSubtree(
                    key: sectionKeyWidget,
                    child: Padding(
                      // 16 px gap between consecutive sections (last section
                      // gets the same padding; SliverPadding.bottom adds another
                      // 16 so the final gap is 32 px, matching the old layout).
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Section header ─────────────────────────────────
                          if (section.headerText != null)
                            section.isEditable
                                ? _SwipeToRevealDelete(
                                    iconSize: MediaQuery.textScalerOf(
                                      context,
                                    ).scale(15),
                                    deleteIconVerticalOffset: -4,
                                    onDelete: () {
                                      final index = section.customSectionIndex;
                                      if (index != null) {
                                        widget.onCustomSectionDeleted?.call(
                                          index,
                                        );
                                      }
                                    },
                                    child: _DcvEditableSectionLabel(
                                      initialText: section.headerText!,
                                      // isFirst controls top padding: 0 for
                                      // the first section (SliverPadding
                                      // provides the DCV header gap).
                                      isFirst: true,
                                      isCollapsed: isCollapsed,
                                      accentColor: widget.color,
                                      onToggle: () =>
                                          _toggleSection(sectionKey!),
                                      onChanged: (title) {
                                        final index =
                                            section.customSectionIndex;
                                        if (index != null) {
                                          widget.onCustomSectionEditingChanged
                                              ?.call(index, title);
                                        }
                                      },
                                      onSubmitted: (title) {
                                        final index =
                                            section.customSectionIndex;
                                        if (index != null) {
                                          widget.onCustomSectionRenamed?.call(
                                            index,
                                            title,
                                          );
                                        }
                                      },
                                    ),
                                  )
                                : _DcvSectionLabel(
                                    text: section.headerText!,
                                    // isFirst controls top padding: 0 for first
                                    // section (SliverPadding provides gap from
                                    // DCV header), also 0 for others (section
                                    // bottom padding provides inter-section gap).
                                    isFirst: true,
                                    isCollapsed: isCollapsed,
                                    accentColor: widget.color,
                                    onTap: () => _toggleSection(sectionKey!),
                                  ),

                          // ── Grouped event card (collapses as one unit) ─────
                          // AnimatedSize smoothly animates the group to zero
                          // height when the section header is tapped.
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            child: isCollapsed
                                ? const SizedBox.shrink()
                                : Container(
                                    // clipBehavior clips children to the squircle
                                    // shape so press highlights stay within bounds.
                                    clipBehavior: Clip.antiAlias,
                                    decoration: ShapeDecoration(
                                      color: resolveThemeColor(
                                        kSbSurface,
                                        context,
                                      ),
                                      shape: BoundedContinuousRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          _kCornerRadius,
                                        ),
                                      ),
                                      shadows: resolveThemeShadows(
                                        kCardShadow,
                                        context,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        for (
                                          int ei = 0;
                                          ei < section.events.length;
                                          ei++
                                        )
                                          _buildEventRow(
                                            context,
                                            section.events[ei],
                                            ei,
                                            section.events.length,
                                            isReorderable,
                                            previousEventById[section
                                                .events[ei]
                                                .id],
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // ── No events — show empty state ───────────────────────────────────────
    // Plain SizedBox.expand avoids the multi-pass scroll-geometry layout of
    // CustomScrollView + SliverFillRemaining, which could cause a one-frame
    // positional flash on Flutter web before the sliver settled to center.
    final content = Center(
      key: ValueKey('placeholder_${widget.label}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(child: _buildIcon()),
          SizedBox(height: 18),
          Text(
            widget.categoryType == 'Shopping List'
                ? 'Add Shopping Items'
                : 'No Events',
            textAlign: TextAlign.center,
            style: TextStyle(
              inherit: false,
              color: primaryLabel,
              fontSize: 22,
              fontFamily: kSFProDisplay,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
              letterSpacing: -0.3,
              height: 1.15,
            ),
          ),
          SizedBox(height: 6),
          Text(
            _emptyStateSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              inherit: false,
              color: secondaryLabel,
              fontSize: 15,
              fontFamily: kSFProText,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.normal,
              letterSpacing: kTracking16,
              height: kLineHeight,
            ),
          ),
        ],
      ),
    );
    // On web a CustomScrollView causes a one-frame positional flash before
    // the sliver geometry settles; SizedBox.expand sidesteps that entirely.
    //
    // On native, rubber-band overscroll feel is only needed when the DCV is
    // actually visible (label is not empty).  When label is empty the DCV is
    // always off-screen (controller value == 0, wrapped in IgnorePointer).
    // Keeping a CustomScrollView alive in that state registers drag gesture
    // recognizers that can win the gesture arena even through IgnorePointer's
    // hit-test exclusion, ultimately calling primaryFocus?.unfocus() and
    // dismissing the search keyboard.  Using SizedBox.expand eliminates all
    // gesture recognizers entirely, matching the Notes Tab's clean structure.
    if (kIsWeb || widget.label.isEmpty) return SizedBox.expand(child: content);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      slivers: [SliverFillRemaining(hasScrollBody: false, child: content)],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event context menu — long-press overlay for event cards.
// Supports press-animation (shrink + bloom) and optional drag-to-reorder,
// mirroring _CategoryContextMenu.
// ─────────────────────────────────────────────────────────────────────────────
class _EventContextMenu extends StatefulWidget {
  final Widget child;
  final WidgetBuilder previewBuilder;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// When true, long-press-then-move triggers drag-to-reorder; long-press
  /// without movement shows the context menu.  Mirrors the disambiguation
  /// logic in [_CategoryContextMenu].
  final bool reorderable;
  final void Function(Offset globalPosition)? onReorderStart;
  final void Function(Offset globalPosition)? onReorderUpdate;
  final VoidCallback? onReorderEnd;
  final VoidCallback? onReorderCancel;

  const _EventContextMenu({
    required this.child,
    required this.previewBuilder,
    this.onEdit,
    this.onDelete,
    this.reorderable = false,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
  });

  @override
  State<_EventContextMenu> createState() => _EventContextMenuState();
}

class _EventContextMenuState extends State<_EventContextMenu>
    with TickerProviderStateMixin {
  late final AnimationController _overlayCtrl = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 1.5,
  );
  final ValueNotifier<bool> _isClosing = ValueNotifier(false);
  OverlayEntry? _entry;
  OverlayEntry? _closingEntry;

  // ── Drag-reorder disambiguation (mirrors _CategoryContextMenu) ────────────
  static const double _kReorderSlop = 10.0;
  static const int _kMenuDelayMs = 250;
  Offset? _pressStartGlobal;
  bool _reorderActive = false;
  Timer? _menuShowTimer;

  // ── Press (shrink) + lift (drag-elevation) controllers ───────────────────
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    lowerBound: 0.0,
    upperBound: 1.0,
  );
  late final AnimationController _liftCtrl = AnimationController(
    vsync: this,
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    final wasMidClose = _closingEntry != null;
    _closingEntry?.remove();
    _closingEntry = null;
    if (sbContextMenuDismiss.value == _hide) {
      sbContextMenuDismiss.value = null;
      sbContextMenuActive.value = false;
    } else if (wasMidClose) {
      sbContextMenuActive.value = false;
    }
    _menuShowTimer?.cancel();
    _menuShowTimer = null;
    _isClosing.dispose();
    _overlayCtrl.dispose();
    _pressCtrl.dispose();
    _liftCtrl.dispose();
    super.dispose();
  }

  void _show() {
    if (_entry != null) return;
    if (sbContextMenuActive.value) return;
    sbContextMenuActive.value = true;
    sbContextMenuDismiss.value = _hide;
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    _isClosing.value = false;
    _overlayCtrl.value = 0;
    _entry = OverlayEntry(
      builder: (ctx) => _ContextMenuOverlay(
        animation: _overlayCtrl,
        isClosing: _isClosing,
        originalOffset: offset,
        originalSize: size,
        previewBuilder: widget.previewBuilder,
        isSmartCategory: false,
        isPinned: false,
        isEvent: true,
        onDismiss: _hide,
        onEdit: widget.onEdit != null ? () => _hide(then: widget.onEdit) : null,
        onDelete: widget.onDelete != null
            ? () => _hide(then: widget.onDelete)
            : null,
      ),
    );
    Overlay.of(context).insert(_entry!);
    _overlayCtrl.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1.0,
          stiffness: 460.0,
          ratio: 0.68,
        ),
        0,
        1,
        0,
      ),
    );
  }

  void _hide({VoidCallback? then}) {
    sbContextMenuDismiss.value = null;
    final entry = _entry;
    _entry = null;
    if (entry == null) {
      then?.call();
      return;
    }
    _closingEntry = entry;
    _isClosing.value = true;
    void cleanup() {
      _closingEntry = null;
      sbContextMenuActive.value = false;
      entry.remove();
      then?.call();
    }

    _overlayCtrl
        .animateTo(
          0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeIn,
        )
        .then((_) => cleanup(), onError: (_) => cleanup());
  }

  // ── Long-press + movement disambiguation ──────────────────────────────────

  void _onLongPressStart(LongPressStartDetails d) {
    _pressStartGlobal = d.globalPosition;
    _reorderActive = false;
    if (!widget.reorderable) {
      _show();
      return;
    }
    // Start a short timer; if the finger moves before it fires → drag mode.
    _menuShowTimer = Timer(const Duration(milliseconds: _kMenuDelayMs), () {
      _menuShowTimer = null;
      if (!_reorderActive && mounted) _show();
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (!widget.reorderable) return;
    if (_reorderActive) {
      widget.onReorderUpdate?.call(d.globalPosition);
      return;
    }
    if (_entry != null || _closingEntry != null) return;
    final start = _pressStartGlobal;
    if (start == null) return;
    if ((d.globalPosition - start).distance >= _kReorderSlop) {
      _menuShowTimer?.cancel();
      _menuShowTimer = null;
      _reorderActive = true;
      _pressCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
      _liftCtrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      widget.onReorderStart?.call(d.globalPosition);
    }
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    _menuShowTimer?.cancel();
    _menuShowTimer = null;
    if (_reorderActive) {
      _reorderActive = false;
      _liftCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
      widget.onReorderEnd?.call();
    }
  }

  void _onLongPressCancel() {
    _menuShowTimer?.cancel();
    _menuShowTimer = null;
    if (_reorderActive) {
      _reorderActive = false;
      _liftCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
      widget.onReorderCancel?.call();
    }
  }

  // ── Tap feedback (press-and-release squish) ───────────────────────────────

  void _onTapDown(TapDownDetails _) {
    _pressCtrl.stop();
    _pressCtrl.value = 0.0;
    _pressCtrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 60),
      curve: Curves.easeOut,
    );
  }

  void _onTapCancel() {
    _pressCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      onTapDown: _onTapDown,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _liftCtrl,
        builder: (context, child) =>
            Transform.scale(scale: 1.0 + 0.05 * _liftCtrl.value, child: child),
        // _TilePress broadcasts _pressCtrl so _TilePressScale inside
        // _buildCard shrinks the card content on press / long-press.
        child: _TilePress(press: _pressCtrl, child: widget.child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scheduled event card — Events tab, AI-extracted events section
// ─────────────────────────────────────────────────────────────────────────────
class _ScheduledEventCard extends StatelessWidget {
  final ScheduledEvent event;

  /// Optional resolved category color for the event dot.
  /// Null falls back to the app accent color.
  final Color? dotColor;

  /// Called when the user selects "Edit Event" from the long-press menu.
  final VoidCallback? onEdit;

  /// When true the card participates in long-press drag-to-reorder (e.g. in
  /// the Category Detail View).  The callbacks mirror [_CategoryContextMenu].
  final bool reorderable;
  final void Function(Offset globalPosition)? onReorderStart;
  final void Function(Offset globalPosition)? onReorderUpdate;
  final VoidCallback? onReorderEnd;
  final VoidCallback? onReorderCancel;

  /// When true the card is rendered inside a shared grouped-card container
  /// (see [_CategoryDetailViewState._buildEventRow]).  The outer container
  /// provides the surface colour, corner-radius clip, and drop shadow, so
  /// this card renders content only (no decoration of its own).
  ///
  /// [isFirst] / [isLast] are unused in the current rendering path but are
  /// kept as named parameters so callers can be self-documenting.
  final bool isGrouped;
  final bool isFirst;
  final bool isLast;

  /// True when the invisible dragging placeholder sits directly above this row.
  /// Causes a top separator to be painted so the line that was between the
  /// dragging tile and this row remains visible — matching the [hasGapAbove]
  /// rule in [_CategoryRow._buildRowContent].
  final bool hasGapAbove;

  /// When true the standalone card uses the larger lifted drop shadow
  /// (blurRadius 18, offset 0×6) instead of [kCardShadow].  Used for the
  /// drag-reorder ghost overlay so the lifted tile looks elevated.
  final bool elevatedShadow;

  const _ScheduledEventCard({
    required this.event,
    this.dotColor,
    this.onEdit,
    this.reorderable = false,
    this.onReorderStart,
    this.onReorderUpdate,
    this.onReorderEnd,
    this.onReorderCancel,
    this.isGrouped = false,
    this.isFirst = true,
    this.isLast = true,
    this.hasGapAbove = false,
    this.elevatedShadow = false,
  });

  /// Converts "August 8, 2026" → "08/08/2026".
  /// Returns [raw] unchanged if the format is not recognised.
  static String _formatDate(String raw) {
    const months = {
      'January': '01',
      'February': '02',
      'March': '03',
      'April': '04',
      'May': '05',
      'June': '06',
      'July': '07',
      'August': '08',
      'September': '09',
      'October': '10',
      'November': '11',
      'December': '12',
    };
    final parts = raw.split(' ');
    if (parts.length < 3) return raw;
    final mm = months[parts[0]];
    final dd = parts[1].replaceAll(',', '').padLeft(2, '0');
    final yyyy = parts[2];
    if (mm == null) return raw;
    return '$mm/$dd/$yyyy';
  }

  // ── Content helpers ──────────────────────────────────────────────────────────

  String _subtitle(BuildContext context) {
    final String? dateStr;
    if (event.date == null) {
      dateStr = null;
    } else {
      final abs = event.parsedDate?.absoluteDate;
      if (abs != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final absDay = DateTime(abs.year, abs.month, abs.day);
        if (absDay == today)
          dateStr = 'Today';
        else if (absDay == tomorrow)
          dateStr = 'Tomorrow';
        else
          dateStr = _formatDate(event.date!);
      } else {
        dateStr = _formatDate(event.date!);
      }
    }
    final String? timeStr;
    if (event.isAllDay) {
      timeStr = 'ALL-DAY';
    } else if (event.time != null) {
      timeStr = event.endTime != null
          ? '${event.time!} - ${event.endTime!}'
          : event.time!;
    } else {
      timeStr = null;
    }
    final parts = [if (dateStr != null) dateStr, if (timeStr != null) timeStr];
    return parts.isEmpty ? 'UNSCHEDULED' : parts.join('  ·  ');
  }

  /// Inner content row (title + subtitle + location), shared by all render modes.
  /// When [isGrouped] and not [isLast], a 0.5 px separator is painted at the
  /// bottom so it travels with the row during FLIP / drag animation — matching
  /// the rule used by [_CategoryRow._buildRowContent].
  Widget _buildContent(BuildContext context) {
    final sub = _subtitle(context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top separator when the invisible dragging placeholder sits directly
        // above this row — keeps the hairline visible during reorder.
        if (isGrouped && hasGapAbove)
          Container(height: 0.5, color: separatorColor),
        _TilePressScale(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor ?? resolveAccentColor(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          inherit: false,
                          color: resolveThemeColor(kPrimaryLabel, context),
                          fontSize: 17,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
                          letterSpacing: kTracking16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sub.toUpperCase(),
                        style: TextStyle(
                          inherit: false,
                          color: resolveThemeColor(kSecondaryLabel, context),
                          fontSize: 13,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
                          letterSpacing: kTracking16,
                        ),
                      ),
                      if (event.location != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_fill,
                              size: 11,
                              color: resolveThemeColor(
                                kSecondaryLabel,
                                context,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                event.location!.toUpperCase(),
                                style: TextStyle(
                                  inherit: false,
                                  color: resolveThemeColor(
                                    kSecondaryLabel,
                                    context,
                                  ),
                                  fontSize: 13,
                                  fontFamily: kSFProText,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.normal,
                                  letterSpacing: kTracking16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Separator travels with the row during FLIP / drag — only shown
        // between grouped rows, never after the last one.
        if (isGrouped && !isLast) Container(height: 0.5, color: separatorColor),
      ],
    );
  }

  /// Full standalone card: squircle background + drop shadow.
  /// Used as the drag-ghost, as the context-menu preview, and for cards
  /// rendered outside the grouped-card container (e.g. standalone usage).
  Widget _buildCard(BuildContext context) {
    // Lifted ghost uses a larger shadow to simulate elevation.
    final shadows = elevatedShadow
        ? resolveThemeShadows(const [
            BoxShadow(
              color: Color(0x3A000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ], context)
        : resolveThemeShadows(kCardShadow, context);
    return Container(
      decoration: ShapeDecoration(
        color: resolveThemeColor(kSbSurface, context),
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
        ),
        shadows: shadows,
      ),
      child: _buildContent(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EventContextMenu(
      // Preview is always the full standalone card regardless of isGrouped,
      // so the drag ghost looks correct even when the card is inside a group.
      previewBuilder: _buildCard,
      onEdit: onEdit,
      onDelete: () => EventStore.instance.remove(event.id),
      reorderable: reorderable,
      onReorderStart: onReorderStart,
      onReorderUpdate: onReorderUpdate,
      onReorderEnd: onReorderEnd,
      onReorderCancel: onReorderCancel,
      // Grouped cards let the outer section container paint the surface and
      // shadow; only the content row is rendered here.
      child: isGrouped ? _buildContent(context) : _buildCard(context),
    );
  }
}

// ── Folder icon rendered with sub-pixel offsets to simulate ~0.5 px
// thicker strokes — used inside blue circles for Unnamed / Uncategorized.
class _ThickFolderIcon extends StatelessWidget {
  const _ThickFolderIcon();

  static const _offsets = [
    Offset.zero,
    Offset(-0.03, -0.03),
    Offset(0.03, -0.03),
    Offset(-0.03, 0.03),
    Offset(0.03, 0.03),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        for (final o in _offsets)
          Transform.translate(
            offset: o,
            child: const Icon(
              CupertinoIcons.folder,
              color: Color(0xFFFFFFFF),
              size: 20,
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Repeat Sheet
// Third layer of the modal stack: Main app → New/Edit Category → Custom Repeat.
// ─────────────────────────────────────────────────────────────────────────────

// ── Custom repeat transfer objects ───────────────────────────────────────────

class _CustomRepeatConfig {
  final String frequency;
  final int everyCount;
  final Set<String> selectedDays;
  final String monthlyMode;
  final Set<int> selectedDates;
  final int onThePositionIndex;
  final int onTheDayIndex;
  final Set<int> selectedMonths;
  final bool yearlyDaysEnabled;
  final int yearlyPositionIndex;
  final int yearlyDayIndex;
  const _CustomRepeatConfig({
    this.frequency = 'Daily',
    this.everyCount = 1,
    this.selectedDays = const {},
    this.monthlyMode = 'Each',
    this.selectedDates = const {},
    this.onThePositionIndex = 0,
    this.onTheDayIndex = 0,
    this.selectedMonths = const {},
    this.yearlyDaysEnabled = false,
    this.yearlyPositionIndex = 0,
    this.yearlyDayIndex = 0,
  });
}

class _CustomRepeatResult {
  final String label;
  final _CustomRepeatConfig config;
  const _CustomRepeatResult(this.label, this.config);
}

// ─────────────────────────────────────────────────────────────────────────────

class _CustomRepeatSheet extends StatefulWidget {
  final Color accentColor;
  final _CustomRepeatConfig? config;
  const _CustomRepeatSheet({required this.accentColor, this.config});

  @override
  State<_CustomRepeatSheet> createState() => _CustomRepeatSheetState();
}

class _CustomRepeatSheetState extends State<_CustomRepeatSheet>
    with TickerProviderStateMixin {
  // ── Frequency state ───────────────────────────────────────────────────────
  String _frequency = 'Daily';

  static const List<String> _kFrequencyOptions = [
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  // Singular unit label per frequency (count == 1).
  static const Map<String, String> _kFrequencyUnit = {
    'Daily': 'Day',
    'Weekly': 'Week',
    'Monthly': 'Month',
    'Yearly': 'Year',
  };

  // Plural unit label per frequency (count >= 2).
  static const Map<String, String> _kFrequencyUnitPlural = {
    'Daily': 'Days',
    'Weekly': 'Weeks',
    'Monthly': 'Months',
    'Yearly': 'Years',
  };

  // Returns the correct singular/plural unit for the current state.
  String get _everyUnit => _everyCount == 1
      ? _kFrequencyUnit[_frequency]!
      : _kFrequencyUnitPlural[_frequency]!;

  // ── Weekly day-selection state ────────────────────────────────────────────
  static const List<String> _kDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final Set<String> _selectedDays = {};

  // ── Monthly mode state ────────────────────────────────────────────────────
  static const List<String> _kPositions = [
    'first',
    'second',
    'third',
    'fourth',
    'fifth',
    'last',
  ];
  String _monthlyMode = 'Each'; // 'Each' | 'OnThe'
  final Set<int> _selectedDates = {};
  int _onThePositionIndex = 0;
  int _onTheDayIndex = 0;
  late final FixedExtentScrollController _onThePositionCtrl;
  late final FixedExtentScrollController _onTheDayCtrl;

  // ── Yearly state ──────────────────────────────────────────────────────────
  static const List<String> _kMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const List<String> _kMonthsFull = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final Set<int> _selectedMonths = {}; // 1-indexed (1=Jan … 12=Dec)
  bool _yearlyDaysEnabled = false;
  int _yearlyPositionIndex = 0;
  int _yearlyDayIndex = 0;
  late final FixedExtentScrollController _yearlyPositionCtrl;
  late final FixedExtentScrollController _yearlyDayCtrl;
  late final AnimationController _yearlyDaysCtrl;

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  // Returns days in calendar order (Mon→Sun).
  List<String> get _orderedSelectedDays =>
      _kDays.where(_selectedDays.contains).toList();

  // Oxford-comma join: "A", "A and B", "A, B, and C".
  static String _joinDays(List<String> days) {
    if (days.length == 1) return days[0];
    if (days.length == 2) return '${days[0]} and ${days[1]}';
    return '${days.take(days.length - 1).join(', ')}, and ${days.last}';
  }

  // Static context footer — always visible below Card 1, reflects live state.
  String get _footerText {
    final unit = _everyUnit.toLowerCase();
    final every = _everyCount == 1
        ? 'every $unit'
        : 'every $_everyCount ${unit}';
    if (_frequency == 'Weekly' && _selectedDays.isNotEmpty) {
      return 'Event will occur $every on ${_joinDays(_orderedSelectedDays)}.';
    }
    if (_frequency == 'Monthly') {
      if (_monthlyMode == 'Each' && _selectedDates.isNotEmpty) {
        final sorted = _selectedDates.toList()..sort();
        final ordinals = sorted.map(_ordinal).toList();
        return 'Event will occur $every on the ${_joinDays(ordinals)}.';
      }
      if (_monthlyMode == 'OnThe') {
        final pos = _kPositions[_onThePositionIndex];
        final day = _kDays[_onTheDayIndex];
        return 'Event will occur $every on the $pos $day.';
      }
    }
    if (_frequency == 'Yearly') {
      final sortedMonths = _selectedMonths.toList()..sort();
      final monthNames = sortedMonths.map((i) => _kMonthsFull[i - 1]).toList();
      final String base = monthNames.isEmpty
          ? 'Event will occur $every'
          : 'Event will occur $every in ${_joinDays(monthNames)}';
      if (_yearlyDaysEnabled) {
        final pos = _kPositions[_yearlyPositionIndex];
        final day = _kDays[_yearlyDayIndex];
        return '$base on the $pos $day.';
      }
      return '$base.';
    }
    return 'Event will occur $every.';
  }

  // ── Every subcard state ───────────────────────────────────────────────────
  int _everyCount = 1;
  late final FixedExtentScrollController _everyCountCtrl;
  late final AnimationController _everyPickerCtrl;

  // ── Picker overlay (mirrors parent sheet's picker machinery) ──────────────
  final _pickerIsClosing = ValueNotifier<bool>(false);
  OverlayEntry? _pickerEntry;
  bool _pickerMenuOpen = false;
  String? _openPickerLabel;

  @override
  void initState() {
    super.initState();
    // Restore state from a previously saved config (if reopening Custom).
    final c = widget.config;
    if (c != null) {
      _frequency = c.frequency;
      _everyCount = c.everyCount;
      _selectedDays.addAll(c.selectedDays);
      _monthlyMode = c.monthlyMode;
      _selectedDates.addAll(c.selectedDates);
      _onThePositionIndex = c.onThePositionIndex;
      _onTheDayIndex = c.onTheDayIndex;
      _selectedMonths.addAll(c.selectedMonths);
      _yearlyDaysEnabled = c.yearlyDaysEnabled;
      _yearlyPositionIndex = c.yearlyPositionIndex;
      _yearlyDayIndex = c.yearlyDayIndex;
    }
    _everyCountCtrl = FixedExtentScrollController(initialItem: _everyCount - 1);
    _onThePositionCtrl = FixedExtentScrollController(
      initialItem: _onThePositionIndex,
    );
    _onTheDayCtrl = FixedExtentScrollController(initialItem: _onTheDayIndex);
    _yearlyPositionCtrl = FixedExtentScrollController(
      initialItem: _yearlyPositionIndex,
    );
    _yearlyDayCtrl = FixedExtentScrollController(initialItem: _yearlyDayIndex);
    _everyPickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _yearlyDaysCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _yearlyDaysEnabled ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _everyCountCtrl.dispose();
    _onThePositionCtrl.dispose();
    _onTheDayCtrl.dispose();
    _yearlyPositionCtrl.dispose();
    _yearlyDayCtrl.dispose();
    _everyPickerCtrl.dispose();
    _yearlyDaysCtrl.dispose();
    _pickerIsClosing.dispose();
    _pickerEntry?.remove();
    super.dispose();
  }

  void _toggleEveryPicker() {
    if (_everyPickerCtrl.isDismissed) {
      _everyPickerCtrl.forward();
    } else {
      _everyPickerCtrl.reverse();
    }
  }

  void _dismissPickerOverlay({bool animate = true}) {
    if (!_pickerMenuOpen) return;
    _pickerIsClosing.value = true;
    if (mounted) setState(() => _openPickerLabel = null);
    final delay = animate ? const Duration(milliseconds: 420) : Duration.zero;
    Future.delayed(delay, () {
      _pickerEntry?.remove();
      _pickerEntry = null;
      if (mounted) {
        _pickerIsClosing.value = false;
        setState(() => _pickerMenuOpen = false);
      }
    });
  }

  void _showPickerOverlay(
    BuildContext rowCtx,
    String rowLabel,
    List<ActionItem> items,
  ) {
    if (_pickerMenuOpen) _dismissPickerOverlay(animate: false);
    FocusManager.instance.primaryFocus?.unfocus();
    final box = rowCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _pickerIsClosing.value = false;
    setState(() {
      _pickerMenuOpen = true;
      _openPickerLabel = rowLabel;
    });
    _pickerEntry = OverlayEntry(
      builder: (ctx) => ActionMenuOverlay(
        buttonRect: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
        isClosing: _pickerIsClosing,
        onDismiss: _dismissPickerOverlay,
        actions: items,
        panelWidth: kPickerPanelWidth,
        chevronColumn: true,
        anchorToRight: true,
        labelFontSize: 15,
        bouncingScroll: true, // modal-sheet mini panels retain rubberband
      ),
    );
    Overlay.of(context).insert(_pickerEntry!);
  }

  List<ActionItem> _makeItems(
    List<String> options,
    String current,
    void Function(String) onSelect, {
    Color? checkmarkColor,
  }) => options
      .map(
        (label) => ActionItem(
          label: label,
          icon: SFIcons.sf_circle,
          iconBuilder: (_) => const SizedBox.shrink(),
          checkmark: label == current,
          checkmarkColor: checkmarkColor,
          onTap: () {
            onSelect(label);
            Future.delayed(
              const Duration(milliseconds: 80),
              _dismissPickerOverlay,
            );
          },
        ),
      )
      .toList();

  // ── Local card / row helpers (match parent sheet's visual language) ────────

  TextStyle get _kRowLabelStyle => TextStyle(
    inherit: false,
    color: resolveThemeColor(kPrimaryLabel, context),
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  TextStyle get _kRowValueStyle => TextStyle(
    inherit: false,
    color: resolveThemeColor(kSecondaryLabel, context),
    fontSize: 15,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  TextStyle get _kPickerItemStyle => TextStyle(
    inherit: false,
    color: resolveThemeColor(kPrimaryLabel, context),
    fontSize: 16,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
  );

  Widget _card(List<Widget> rows) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(kCardCornerRadius),
        ),
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _cardWithRadius(List<Widget> rows, BorderRadius radius) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: BoundedContinuousRectangleBorder(borderRadius: radius),
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _sep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      height: 0.5,
      color: resolveThemeColor(kSeparatorColor, context),
    ),
  );

  Widget _pickerRow(
    String label,
    String value, {
    List<ActionItem>? items,
    bool showChevron = true,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final isOpen = items != null && _openPickerLabel == label;
    final TextStyle valueStyle = valueColor != null
        ? _kRowValueStyle.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          )
        : _kRowValueStyle;
    // Keep the value/chevron in the same fixed trailing slot as the parent
    // event sheet and every other modal-sheet picker row.
    return Builder(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: items != null
            ? () => _showPickerOverlay(ctx, label, items)
            : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: MinGapLabelValueRow(
            label: label,
            labelStyle: _kRowLabelStyle,
            value: value,
            valueStyle: valueStyle,
            trailing: AnimatedOpacity(
              opacity: isOpen ? kPickerRowOpenDimOpacity : 1.0,
              duration: const Duration(milliseconds: 150),
              child: ModalSheetPickerTrailing(
                value: value,
                style: valueStyle,
                chevronColor: resolveThemeColor(kSecondaryLabel, context),
                showChevron: showChevron,
              ),
            ),
            trailingExtraWidth: showChevron ? 16 : 0,
          ),
        ),
      ),
    );
  }

  // ── Every drum-picker subcard ─────────────────────────────────────────────

  Widget _buildEverySubcard() => SizeTransition(
    sizeFactor: _everyPickerCtrl,
    axisAlignment: 1.0,
    child: _cardWithRadius(
      [
        _sep(),
        SizedBox(
          height: 216,
          // Expanded columns keep the shared selection pill full-width.
          // Items are edge-aligned toward the column boundary so the number and
          // unit word appear close together in the centre of the picker.
          child: Row(
            children: [
              // Left barrel: numbers 1–999 — right-aligned toward the dividing line.
              // capEndEdge:false so the selection pill merges with the right barrel.
              Expanded(
                child: CupertinoPicker(
                  scrollController: _everyCountCtrl,
                  itemExtent: 32.0,
                  backgroundColor: CupertinoColors.transparent,
                  useMagnifier: true,
                  magnification: 2.35 / 2.1,
                  squeeze: 1.25,
                  offAxisFraction: -0.45,
                  selectionOverlay:
                      const CupertinoPickerDefaultSelectionOverlay(
                        capStartEdge: true,
                        capEndEdge: false,
                      ),
                  onSelectedItemChanged: (i) =>
                      setState(() => _everyCount = i + 1),
                  children: List.generate(
                    999,
                    (i) => Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Text('${i + 1}', style: _kPickerItemStyle),
                      ),
                    ),
                  ),
                ),
              ),
              // Right barrel: unit word — left-aligned toward the dividing line.
              // capStartEdge:false so the selection pill continues from the left barrel.
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32.0,
                  backgroundColor: CupertinoColors.transparent,
                  useMagnifier: true,
                  magnification: 2.35 / 2.1,
                  squeeze: 1.25,
                  offAxisFraction: 0.45,
                  selectionOverlay:
                      const CupertinoPickerDefaultSelectionOverlay(
                        capStartEdge: false,
                        capEndEdge: true,
                      ),
                  onSelectedItemChanged: (_) {},
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Text(_everyUnit, style: _kPickerItemStyle),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      const BorderRadius.only(
        bottomLeft: Radius.circular(kCardCornerRadius),
        bottomRight: Radius.circular(kCardCornerRadius),
      ),
    ),
  );

  // ── Weekly day-selection card (Card 2) ───────────────────────────────────

  Widget _dayRow(String day) {
    final selected = _selectedDays.contains(day);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (selected) {
          _selectedDays.remove(day);
        } else {
          _selectedDays.add(day);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(day, style: _kRowLabelStyle),
            const Spacer(),
            if (selected)
              FixedSFIcon(
                SFIcons.sf_checkmark,
                fontSize: 17,
                color: widget.accentColor,
                fontWeight: FontWeight.w600,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDaysCard() => _card([
    for (int i = 0; i < _kDays.length; i++) ...[
      if (i > 0) _sep(),
      _dayRow(_kDays[i]),
    ],
  ]);

  // ── Monthly — unified card (mode selector + sub-content) ─────────────────

  Widget _buildMonthlyUnifiedCard() => _card([
    _monthlyModeRow('Each', 'Each'),
    _sep(),
    _monthlyModeRow('On the\u2026', 'OnThe'),
    _sep(),
    if (_monthlyMode == 'Each') ...[
      for (int row = 0; row < 5; row++) ...[
        if (row > 0)
          Container(
            height: 0.5,
            color: resolveThemeColor(kSeparatorColor, context),
          ),
        SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int col = 0; col < 7; col++) ...[
                if (col > 0)
                  Container(
                    width: 0.5,
                    color: resolveThemeColor(kSeparatorColor, context),
                  ),
                Expanded(child: _dateCell(row * 7 + col + 1)),
              ],
            ],
          ),
        ),
      ],
    ] else ...[
      SizedBox(
        height: 216,
        child: Row(
          children: [
            Expanded(
              child: CupertinoPicker(
                scrollController: _onThePositionCtrl,
                itemExtent: 32.0,
                backgroundColor: CupertinoColors.transparent,
                useMagnifier: true,
                magnification: 2.35 / 2.1,
                squeeze: 1.25,
                offAxisFraction: -0.45,
                selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                  capStartEdge: true,
                  capEndEdge: false,
                ),
                onSelectedItemChanged: (i) =>
                    setState(() => _onThePositionIndex = i),
                children: _kPositions
                    .map(
                      (p) => Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Text(p, style: _kPickerItemStyle),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: _onTheDayCtrl,
                itemExtent: 32.0,
                backgroundColor: CupertinoColors.transparent,
                useMagnifier: true,
                magnification: 2.35 / 2.1,
                squeeze: 1.25,
                offAxisFraction: 0.45,
                selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                  capStartEdge: false,
                  capEndEdge: true,
                ),
                onSelectedItemChanged: (i) =>
                    setState(() => _onTheDayIndex = i),
                children: _kDays
                    .map(
                      (d) => Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Text(d, style: _kPickerItemStyle),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ],
  ]);

  Widget _monthlyModeRow(String label, String key) {
    final selected = _monthlyMode == key;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _monthlyMode = key),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label, style: _kRowLabelStyle),
            const Spacer(),
            if (selected)
              FixedSFIcon(
                SFIcons.sf_checkmark,
                fontSize: 17,
                color: widget.accentColor,
                fontWeight: FontWeight.w600,
              ),
          ],
        ),
      ),
    );
  }

  // ── Monthly — date cell (used inside unified card) ───────────────────────

  static final _kDateCellStyle = TextStyle(
    inherit: false,
    color: kPrimaryLabel,
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  Widget _dateCell(int n) {
    if (n > 31) {
      // Empty placeholder — keeps grid columns aligned.
      return SizedBox(height: 44);
    }
    final selected = _selectedDates.contains(n);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (selected)
          _selectedDates.remove(n);
        else
          _selectedDates.add(n);
      }),
      child: SizedBox(
        height: 44,
        child: ColoredBox(
          color: selected ? widget.accentColor : const Color(0x00000000),
          child: Center(
            child: Text(
              '$n',
              style: _kDateCellStyle.copyWith(
                color: selected
                    ? CupertinoColors.white
                    : resolveThemeColor(kPrimaryLabel, context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Yearly — month grid (Card 2) ─────────────────────────────────────────

  Widget _monthCell(int monthIndex) {
    final selected = _selectedMonths.contains(monthIndex);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (selected)
          _selectedMonths.remove(monthIndex);
        else
          _selectedMonths.add(monthIndex);
      }),
      child: SizedBox(
        height: 44,
        child: ColoredBox(
          color: selected ? widget.accentColor : const Color(0x00000000),
          child: Center(
            child: Text(
              _kMonths[monthIndex - 1],
              style: _kDateCellStyle.copyWith(
                fontSize: 16,
                color: selected
                    ? CupertinoColors.white
                    : resolveThemeColor(kPrimaryLabel, context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearlyMonthCard() => _card([
    for (int row = 0; row < 3; row++) ...[
      if (row > 0)
        Container(
          height: 0.5,
          color: resolveThemeColor(kSeparatorColor, context),
        ),
      SizedBox(
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int col = 0; col < 4; col++) ...[
              if (col > 0)
                Container(
                  width: 0.5,
                  color: resolveThemeColor(kSeparatorColor, context),
                ),
              Expanded(child: _monthCell(row * 4 + col + 1)),
            ],
          ],
        ),
      ),
    ],
  ]);

  // ── Yearly — Days of Week toggle + picker (Card 3) ───────────────────────

  void _toggleYearlyDays() {
    setState(() => _yearlyDaysEnabled = !_yearlyDaysEnabled);
    if (_yearlyDaysEnabled) {
      _yearlyDaysCtrl.forward();
    } else {
      _yearlyDaysCtrl.reverse();
    }
  }

  Widget _buildYearlyDaysCard() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedBuilder(
        animation: _yearlyDaysCtrl,
        builder: (ctx, _) => _cardWithRadius(
          [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleYearlyDays,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text('Days of Week', style: _kRowLabelStyle),
                    const Spacer(),
                    // height: 30 matches pill height so switch rows == date rows
                    SizedBox(
                      width: 70 * 0.80,
                      height: 30,
                      child: OverflowBox(
                        maxWidth: 70,
                        maxHeight: 31,
                        alignment: Alignment.center,
                        child: Transform.scale(
                          scale: 0.80,
                          child: AppSwitch(
                            value: _yearlyDaysEnabled,
                            onChanged: (_) => _toggleYearlyDays(),
                            color: widget.accentColor,
                            height: 31,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          BorderRadius.only(
            topLeft: Radius.circular(kCardCornerRadius),
            topRight: Radius.circular(kCardCornerRadius),
            bottomLeft: Radius.circular(
              _yearlyDaysCtrl.value > 0 ? 0.0 : kCardCornerRadius,
            ),
            bottomRight: Radius.circular(
              _yearlyDaysCtrl.value > 0 ? 0.0 : kCardCornerRadius,
            ),
          ),
        ),
      ),
      SizeTransition(
        sizeFactor: _yearlyDaysCtrl,
        axisAlignment: 1.0,
        child: _cardWithRadius(
          [
            _sep(),
            SizedBox(
              height: 216,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _yearlyPositionCtrl,
                      itemExtent: 32.0,
                      backgroundColor: CupertinoColors.transparent,
                      useMagnifier: true,
                      magnification: 2.35 / 2.1,
                      squeeze: 1.25,
                      offAxisFraction: -0.45,
                      selectionOverlay:
                          const CupertinoPickerDefaultSelectionOverlay(
                            capStartEdge: true,
                            capEndEdge: false,
                          ),
                      onSelectedItemChanged: (i) =>
                          setState(() => _yearlyPositionIndex = i),
                      children: _kPositions
                          .map(
                            (p) => Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Text(p, style: _kPickerItemStyle),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _yearlyDayCtrl,
                      itemExtent: 32.0,
                      backgroundColor: CupertinoColors.transparent,
                      useMagnifier: true,
                      magnification: 2.35 / 2.1,
                      squeeze: 1.25,
                      offAxisFraction: 0.45,
                      selectionOverlay:
                          const CupertinoPickerDefaultSelectionOverlay(
                            capStartEdge: false,
                            capEndEdge: true,
                          ),
                      onSelectedItemChanged: (i) =>
                          setState(() => _yearlyDayIndex = i),
                      children: _kDays
                          .map(
                            (d) => Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Text(d, style: _kPickerItemStyle),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const BorderRadius.only(
            bottomLeft: Radius.circular(kCardCornerRadius),
            bottomRight: Radius.circular(kCardCornerRadius),
          ),
        ),
      ),
    ],
  );

  // ── Label & dismiss ───────────────────────────────────────────────────────

  /// Returns the footer sentence starting from "Every…" (capitalised, no period).
  String get _customLabel {
    const prefix = 'Event will occur ';
    final text = _footerText;
    final raw = text.startsWith(prefix) ? text.substring(prefix.length) : text;
    final stripped = raw.endsWith('.') ? raw.substring(0, raw.length - 1) : raw;
    return stripped[0].toUpperCase() + stripped.substring(1);
  }

  _CustomRepeatConfig get _currentConfig => _CustomRepeatConfig(
    frequency: _frequency,
    everyCount: _everyCount,
    selectedDays: Set.unmodifiable(_selectedDays),
    monthlyMode: _monthlyMode,
    selectedDates: Set.unmodifiable(_selectedDates),
    onThePositionIndex: _onThePositionIndex,
    onTheDayIndex: _onTheDayIndex,
    selectedMonths: Set.unmodifiable(_selectedMonths),
    yearlyDaysEnabled: _yearlyDaysEnabled,
    yearlyPositionIndex: _yearlyPositionIndex,
    yearlyDayIndex: _yearlyDayIndex,
  );

  void _dismiss() => Navigator.of(context).pop<_CustomRepeatResult?>(null);
  void _save() => Navigator.of(context).pop<_CustomRepeatResult?>(
    _CustomRepeatResult(_customLabel, _currentConfig),
  );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kModalBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            SizedBox(height: 12.5),
            RoundedCupertinoSheetHeader(
              child: SizedBox(
                height: 40.0,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Custom',
                      style: TextStyle(
                        inherit: false,
                        color: resolveThemeColor(kPrimaryLabel, context),
                        fontSize: 17,
                        fontFamily: kSFProText,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.normal,
                        letterSpacing: kTracking17,
                        height: kLineHeight,
                      ),
                    ),
                    Positioned(
                      left: 16.0,
                      child: _ModalCircleButton(
                        icon: CupertinoIcons.chevron_left,
                        iconColor: resolveThemeColor(kPrimaryLabel, context),
                        iconOffset: const Offset(-1.5, 0),
                        tapDelay: const Duration(milliseconds: 130),
                        onTap: _dismiss,
                      ),
                    ),
                    Positioned(
                      right: 16.0,
                      child: _ModalCircleButton(
                        icon: CupertinoIcons.checkmark,
                        containerColor: widget.accentColor,
                        iconColor: CupertinoColors.white,
                        tapDelay: const Duration(milliseconds: 130),
                        onTap: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Same 12px gap the parent sheet uses so content never sits flush
            // against the header buttons as it scrolls underneath.
            const SizedBox(height: 12),
            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // ── Card 1 ─────────────────────────────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _everyPickerCtrl,
                        builder: (ctx, _) => _cardWithRadius(
                          [
                            _pickerRow(
                              'Frequency',
                              _frequency,
                              items: _makeItems(
                                _kFrequencyOptions,
                                _frequency,
                                (v) => setState(() => _frequency = v),
                                checkmarkColor: widget.accentColor,
                              ),
                            ),
                            _sep(),
                            _pickerRow(
                              'Every',
                              _everyCount == 1
                                  ? _everyUnit
                                  : '$_everyCount $_everyUnit',
                              showChevron: false,
                              valueColor: widget.accentColor,
                              onTap: _toggleEveryPicker,
                            ),
                          ],
                          BorderRadius.only(
                            topLeft: Radius.circular(kCardCornerRadius),
                            topRight: Radius.circular(kCardCornerRadius),
                            bottomLeft: Radius.circular(
                              _everyPickerCtrl.value > 0
                                  ? 0.0
                                  : kCardCornerRadius,
                            ),
                            bottomRight: Radius.circular(
                              _everyPickerCtrl.value > 0
                                  ? 0.0
                                  : kCardCornerRadius,
                            ),
                          ),
                        ),
                      ),
                      _buildEverySubcard(),
                      // Static context footer — always visible, updates live.
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, left: 16),
                          child: Text(
                            _footerText,
                            style: _kContextFooterStyle(context),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                      // Card 2 — day-of-week selector (Weekly only).
                      if (_frequency == 'Weekly') ...[
                        const SizedBox(height: 18),
                        _buildWeekDaysCard(),
                      ],
                      // Card 2 — unified mode + sub-content (Monthly only).
                      if (_frequency == 'Monthly') ...[
                        const SizedBox(height: 18),
                        _buildMonthlyUnifiedCard(),
                      ],
                      // Card 2 — month grid (Yearly only).
                      // Card 3 — Days of Week toggle + picker (Yearly only).
                      if (_frequency == 'Yearly') ...[
                        const SizedBox(height: 18),
                        _buildYearlyMonthCard(),
                        const SizedBox(height: 18),
                        _buildYearlyDaysCard(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
