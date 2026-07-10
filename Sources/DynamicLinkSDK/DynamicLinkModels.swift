import Foundation

/// JSON value for custom link payloads (supports nested objects like Flutter `customData`).
public enum DynamicLinkJSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: DynamicLinkJSONValue])
    case array([DynamicLinkJSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: DynamicLinkJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([DynamicLinkJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    /// Scalar string for routing (`screen`, `user_id`, etc.). Nested objects return `nil`.
    public var scalarString: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null, .object, .array:
            return nil
        }
    }

    func foundationObject() -> Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues { $0.foundationObject() }
        case .array(let value):
            return value.map { $0.foundationObject() }
        case .null:
            return NSNull()
        }
    }
}

/// Mirrors the `data` object returned by the Tecocraft dynamic link API (see RN `IDynamicLinkResponse`).
public struct DynamicLinkResponse: Decodable, Sendable, Equatable {
    public let name: String
    public let description: String
    public let shortCode: String
    public let customDomain: String?
    /// Flat string map (RN `params`); derived from ``customData`` when the API omits `params`.
    public let params: [String: String]?
    /// JSON from the Dynamic Link Tool. API field is usually `data` (Flutter `customData`), not `params`.
    public let customData: [String: DynamicLinkJSONValue]?
    public let projectId: String
    public let androidScheme: String
    public let iosScheme: String
    public let desktopLink: String?
    public let project: DynamicLinkProject

    enum CodingKeys: String, CodingKey {
        case name, description, params, data, project
        case shortCode = "short_code"
        case customDomain = "custom_domain"
        case projectId = "projectId"
        case androidScheme = "android_scheme"
        case iosScheme = "ios_scheme"
        case desktopLink = "desktop_link"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        shortCode = try container.decode(String.self, forKey: .shortCode)
        customDomain = try container.decodeIfPresent(String.self, forKey: .customDomain)
        projectId = try container.decode(String.self, forKey: .projectId)
        androidScheme = try container.decode(String.self, forKey: .androidScheme)
        iosScheme = try container.decode(String.self, forKey: .iosScheme)
        desktopLink = try container.decodeIfPresent(String.self, forKey: .desktopLink)
        project = try container.decode(DynamicLinkProject.self, forKey: .project)

        let fromParams = try container.decodeIfPresent([String: DynamicLinkJSONValue].self, forKey: .params)
        let fromData = try container.decodeIfPresent([String: DynamicLinkJSONValue].self, forKey: .data)
        customData = fromParams ?? fromData
        params = customData?.compactMapValues(\.scalarString)
    }

    /// Pretty-printed JSON for logging / debug UI (full nested payload).
    public var payloadJSON: String? {
        guard let customData, !customData.isEmpty else { return nil }
        let root = customData.mapValues { $0.foundationObject() }
        guard JSONSerialization.isValidJSONObject(root),
            let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }
}

public struct DynamicLinkProject: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let onPlaystore: Bool
    public let onAppstore: Bool
    public let androidPackageName: String
    public let iosBundleId: String?
    public let defaultUrl: String
    public let androidFallbackUrl: String
    public let iosFallbackUrl: String
    public let androidHost: String?
    public let iosHost: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case onPlaystore = "on_playstore"
        case onAppstore = "on_appstore"
        case androidPackageName = "android_package_name"
        case iosBundleId = "ios_bundle_id"
        case defaultUrl = "default_url"
        case androidFallbackUrl = "android_fallback_url"
        case iosFallbackUrl = "ios_fallback_url"
        case androidHost = "android_host"
        case iosHost = "ios_host"
    }
}

struct DynamicLinkAPIEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T?
}

/// Minimal `data` object from `POST /pending-redirect` (usually only `short_code`).
struct PendingRedirectData: Decodable, Sendable {
    let shortCode: String?

    enum CodingKeys: String, CodingKey {
        case shortCode = "short_code"
    }
}

/// Request body for `POST /api/links/public-link` (create a shareable link from the app).
/// The project is identified by the `clientId` HTTP header on ``DynamicLinkConfiguration``.
public struct PublicLinkCreateRequest: Encodable, Sendable {
    public let title: String
    public let description: String
    public let androidScheme: String
    public let iosScheme: String
    public let data: [String: DynamicLinkJSONValue]

    public init(
        title: String,
        description: String,
        iosScheme: String,
        androidScheme: String? = nil,
        data: [String: DynamicLinkJSONValue]
    ) {
        self.title = title
        self.description = description
        self.iosScheme = iosScheme
        self.androidScheme = androidScheme ?? iosScheme
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case title, description, data
        case androidScheme = "android_scheme"
        case iosScheme = "ios_scheme"
    }
}

/// Result of creating a public share link (`POST /api/links/public-link`).
public struct PublicLinkCreateResult: Sendable, Equatable {
    public let shortCode: String
    /// HTTPS link to share, e.g. `https://backend-dynamiclink.tecocraft.us/{shortCode}`.
    public let shareURL: URL
}

struct PublicLinkCreateData: Decodable, Sendable {
    let shortCode: String

    enum CodingKeys: String, CodingKey {
        case shortCode = "short_code"
    }
}

public enum DynamicLinkError: Error, Sendable, Equatable {
    case invalidURL
    case httpStatus(Int)
    case emptyResponse
    case decodingFailed(String)
    /// `clientId` is required on ``DynamicLinkConfiguration`` for ``DynamicLinkClient/createPublicLink(_:)``.
    case missingClientId
    /// `POST /pending-redirect` succeeded but returned no `data` (no deferred link for this install).
    case noPendingRedirect
    /// Short link HTML (`/s/…`) did not contain a recognizable redirect target.
    case shortLinkRedirectNotFound
}

extension DynamicLinkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for the dynamic link request."
        case .httpStatus(let code):
            if code == 404 {
                return "No link was found for this short code (HTTP 404). Use a short_code that exists in your Tecocraft project."
            }
            return "Dynamic link API error (HTTP \(code))."
        case .emptyResponse:
            return "The API returned no link payload (empty data)."
        case .missingClientId:
            return "clientId is required. Set DynamicLinkConfiguration(clientId:) with the value from your Dynamic Link Tool project."
        case .decodingFailed(let message):
            return "Could not decode the API response: \(message)"
        case .noPendingRedirect:
            return "No deferred deep link was found for this install (pending-redirect returned empty data)."
        case .shortLinkRedirectNotFound:
            return "This short link page did not contain a redirect URL we could read (expected meta refresh, window.location, or canonical link)."
        }
    }
}
