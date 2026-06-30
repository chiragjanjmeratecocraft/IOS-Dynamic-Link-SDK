#if canImport(SwiftUI)
import SwiftUI

// MARK: - Environment (optional access from any child view)

private enum SmartLinkingCoordinatorEnvironmentKey: EnvironmentKey {
    static let defaultValue: SmartLinkingCoordinator? = nil
}

public extension EnvironmentValues {
    /// Set automatically by ``SmartLinkingRoot``. Use for manual tests or `handleIncomingURLString` from UI.
    var smartLinkingCoordinator: SmartLinkingCoordinator? {
        get { self[SmartLinkingCoordinatorEnvironmentKey.self] }
        set { self[SmartLinkingCoordinatorEnvironmentKey.self] = newValue }
    }
}

// MARK: - App root (RN `useSmartLinking` equivalent)

/// Owns a ``SmartLinkingCoordinator`` and applies the same wiring as React Native `useSmartLinking` — use once at the root of your `WindowGroup` in any app.
public struct SmartLinkingRoot<Content: View>: View {
    @StateObject private var coordinator: SmartLinkingCoordinator
    private let options: SmartLinkingOptions
    private let appId: String
    private let deviceType: String
    private let userAgent: String?
    private let content: () -> Content

    /// - Parameters:
    ///   - configuration: Override API base URL or timeout when not using the default Tecocraft backend.
    ///   - options: Callbacks (`onUrl`, `onSuccess`, `onError`, …) — same idea as RN `useSmartLinking`.
    ///   - appId: Defaults to your app’s bundle id (`SmartLinkingDefaults.appId`).
    ///   - deviceType: Defaults to `IOS` (`SmartLinkingDefaults.deviceType`).
    ///   - userAgent: Defaults to an RN-style UA string; pass `nil` to omit the header.
    public init(
        configuration: DynamicLinkConfiguration = .init(),
        options: SmartLinkingOptions,
        appId: String = SmartLinkingDefaults.appId,
        deviceType: String = SmartLinkingDefaults.deviceType,
        userAgent: String? = SmartLinkingDefaults.userAgent,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _coordinator = StateObject(wrappedValue: SmartLinkingCoordinator(client: DynamicLinkClient(configuration: configuration)))
        self.options = options
        self.appId = appId
        self.deviceType = deviceType
        self.userAgent = userAgent
        self.content = content
    }

    public var body: some View {
        content()
            .environment(\.smartLinkingCoordinator, coordinator)
            .smartLinking(coordinator, options: options, appId: appId, deviceType: deviceType, userAgent: userAgent)
    }
}

// MARK: - View modifier

public extension View {
    /// Wires RN-style smart linking: runs first-launch `pending-redirect` once, then handles custom URLs and Universal Links.
    func smartLinking(
        _ coordinator: SmartLinkingCoordinator,
        options: SmartLinkingOptions,
        appId: String = SmartLinkingDefaults.appId,
        deviceType: String = SmartLinkingDefaults.deviceType,
        userAgent: String? = SmartLinkingDefaults.userAgent
    ) -> some View {
        modifier(SmartLinkingModifier(
            coordinator: coordinator,
            options: options,
            appId: appId,
            deviceType: deviceType,
            userAgent: userAgent
        ))
    }
}

private struct SmartLinkingModifier: ViewModifier {
    let coordinator: SmartLinkingCoordinator
    let options: SmartLinkingOptions
    let appId: String
    let deviceType: String
    let userAgent: String?

    func body(content: Content) -> some View {
        content
            .task {
                await coordinator.start(
                    options: options,
                    appId: appId,
                    deviceType: deviceType,
                    userAgent: userAgent
                )
            }
            .onOpenURL { url in
                Task { await coordinator.handleOpenURL(url) }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                Task { await coordinator.handleContinueUserActivity(activity) }
            }
    }
}
#endif
