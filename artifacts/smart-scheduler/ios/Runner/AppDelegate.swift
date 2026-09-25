import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nativeStt: NativeSttPlugin?
  private var offlineOcr: NativeOfflineOcrPlugin?
  private var nativeTabBarController: UIViewController?

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
    // Native bridges — register after plugin registration so the binary
    // messenger is fully initialised.
    if let controller = window?.rootViewController as? FlutterViewController {
      nativeStt = NativeSttPlugin(messenger: controller.binaryMessenger)
      offlineOcr = NativeOfflineOcrPlugin(messenger: controller.binaryMessenger)
      let dropMetadataChannel = FlutterMethodChannel(
        name: "com.smartscheduler/drop_metadata",
        binaryMessenger: controller.binaryMessenger
      )
      dropMetadataChannel.setMethodCallHandler { call, result in
        guard call.method == "resolveUriMetadata" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let arguments = call.arguments as? [String: Any]
        let uri = arguments?["uri"] as? String
        let typeIdentifiers = arguments?["typeIdentifiers"] as? [String] ?? []
        result(self.resolveDropMetadata(
          uriString: uri,
          typeIdentifiers: typeIdentifiers
        ))
      }
      let nativeTabBar = NativeSystemTabBarController(
        messenger: controller.binaryMessenger
      )
      let fluidSliderRegistrar = registrar(forPlugin: "NativeFluidSliderPlugin")
      fluidSliderRegistrar.register(
        NativeFluidSliderFactory(messenger: controller.binaryMessenger),
        withId: NativeFluidSliderFactory.viewType
      )
      controller.addChild(nativeTabBar)
      nativeTabBar.view.frame = controller.view.bounds
      nativeTabBar.view.autoresizingMask = [
        .flexibleWidth,
        .flexibleHeight,
      ]
      controller.view.addSubview(nativeTabBar.view)
      nativeTabBar.didMove(toParent: controller)
      nativeTabBarController = nativeTabBar
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func resolveDropMetadata(
    uriString: String?,
    typeIdentifiers: [String]
  ) -> [String: Any] {
    let url: URL?
    if let uriString,
       let candidate = URL(string: uriString),
       candidate.isFileURL {
      url = candidate
    } else {
      url = nil
    }
    let hasSecurityScope = url?.startAccessingSecurityScopedResource() ?? false
    defer {
      if hasSecurityScope {
        url?.stopAccessingSecurityScopedResource()
      }
    }

    let resourceValues = url.flatMap {
      try? $0.resourceValues(forKeys: [.nameKey, .typeIdentifierKey])
    }
    let displayName = resourceValues?.name ?? url?.lastPathComponent

    let genericTypeIdentifiers: Set<String> = [
      "public.data",
      "public.content",
      "public.item",
      "public.text",
      "public.image",
      "public.movie",
      "public.audio",
      "public.archive",
      "public.url",
      "public.file-url",
      "public.folder",
      "public.composite-content",
    ]

    func typeForIdentifier(_ identifier: String) -> UTType? {
      if identifier.contains("/") {
        return UTType(mimeType: identifier)
      }
      return UTType(identifier)
    }

    var candidateIdentifiers = typeIdentifiers.filter {
      !genericTypeIdentifiers.contains($0.lowercased())
    }
    if let resourceTypeIdentifier = resourceValues?.typeIdentifier,
       !genericTypeIdentifiers.contains(resourceTypeIdentifier.lowercased()) {
      candidateIdentifiers.insert(resourceTypeIdentifier, at: 0)
    }
    let candidateTypes = candidateIdentifiers.compactMap {
      typeForIdentifier($0)
    }
    let reportedType = candidateTypes
      .first(where: { $0.preferredFilenameExtension != nil })
      ?? candidateTypes.first(where: { $0.preferredMIMEType != nil })
    let pathType = url.flatMap { candidate in
      guard !candidate.pathExtension.isEmpty else {
        return nil
      }
      return UTType(filenameExtension: candidate.pathExtension)
    }
    let resolvedType = reportedType ?? pathType

    var metadata: [String: Any] = [:]
    if let displayName, !displayName.isEmpty {
      metadata["displayName"] = displayName
    }
    if let mimeType = resolvedType?.preferredMIMEType {
      metadata["mimeType"] = mimeType
    }
    if let preferredExtension = resolvedType?.preferredFilenameExtension {
      metadata["preferredExtension"] = preferredExtension
    }
    return metadata
  }
}
