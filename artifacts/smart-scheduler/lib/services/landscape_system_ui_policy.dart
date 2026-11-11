import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Applies the iOS status-bar visibility policy as the app window rotates.
///
/// Android uses WindowInsetsControllerCompat in MainActivity so modern Android
/// versions retain transient system-bar reveal and edge-to-edge layout.
class LandscapeSystemUiPolicy extends StatefulWidget {
  const LandscapeSystemUiPolicy({
    super.key,
    required this.child,
    @visibleForTesting this.platformOverride,
  });

  final Widget child;

  @visibleForTesting
  final TargetPlatform? platformOverride;

  @override
  State<LandscapeSystemUiPolicy> createState() =>
      _LandscapeSystemUiPolicyState();
}

class _LandscapeSystemUiPolicyState extends State<LandscapeSystemUiPolicy>
    with WidgetsBindingObserver {
  bool? _lastRequestedLandscape;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncForCurrentOrientation();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncForCurrentOrientation();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The OS may have reset status-bar visibility while SKEDDO was inactive.
      _lastRequestedLandscape = null;
      _syncForCurrentOrientation();
    }
  }

  void _syncForCurrentOrientation() {
    final platform = widget.platformOverride ?? defaultTargetPlatform;
    if (platform != TargetPlatform.iOS) return;

    final size = MediaQuery.sizeOf(context);
    if (size.isEmpty) return;
    final isLandscape = size.width > size.height;
    if (_lastRequestedLandscape == isLandscape) return;
    _lastRequestedLandscape = isLandscape;

    unawaited(_applyIosStatusBarVisibility(isLandscape));
  }

  Future<void> _applyIosStatusBarVisibility(bool isLandscape) async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        isLandscape ? SystemUiMode.manual : SystemUiMode.edgeToEdge,
        // Keep the iOS home indicator available; only the status bar is hidden.
        overlays: isLandscape ? const [SystemUiOverlay.bottom] : null,
      );
    } catch (error) {
      if (_lastRequestedLandscape == isLandscape) {
        _lastRequestedLandscape = null;
      }
      debugPrint('Unable to update iOS status bar visibility: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
