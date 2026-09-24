import Flutter
import SwiftUI
import UIKit

/// Native tab-bar surface. UITabBarController owns the system presentation:
/// classic bottom bar on older iOS and floating Liquid Glass on iOS 26+.
/// Flutter continues to own the actual tab content.
///
/// The transparent child controllers are intentional. The Flutter view remains
/// the content surface underneath this controller, while this overlay owns
/// only the native tab-bar chrome and its hit testing.
final class NativeSystemTabBarController: UITabBarController,
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
        case "isFloating":
            if #available(iOS 26.0, *) {
                result(true)
            } else {
                result(false)
            }
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

private final class NativeTabPlaceholderViewController: UIViewController {
    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
    }
}

/// Lets Flutter receive all touches outside the native tab-bar subtree.
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

private struct NativeFluidSliderConfiguration {
    var value: Double
    let minimumValue: Double
    let maximumValue: Double
    let minimumIcon: String
    let maximumIcon: String
    let iconSize: CGFloat
    let divisions: Int
    var accentColor: Color
    var tickColor: Color
    var darkMode: Bool
}

private final class NativeFluidSliderModel: ObservableObject {
    @Published var configuration: NativeFluidSliderConfiguration

    init(configuration: NativeFluidSliderConfiguration) {
        self.configuration = configuration
    }
}

private final class NativeFluidSliderEventRelay {
    var sink: FlutterEventSink?
}

private struct NativeFluidSliderRow: View {
    @ObservedObject var model: NativeFluidSliderModel
    let relay: NativeFluidSliderEventRelay

    private var progress: Double {
        let range = model.configuration.maximumValue - model.configuration.minimumValue
        guard range > 0 else { return 0 }
        return min(
            max(
                (model.configuration.value - model.configuration.minimumValue) / range,
                0
            ),
            1
        )
    }

    private func snappedValue(_ value: Double) -> Double {
        let minimumValue = model.configuration.minimumValue
        let maximumValue = model.configuration.maximumValue
        let clampedValue = min(max(value, minimumValue), maximumValue)
        let divisions = model.configuration.divisions
        guard divisions > 0, maximumValue > minimumValue else {
            return clampedValue
        }

        let step = (maximumValue - minimumValue) / Double(divisions)
        guard step > 0 else { return clampedValue }
        return min(
            max(
                minimumValue
                    + ((clampedValue - minimumValue) / step).rounded() * step,
                minimumValue
            ),
            maximumValue
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            edgeIcon(name: model.configuration.minimumIcon, isLeading: true)

            Slider(
                value: Binding(
                    get: { model.configuration.value },
                    set: { value in
                        var configuration = model.configuration
                        configuration.value = min(
                            max(value, configuration.minimumValue),
                            configuration.maximumValue
                        )
                        model.configuration = configuration
                        relay.sink?([
                            "phase": "change",
                            "value": configuration.value,
                        ])
                    }
                ),
                in: model.configuration.minimumValue...model.configuration.maximumValue,
                onEditingChanged: { isEditing in
                    let currentValue = model.configuration.value
                    // Match Flutter's continuous drag and snap on release;
                    // Slider(step:) would quantize every movement instead.
                    let value = isEditing ? currentValue : snappedValue(currentValue)

                    if !isEditing, value != currentValue {
                        var configuration = model.configuration
                        configuration.value = value
                        model.configuration = configuration
                        relay.sink?([
                            "phase": "change",
                            "value": value,
                        ])
                    }

                    relay.sink?([
                        "phase": isEditing ? "start" : "end",
                        "value": value,
                    ])
                }
            )
            .tint(model.configuration.accentColor)
            .accessibilityIdentifier("native-fluid-slider")
            .overlay {
                GeometryReader { geometry in
                    let divisions = max(model.configuration.divisions, 1)
                    ForEach(0...divisions, id: \.self) { index in
                        Capsule()
                            .fill(model.configuration.tickColor)
                            .frame(width: 2, height: 3)
                            .position(
                                x: 13
                                    + (geometry.size.width - 26)
                                    * CGFloat(index)
                                    / CGFloat(divisions),
                                y: geometry.size.height / 2 + 8
                            )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            edgeIcon(name: model.configuration.maximumIcon, isLeading: false)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Capsule())
        .clipShape(Capsule())
        .environment(
            \.colorScheme,
            model.configuration.darkMode ? .dark : .light
        )
    }

    private func edgeIcon(name: String, isLeading: Bool) -> some View {
        let pressure: Double
        if isLeading {
            pressure = min(max((0.05 - progress) / 0.05, 0), 1)
        } else {
            pressure = min(max((progress - 0.95) / 0.05, 0), 1)
        }

        return Image(name)
            .resizable()
            .scaledToFit()
            .frame(
                width: model.configuration.iconSize,
                height: model.configuration.iconSize
            )
            .scaleEffect(1 - pressure * 0.16)
            .offset(x: (isLeading ? -1 : 1) * pressure * 10)
            .animation(
                .interactiveSpring(
                    response: 0.34,
                    dampingFraction: 0.74,
                    blendDuration: 0.16
                ),
                value: pressure
            )
            .accessibilityHidden(true)
    }
}

final class NativeFluidSliderFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "com.smartscheduler/native_fluid_slider"

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        NativeFluidSliderPlatformView(
            frame: frame,
            viewId: viewId,
            arguments: args as? [String: Any] ?? [:],
            messenger: messenger
        )
    }
}

private final class NativeFluidSliderPlatformView: NSObject,
    FlutterPlatformView,
    FlutterStreamHandler {
    private let hostingController: UIHostingController<NativeFluidSliderRow>
    private let relay: NativeFluidSliderEventRelay
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel

    init(
        frame: CGRect,
        viewId: Int64,
        arguments: [String: Any],
        messenger: FlutterBinaryMessenger
    ) {
        let model = NativeFluidSliderModel(
            configuration: Self.configuration(from: arguments)
        )
        let relay = NativeFluidSliderEventRelay()
        let channelSuffix = "\(viewId)"

        self.relay = relay
        self.methodChannel = FlutterMethodChannel(
            name: "com.smartscheduler/native_fluid_slider/\(channelSuffix)",
            binaryMessenger: messenger
        )
        self.eventChannel = FlutterEventChannel(
            name: "com.smartscheduler/native_fluid_slider_events/\(channelSuffix)",
            binaryMessenger: messenger
        )
        self.hostingController = UIHostingController(
            rootView: NativeFluidSliderRow(model: model, relay: relay)
        )

        super.init()

        hostingController.view.frame = frame
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        eventChannel.setStreamHandler(self)
        methodChannel.setMethodCallHandler { [weak model] call, result in
            guard call.method == "update",
                  let values = call.arguments as? [String: Any],
                  let model = model
            else {
                result(FlutterMethodNotImplemented)
                return
            }
            model.configuration = Self.configuration(
                from: values,
                preservingValue: model.configuration.value
            )
            result(nil)
        }
    }

    func view() -> UIView {
        hostingController.view
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        relay.sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        relay.sink = nil
        return nil
    }

    deinit {
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }

    private static func configuration(
        from values: [String: Any],
        preservingValue oldValue: Double? = nil
    ) -> NativeFluidSliderConfiguration {
        let minimumValue = (values["minimumValue"] as? NSNumber)?.doubleValue ?? 0
        let maximumValue = (values["maximumValue"] as? NSNumber)?.doubleValue ?? 1
        let normalizedMaximum = max(maximumValue, minimumValue + 0.0001)
        let requestedValue =
            (values["value"] as? NSNumber)?.doubleValue ?? oldValue ?? minimumValue

        return NativeFluidSliderConfiguration(
            value: min(max(requestedValue, minimumValue), normalizedMaximum),
            minimumValue: minimumValue,
            maximumValue: normalizedMaximum,
            minimumIcon: values["minimumIcon"] as? String ?? "TextSizeSmaller",
            maximumIcon: values["maximumIcon"] as? String ?? "TextSizeLarger",
            iconSize: CGFloat(
                (values["iconSize"] as? NSNumber)?.doubleValue ?? 20
            ),
            divisions: (values["divisions"] as? NSNumber)?.intValue ?? 0,
            accentColor: color(from: values["accentColor"] as? NSNumber),
            tickColor: color(from: values["tickColor"] as? NSNumber),
            darkMode: values["darkMode"] as? Bool ?? false
        )
    }

    private static func color(from number: NSNumber?) -> Color {
        let argb = number?.uint32Value ?? 0xFF007AFF
        return Color(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}