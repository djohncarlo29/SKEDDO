import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nativeStt: NativeSttPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Native STT — register after plugin registration so the binary
    // messenger is fully initialised.
    if let controller = window?.rootViewController as? FlutterViewController {
      nativeStt = NativeSttPlugin(messenger: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
