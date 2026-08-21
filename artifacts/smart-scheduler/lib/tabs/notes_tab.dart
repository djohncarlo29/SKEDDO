import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';
import '../widgets/squircle_glow.dart';
import '../app_theme.dart';
import '../widgets/fixed_size_icon.dart';
import '../services/event_extractor.dart';
import '../services/event_store.dart';
import '../services/speech_service.dart';
import '../widgets/action_panel.dart';
import '../widgets/native_text_input.dart';
import '../widgets/search_bar_widget.dart';
import '../ai/search/search_service.dart';
import '../services/event_store.dart' show EventStore;
import 'events_tab.dart'
    show wrapSearchEventTileWithActions, wrapSearchEventTileWithPressScale;
import '../widgets/smart_search_results.dart';

// True while the user is in "search mode" — i.e. the search bar is focused
// (with or without typed text). In this state the only valid way to leave
// search mode is the X-circle button next to the search bar; tap-outside
// dismissal is disabled so the user can scroll the No-Results pane, tap
// dead space, or interact anywhere else without accidentally collapsing
// the header. Tapping into the multi-line note input is still allowed —
// that's a natural focus shift handled at the native layer (the search
// bar's onFocusChanged fires false when the note grabs focus).
//
// Lives at module scope so the dismissal callbacks invoked from the
// note input's TapRegion (which doesn't have a State reference) can
// query it cheaply without plumbing flags through every widget.
//
// Aliased to the shared [sbSearchModeActive] flag — see search_bar_widget.dart.

// Public reset hook for AppShell to call from _switchTab.  The underlying
// implementation now lives in search_bar_widget.dart as [sbResetSearchMode].
// This thin wrapper preserves the name AppShell already calls.
void resetNotesSearchMode() => sbResetSearchMode();

// ─────────────────────────────────────────────────────────────────────────────
// Scroll controller whose position IGNORES ensureVisible / showOnScreen.
//
// CupertinoTextField internally calls RenderObject.showOnScreen() when the
// cursor moves or selection changes. That propagates up to the nearest
// ScrollPosition via ensureVisible(), causing the outer SingleChildScrollView
// to snap to the cursor — even when the text field uses
// NeverScrollableScrollPhysics. Overriding ensureVisible to a no-op stops
// that entirely. User-driven scroll (finger/wheel drag) is unaffected because
// it goes through applyUserOffset(), not ensureVisible().
// ─────────────────────────────────────────────────────────────────────────────
class _FixedScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _FixedScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
    );
  }
}

class _FixedScrollPosition extends ScrollPositionWithSingleContext {
  _FixedScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  @override
  Future<void> ensureVisible(
    RenderObject object, {
    double alignment = 0.0,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
    ScrollPositionAlignmentPolicy alignmentPolicy =
        ScrollPositionAlignmentPolicy.explicit,
    RenderObject? targetRenderObject,
  }) async {
    // Intentionally no-op.
    // The text field must not auto-jump the outer scroll view.
  }
}

// ── Search header delegate ────────────────────────────────────────────────────
// Same pattern as EventsTab: always a SliverPersistentHeader so the AppSearchBar
// element is never remounted across search-mode transitions.
// Normal mode (pinned:false, floating:false): scrolls with content including
// rubber-band — identical to a SliverToBoxAdapter.
// Search mode (pinned:true, floating:true): locked at top, immune to
// rubber-band; only the content below the separator moves.
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

// ─────────────────────────────────────────────────────────────────────────────
// Tab
// ─────────────────────────────────────────────────────────────────────────────
class NotesTab extends StatefulWidget {
  final ValueChanged<bool>? onSearchFocusChanged;
  final Animation<double>? searchModeAnimation;
  final void Function(ScheduledEvent event)? onEditEvent;

  const NotesTab({
    super.key,
    this.onSearchFocusChanged,
    this.searchModeAnimation,
    this.onEditEvent,
  });

  @override
  State<NotesTab> createState() => NotesTabState();
}

class NotesTabState extends State<NotesTab> with WidgetsBindingObserver {
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _noteInputKey = GlobalKey<_NoteInputCardState>();
  // GlobalKey keeps _AppSearchBarState alive when the parent sliver switches
  // between SliverToBoxAdapter (unfocused) and SliverPersistentHeader (focused).
  // Without this key, the element is remounted on every search-mode transition,
  // which kills any in-progress STT session (onPartial/onFinal see !mounted).
  final _searchBarKey = GlobalKey<AppSearchBarState>();
  bool _searchFocused = false;
  bool _activatedFromOffScreen = false;
  double _savedScrollOffset = 0;
  // Re-entrancy guard for _enforceScrollLock — prevents jumpTo from
  // triggering the listener a second time and causing an infinite loop.
  bool _lockingScrollDrift = false;
  // Grey overlay animation: _greyActive keeps the grey sliver in the tree;
  // _greyFadeIn drives opacity (true = 1.0, false = 0.0 → fade-out).
  bool _greyActive = false;
  bool _greyFadeIn = false;
  String _searchText = '';
  bool _wasSearchFocusedBeforePause = false;

  // ── Smart search results (filled asynchronously by _scheduleSearch) ────────
  List<SearchHit> _searchHits = [];
  String? _searchSuggestion;
  Timer? _searchDebounce;

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

  /// Called by AppShell when the search bar is off-screen and the header
  /// search button is tapped.  Sets the tab's own _searchFocused flag
  /// synchronously (grey fill appears immediately) without bubbling to
  /// AppShell — AppShell already handles _searchModeController and its own
  /// _searchFocused in _activateTabSearch().  Then focuses the native field.
  void activateSearchMode() {
    if (_searchFocused) return;
    _activatedFromOffScreen = true;
    _greyActive = true;
    _greyFadeIn = true;
    // Save where the user was so we can restore it when they cancel.
    _savedScrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
    // Do NOT scroll to 0.  The SliverPersistentHeader is pinned so it stays
    // visible at the viewport top regardless of scroll offset.  The
    // SliverFillRemaining grey fill covers the rest of the viewport, making
    // the search bar appear as an overlay without disturbing the scroll position.
    setState(() => _searchFocused = true);
    // One post-frame is enough: the rebuild switches to SliverPersistentHeader
    // (pinned), so the bar is in the viewport by the time the frame paints.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NativeTextInput.focus(_searchController);
    });
  }

  bool get _appIsBackgrounded {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_enforceScrollLock);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchTextChanged);
    _scrollController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
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
      // Search is local, so clear the previous query's hits immediately while
      // the next local semantic query completes.
      _searchHits = [];
      _searchSuggestion = null;
    });
    _scheduleSearch();
  }

  /// Debounced 150 ms smart search across all events.
  void _scheduleSearch() {
    _searchDebounce?.cancel();
    final q = _searchText.trim();
    if (q.isEmpty) {
      if (_searchHits.isNotEmpty) {
        setState(() {
          _searchHits = [];
          _searchSuggestion = null;
        });
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 150), () async {
      // Search the same expanded corpus used by Calendar and Events.  This
      // keeps recurring occurrences searchable by their concrete dates while
      // remaining completely independent of the current tab.
      final all = EventStore.instance.expandedEvents();
      final results = await SearchService().query(q, all);
      if (!mounted || _searchText.trim() != q) return;
      setState(() {
        _searchHits = results.all;
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

  void _onSearchFocusChanged(bool focused) {
    if (_searchFocused == focused) return;

    if (focused) {
      setState(() => _searchFocused = true);
      // The sliver type just changed (SliverToBoxAdapter → SliverPersistentHeader),
      // which remounts AppSearchBar and its NativeTextInput platform view. A
      // post-frame refocus restores the cursor after the rebuild settles.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchFocused) NativeTextInput.focus(_searchController);
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
    if (_searchFocused || _searchText.isNotEmpty || _greyActive) {
      // Hard reset — skip animations when the widget is leaving the tree.
      _searchFocused = false;
      _activatedFromOffScreen = false;
      _greyActive = false;
      _greyFadeIn = false;
      _searchText = '';
      _searchSuggestion = null;
      sbSearchModeActive = false;
      _searchController.clear();
      NativeTextInput.unfocusAll();
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onSearchFocusChanged?.call(false);
    }

    super.deactivate();
  }

  /// True while the attach action panel or the attachment preview overlay is open.
  bool get hasOpenPanel {
    final cardState = _noteInputKey.currentState;
    return cardState != null &&
        (cardState._attachMenuOpen || cardState._previewOverlay != null);
  }

  /// Dismisses the topmost open panel via the OS back gesture.
  /// Preview overlay takes priority over the attach action panel.
  void dismissOpenPanel() {
    final cardState = _noteInputKey.currentState;
    if (cardState == null) return;
    if (cardState._previewOverlay != null) {
      cardState._dismissAttachmentPreview();
    } else {
      cardState._hideAttachMenu();
    }
  }

  /// Public hook for AppShell to cancel search via OS back gesture.
  void cancelSearch() => _cancelSearch();

  void _cancelSearch() {
    // Stop any active mic session before clearing the search bar.
    _searchBarKey.currentState?.cancelMic();
    final wasFocused = _searchFocused;
    final wasOffScreen = _activatedFromOffScreen;
    sbSearchModeActive = false;
    _searchController.clear();
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
        _searchSuggestion = null;
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
        _searchSuggestion = null;
      });
    }
    if (wasFocused) widget.onSearchFocusChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final bool showResults = _searchFocused && _searchText.isNotEmpty;

    // Search bar row — carries _searchBarKey.
    // When off-screen search is active (_activatedFromOffScreen) this widget
    // lives in the Stack overlay below so the scroll view is left completely
    // untouched and the scroll position is preserved.  At all other times it
    // lives inside the scroll view sliver.
    final searchBarRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: AppSearchBar(
              key: _searchBarKey,
              controller: _searchController,
              onFocusChanged: _onSearchFocusChanged,
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

    return Stack(
      children: [
        // ── Main scroll view ──────────────────────────────────────────────
        // Never structurally modified when off-screen search is active.
        // The overlay Stack child covers it entirely, preserving scroll
        // position for the whole duration of the off-screen session.
        CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Search bar sliver ─────────────────────────────────────────
            // Off-screen active : _searchBarKey lives in the overlay Stack;
            //   a same-height SizedBox placeholder occupies this slot so
            //   the content below doesn't shift.
            // Inline search     : SliverPersistentHeader (pinned) locks the
            //   bar at the viewport top while the user types.
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

            // ── Content ───────────────────────────────────────────────────
            // Inline search results use the same shared renderer as the
            // off-screen overlay.  Keeping both paths on the same widget
            // prevents the visible-at-top search mode from getting stuck on
            // the old no-results placeholder.
            if (showResults && !_activatedFromOffScreen) ...[
              SmartSearchResultsSliver(
                hits: _searchHits,
                suggestedQuery: _searchSuggestion,
                onSuggestionTap: _applySearchSuggestion,
                eventTopPadding: 18,
                eventTileWrapper: (hit, child, previewBuilder) =>
                    wrapSearchEventTileWithActions(
                      hit: hit,
                      child: child,
                      previewBuilder: previewBuilder,
                      onEdit: widget.onEditEvent == null
                          ? null
                          : () => widget.onEditEvent!(hit.event),
                    ),
                eventTilePressWrapper: wrapSearchEventTileWithPressScale,
              ),
              if (_searchHits.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: floatingTabBarContentBottomClearance(context),
                  ),
                ),
            ] else ...[
              // Normal content — also kept in the tree when off-screen search
              // is active (it is hidden by the overlay) so it is already
              // rendered at the correct position when the overlay fades out.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NoteInputCard(
                        key: _noteInputKey,
                        controller: _noteController,
                      ),
                      const SizedBox(height: 18),
                      const _SaveEventButton(),
                    ],
                  ),
                ),
              ),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: floatingTabBarContentBottomClearance(context),
                ),
              ),
            ],
          ],
        ),

        // ── Off-screen search overlay ─────────────────────────────────────
        // Covers the scroll view without touching it.  _searchBarKey lives
        // here while the overlay is present, moving back to the scroll view
        // sliver once _greyActive / _activatedFromOffScreen are cleared.
        if (_greyActive)
          AnimatedOpacity(
            opacity: _greyFadeIn ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            // No onEnd: exit is instant (overlay removed directly in
            // _cancelSearch), so there is no fade-out to wait for.
            child: ColoredBox(
              color: resolveThemeColor(kBackgroundColor, context),
              // CustomScrollView gives the overlay its own rubber-band
              // physics, identical to the scroll view it sits above.
              // primary:false prevents Flutter from adopting the
              // PrimaryScrollController (which in a CupertinoTabScaffold is
              // the tab's own scroll controller) — that would reset the tab's
              // scroll offset to 0 the moment this overlay appears.
              child: CustomScrollView(
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                slivers: [
                  // Search bar pinned at top — same delegate as inline
                  // search so the appearance is identical.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SearchHeaderDelegate(
                      searchBarRow: searchBarRow,
                      extent: 76.5,
                      showSeparator: true,
                    ),
                  ),
                  // Content area: smart search results or empty grey fill.
                  if (showResults)
                    SmartSearchResultsSliver(
                      hits: _searchHits,
                      suggestedQuery: _searchSuggestion,
                      onSuggestionTap: _applySearchSuggestion,
                      eventTopPadding: 18,
                      eventTileWrapper: (hit, child, previewBuilder) =>
                          wrapSearchEventTileWithActions(
                            hit: hit,
                            child: child,
                            previewBuilder: previewBuilder,
                            onEdit: widget.onEditEvent == null
                                ? null
                                : () => widget.onEditEvent!(hit.event),
                          ),
                      eventTilePressWrapper: wrapSearchEventTileWithPressScale,
                    )
                  else
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: SizedBox.expand(),
                    ),
                  if (!showResults || _searchHits.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: floatingTabBarContentBottomClearance(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note input card
// ─────────────────────────────────────────────────────────────────────────────
class _NoteInputCard extends StatefulWidget {
  final TextEditingController controller;
  const _NoteInputCard({super.key, required this.controller});

  @override
  State<_NoteInputCard> createState() => _NoteInputCardState();
}

class _NoteInputCardState extends State<_NoteInputCard>
    with TickerProviderStateMixin {
  bool _micPressed = false;
  bool _noteFocused = false;

  // ── Plus button opacity animation ──────────────────────────────────────────
  // Dims to 0.45 on tap-down / while attach menu is open; restores on dismiss.
  late final AnimationController _plusScaleCtrl;
  late final Animation<double> _plusOpacity;
  late final AnimationController _clearScaleCtrl;
  late final Animation<double> _clearOpacity;

  // ── Attach-menu (plus button) overlay ──────────────────────────────────────
  final GlobalKey _plusKey = GlobalKey();
  final ValueNotifier<bool> _attachClosing = ValueNotifier(false);
  OverlayEntry? _attachOverlay;
  bool _attachMenuOpen = false;

  // ── Attachment state ───────────────────────────────────────────────────────
  XFile? _pickedImage; // from camera or photo library
  PlatformFile? _pickedFile; // from document picker
  Uint8List? _imageBytes; // pre-loaded bytes for display + AI call
  bool _isAnalyzing = false;
  String? _extractionError;
  String _pendingMime = 'image/jpeg';
  OverlayEntry? _previewOverlay;

  // ── Speech-to-text state ───────────────────────────────────────────────────
  bool _micListening = false;
  bool _micBusy =
      false; // guard: prevents double-fire from AnimatedSwitcher fade-out
  String _preListenText = '';
  int _sttSession = 0;

  // [GEMINI LIVE] Background Gemini correction timer — kept as inert state so
  // the SquircleGlowBorder widget in the build tree compiles.  Re-enable by
  // un-commenting the mutation sites in _onMicTap and restoring the two
  // commented-out methods below.
  Timer? _sttBoundaryTimer;
  String _bgRaw = '';
  String _bgFormatted = '';
  bool _bgActive = false;
  bool _glowActive = false;
  int _bgLock = 0;

  late final AnimationController _pulseCtrl;

  void _showAttachMenu() {
    if (_attachMenuOpen) return;
    final box = _plusKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _attachClosing.value = false;
    _attachMenuOpen = true;
    // Keep icon in "pressed" (scaled-down) state while menu is open.
    // _plusScaleCtrl was already forwarded on tap-down; don't reverse it.
    final items = [
      ActionItem(
        label: 'Use Camera',
        icon: SFIcons.sf_camera,
        onTap: _onUseCamera,
      ),
      ActionItem(
        label: 'Document File',
        icon: SFIcons.sf_document,
        onTap: _onDocumentFile,
      ),
      ActionItem(
        label: 'Photo Library',
        icon: SFIcons.sf_photo_on_rectangle,
        onTap: _onPhotoLibrary,
      ),
    ];
    _attachOverlay = OverlayEntry(
      builder: (ctx) => ActionMenuOverlay(
        buttonRect: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
        isClosing: _attachClosing,
        onDismiss: _hideAttachMenu,
        actions: items,
      ),
    );
    Overlay.of(context).insert(_attachOverlay!);
    setState(() {});
  }

  void _onUseCamera() {
    _hideAttachMenu();
    Future.microtask(() async {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImage = file;
        _pickedFile = null;
        _imageBytes = bytes;
        _extractionError = null;
        _pendingMime = 'image/jpeg';
      });
      if (context.mounted) _showAttachmentPreview();
    });
  }

  void _onPhotoLibrary() {
    _hideAttachMenu();
    Future.microtask(() async {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final ext = file.name.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';
      setState(() {
        _pickedImage = file;
        _pickedFile = null;
        _imageBytes = bytes;
        _extractionError = null;
        _pendingMime = mime;
      });
      if (context.mounted) _showAttachmentPreview();
    });
  }

  void _onDocumentFile() {
    _hideAttachMenu();
    Future.microtask(() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'heic',
          ..._kTextExts,
          ..._kAiDocumentExts,
          ..._kLegacyOfficeExts,
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      final ext = (file.extension ?? '').toLowerCase();
      final isImg = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext);
      final mime = isImg ? _mimeForImageExtension(ext) : '';
      setState(() {
        _pickedFile = file;
        _pickedImage = null;
        _imageBytes = isImg ? file.bytes : null;
        _extractionError = null;
        _pendingMime = mime;
      });
      if (context.mounted) _showAttachmentPreview();
    });
  }

  // ── Full-screen attachment preview ─────────────────────────────────────────
  void _showAttachmentPreview() {
    if (_previewOverlay != null) return;
    _previewOverlay = OverlayEntry(
      builder: (_) => _AttachmentPreviewOverlay(
        imageBytes: _imageBytes,
        docBytes: (_imageBytes == null) ? _pickedFile?.bytes : null,
        filename: _pickedFile?.name,
        fileExt: _pickedFile?.extension,
        onConfirm: _confirmAttachment,
        onDismiss: _dismissAttachmentPreview,
      ),
    );
    Overlay.of(context).insert(_previewOverlay!);
  }

  void _dismissAttachmentPreview() {
    _previewOverlay?.remove();
    _previewOverlay = null;
    _clearAttachment();
  }

  void _confirmAttachment() {
    _previewOverlay?.remove();
    _previewOverlay = null;
    if (_imageBytes != null) {
      _analyzeImage(_imageBytes!, _pendingMime);
    } else if (_pickedFile != null) {
      final ext = (_pickedFile!.extension ?? '').toLowerCase();
      final bytes = _pickedFile!.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _extractionError = 'Could not read this file.');
        return;
      }

      if (_kTextExts.contains(ext)) {
        final raw = utf8.decode(bytes, allowMalformed: true);
        final text = ext == 'rtf'
            ? _stripRtf(raw)
            : (ext == 'html' || ext == 'htm')
            ? _stripTags(raw)
            : raw;
        _analyzeText(text);
        return;
      }

      switch (ext) {
        case 'pdf':
          // Gemini accepts PDFs as native multimodal document input.
          _analyzeImage(bytes, 'application/pdf');
          return;
        case 'docx':
          _analyzeText(_extractDocxText(bytes));
          return;
        case 'xlsx':
          _analyzeText(_extractXlsxText(bytes));
          return;
        case 'pptx':
          _analyzeText(_extractPptxText(bytes));
          return;
        case 'odt':
        case 'ods':
        case 'odp':
          _analyzeText(_extractOpenDocumentText(bytes));
          return;
        default:
          if (_kLegacyOfficeExts.contains(ext)) {
            _analyzeLegacyOffice(bytes, _pickedFile!.name);
          } else {
            setState(
              () => _extractionError =
                  'This file format is not supported yet for AI analysis.',
            );
          }
      }
    }
  }

  Future<void> _analyzeLegacyOffice(Uint8List bytes, String filename) async {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
      _extractionError = null;
    });
    try {
      final events = await EventExtractor.fromLegacyOffice(bytes, filename);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      if (context.mounted) _showResultSheet(events);
    } on ExtractionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _extractionError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _extractionError = 'Could not convert this legacy Office file.';
      });
    }
  }

  Future<void> _analyzeImage(Uint8List bytes, String mimeType) async {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
      _extractionError = null;
    });
    try {
      final events = await EventExtractor.fromImage(bytes, mimeType);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      if (context.mounted) _showResultSheet(events);
    } on ExtractionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _extractionError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _extractionError = 'Analysis failed. Please try again.';
      });
    }
  }

  Future<void> _analyzeText(String text) async {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
      _extractionError = null;
    });
    try {
      final events = await EventExtractor.fromText(text);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      if (context.mounted) _showResultSheet(events);
    } on ExtractionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _extractionError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _extractionError = 'Analysis failed. Please try again.';
      });
    }
  }

  void _showResultSheet(List<ExtractedEvent> events) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _ExtractionResultSheet(events: events),
    );
  }

  void _clearAttachment() {
    _previewOverlay?.remove();
    _previewOverlay = null;
    setState(() {
      _pickedImage = null;
      _pickedFile = null;
      _imageBytes = null;
      _isAnalyzing = false;
      _extractionError = null;
    });
  }

  void _hideAttachMenu() {
    if (!_attachMenuOpen) return;
    _attachMenuOpen = false;
    _plusScaleCtrl.reverse(); // animate icon back to full size
    _attachClosing.value = true;
    // Wait for the panel's close animation (≈358 ms for 3 items) + buffer.
    Future.delayed(const Duration(milliseconds: 420), () {
      _attachOverlay?.remove();
      _attachOverlay = null;
      if (mounted) {
        _attachClosing.value = false;
        setState(() {});
      }
    });
  }

  // ── Fast offline punctuator ───────────────────────────────────────────────
  // Runs synchronously with no network — used for the final tail chunk so
  // the result appears the instant the user stops talking.
  static String _localPunctuate(String raw) {
    if (raw.trim().isEmpty) return raw;
    var t = raw.trim();
    // Capitalise after sentence-ending punctuation
    t = t.replaceAllMapped(
      RegExp(r'([.!?]+\s+)([a-z])'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    );
    // Standalone 'i' → 'I'
    t = t.replaceAllMapped(RegExp(r'\bi\b'), (_) => 'I');
    // Capitalise first character
    if (t.isNotEmpty) t = '${t[0].toUpperCase()}${t.substring(1)}';
    // Add terminal period if none present
    if (!RegExp(r'[.!?]$').hasMatch(t)) t = '$t.';
    return t;
  }

  // ── [GEMINI LIVE] Gemini REST correction methods — commented out, not deleted
  // Replaced by the in-stream Gemini Live path in SpeechService.  Re-enable
  // both methods (and the mutation sites in _onMicTap below) to restore the
  // old two-step REST correction + AI glow flow.
  //
  // Future<void> _backgroundCorrect(String fullWords, int sessionId) async {
  //   if (!mounted || _sttSession != sessionId || _bgActive) return;
  //   final rawNew = fullWords.length > _bgRaw.length
  //       ? fullWords.substring(_bgRaw.length).trim()
  //       : '';
  //   if (rawNew.isEmpty) return;
  //   final lockId = ++_bgLock;
  //   if (mounted) setState(() { _bgActive = true; _glowActive = true; });
  //   final corrected =
  //       await SpeechService.instance.applySmartPunctuation(rawNew);
  //   if (!mounted || _sttSession != sessionId || _bgLock != lockId) {
  //     if (mounted) setState(() { _bgActive = false; });
  //     return;
  //   }
  //   _bgRaw = fullWords.trim();
  //   _bgFormatted =
  //       _bgFormatted.isEmpty ? corrected : '$_bgFormatted $corrected';
  //   if (mounted) setState(() { _bgActive = false; });
  // }
  //
  // Future<void> _finalizeDictation(String words, int sessionId) async {
  //   final rawTail = words.length > _bgRaw.length
  //       ? words.substring(_bgRaw.length).trim()
  //       : '';
  //   if (rawTail.isNotEmpty) {
  //     final lockId = ++_bgLock;
  //     if (mounted) setState(() { _bgActive = true; _glowActive = true; });
  //     final tailCorrected =
  //         await SpeechService.instance.applySmartPunctuation(rawTail);
  //     if (!mounted || _sttSession != sessionId || _bgLock != lockId) {
  //       if (mounted) {
  //         setState(() { _bgActive = false; _glowActive = false; _micListening = false; });
  //         await Future.delayed(const Duration(milliseconds: 250));
  //         if (mounted) setState(() { _micBusy = false; });
  //       }
  //       return;
  //     }
  //     final full = _bgFormatted.isNotEmpty
  //         ? '$_bgFormatted $tailCorrected'
  //         : tailCorrected;
  //     final sep = _preListenText.isEmpty ? '' : ' ';
  //     widget.controller.text = '$_preListenText$sep$full';
  //   } else if (_bgFormatted.isNotEmpty) {
  //     final sep = _preListenText.isEmpty ? '' : ' ';
  //     widget.controller.text = '$_preListenText$sep$_bgFormatted';
  //   }
  //   _bgRaw = ''; _bgFormatted = ''; _bgActive = false;
  //   if (mounted) setState(() { _micListening = false; _glowActive = false; });
  //   await Future.delayed(const Duration(milliseconds: 250));
  //   if (mounted) setState(() { _micBusy = false; });
  // }

  // ── Mic / speech-to-text ──────────────────────────────────────────────────
  Future<void> _onMicTap() async {
    // Guard: prevents the AnimatedSwitcher fade-out ghost tap from re-firing,
    // or any other double-invocation while an async operation is in flight.
    if (_micBusy) return;
    _micBusy = true;

    final svc = SpeechService.instance;

    // Tap while listening → cancel everything and return to idle.
    if (_micListening) {
      _sttSession++;
      _sttBoundaryTimer?.cancel();
      // [GEMINI LIVE] _bgLock++;
      // [GEMINI LIVE] _bgRaw = ''; _bgFormatted = ''; _bgActive = false; _glowActive = false;
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
      // Keep _micBusy = true until AnimatedSwitcher fade-out finishes (180ms)
      // so ghost taps on the outgoing listening widget are blocked.
      setState(() {
        _micListening = false;
      });
      await svc.cancel();
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted)
        setState(() {
          _micBusy = false;
        });
      return;
    }

    // Request permission (shows our pre-prompt + OS dialog as needed).
    if (!mounted) return;
    final result = await svc.requestPermission(context);
    if (!mounted) return;

    if (result == SttRequestResult.denied) {
      _micBusy = false;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Microphone Access Denied'),
          content: const Text(
            'To use voice input, enable microphone access in your device Settings.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (result == SttRequestResult.userCancelled) {
      _micBusy = false;
      return;
    }

    // [GEMINI LIVE] _bgRaw = ''; _bgFormatted = ''; _bgActive = false; _glowActive = false; _bgLock++;

    // Snapshot current text so partials are appended, not replaced.
    _preListenText = widget.controller.text;
    final sessionId = ++_sttSession;

    // Focus the text field so the keyboard is visible during dictation.
    NativeTextInput.focus(widget.controller);

    setState(() => _micListening = true);
    _pulseCtrl.repeat(reverse: true);

    // Tracks the most recent raw dictation text so a native "error" event
    // (session died without a proper 'final') can still finalize gracefully
    // with whatever was already transcribed, instead of losing it.
    String lastWords = '';

    void endSession(String words) {
      if (!mounted || _sttSession != sessionId) return;
      _sttBoundaryTimer?.cancel();
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
      // Commit whatever was transcribed (already smart-formatted by Gemini Live
      // in-stream; no post-processing step needed).
      if (words.trim().isNotEmpty) {
        final sep = _preListenText.isEmpty ? '' : ' ';
        widget.controller.text = '$_preListenText$sep${words.trim()}';
      }
      setState(() {
        _micListening = false;
        _micBusy = false;
      });
      // [GEMINI LIVE] Old two-step REST correction path:
      // _bgRaw = ''; _bgFormatted = ''; _bgActive = false; _glowActive = false;
      // setState(() { _micListening = false; });
      // _finalizeDictation(words, sessionId);
    }

    await svc.startListening(
      onPartial: (words) {
        if (!mounted || _sttSession != sessionId) return;
        lastWords = words;
        // Show raw text live; Gemini Live formats it in-stream so no
        // background correction step is needed.
        final sep = _preListenText.isEmpty ? '' : ' ';
        widget.controller.text = '$_preListenText$sep$words';
        // [GEMINI LIVE] Background Gemini REST correction timer removed —
        // in-stream formatting means no post-processing pause needed.
        // _sttBoundaryTimer?.cancel();
        // final rawNew = words.length > _bgRaw.length
        //     ? words.substring(_bgRaw.length).trim()
        //     : '';
        // if (rawNew.isNotEmpty) {
        //   _sttBoundaryTimer = Timer(
        //     const Duration(milliseconds: 1800),
        //     () => _backgroundCorrect(words, sessionId),
        //   );
        // }
      },
      onFinal: endSession,
      // Native recognizer stopped/errored without ever sending 'final' (e.g.
      // Android "no match"/"speech timeout" after a silence) — end the
      // session using whatever was last transcribed so the mic doesn't get
      // stuck showing the blue pulsing "listening" state forever.
      onError: () => endSession(lastWords),
    );
    // startListening() itself returned — the mic was released (or failed to
    // start). Only clear _micBusy here if we're not still in the middle of
    // the finalization async path (which clears it itself).
    if (mounted && !_micListening) _micBusy = false;
  }

  // Rebuild whenever controller text transitions between empty ↔ non-empty.
  // Also clear the attachment when the user taps the X (clear) button so the
  // card resets fully — empty text + no attachment.
  void _onControllerChanged() {
    if (widget.controller.text.isEmpty) _clearAttachment();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _plusScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _plusOpacity = Tween<double>(
      begin: 1.0,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _plusScaleCtrl, curve: Curves.easeOut));
    _clearScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _clearOpacity = Tween<double>(
      begin: 1.0,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _clearScaleCtrl, curve: Curves.easeOut));
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.4,
      upperBound: 1.0,
    );
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _sttBoundaryTimer?.cancel();
    _plusScaleCtrl.dispose();
    _clearScaleCtrl.dispose();
    _pulseCtrl.dispose();
    _attachOverlay?.remove();
    _attachClosing.dispose();
    super.dispose();
  }

  double _noteInputHeight(BuildContext context, Color placeholderColor) {
    final placeholderStyle = TextStyle(
      inherit: false,
      color: placeholderColor,
      fontSize: 17,
      fontFamily: 'SFProText',
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      letterSpacing: kTracking16,
      height: kLineHeight,
    );
    // Card width minus the outer row insets and the clear-button column.
    final inputWidth = MediaQuery.sizeOf(context).width - 91.0;
    final painter = TextPainter(
      text: TextSpan(
        text: 'Type your schedule here...',
        style: placeholderStyle,
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: inputWidth < 80.0 ? 80.0 : inputWidth);
    final requiredHeight = painter.height + 24.0;
    return requiredHeight > 155.0 ? requiredHeight : 155.0;
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = resolveThemeColor(kSbSurface, context);
    final cardShadows = resolveThemeShadows(kCardShadow, context);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    final tertiaryLabel = resolveThemeColor(kTertiaryLabel, context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: surfaceColor,
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(kSbCornerRadius),
        ),
        shadows: cardShadows,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 17, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: _noteInputHeight(context, secondaryLabel),
                        child: ClipRect(
                          child: TapRegion(
                            groupId: kSbGroupId,
                            onTapOutside: (_) => sbDismissTextFieldFocus(),
                            // When empty + unfocused: IgnorePointer makes the
                            // PlatformView invisible to hit-testing so all
                            // touches (including drags) fall through to the
                            // parent CustomScrollView — enabling rubber-band
                            // overscroll even from inside the input area.
                            // A tap-through GestureDetector overlay restores
                            // focus programmatically so the keyboard appears.
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                IgnorePointer(
                                  ignoring:
                                      _attachMenuOpen ||
                                      (!_noteFocused &&
                                          widget.controller.text.isEmpty),
                                  child: NativeTextInput(
                                    controller: widget.controller,
                                    placeholder: 'Type your schedule here...',
                                    multiline: true,
                                    onFocusChanged: (focused) =>
                                        setState(() => _noteFocused = focused),
                                    style: TextStyle(
                                      inherit: false,
                                      fontSize: 17,
                                      color: primaryLabel,
                                      fontFamily: 'SFProText',
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FontStyle.normal,
                                      letterSpacing: kTracking16,
                                      height: kLineHeight,
                                    ),
                                    placeholderStyle: TextStyle(
                                      inherit: false,
                                      color: secondaryLabel,
                                      fontSize: 17,
                                      fontFamily: 'SFProText',
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FontStyle.normal,
                                      letterSpacing: kTracking16,
                                      height: kLineHeight,
                                    ),
                                    cursorColor: resolveAccentColor(context),
                                  ),
                                ),
                                if (!_noteFocused &&
                                    widget.controller.text.isEmpty)
                                  GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () => NativeTextInput.focus(
                                      widget.controller,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.controller,
                      builder: (context, value, child) {
                        final bool hasText = value.text.isNotEmpty;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _clearScaleCtrl.forward(),
                          onTapCancel: () => _clearScaleCtrl.reverse(),
                          onTap: () {
                            _clearScaleCtrl.reverse();
                            if (hasText) widget.controller.clear();
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 5, 8),
                            child: AnimatedBuilder(
                              animation: _clearScaleCtrl,
                              builder: (context, _) => Transform.scale(
                                scale: 1.0 - (_clearScaleCtrl.value * 0.22),
                                child: Opacity(
                                  // Empty fields keep the same assigned
                                  // colour, but at a deliberately quieter
                                  // base opacity. A press still animates
                                  // even though it has no clear action.
                                  opacity:
                                      (hasText ? 1.0 : 0.45) *
                                      _clearOpacity.value,
                                  child: Icon(
                                    CupertinoIcons.clear,
                                    size: 20,
                                    weight: 300.0,
                                    color: secondaryLabel,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // ── Analyzing spinner ───────────────────────────────────────────────
              if (_isAnalyzing) const _AnalyzingIndicator(),
              // ── Extraction error ────────────────────────────────────────────────
              if (_extractionError != null && !_isAnalyzing)
                _ErrorChip(message: _extractionError!),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      key: _plusKey,
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) {
                        if (!_attachMenuOpen) _plusScaleCtrl.forward();
                      },
                      onTapCancel: () {
                        if (!_attachMenuOpen) _plusScaleCtrl.reverse();
                      },
                      onTap: _showAttachMenu,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 6, 10, 0),
                        child: AnimatedBuilder(
                          animation: _plusScaleCtrl,
                          builder: (context, _) => Opacity(
                            opacity: _plusOpacity.value,
                            child: Icon(
                              CupertinoIcons.add,
                              size: 24,
                              weight: 300.0,
                              color: secondaryLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // ── Mic button: idle / listening ─────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: _micListening
                          // Listening: accent mic pulsing, tap to stop early.
                          ? GestureDetector(
                              key: const ValueKey('mic-listening'),
                              onTap: _onMicTap,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 6, 0, 0),
                                child: AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (_, __) => Opacity(
                                    opacity: _pulseCtrl.value,
                                    child: FixedSFIcon(
                                      SFIcons.sf_microphone_fill,
                                      fontSize: 17,
                                      color: resolveAccentColor(context),
                                      shadows: resolveThemeTextShadows([
                                        Shadow(
                                          color: resolveAccentColor(context),
                                          blurRadius: 0.4,
                                        ),
                                      ], context),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          // Idle: dim mic, press highlight, tap to start.
                          : AnimatedTapIcon(
                              key: const ValueKey('mic-idle'),
                              padding: const EdgeInsets.fromLTRB(10, 6, 0, 0),
                              onTap: _onMicTap,
                              onPressedChanged: (pressed) =>
                                  setState(() => _micPressed = pressed),
                              child: FixedSFIcon(
                                SFIcons.sf_microphone_fill,
                                fontSize: 17,
                                color: _micPressed
                                    ? secondaryLabel
                                    : tertiaryLabel,
                                shadows: resolveThemeTextShadows([
                                  Shadow(
                                    color: _micPressed
                                        ? secondaryLabel
                                        : tertiaryLabel,
                                    blurRadius: 0.4,
                                  ),
                                ], context),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Native platform views (NativeTextInput) render outside Flutter's
          // compositor layer, so BackdropFilter cannot reach them. This tinted
          // cover sits on top of the entire card (clipped to the squircle by
          // the parent Container) and visually obscures the native content
          // when the attach-menu is open — giving the frosted-glass effect.
          IgnorePointer(
            ignoring: !_attachMenuOpen,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: AnimatedOpacity(
                opacity: _attachMenuOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  color: resolveThemeColor(kAttachmentMenuOverlay, context),
                ),
              ),
            ),
          ),
          // ── AI glow — inner-edge glow on the whole card ────────────────
          // Shown while Gemini is actively correcting (_bgActive).  Uses
          // SquircleGlowBorder so the path follows ContinuousRectangleBorder
          // exactly — no corner gaps.  clipBehavior on the parent Container
          // clips the glow to the squircle shape automatically.
          if (_glowActive)
            Positioned.fill(
              child: IgnorePointer(
                child: SquircleGlowBorder(
                  cornerRadius: kSbCornerRadius,
                  outer: false,
                  glowWidth: 7,
                  blurSigma: 8,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Save button
// ─────────────────────────────────────────────────────────────────────────────
class _SaveEventButton extends StatefulWidget {
  const _SaveEventButton();

  @override
  State<_SaveEventButton> createState() => _SaveEventButtonState();
}

class _SaveEventButtonState extends State<_SaveEventButton>
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

  @override
  Widget build(BuildContext context) {
    final surfaceColor = resolveThemeColor(kSbSurface, context);
    final cardShadows = resolveThemeShadows(kCardShadow, context);
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: () {
        sbDismissTextFieldFocus();
        _ctrl.forward(from: 0).then((_) {
          if (mounted) _ctrl.reverse();
        });
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - 0.04 * _ctrl.value,
          child: Opacity(opacity: 1.0 - 0.35 * _ctrl.value, child: child!),
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: surfaceColor,
            shape: const BoundedContinuousRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(kSquircleStadiumRadius),
              ),
            ),
            shadows: cardShadows,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Save Event',
                style: TextStyle(
                  inherit: false,
                  color: resolveAccentColor(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SFProText',
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking17,
                  height: kLineHeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: floatingTabBarContentBottomClearance(context),
      ),
      child: Center(
        child: Text(
          'No Events',
          style: TextStyle(
            inherit: false,
            color: resolveThemeColor(kSecondaryLabel, context),
            fontSize: 17,
            fontFamily: 'SFProText',
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            letterSpacing: kTracking16,
            height: kLineHeight,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// (ActionMenuOverlay moved to widgets/action_panel.dart for reuse.)

// ─────────────────────────────────────────────────────────────────────────────
// Attachment image preview
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentImagePreview extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onRemove;
  const _AttachmentImagePreview({required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: Image.memory(
                bytes,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xCC000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: CupertinoColors.white,
                    size: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attachment file chip
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentFileChip extends StatelessWidget {
  final String filename;
  final VoidCallback onRemove;
  const _AttachmentFileChip({required this.filename, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: kModalButtonBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.doc,
                  size: 15,
                  color: kSecondaryLabel,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    filename,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      inherit: false,
                      color: kPrimaryLabel,
                      fontSize: 13,
                      fontFamily: 'SFProText',
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      letterSpacing: kTracking16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: kTertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analyzing indicator
// ─────────────────────────────────────────────────────────────────────────────
class _AnalyzingIndicator extends StatelessWidget {
  const _AnalyzingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CupertinoActivityIndicator(radius: 9),
          SizedBox(width: 8),
          Text(
            'Reading your content\u2026',
            style: TextStyle(
              inherit: false,
              color: kSecondaryLabel,
              fontSize: 13,
              fontFamily: 'SFProText',
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.normal,
              letterSpacing: kTracking16,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extraction error chip
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorChip extends StatelessWidget {
  final String message;
  const _ErrorChip({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 14,
            color: CupertinoColors.destructiveRed,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                inherit: false,
                color: CupertinoColors.destructiveRed,
                fontSize: 12,
                fontFamily: 'SFProText',
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.normal,
                letterSpacing: kTracking16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extraction result sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ExtractionResultSheet extends StatefulWidget {
  final List<ExtractedEvent> events;
  const _ExtractionResultSheet({required this.events});

  @override
  State<_ExtractionResultSheet> createState() => _ExtractionResultSheetState();
}

class _ExtractionResultSheetState extends State<_ExtractionResultSheet> {
  // Mutable local copy so rows can be removed individually.
  late final List<ExtractedEvent> _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = List.from(widget.events);
  }

  void _addAndRemove(int index) {
    final e = _remaining[index];
    EventStore.instance.create(
      title: e.title,
      date: e.date,
      time: e.time,
      location: e.location,
    );
    setState(() => _remaining.removeAt(index));
  }

  void _dismiss(int index) {
    setState(() => _remaining.removeAt(index));
  }

  String get _title {
    final n = widget.events.length;
    if (n == 0) return 'No Events Found';
    if (n == 1) return '1 Event Found';
    return '$n Events Found';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
      decoration: const BoxDecoration(
        color: kModalBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kModalHandleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _title,
                style: const TextStyle(
                  inherit: false,
                  color: kPrimaryLabel,
                  fontSize: 17,
                  fontFamily: 'SFProText',
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking17,
                ),
              ),
            ),
          ),
          // Empty / all-dismissed state
          if (_remaining.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Text(
                widget.events.isEmpty
                    ? "We couldn't find any events in this image. "
                          'Try a photo of a calendar, invite, or flyer.'
                    : 'All events have been handled.',
                style: const TextStyle(
                  inherit: false,
                  color: kSecondaryLabel,
                  fontSize: 14,
                  fontFamily: 'SFProText',
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking16,
                  height: kLineHeight,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                itemCount: _remaining.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _EventRow(
                  event: _remaining[i],
                  onAdd: () => _addAndRemove(i),
                  onDismiss: () => _dismiss(i),
                ),
              ),
            ),
          // Dismiss all
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: kModalButtonBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Dismiss All',
                      style: TextStyle(
                        inherit: false,
                        color: kPrimaryLabel,
                        fontSize: 16,
                        fontFamily: 'SFProText',
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                        letterSpacing: kTracking16,
                      ),
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

// ── Single event row inside the result sheet ──────────────────────────────────
class _EventRow extends StatelessWidget {
  final ExtractedEvent event;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;
  const _EventRow({
    required this.event,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: kPreviewCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPreviewCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    inherit: false,
                    color: kPrimaryLabel,
                    fontSize: 15,
                    fontFamily: 'SFProText',
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.normal,
                    letterSpacing: kTracking16,
                  ),
                ),
                if (event.date != null || event.time != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (event.date != null) event.date!,
                      if (event.time != null) event.time!,
                    ].join('  ·  '),
                    style: const TextStyle(
                      inherit: false,
                      color: kSecondaryLabel,
                      fontSize: 13,
                      fontFamily: 'SFProText',
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      letterSpacing: kTracking16,
                    ),
                  ),
                ],
                if (event.location != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location_fill,
                        size: 11,
                        color: kTertiaryLabel,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: const TextStyle(
                            inherit: false,
                            color: kTertiaryLabel,
                            fontSize: 12,
                            fontFamily: 'SFProText',
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
          const SizedBox(width: 8),
          // Add button
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: resolveAccentColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Add',
                style: TextStyle(
                  inherit: false,
                  color: CupertinoColors.white,
                  fontSize: 13,
                  fontFamily: 'SFProText',
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Per-row dismiss
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                CupertinoIcons.xmark,
                size: 14,
                color: kTertiaryLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File-type routing helpers
// ─────────────────────────────────────────────────────────────────────────────

// Extensions rendered as scrollable plain text.
const _kTextExts = <String>{
  'txt',
  'md',
  'markdown',
  'log',
  'csv',
  'tsv',
  'json',
  'xml',
  'html',
  'htm',
  'yaml',
  'yml',
  'ini',
  'toml',
  'rtf',
};

// Subset of _kTextExts that uses a monospace font.
const _kMonoExts = <String>{'csv', 'tsv', 'json', 'xml', 'ini', 'toml'};

// Formats that are structurally unrenderable without server-side conversion.
const _kNoPreviewExts = <String>{'doc', 'xls', 'xlsx', 'ppt', 'pptx'};

// Common document formats that can be analyzed after picking them from the
// Notes attachment menu. PDFs remain multimodal input; modern Office and
// OpenDocument formats are read locally, while legacy binary formats use the
// server's LibreOffice conversion path.
const _kAiDocumentExts = <String>{
  'pdf',
  'docx',
  'xlsx',
  'pptx',
  'odt',
  'ods',
  'odp',
};

const _kLegacyOfficeExts = <String>{
  'doc',
  'xls',
  'ppt',
  'wps',
  'wpd',
  'sxw',
  'sxc',
  'sxi',
  'sdw',
  'vor',
};

String _mimeForImageExtension(String ext) {
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'heic':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}

// Human-readable hint shown for each unsupported format.
String _noPreviewNote(String ext) {
  switch (ext) {
    case 'doc':
      return 'Save as DOCX to preview';
    case 'xls':
    case 'xlsx':
      return 'Spreadsheet preview\nnot supported';
    case 'ppt':
    case 'pptx':
      return 'Presentation preview\nnot supported';
    default:
      return 'Preview not supported';
  }
}

/// Strip RTF control words / groups leaving readable prose.
String _stripRtf(String rtf) {
  if (!rtf.trimLeft().startsWith(r'{\rtf')) return rtf;
  return rtf
      .replaceAll(RegExp(r'\{[^{}]*\}'), '')
      .replaceAll(RegExp(r'\\[a-z]+\d*[ ]?'), '')
      .replaceAll(RegExp(r'\\[^ ]'), '')
      .replaceAll(RegExp(r'[{}]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Strip HTML/XML tags leaving inner text.
String _stripTags(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Extract readable text from a DOCX byte array.
/// DOCX is a ZIP; we unpack word/document.xml and pull <w:t> text runs.
String _extractDocxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) return '[No word/document.xml found in DOCX]';

    final xmlStr = utf8.decode(
      entry.content as List<int>,
      allowMalformed: true,
    );

    // XmlDocument.parse decodes all XML entities (&amp; &lt; &#NNN; etc.)
    final doc = XmlDocument.parse(xmlStr);
    final buf = StringBuffer();
    bool prevWasBlank = false;

    for (final para in doc.findAllElements('w:p')) {
      final line = StringBuffer();
      for (final node in para.descendants) {
        if (node is! XmlElement) continue;
        final q = node.name.qualified;
        if (q == 'w:t') {
          line.write(node.innerText);
        } else if (q == 'w:br') {
          line.write('\n');
        } else if (q == 'w:tab') {
          line.write('\t');
        }
      }
      final s = line.toString().trimRight();
      if (s.isEmpty) {
        if (!prevWasBlank && buf.isNotEmpty) buf.write('\n');
        prevWasBlank = true;
      } else {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(s);
        prevWasBlank = false;
      }
    }

    final result = buf.toString().trim();
    return result.isEmpty
        ? '[Document appears to have no text content]'
        : result;
  } catch (e) {
    return '[Could not parse DOCX: $e]';
  }
}

String _archiveEntryText(ArchiveFile entry) {
  return utf8.decode(entry.content as List<int>, allowMalformed: true);
}

String _xmlText(XmlDocument doc, {String? localName}) {
  final parts = <String>[];
  for (final node in doc.descendants) {
    if (node is! XmlElement) continue;
    if (localName != null && node.name.local != localName) continue;
    if (node.name.local == 't' ||
        node.name.local == 'p' ||
        node.name.local == 'h' ||
        node.name.local == 'span') {
      final text = node.innerText.trim();
      if (text.isNotEmpty) parts.add(text);
    }
  }
  return parts.join('\n').trim();
}

/// Extract readable cell values from an XLSX ZIP package.
String _extractXlsxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final shared = <String>[];
    final sharedEntry = archive.findFile('xl/sharedStrings.xml');
    if (sharedEntry != null) {
      final doc = XmlDocument.parse(_archiveEntryText(sharedEntry));
      for (final si in doc.findAllElements('si')) {
        shared.add(
          si.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join(),
        );
      }
    }

    final sheets =
        archive.files
            .where(
              (file) =>
                  file.name.startsWith('xl/worksheets/sheet') &&
                  file.name.endsWith('.xml'),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final output = StringBuffer();
    for (final sheet in sheets) {
      final doc = XmlDocument.parse(_archiveEntryText(sheet));
      for (final row in doc.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'row',
      )) {
        final values = <String>[];
        for (final cell in row.children.whereType<XmlElement>().where(
          (e) => e.name.local == 'c',
        )) {
          final type = cell.getAttribute('t');
          final value = cell.children
              .whereType<XmlElement>()
              .where((e) => e.name.local == 'v')
              .map((e) => e.innerText)
              .firstOrNull;
          if (value == null) {
            values.add('');
          } else if (type == 's') {
            final index = int.tryParse(value);
            values.add(
              index != null && index >= 0 && index < shared.length
                  ? shared[index]
                  : value,
            );
          } else {
            values.add(value);
          }
        }
        if (values.any((value) => value.isNotEmpty)) {
          output.writeln(values.join('\t'));
        }
      }
    }
    final result = output.toString().trim();
    return result.isEmpty
        ? '[Spreadsheet appears to have no text content]'
        : result;
  } catch (e) {
    return '[Could not parse XLSX: $e]';
  }
}

/// Extract text from PPTX slide XML files in slide order.
String _extractPptxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final slides =
        archive.files
            .where(
              (file) =>
                  file.name.startsWith('ppt/slides/slide') &&
                  file.name.endsWith('.xml'),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final output = StringBuffer();
    for (final slide in slides) {
      final doc = XmlDocument.parse(_archiveEntryText(slide));
      final text = _xmlText(doc, localName: 't');
      if (text.isNotEmpty) output.writeln(text);
    }
    final result = output.toString().trim();
    return result.isEmpty
        ? '[Presentation appears to have no text content]'
        : result;
  } catch (e) {
    return '[Could not parse PPTX: $e]';
  }
}

/// Extract prose from OpenDocument packages (ODT/ODS/ODP).
String _extractOpenDocumentText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('content.xml');
    if (entry == null) return '[No content.xml found in OpenDocument file]';
    final text = _xmlText(XmlDocument.parse(_archiveEntryText(entry)));
    return text.isEmpty ? '[Document appears to have no text content]' : text;
  } catch (e) {
    return '[Could not parse OpenDocument file: $e]';
  }
}

/// Parse a DOCX byte array into structured paragraphs for rich rendering.
/// Handles: heading levels, bold/italic/underline, font size, color, alignment.
// ── Parse a single DOCX <w:p> element into a _DocxParagraph ─────────────────
_DocxParagraph _parsePara(XmlElement para, bool Function(XmlElement?) wBool) {
  final pPr = para.findElements('w:pPr').firstOrNull;
  final pStyleVal =
      pPr?.findElements('w:pStyle').firstOrNull?.getAttribute('w:val') ?? '';
  final styleLow = pStyleVal
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('_', '');

  int headingLevel = 0;
  if (styleLow == 'title' || styleLow == 'heading1')
    headingLevel = 1;
  else if (styleLow == 'subtitle' || styleLow == 'heading2')
    headingLevel = 2;
  else if (styleLow == 'heading3')
    headingLevel = 3;
  else if (styleLow.startsWith('heading'))
    headingLevel = 4;

  final jcVal =
      pPr?.findElements('w:jc').firstOrNull?.getAttribute('w:val') ?? '';
  final alignment = switch (jcVal) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    'both' => TextAlign.justify,
    _ => TextAlign.start,
  };

  final runs = <_DocxRun>[];
  for (final r in para.findElements('w:r')) {
    final rPr = r.findElements('w:rPr').firstOrNull;

    final buf = StringBuffer();
    for (final node in r.children) {
      if (node is! XmlElement) continue;
      final q = node.name.qualified;
      if (q == 'w:t') buf.write(node.innerText);
      if (q == 'w:br') buf.write('\n');
      if (q == 'w:tab') buf.write('    ');
    }
    final text = buf.toString();
    if (text.isEmpty) continue;

    final bold =
        headingLevel > 0 ||
        wBool(rPr?.findElements('w:b').firstOrNull) ||
        wBool(rPr?.findElements('w:bCs').firstOrNull);
    final italic =
        wBool(rPr?.findElements('w:i').firstOrNull) ||
        wBool(rPr?.findElements('w:iCs').firstOrNull);
    final uEl = rPr?.findElements('w:u').firstOrNull;
    final uVal = uEl?.getAttribute('w:val') ?? '';
    final underline = uEl != null && uVal != 'none' && uVal != '0';
    final szEl = rPr?.findElements('w:sz').firstOrNull;
    final szRaw = szEl != null
        ? int.tryParse(szEl.getAttribute('w:val') ?? '')
        : null;
    final fontSize = szRaw != null ? (szRaw / 2.0).clamp(8.0, 72.0) : null;
    final colorVal = rPr
        ?.findElements('w:color')
        .firstOrNull
        ?.getAttribute('w:val');
    Color? color;
    if (colorVal != null && colorVal != 'auto' && colorVal.length == 6) {
      final v = int.tryParse(colorVal, radix: 16);
      if (v != null) color = Color(0xFF000000 | v);
    }
    runs.add(
      _DocxRun(
        text: text,
        bold: bold,
        italic: italic,
        underline: underline,
        fontSize: fontSize,
        color: color,
      ),
    );
  }
  return _DocxParagraph(
    runs: runs,
    headingLevel: headingLevel,
    alignment: alignment,
  );
}

List<_DocxParagraph> _parseDocxFormatted(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) return [];
    final xmlStr = utf8.decode(
      entry.content as List<int>,
      allowMalformed: true,
    );
    final doc = XmlDocument.parse(xmlStr);
    bool wBool(XmlElement? el) {
      if (el == null) return false;
      final v = el.getAttribute('w:val');
      return v == null || v == '1' || v == 'true' || v == 'on' || v.isEmpty;
    }

    return doc.findAllElements('w:p').map((p) => _parsePara(p, wBool)).toList();
  } catch (_) {
    return [];
  }
}

// ── Parse DOCX body → ordered list of paragraphs + tables ────────────────────
List<_DocxBodyElem> _parseDocxBody(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) return [];
    final xmlStr = utf8.decode(
      entry.content as List<int>,
      allowMalformed: true,
    );
    final doc = XmlDocument.parse(xmlStr);
    bool wBool(XmlElement? el) {
      if (el == null) return false;
      final v = el.getAttribute('w:val');
      return v == null || v == '1' || v == 'true' || v == 'on' || v.isEmpty;
    }

    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) return [];
    final result = <_DocxBodyElem>[];
    for (final child in body.children) {
      if (child is! XmlElement) continue;
      final q = child.name.qualified;
      if (q == 'w:p') {
        result.add(_DocxParaElem(_parsePara(child, wBool)));
      } else if (q == 'w:tbl') {
        final rows = <List<List<_DocxParagraph>>>[];
        for (final tr in child.findElements('w:tr')) {
          final row = <List<_DocxParagraph>>[];
          for (final tc in tr.findElements('w:tc')) {
            row.add(
              tc.findElements('w:p').map((p) => _parsePara(p, wBool)).toList(),
            );
          }
          if (row.isNotEmpty) rows.add(row);
        }
        if (rows.isNotEmpty) result.add(_DocxTableElem(rows));
      }
    }
    return result;
  } catch (_) {
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen attachment preview overlay
//
// Layout:
//   • Full-screen BackdropFilter blur + dark dim — covers the entire app.
//   • × button: same position as app header hamburger (safeTop+10, left: 16).
//   • ✓ button: same position as app header + icon   (safeTop+10, right: 16).
//   • Content sits below the button row, centred vertically in the remaining
//     space, with 60 px horizontal padding.
//   • Images size to fill the available width at natural aspect ratio — no
//     white fill, squircle applied directly to the image edge.
//   • PDFs: page-by-page render via pdfx with ‹ / › nav circle buttons.
//   • Other docs: portrait-ratio squircle with filename + type label.
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentPreviewOverlay extends StatefulWidget {
  final Uint8List? imageBytes; // pre-decoded image bytes
  final Uint8List? docBytes; // raw PDF / doc bytes
  final String? filename;
  final String? fileExt;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _AttachmentPreviewOverlay({
    this.imageBytes,
    this.docBytes,
    this.filename,
    this.fileExt,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<_AttachmentPreviewOverlay> createState() =>
      _AttachmentPreviewOverlayState();
}

class _AttachmentPreviewOverlayState extends State<_AttachmentPreviewOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // PDF nav state — written by _PdfPageView via onPageChanged so the overlay
  // can render the nav row outside the shadow card.
  final GlobalKey<_PdfPageViewState> _pdfKey = GlobalKey();
  int _pdfPage = 1;
  int _pdfTotal = 0;
  // Drives the nav row via ListenableBuilder so chevron colours update
  // immediately when the page changes — independent of AnimatedBuilder.
  final _pdfNav = ValueNotifier<(int, int)>((1, 0));
  Uint8List? _docxPdfBytes;
  bool _docxConverting = false;

  // Natural pixel dimensions of an image attachment, decoded asynchronously
  // so the card can be sized to exactly the image's intrinsic aspect ratio.
  Size? _imgNatSize;

  void _onPdfPageChanged(int page, int total) {
    _pdfNav.value = (page, total);
    if (mounted)
      setState(() {
        _pdfPage = page;
        _pdfTotal = total;
      });
  }

  Future<void> _convertDocxToPdf() async {
    if (mounted) setState(() => _docxConverting = true);
    final pdf = await _convertDocxToPdfBytes(widget.docBytes!);
    if (mounted)
      setState(() {
        _docxPdfBytes = pdf;
        _docxConverting = false;
      });
  }

  Future<void> _loadImageSize() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes!);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(
          () => _imgNatSize = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          ),
        );
      }
      frame.image.dispose();
      codec.dispose();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _ctrl.forward();
    if (widget.imageBytes != null) _loadImageSize();
    if ((widget.fileExt ?? '').toLowerCase() == 'docx' &&
        widget.docBytes != null) {
      _convertDocxToPdf();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pdfNav.dispose();
    super.dispose();
  }

  // AppShell header icon coordinates — replicated for overlay button alignment.
  //   top:  safeTop + 10 px   bottom of status bar + 10
  //   left/right: 16 px       same horizontal edge as hamburger / + icon
  static const double _kBtnTop = 10.0;
  static const double _kBtnEdge = 16.0;

  Widget _buildContent() {
    // ── Image ──────────────────────────────────────────────────────────────
    if (widget.imageBytes != null) {
      return LayoutBuilder(
        builder: (_, c) {
          double displayW, displayH;
          if (_imgNatSize != null && _imgNatSize!.width > 0) {
            final aspect = _imgNatSize!.width / _imgNatSize!.height;
            final naturalH = c.maxWidth / aspect;
            if (c.maxHeight.isFinite && naturalH > c.maxHeight) {
              displayH = c.maxHeight;
              displayW = c.maxHeight * aspect;
            } else {
              displayW = c.maxWidth;
              displayH = naturalH;
            }
          } else {
            // Size not yet decoded — use full width; will snap to exact size once known.
            displayW = c.maxWidth;
            displayH = c.maxHeight.isFinite ? c.maxHeight : c.maxWidth;
          }
          return ClipPath(
            clipper: _PreviewSquircleClipper(),
            child: SizedBox(
              width: displayW,
              height: displayH,
              child: Image.memory(widget.imageBytes!, fit: BoxFit.fill),
            ),
          );
        },
      );
    }

    final ext = (widget.fileExt ?? '').toLowerCase();
    final bytes = widget.docBytes;

    // ── PDF ────────────────────────────────────────────────────────────────
    if (ext == 'pdf' && bytes != null) {
      return _PdfPageView(
        key: _pdfKey,
        pdfBytes: bytes,
        onPageChanged: _onPdfPageChanged,
      );
    }

    // ── DOCX — converted on-device to PDF for faithful rendering ──────────
    if (ext == 'docx' && bytes != null) {
      if (_docxConverting) {
        return ClipPath(
          clipper: _PreviewSquircleClipper(),
          child: const AspectRatio(
            aspectRatio: 3 / 4,
            child: ColoredBox(
              color: kSbSurface,
              child: Center(child: CupertinoActivityIndicator()),
            ),
          ),
        );
      }
      if (_docxPdfBytes != null) {
        return _PdfPageView(
          key: _pdfKey,
          pdfBytes: _docxPdfBytes!,
          onPageChanged: _onPdfPageChanged,
        );
      }
      // Fallback: conversion failed — show rich-text view.
      return _DocxTextView(
        bytes: bytes,
        filename: widget.filename ?? 'Document',
      );
    }

    // ── Plain-text family ──────────────────────────────────────────────────
    if (_kTextExts.contains(ext) && bytes != null) {
      try {
        final raw = utf8.decode(bytes, allowMalformed: true);
        final cooked = ext == 'rtf'
            ? _stripRtf(raw)
            : (ext == 'html' || ext == 'htm')
            ? _stripTags(raw)
            : raw;
        final trimmed = cooked.length > 20000
            ? '${cooked.substring(0, 20000)}\n…'
            : cooked;
        return _TextPreview(
          content: trimmed,
          monospace: _kMonoExts.contains(ext),
        );
      } catch (_) {}
    }

    // ── Structurally unrenderable formats ──────────────────────────────────
    if (_kNoPreviewExts.contains(ext)) {
      return ClipPath(
        clipper: _PreviewSquircleClipper(),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: _FileDocPreview(
            filename: widget.filename ?? 'Document',
            ext: ext,
            note: _noPreviewNote(ext),
          ),
        ),
      );
    }

    // ── Generic fallback ───────────────────────────────────────────────────
    return ClipPath(
      clipper: _PreviewSquircleClipper(),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: _FileDocPreview(
          filename: widget.filename ?? 'Document',
          ext: ext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_ctrl.value);
        final ts = Curves.easeOutBack.transform(_ctrl.value);

        return Stack(
          children: [
            // ── Themed grouped background — fades in ───────────────────────
            Positioned.fill(
              child: Opacity(
                opacity: t,
                child: ColoredBox(
                  color: resolveThemeColor(
                    kAttachmentPreviewBackground,
                    context,
                  ),
                ),
              ),
            ),

            // ── Squircle attachment card (shadow + content) ─────────────────
            // Padding: top 60 px (sits below the header buttons with room),
            //          left / right / bottom 50 px.
            SafeArea(
              child: Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: 0.90 + 0.10 * ts,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 60, 30, 75),
                    child: LayoutBuilder(
                      builder: (_, bc) {
                        // Reserve 60 px (16 gap + 44 button) for the PDF nav
                        // row when it's visible so the card never overflows.
                        const navH = 16.0 + 44.0;
                        final cardMaxH =
                            (bc.maxHeight - (_pdfTotal > 1 ? navH : 0.0)).clamp(
                              0.0,
                              double.infinity,
                            );

                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Squircle card — height-capped, shadow + border
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: bc.maxWidth,
                                  maxHeight: cardMaxH,
                                ),
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: kCardColor,
                                    shape: BoundedContinuousRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        kSquircleStadiumRadius,
                                      ),
                                      side: const BorderSide(
                                        color: kAttachmentBorder,
                                        width: 0.5,
                                      ),
                                    ),
                                    shadows: resolveThemeShadows(const [
                                      BoxShadow(
                                        color: kAttachmentShadow,
                                        blurRadius: 20,
                                        offset: Offset(0, 4),
                                      ),
                                    ], context),
                                  ),
                                  child: child!,
                                ),
                              ),
                              // PDF nav row — 16 px below squircle, outside the
                              // shadow card so it doesn't distort the shadow.
                              if (_pdfTotal > 1) ...[
                                const SizedBox(height: 16),
                                // Fixed-width Stack so the chevrons never shift
                                // as the page-indicator text grows (e.g. "99 / 100").
                                // Buttons are pinned to the left/right edges;
                                // text floats in the centre with 50 px padding on
                                // each side — plenty even for triple-digit counts.
                                SizedBox(
                                  width: 224,
                                  height: 40,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 50,
                                        ),
                                        child: Text(
                                          '$_pdfPage / $_pdfTotal',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            inherit: false,
                                            color: kPrimaryLabel,
                                            fontSize: 15,
                                            fontFamily: 'SFProText',
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FontStyle.normal,
                                            letterSpacing: kTracking16,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        child: _PreviewCircleButton(
                                          icon: SFIcons.sf_chevron_right,
                                          flipHorizontal: true,
                                          verticalIconOffset: -2,
                                          iconColor: _pdfPage > 1
                                              ? kPrimaryLabel
                                              : kTertiaryLabel,
                                          onTap: () => _pdfKey.currentState
                                              ?.navigate(-1),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: _PreviewCircleButton(
                                          icon: SFIcons.sf_chevron_right,
                                          verticalIconOffset: -2,
                                          iconColor: _pdfPage < _pdfTotal
                                              ? kPrimaryLabel
                                              : kTertiaryLabel,
                                          onTap: () =>
                                              _pdfKey.currentState?.navigate(1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ── × button — same coords as app hamburger ─────────────────────
            Positioned(
              top: safeTop + _kBtnTop,
              left: _kBtnEdge,
              child: Opacity(
                opacity: t,
                child: _PreviewCircleButton(
                  icon: CupertinoIcons.xmark,
                  iconColor: kPrimaryLabel,
                  tapDelay: const Duration(milliseconds: 130),
                  onTap: widget.onDismiss,
                ),
              ),
            ),

            // ── ✓ button — same coords as app + icon ────────────────────────
            Positioned(
              top: safeTop + _kBtnTop,
              right: _kBtnEdge,
              child: Opacity(
                opacity: t,
                child: _PreviewCircleButton(
                  icon: CupertinoIcons.checkmark,
                  containerColor: resolveAccentColor(context),
                  iconColor: CupertinoColors.white,
                  tapDelay: const Duration(milliseconds: 130),
                  onTap: widget.onConfirm,
                ),
              ),
            ),
          ],
        );
      },
      child: _buildContent(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF page viewer — renders pages via pdfx, ‹ / › circle nav buttons
// ─────────────────────────────────────────────────────────────────────────────
class _PdfPageView extends StatefulWidget {
  final Uint8List pdfBytes;

  /// Called whenever the current page or total page count is known/changes.
  final void Function(int page, int total)? onPageChanged;
  const _PdfPageView({super.key, required this.pdfBytes, this.onPageChanged});

  @override
  State<_PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<_PdfPageView> {
  PdfDocument? _doc;
  int _page = 1;
  int _total = 0;
  double _pageAspect = 0.0;
  Uint8List? _pageBytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final doc = await PdfDocument.openData(widget.pdfBytes);
      _doc = doc;
      _total = doc.pagesCount;
      await _renderPage(1);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load PDF.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _renderPage(int num) async {
    if (_doc == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final page = await _doc!.getPage(num);
      final aspect = page.width / page.height;
      final img = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: PdfPageImageFormat.png,
      );
      if (img == null) {
        await page.close();
        if (mounted)
          setState(() {
            _error = 'Page $num failed.';
            _loading = false;
          });
        return;
      }
      final bytes = img.bytes;
      await page.close();
      if (mounted) {
        setState(() {
          _page = num;
          _pageBytes = bytes;
          _pageAspect = aspect;
          _loading = false;
        });
        widget.onPageChanged?.call(num, _total);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Page $num failed.';
          _loading = false;
        });
      }
    }
  }

  /// Called by the overlay to step forward (+1) or backward (−1).
  void navigate(int delta) {
    if (_loading) return;
    final target = _page + delta;
    if (target >= 1 && target <= _total) _renderPage(target);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ClipPath(
        clipper: _PreviewSquircleClipper(),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: _FileDocPreview(filename: _error!, ext: 'PDF'),
        ),
      );
    }

    if (_loading && _pageBytes == null) {
      return ClipPath(
        clipper: _PreviewSquircleClipper(),
        child: const AspectRatio(
          aspectRatio: 3 / 4,
          child: ColoredBox(
            color: kPreviewCardBackground,
            child: Center(child: CupertinoActivityIndicator()),
          ),
        ),
      );
    }

    if (_pageBytes == null) return const SizedBox.shrink();

    // Size the card to exactly the page's aspect ratio — no white letterboxing.
    return LayoutBuilder(
      builder: (_, c) {
        double displayW, displayH;
        if (_pageAspect > 0) {
          final naturalH = c.maxWidth / _pageAspect;
          if (c.maxHeight.isFinite && naturalH > c.maxHeight) {
            displayH = c.maxHeight;
            displayW = c.maxHeight * _pageAspect;
          } else {
            displayW = c.maxWidth;
            displayH = naturalH;
          }
        } else {
          displayW = c.maxWidth;
          displayH = c.maxWidth * 4 / 3;
        }
        return ClipPath(
          clipper: _PreviewSquircleClipper(),
          child: SizedBox(
            width: displayW,
            height: displayH,
            child: _loading
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(_pageBytes!, fit: BoxFit.fill),
                      const CupertinoActivityIndicator(),
                    ],
                  )
                : Image.memory(_pageBytes!, fit: BoxFit.fill),
          ),
        );
      },
    );
  }
}

// ── Shared-radius squircle preview clipper ───────────────────────────────────
class _PreviewSquircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => BoundedContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(kSquircleStadiumRadius),
  ).getOuterPath(Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  bool shouldReclip(_PreviewSquircleClipper old) => false;
}

// ── Circle button — × / ✓ / ‹ / › ───────────────────────────────────────────
// Gel-bloom circle button — uses GelBloomButton from app_theme.dart.
// Icon centering: TextHeightBehavior strips ascent/descent font-metric padding
// so the SF glyph sits at the true geometric centre of the circle.
class _PreviewCircleButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;

  /// Background color of the circle.  Defaults to [kCardColor] for nav/dismiss
  /// buttons.  Pass the accent/category color for save-ready confirm buttons.
  final Color containerColor;
  final VoidCallback onTap;
  // When true the icon is mirrored horizontally, so both nav chevrons can
  // use the SAME sf_chevron_right glyph — guaranteeing identical stroke weight.
  final bool flipHorizontal;
  // Fine vertical nudge for icons whose glyph sits off-centre in its em-square.
  // Chevrons need -2; xmark and checkmark are fine at 0.
  final double verticalIconOffset;
  // Delay before firing onTap. Use ~130 ms for dismiss buttons so the bloom
  // peak is visible before the screen closes. Duration.zero = immediate.
  final Duration tapDelay;

  const _PreviewCircleButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.containerColor = kCardColor,
    this.flipHorizontal = false,
    this.verticalIconOffset = 0.0,
    this.tapDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final fontFamily = icon.fontPackage != null
        ? 'packages/${icon.fontPackage}/${icon.fontFamily}'
        : (icon.fontFamily ?? '');

    final resolvedContainerColor = resolveThemeColor(containerColor, context);
    final resolvedIconColor = resolveThemeColor(iconColor, context);
    return GelBloomButton(
      peakScale: 1.15,
      tapDelay: tapDelay,
      onTap: onTap,
      child: LiquidGlassGelCircle(
        color: resolvedContainerColor,
        child: Center(
          child: Transform.translate(
            offset: Offset(0, verticalIconOffset),
            child: Transform.scale(
              scaleX: flipHorizontal ? -1.0 : 1.0,
              child: SizedBox(
                width: 20,
                height: 20,
                child: Center(
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
      ),
    );
  }
}

// ── Scrollable plain-text viewer ──────────────────────────────────────────────
class _TextPreview extends StatelessWidget {
  final String content;
  final bool monospace;
  const _TextPreview({required this.content, this.monospace = false});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _PreviewSquircleClipper(),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(
          color: kSbSurface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Text(
              content,
              style: TextStyle(
                inherit: false,
                color: kPrimaryLabel,
                fontSize: monospace ? 11 : 13,
                fontFamily: monospace ? 'Courier' : 'SFProText',
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.normal,
                height: 1.55,
                letterSpacing: monospace ? 0 : kTracking16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── DOCX rich-text data model ─────────────────────────────────────────────────

/// A single run of text inside a DOCX paragraph, with uniform formatting.
// ── Sealed DOCX body element — paragraph or table ─────────────────────────────
sealed class _DocxBodyElem {}

final class _DocxParaElem extends _DocxBodyElem {
  final _DocxParagraph para;
  _DocxParaElem(this.para);
}

final class _DocxTableElem extends _DocxBodyElem {
  final List<List<List<_DocxParagraph>>> rows; // [row][col][paragraphs]
  _DocxTableElem(this.rows);
}

class _DocxRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final double? fontSize; // in points (w:sz value / 2)
  final Color? color;

  const _DocxRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.fontSize,
    this.color,
  });
}

/// A single DOCX paragraph with its runs and paragraph-level style.
class _DocxParagraph {
  final List<_DocxRun> runs;
  final int headingLevel; // 0 = body, 1 = H1, 2 = H2, 3 = H3, 4+
  final TextAlign alignment;

  const _DocxParagraph({
    required this.runs,
    this.headingLevel = 0,
    this.alignment = TextAlign.start,
  });

  bool get isEmpty => runs.isEmpty || runs.every((r) => r.text.trim().isEmpty);
}

// ── DOCX text extractor widget (async ZIP → XML parse) ────────────────────────
class _DocxTextView extends StatefulWidget {
  final Uint8List bytes;
  final String filename;
  const _DocxTextView({required this.bytes, required this.filename});

  @override
  State<_DocxTextView> createState() => _DocxTextViewState();
}

class _DocxTextViewState extends State<_DocxTextView> {
  List<_DocxParagraph>? _paragraphs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _extract();
  }

  Future<void> _extract() async {
    // Run in a microtask so the spinner paints first.
    final result = await Future.microtask(
      () => _parseDocxFormatted(widget.bytes),
    );
    if (mounted)
      setState(() {
        _paragraphs = result;
        _loading = false;
      });
  }

  TextSpan _runSpan(_DocxRun run, double basePt) {
    final size = run.fontSize?.clamp(8.0, 72.0) ?? basePt;
    return TextSpan(
      text: run.text,
      style: TextStyle(
        inherit: false,
        color: run.color ?? kPrimaryLabel,
        fontSize: size,
        fontFamily: 'SFProText',
        fontWeight: run.bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
        decoration: run.underline ? TextDecoration.underline : null,
        decorationColor: run.color ?? kPrimaryLabel,
        height: 1.5,
        letterSpacing: 0,
      ),
    );
  }

  Widget _buildParagraph(_DocxParagraph para) {
    final basePt = para.headingLevel == 1
        ? 22.0
        : para.headingLevel == 2
        ? 18.0
        : para.headingLevel == 3
        ? 15.0
        : 13.0;
    final bottomPad = para.headingLevel == 1
        ? 10.0
        : para.headingLevel == 2
        ? 7.0
        : para.headingLevel == 3
        ? 5.0
        : 3.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Text.rich(
        TextSpan(children: para.runs.map((r) => _runSpan(r, basePt)).toList()),
        textAlign: para.alignment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ClipPath(
        clipper: _PreviewSquircleClipper(),
        child: const AspectRatio(
          aspectRatio: 3 / 4,
          child: ColoredBox(
            color: kSbSurface,
            child: Center(child: CupertinoActivityIndicator()),
          ),
        ),
      );
    }

    final paras = _paragraphs ?? [];
    final hasContent = paras.any((p) => !p.isEmpty);

    if (!hasContent) {
      return ClipPath(
        clipper: _PreviewSquircleClipper(),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: _FileDocPreview(
            filename: widget.filename,
            ext: 'docx',
            note: 'No readable text found',
          ),
        ),
      );
    }

    return ClipPath(
      clipper: _PreviewSquircleClipper(),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(
          color: kSbSurface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in paras)
                  if (!p.isEmpty) _buildParagraph(p),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── File/doc icon fallback (unrenderable formats) ─────────────────────────────
class _FileDocPreview extends StatelessWidget {
  final String filename;
  final String ext;
  final String? note; // optional hint line shown below the ext badge

  const _FileDocPreview({required this.filename, required this.ext, this.note});

  @override
  Widget build(BuildContext context) {
    final previewBackground = resolveThemeColor(
      kPreviewCardBackground,
      context,
    );
    final primary = resolveThemeColor(kPrimaryLabel, context);
    final secondary = resolveThemeColor(kSecondaryLabel, context);
    return ColoredBox(
      color: previewBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.doc_fill, size: 52, color: secondary),
              const SizedBox(height: 14),
              Text(
                filename,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  inherit: false,
                  color: primary,
                  fontSize: 15,
                  fontFamily: 'SFProText',
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.normal,
                  letterSpacing: kTracking16,
                ),
              ),
              if (ext.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  ext.toUpperCase(),
                  style: TextStyle(
                    inherit: false,
                    color: secondary,
                    fontSize: 12,
                    fontFamily: 'SFProText',
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                    letterSpacing: kTracking16,
                  ),
                ),
              ],
              if (note != null && note!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    inherit: false,
                    color: kTertiaryLabel,
                    fontSize: 12,
                    fontFamily: 'SFProText',
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                    letterSpacing: kTracking16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── DOCX → PDF builder helpers (pure Dart, on-device) ────────────────────────

pw.Widget _buildPdfPara(_DocxParagraph para) {
  if (para.isEmpty) return pw.SizedBox(height: 5);
  final basePt = para.headingLevel == 1
      ? 18.0
      : para.headingLevel == 2
      ? 14.0
      : para.headingLevel == 3
      ? 12.0
      : 10.0;
  final spans = para.runs.map((r) {
    final fs = (r.fontSize ?? basePt).clamp(6.0, 72.0);
    final font = r.bold && r.italic
        ? pw.Font.helveticaBoldOblique()
        : r.bold
        ? pw.Font.helveticaBold()
        : r.italic
        ? pw.Font.helveticaOblique()
        : pw.Font.helvetica();
    return pw.TextSpan(
      text: r.text,
      style: pw.TextStyle(
        font: font,
        fontSize: fs,
        color: r.color != null
            ? PdfColor(
                r.color!.red / 255,
                r.color!.green / 255,
                r.color!.blue / 255,
              )
            : PdfColors.black,
        decoration: r.underline
            ? pw.TextDecoration.underline
            : pw.TextDecoration.none,
      ),
    );
  }).toList();
  final pdfAlign = switch (para.alignment) {
    TextAlign.center => pw.TextAlign.center,
    TextAlign.right => pw.TextAlign.right,
    TextAlign.justify => pw.TextAlign.justify,
    _ => pw.TextAlign.left,
  };
  return pw.Padding(
    padding: pw.EdgeInsets.only(bottom: para.headingLevel > 0 ? 6 : 2),
    child: pw.RichText(
      text: pw.TextSpan(children: spans),
      textAlign: pdfAlign,
    ),
  );
}

pw.Widget _buildPdfTable(List<List<List<_DocxParagraph>>> rows) {
  final colCount = rows.fold(0, (m, r) => r.length > m ? r.length : m);
  if (colCount == 0) return pw.SizedBox();
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        for (int i = 0; i < colCount; i++) i: const pw.FlexColumnWidth(),
      },
      children: rows
          .map(
            (row) => pw.TableRow(
              children: List.generate(colCount, (ci) {
                final cellParas = ci < row.length
                    ? row[ci]
                    : <_DocxParagraph>[];
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: cellParas.map(_buildPdfPara).toList(),
                  ),
                );
              }),
            ),
          )
          .toList(),
    ),
  );
}

Future<Uint8List?> _convertDocxToPdfBytes(Uint8List docxBytes) async {
  try {
    final elements = await Future.microtask(() => _parseDocxBody(docxBytes));
    if (elements.isEmpty) return null;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 50, 50, 50),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          for (final elem in elements) {
            switch (elem) {
              case _DocxParaElem(:final para):
                widgets.add(_buildPdfPara(para));
              case _DocxTableElem(:final rows):
                widgets.add(_buildPdfTable(rows));
                widgets.add(pw.SizedBox(height: 6));
            }
          }
          return widgets;
        },
      ),
    );
    return await doc.save();
  } catch (_) {
    return null;
  }
}
