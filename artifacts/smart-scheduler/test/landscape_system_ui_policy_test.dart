import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/services/landscape_system_ui_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platformCalls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    platformCalls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) {
        platformCalls.add(call);
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('landscape hides status bar but keeps home indicator', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 420);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => LandscapeSystemUiPolicy(
          platformOverride: TargetPlatform.iOS,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SizedBox.expand(),
      ),
    );
    await tester.pump();

    expect(platformCalls, hasLength(1));
    expect(
      platformCalls.single.method,
      'SystemChrome.setEnabledSystemUIOverlays',
    );
    expect(platformCalls.single.arguments, ['SystemUiOverlay.bottom']);
  });

  testWidgets('portrait restores the normal edge-to-edge system bars', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => LandscapeSystemUiPolicy(
          platformOverride: TargetPlatform.iOS,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SizedBox.expand(),
      ),
    );
    await tester.pump();

    expect(platformCalls, hasLength(1));
    expect(platformCalls.single.method, 'SystemChrome.setEnabledSystemUIMode');
    expect(platformCalls.single.arguments, 'SystemUiMode.edgeToEdge');
  });

  testWidgets('rotation switches iOS status-bar visibility both ways', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => LandscapeSystemUiPolicy(
          platformOverride: TargetPlatform.iOS,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SizedBox.expand(),
      ),
    );
    await tester.pump();

    tester.view.physicalSize = const Size(900, 420);
    await tester.pump();
    await tester.pump();

    tester.view.physicalSize = const Size(420, 900);
    await tester.pump();
    await tester.pump();

    expect(platformCalls.map((call) => call.method).toList(), [
      'SystemChrome.setEnabledSystemUIMode',
      'SystemChrome.setEnabledSystemUIOverlays',
      'SystemChrome.setEnabledSystemUIMode',
    ]);
    expect(platformCalls[1].arguments, ['SystemUiOverlay.bottom']);
    expect(platformCalls[2].arguments, 'SystemUiMode.edgeToEdge');
  });
}
