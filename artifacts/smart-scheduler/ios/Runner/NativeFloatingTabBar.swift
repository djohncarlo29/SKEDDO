import Flutter
import UIKit

/// iOS 26's native tab-bar surface. UITabBarController owns the floating
/// Liquid Glass presentation; Flutter continues to own the actual tab content.
///
/// The transparent child controllers are intentional. The Flutter view remains
/// the content surface underneath this controller, while this overlay owns
/// only the native tab-bar chrome and its hit testing.
@available(iOS 26.0, *)
final class NativeFloatingTabBarController: UITabBarController,
    UITabBarControllerDelegate {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.smartscheduler/native_tab_bar",
            binaryMessenger: messenger
        )
        super.init(nibName: nil, bundle: nil)
        delegate = self
        channel.setMethodCallHandler(handle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NativeTabBarPassthroughView()
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let tabs = [
            makeTab(title: "Notes", imageName: "doc.text"),
            makeTab(title: "Calendar", imageName: "calendar"),
            makeTab(title: "Events", imageName: "list.bullet"),
        ]
        viewControllers = tabs

        // Do not replace the system appearance with a custom background. On
        // iOS 26 this is what lets UIKit provide the native floating glass.
        tabBar.tintColor = .systemBlue
        tabBar.unselectedItemTintColor = .secondaryLabel
        tabBar.isTranslucent = true
        selectedIndex = 0
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (view as? NativeTabBarPassthroughView)?.interactiveView = tabBar
    }

    private func makeTab(title: String, imageName: String) -> UIViewController {
        let controller = NativeTabPlaceholderViewController()
        controller.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: imageName),
            selectedImage: UIImage(systemName: imageName)
        )
        controller.tabBarItem.accessibilityIdentifier =
            "native-tab-\(title.lowercased())"
        return controller
    }

    private func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "isAvailable":
            result(true)
        case "setSelectedIndex":
            guard let index = call.arguments as? Int,
                  index >= 0,
                  index < (viewControllers?.count ?? 0)
            else {
                result(
                    FlutterError(
                        code: "INVALID_TAB_INDEX",
                        message: "The native tab index is invalid.",
                        details: nil
                    )
                )
                return
            }
            if selectedIndex != index {
                selectedIndex = index
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController
    ) {
        channel.invokeMethod("tabSelected", arguments: selectedIndex)
    }
}

@available(iOS 26.0, *)
private final class NativeTabPlaceholderViewController: UIViewController {
    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
    }
}

/// Lets Flutter receive all touches outside the native tab-bar subtree.
@available(iOS 26.0, *)
private final class NativeTabBarPassthroughView: UIView {
    weak var interactiveView: UIView?

    override func hitTest(
        _ point: CGPoint,
        with event: UIEvent?
    ) -> UIView? {
        guard let hit = super.hitTest(point, with: event),
              let interactiveView,
              hit.isDescendant(of: interactiveView)
        else {
            return nil
        }
        return hit
    }
}