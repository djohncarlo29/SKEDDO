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
        let probeSizes: [Double] = stride(from: 1.0, through: 256.0, by: 0.25).map { $0 }
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
        let curves = categories.map { category in
          let traits = UITraitCollection(preferredContentSizeCategory: category)
          return probeSizes.map { size in
            body.scaledValue(for: CGFloat(size), compatibleWith: traits) / CGFloat(size)
          }
        }
        let current = body.scaledValue(for: 17) / base
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
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
