import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nativeStt: NativeSttPlugin?
  private var offlineOcr: NativeOfflineOcrPlugin?
  private var nativeFloatingTabBar: UIViewController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let textScaleChannel = FlutterMethodChannel(
        name: "com.smartscheduler/text_scale",
        binaryMessenger: controller.binaryMessenger
      )
      textScaleChannel.setMethodCallHandler { call, result in
        let categories: [UIContentSizeCategory] = [
          .extraSmall, .small, .medium, .large, .extraLarge,
          .extraExtraLarge, .extraExtraExtraLarge,
          .accessibilityMedium, .accessibilityLarge,
          .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
          .accessibilityExtraExtraExtraLarge
        ]
        let body = UIFontMetrics(forTextStyle: .body)
        let largeTraits = UITraitCollection(
          preferredContentSizeCategory: .large
        )
        let base = body.scaledValue(for: 17, compatibleWith: largeTraits)

        if call.method == "getCurrentScale" {
          // Use the Flutter host window's traits rather than UIKit's ambient
          // current traits. On iPad, the host window's preferredContentSizeCategory
          // can change while the app remains active in Split View or Slide Over.
          // Keeping this endpoint to one scalar makes the live Dart poll cheap.
          let windowTraits = self.window?.traitCollection
          let currentTraits = windowTraits ?? UITraitCollection.current
          let current = body.scaledValue(
            for: 17,
            compatibleWith: currentTraits
          ) / base
          result(current)
          return
        }
        guard call.method == "getProfile" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let probeSizes: [Double] = stride(from: 1.0, through: 256.0, by: 0.25).map { $0 }
        let stops = categories.map { category in
          body.scaledValue(
            for: 17,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
          ) / base
        }
        let curves = categories.map { category in
          let traits = UITraitCollection(preferredContentSizeCategory: category)
          return probeSizes.map { size in
            body.scaledValue(for: CGFloat(size), compatibleWith: traits) / CGFloat(size)
          }
        }
        let windowTraits = self.window?.traitCollection
        let currentTraits = windowTraits ?? UITraitCollection.current
        let current = body.scaledValue(
          for: 17,
          compatibleWith: currentTraits
        ) / base
        result([
          "currentScale": current,
          "stops": stops,
          "probeSizes": probeSizes,
          "curves": curves
        ])
      }
    }
    // Native STT — register after plugin registration so the binary
    // messenger is fully initialised.
    if let controller = window?.rootViewController as? FlutterViewController {
      nativeStt = NativeSttPlugin(messenger: controller.binaryMessenger)
      offlineOcr = NativeOfflineOcrPlugin(messenger: controller.binaryMessenger)
      if #available(iOS 26.0, *) {
        let nativeTabBar = NativeFloatingTabBarController(
          messenger: controller.binaryMessenger
        )
        controller.addChild(nativeTabBar)
        nativeTabBar.view.frame = controller.view.bounds
        nativeTabBar.view.autoresizingMask = [
          .flexibleWidth,
          .flexibleHeight,
        ]
        controller.view.addSubview(nativeTabBar.view)
        nativeTabBar.didMove(toParent: controller)
        nativeFloatingTabBar = nativeTabBar
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
