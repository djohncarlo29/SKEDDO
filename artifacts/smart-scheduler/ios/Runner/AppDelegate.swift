import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nativeStt: NativeSttPlugin?
  private var offlineOcr: NativeOfflineOcrPlugin?

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
        guard call.method == "getProfile" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let categories: [UIContentSizeCategory] = [
          .extraSmall, .small, .medium, .large, .extraLarge,
          .extraExtraLarge, .extraExtraExtraLarge
        ]
        let body = UIFontMetrics(forTextStyle: .body)
        let base = body.scaledValue(for: 17, compatibleWith: UITraitCollection(
          preferredContentSizeCategory: .large
        ))
        let stops = categories.map { category in
          body.scaledValue(
            for: 17,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
          ) / base
        }
        let current = body.scaledValue(for: 17) / base
        result(["currentScale": current, "stops": stops])
      }
    }
    // Native STT — register after plugin registration so the binary
    // messenger is fully initialised.
    if let controller = window?.rootViewController as? FlutterViewController {
      nativeStt = NativeSttPlugin(messenger: controller.binaryMessenger)
      offlineOcr = NativeOfflineOcrPlugin(messenger: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
