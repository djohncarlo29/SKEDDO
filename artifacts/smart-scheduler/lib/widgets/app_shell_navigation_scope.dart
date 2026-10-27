import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

/// Lets app content share the navigator that owns its pinned toolbar routes.
///
/// The app keeps tab bodies mounted beside that Navigator, so normal
/// [Navigator.of] lookups from a tab would otherwise select the root navigator.
class AppShellNavigationScope extends InheritedWidget {
  const AppShellNavigationScope({
    super.key,
    required this.navigatorKey,
    required this.routeRevision,
    required super.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final ValueNotifier<int> routeRevision;

  static NavigatorState navigatorOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppShellNavigationScope>();
    return scope?.navigatorKey.currentState ??
        Navigator.of(context, rootNavigator: true);
  }

  static ValueListenable<int>? routeChangesOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<AppShellNavigationScope>()
          ?.routeRevision;

  @override
  bool updateShouldNotify(AppShellNavigationScope oldWidget) =>
      navigatorKey != oldWidget.navigatorKey ||
      routeRevision != oldWidget.routeRevision;
}

class AppShellNavigationObserver extends NavigatorObserver {
  AppShellNavigationObserver(this.routeRevision);

  final ValueNotifier<int> routeRevision;
  bool _disposed = false;

  void _notifyRouteChange() {
    if (!_disposed) routeRevision.value++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is ModalRoute<dynamic>) {
      route.completed.then((_) => _notifyRouteChange());
    } else {
      _notifyRouteChange();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _notifyRouteChange();
  }

  void dispose() => _disposed = true;
}

Future<T?> showAppCupertinoDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  return AppShellNavigationScope.navigatorOf(context).push<T>(
    CupertinoDialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    ),
  );
}
