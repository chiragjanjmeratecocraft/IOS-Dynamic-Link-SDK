import Combine
import Foundation

/// Callbacks mirroring RN `ISmartLinkingOptions` (`src/types/common.ts` + README).
public struct SmartLinkingOptions {
    public var onUrl: ((String) -> Void)?
    public var onSuccess: ((DynamicLinkResponse) -> Void)?
    public var onError: ((Error) -> Void)?
    /// Optional; RN README mentions this for store / web fallbacks when you wire it yourself.
    public var onFallback: ((String) -> Void)?
    /// Called when the user opens a hosted short link (`https://…/s/{slug}`) and we resolve the HTML redirect to a destination URL (e.g. App Store / Snapchat). Not used for `?short_code=` API links.
    public var onResolvedDestination: ((URL) -> Void)?

    public init(
        onUrl: ((String) -> Void)? = nil,
        onSuccess: ((DynamicLinkResponse) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onFallback: ((String) -> Void)? = nil,
        onResolvedDestination: ((URL) -> Void)? = nil
    ) {
        self.onUrl = onUrl
        self.onSuccess = onSuccess
        self.onError = onError
        self.onFallback = onFallback
        self.onResolvedDestination = onResolvedDestination
    }
}

/// Native counterpart to RN `useSmartLinking` (`src/hooks.ts`): first-launch `pending-redirect`, then URL → `short_code` → `fetchDynamicLink`.
@MainActor
public final class SmartLinkingCoordinator: ObservableObject {
    private let client: DynamicLinkClient
    private let store: any DynamicLinkFirstInstallStoring

    private var options = SmartLinkingOptions()
    private var firstLaunchTask: Task<Void, Never>?

    public init(
        client: DynamicLinkClient = .init(),
        store: any DynamicLinkFirstInstallStoring = UserDefaultsFirstInstallStore()
    ) {
        self.client = client
        self.store = store
    }

    /// Updates callbacks and runs the one-time first-install flow (same order as RN’s first `useEffect`).
    public func start(
        options: SmartLinkingOptions,
        appId: String = SmartLinkingDefaults.appId,
        deviceType: String = SmartLinkingDefaults.deviceType,
        userAgent: String? = SmartLinkingDefaults.userAgent
    ) async {
        self.options = options

        if firstLaunchTask == nil {
            firstLaunchTask = Task { @MainActor [weak self] in
                await self?.performFirstLaunch(appId: appId, deviceType: deviceType, userAgent: userAgent)
            }
        }
        await firstLaunchTask?.value
    }

    /// Call from `onOpenURL` / custom schemes / forwarded `UIApplication` open URL.
    public func handleOpenURL(_ url: URL) async {
        await handleIncomingURLString(url.absoluteString)
    }

    /// Call from `onContinueUserActivity` / Universal Links (`NSUserActivityTypeBrowsingWeb`).
    public func handleContinueUserActivity(_ userActivity: NSUserActivity) async {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL
        else { return }
        await handleOpenURL(url)
    }

    /// Same pipeline as RN `handleUrl` when the system gives you a string.
    /// Supports `?short_code=` (JSON API) and same-host `https://…/s/{slug}` HTML short links.
    public func handleIncomingURLString(_ urlString: String) async {
        options.onUrl?(urlString)
        let shortCode = DynamicLinkClient.extractShortCode(from: urlString)
            ?? DynamicLinkClient.extractShortCodeWithPathFallback(
                from: urlString,
                allowedHosts: client.pathShortCodeHosts
            )
        if let shortCode {
            do {
                let data = try await client.linkDetails(shortCode: shortCode)
                options.onSuccess?(data)
            } catch {
                options.onError?(error)
            }
            return
        }
        guard let pageURL = URL(string: urlString),
            DynamicLinkClient.isHostedShortLinkPage(pageURL, apiBaseURL: client.apiRootURL)
        else { return }
        do {
            let destination = try await client.resolveHostedShortLinkPage(at: pageURL)
            options.onResolvedDestination?(destination)
        } catch {
            options.onError?(error)
        }
    }

    private func performFirstLaunch(appId: String, deviceType: String, userAgent: String?) async {
        do {
            if let data = try await client.consumeFirstLaunchPendingRedirectIfNeeded(
                appId: appId,
                deviceType: deviceType,
                userAgent: userAgent,
                store: store
            ) {
                options.onSuccess?(data)
            }
        } catch {
            options.onError?(error)
        }
    }
}
