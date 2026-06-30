import Foundation
import SwiftUI

/// Default API root used by the published React Native SDK (`src/constants.ts`).
public let defaultDynamicLinkBaseURL = URL(string: "https://backend-dynamiclink.tecocraft.us/api/links")!

public struct DynamicLinkConfiguration: Sendable {
    public var baseURL: URL
    public var timeout: TimeInterval
    /// Hosts where `https://host/{code}` uses the last path segment as short code (Flutter `pathShortCodeHosts`).
    public var pathShortCodeHosts: Set<String>?

    public init(
        baseURL: URL = defaultDynamicLinkBaseURL,
        timeout: TimeInterval = 10,
        pathShortCodeHosts: Set<String>? = nil
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        if let pathShortCodeHosts {
            self.pathShortCodeHosts = pathShortCodeHosts
        } else if let host = baseURL.host?.lowercased() {
            self.pathShortCodeHosts = [host]
        } else {
            self.pathShortCodeHosts = nil
        }
    }
}

/// Persists the same logical flag as RN `STORAGE_KEYS.HAS_FIRST_INSTALL` (AsyncStorage on RN; `UserDefaults` here).
public protocol DynamicLinkFirstInstallStoring: Sendable {
    func hasRecordedFirstInstall() -> Bool
    func setFirstInstallRecorded() async
}

public final class UserDefaultsFirstInstallStore: DynamicLinkFirstInstallStoring, @unchecked Sendable {
    public static let defaultKey = "@storage.hasFirstInstall"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = UserDefaultsFirstInstallStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func hasRecordedFirstInstall() -> Bool {
        defaults.string(forKey: key) == "true"
    }

    public func setFirstInstallRecorded() async {
        defaults.set("true", forKey: key)
    }

    /// Flutter `hasHandledFirstInstall` / RN storage read.
    public static func hasHandledFirstInstall(defaults: UserDefaults = .standard, key: String = defaultKey) -> Bool {
        defaults.string(forKey: key) == "true"
    }

    /// Flutter `resetFirstInstallFlag` for QA deferred-link retests.
    public static func resetFirstInstallFlag(defaults: UserDefaults = .standard, key: String = defaultKey) {
        defaults.removeObject(forKey: key)
    }
}

/// Native counterpart to RN `fetchDynamicLink` / `trackPendingRedirect` in `src/utils.ts`.
public struct DynamicLinkClient: Sendable {
    private let configuration: DynamicLinkConfiguration
    private let session: URLSession

    public init(configuration: DynamicLinkConfiguration = .init(), session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    /// API root (`…/api/links`) — use with ``isHostedShortLinkPage(_:apiBaseURL:)`` when the client uses a custom base URL.
    public var apiRootURL: URL { configuration.baseURL }

    /// Hosts used by ``extractShortCodeWithPathFallback(from:allowedHosts:)`` when `allowedHosts` is omitted.
    public var pathShortCodeHosts: Set<String>? { configuration.pathShortCodeHosts }

    /// `GET {baseURL}/code/{shortCode}` — same as RN `fetchDynamicLink`.
    public func linkDetails(shortCode: String) async throws -> DynamicLinkResponse {
        let url = configuration.baseURL
            .appendingPathComponent("code", isDirectory: false)
            .appendingPathComponent(shortCode, isDirectory: false)

        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.timeout

        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response: response, data: data)

        return try Self.decodeEnvelope(data)
    }

    /// `POST {baseURL}/pending-redirect` then `GET {baseURL}/code/{shortCode}`.
    /// The POST response usually contains only `short_code`; full JSON is loaded in the second GET (same as deferred testing flow).
    public func pendingRedirect(appId: String, deviceType: String, userAgent: String?) async throws -> DynamicLinkResponse? {
        let url = configuration.baseURL.appendingPathComponent("pending-redirect")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        let body = PendingRedirectBody(appId: appId, deviceType: deviceType)
        request.httpBody = try JSONEncoder().encode(body)

        Self.log("POST \(url.absoluteString) app_id=\(appId) device_type=\(deviceType)")

        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response: response, data: data)

        let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        Self.log("pending-redirect response: \(bodyText)")

        let envelope: DynamicLinkAPIEnvelope<PendingRedirectData>
        do {
            envelope = try JSONDecoder().decode(DynamicLinkAPIEnvelope<PendingRedirectData>.self, from: data)
        } catch {
            Self.log("pending-redirect decode failed: \(error.localizedDescription)")
            throw DynamicLinkError.decodingFailed("\(error.localizedDescription). Body: \(bodyText)")
        }

        guard let shortCode = envelope.data?.shortCode?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !shortCode.isEmpty
        else {
            Self.log("pending-redirect: no short_code in data (no deferred link for this install)")
            return nil
        }

        Self.log("pending-redirect short_code=\(shortCode) → GET /code/\(shortCode)")
        return try await linkDetails(shortCode: shortCode)
    }

    /// RN parity alias for ``linkDetails(shortCode:)``.
    public func fetchDynamicLink(shortCode: String) async throws -> DynamicLinkResponse {
        try await linkDetails(shortCode: shortCode)
    }

    /// RN parity alias for ``pendingRedirect(appId:deviceType:userAgent:)`` using ``SmartLinkingDefaults``.
    public func trackPendingRedirect() async throws -> DynamicLinkResponse? {
        try await pendingRedirect(
            appId: SmartLinkingDefaults.appId,
            deviceType: SmartLinkingDefaults.deviceType,
            userAgent: SmartLinkingDefaults.userAgent
        )
    }

    /// Matches RN `extractShortCode`: reads `short_code` from the **query string** only.
    public static func extractShortCode(from urlString: String) -> String? {
        guard let query = urlString.split(separator: "?", maxSplits: 1).dropFirst().first else { return nil }
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == "short_code" else { continue }
            let value = parts[1].removingPercentEncoding ?? parts[1]
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// Flutter `extractShortCodeWithPathFallback`: query `short_code` first, then last path segment on allowed hosts.
    public static func extractShortCodeWithPathFallback(
        from urlString: String,
        allowedHosts: Set<String>? = nil
    ) -> String? {
        if let fromQuery = extractShortCode(from: urlString) {
            return fromQuery
        }
        guard let url = URL(string: urlString),
            let host = url.host?.lowercased(),
            let allowedHosts,
            allowedHosts.contains(host)
        else { return nil }

        let segments = url.path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        guard let last = segments.last else { return nil }
        guard last.count >= 4,
            last.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else { return nil }
        return last
    }

    /// Runs the first-launch deferred redirect once (same control flow as deferred smart linking on first open).
    public func consumeFirstLaunchPendingRedirectIfNeeded(
        appId: String,
        deviceType: String,
        userAgent: String?,
        store: any DynamicLinkFirstInstallStoring
    ) async throws -> DynamicLinkResponse? {
        if store.hasRecordedFirstInstall() {
            Self.log("pending-redirect skipped (first install already handled)")
            return nil
        }
        do {
            let data = try await pendingRedirect(appId: appId, deviceType: deviceType, userAgent: userAgent)
            await store.setFirstInstallRecorded()
            if data == nil {
                Self.log("pending-redirect complete: no deferred link payload")
            }
            return data
        } catch {
            Self.log("pending-redirect failed: \(error)")
            throw error
        }
    }

    private struct PendingRedirectBody: Encodable {
        let appId: String
        let deviceType: String

        enum CodingKeys: String, CodingKey {
            case appId = "app_id"
            case deviceType = "device_type"
        }
    }

    /// Same host as `apiBaseURL` and path `/s/{slug}` (Tecocraft hosted short links).
    public static func isHostedShortLinkPage(_ url: URL, apiBaseURL: URL) -> Bool {
        guard let h1 = url.host?.lowercased(), let h2 = apiBaseURL.host?.lowercased(), h1 == h2 else { return false }
        let parts = url.path.split(separator: "/").map(String.init)
        return parts.count == 2 && parts[0].lowercased() == "s" && !parts[1].isEmpty
    }

    /// Fetches an HTML short link page (`https://host/s/{slug}`) and returns the destination URL embedded in the markup.
    public func resolveHostedShortLinkPage(at pageURL: URL) async throws -> URL {
        guard Self.isHostedShortLinkPage(pageURL, apiBaseURL: configuration.baseURL) else {
            throw DynamicLinkError.invalidURL
        }
        var request = URLRequest(url: pageURL)
        request.timeoutInterval = configuration.timeout

        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response: response, data: data)
        guard let html = String(data: data, encoding: .utf8) else { throw DynamicLinkError.emptyResponse }
        guard let destination = HostedShortLinkHTMLParser.firstRedirectURL(inHTML: html) else {
            throw DynamicLinkError.shortLinkRedirectNotFound
        }
        return destination
    }

    private static func throwIfNeeded(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ... 299).contains(http.statusCode) else {
            throw DynamicLinkError.httpStatus(http.statusCode)
        }
        if data.isEmpty { throw DynamicLinkError.emptyResponse }
    }

    private static func decodeEnvelope(_ data: Data) throws -> DynamicLinkResponse {
        let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        do {
            let envelope = try JSONDecoder().decode(DynamicLinkAPIEnvelope<DynamicLinkResponse>.self, from: data)
            guard let value = envelope.data else { throw DynamicLinkError.emptyResponse }
            return value
        } catch let error as DynamicLinkError {
            throw error
        } catch {
            log("linkDetails decode failed: \(error.localizedDescription). Body: \(bodyText)")
            throw DynamicLinkError.decodingFailed("\(error.localizedDescription). Body: \(bodyText)")
        }
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("DynamicLinkSDK:", message)
        #endif
    }
}
