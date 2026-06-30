import DynamicLinkSDK
import SwiftUI

@main
struct DynamicLinkExampleApp: App {
    @StateObject private var store = AppNavigationStore()

    var body: some Scene {
        WindowGroup {
            SmartLinkingRoot(
                options: SmartLinkingOptions(
                    onUrl: { url in
                        Task { @MainActor in
                            store.lastURL = url
                        }
                    },
                    onSuccess: { data in
                        print("Resolved:", data.shortCode)
                        if let json = data.payloadJSON {
                            print("JSON payload:\n\(json)")
                        }
                        Task { @MainActor in
                            store.handleDeepLink(data)
                        }
                    },
                    onError: { error in
                        print("Deep link error:", error)
                        if let linkError = error as? DynamicLinkError {
                            print("DynamicLinkError:", linkError.localizedDescription)
                        }
                        Task { @MainActor in
                            store.lastError = error.localizedDescription
                        }
                    },
                    onResolvedDestination: { url in
                        Task { @MainActor in
                            store.lastResolvedDestination = url.absoluteString
                        }
                    }
                )
            ) {
                ContentView()
                    .environmentObject(store)
            }
        }
    }
}
