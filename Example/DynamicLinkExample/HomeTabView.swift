import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var store: AppNavigationStore
    @Environment(\.smartLinkingCoordinator) private var coordinator

    var body: some View {
        List {
            Section("Deep link status") {
                row("Last URL", store.lastURL)
                row("Routed to", store.lastRoutedScreen)
                row("Payload", store.lastPayload)
                row("Resolved destination", store.lastResolvedDestination)
                if let error = store.lastError {
                    row("Error", error).foregroundStyle(.red)
                }
            }

            Section("Share from app") {
                Text("Open any user → tap Share to call POST /public-link and open the iOS share sheet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Simulate navigation (no API)") {
                Button("screen: all_users") {
                    store.navigate(to: .allUsers)
                }
                Button("screen: user_detail, user_id: u-101") {
                    store.navigate(to: .userDetail(userId: "u-101"))
                }
                Button("screen: user_portfolio, user_id: u-102") {
                    store.navigate(to: .userPortfolio(userId: "u-102"))
                }
            }

            Section("Test with real short_code") {
                Text("Create links in Dynamic Link Tool with JSON like:")
                    .font(.caption)
                Text("""
                { "screen": "all_users" }
                { "screen": "user_detail", "user_id": "u-101" }
                { "screen": "user_portfolio", "user_id": "u-102" }
                """)
                .font(.caption.monospaced())

                Button("Open ?short_code=YOUR_CODE") {
                    Task {
                        await coordinator?.handleIncomingURLString(
                            "deeplinkexample://open?short_code=YOUR_CODE"
                        )
                    }
                }
                Button("Reset first-install flag") {
                    store.resetFirstInstallFlag()
                }
            }

            Section("Simulator") {
                Text("""
                xcrun simctl openurl booted "deeplinkexample://open?short_code=YOUR_CODE"
                xcrun simctl openurl booted "songLatest://open?short_code=YOUR_CODE"
                """)
                .font(.caption.monospaced())
            }
        }
        .navigationTitle("Deep Link Demo")
    }

    private func row(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}
