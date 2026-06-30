import DynamicLinkSDK
import Foundation

/// Same routing idea as Flutter `example/lib/deeplink_example_app.dart` `_routeFromDeepLink`.
enum DeepLinkRouter {
  static func route(from data: DynamicLinkResponse) -> AppRoute? {
    let payload = data.customData ?? [:]
    let screen = payload["screen"]?.scalarString?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()

    if screen == "all_users" || screen == "users" {
      return .allUsers
    }

    if screen == "user_detail" || screen == "user_details" || payload["user_id"] != nil {
      let userId = payload["user_id"]?.scalarString ?? "UNKNOWN"
      return .userDetail(userId: userId)
    }

    if screen == "user_portfolio" || screen == "portfolio" {
      let userId = payload["user_id"]?.scalarString ?? "UNKNOWN"
      return .userPortfolio(userId: userId)
    }

    return nil
  }

  static func formatPayload(_ data: DynamicLinkResponse) -> String {
    if let json = data.payloadJSON {
      return json
    }
    let params = data.params ?? [:]
    if params.isEmpty {
      return """
      Link resolved but no JSON payload found.
      short_code=\(data.shortCode)
      name=\(data.name)
      """
    }
    return params.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
  }
}
//
