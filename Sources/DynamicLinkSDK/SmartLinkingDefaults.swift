import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Default identity headers aligned with RN `trackPendingRedirect` (`app_id` = bundle id, `device_type` = `IOS`) and `customUserAgent` in `src/utils.ts`.
public enum SmartLinkingDefaults {
    /// `Bundle.main.bundleIdentifier` — same role as RN `getBundleId()`.
    public static var appId: String {
        Bundle.main.bundleIdentifier ?? ""
    }

    /// RN uses `Platform.OS.toUpperCase()` → `"IOS"` on iPhone/iPad.
    public static var deviceType: String {
        #if os(iOS) || os(tvOS) || os(visionOS)
        "IOS"
        #elseif os(macOS)
        "MACOS"
        #else
        "APPLE"
        #endif
    }

    /// RN builds `(AppName/Version) (Manufacturer Model; OS Version)` via `react-native-device-info`.
    public static var userAgent: String? {
        let appName =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
        let version =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0"
        #if os(iOS) || os(tvOS)
        let model = UIDevice.current.model
        let osName = UIDevice.current.userInterfaceIdiom == .tv ? "tvOS" : "iOS"
        let system = "\(osName) \(UIDevice.current.systemVersion)"
        return "(\(appName)/\(version)) (Apple \(model); \(system))"
        #elseif os(macOS)
        let versionPlist = ProcessInfo.processInfo.operatingSystemVersionString
        return "(\(appName)/\(version)) (Apple Mac; \(versionPlist))"
        #else
        return "(\(appName)/\(version))"
        #endif
    }
}
