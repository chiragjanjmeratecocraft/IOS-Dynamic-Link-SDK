import DynamicLinkSDK
import SwiftUI

struct UserDetailView: View {
    let userId: String

    @State private var isGeneratingShareLink = false
    @State private var shareSheetURL: URL?
    @State private var showShareSheet = false
    @State private var shareErrorMessage: String?
    @State private var showShareError = false

    private var user: DemoUser { DemoUsers.find(id: userId) }
    private let linkClient = ExampleSDKConfiguration.client

    var body: some View {
        List {
            Section("Profile") {
                LabeledContent("Name", value: user.name)
                LabeledContent("User ID", value: user.id)
                LabeledContent("Role", value: user.role)
            }
            Section("About") {
                Text(user.bio)
            }
            Section {
                NavigationLink("View portfolio", value: AppRoute.userPortfolio(userId: user.id))
            }
            Section("Share profile") {
                Text("Creates a public dynamic link and opens the iOS share sheet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await shareProfile() }
                } label: {
                    Label("Share profile link", systemImage: "square.and.arrow.up")
                }
                .disabled(isGeneratingShareLink)
            }
        }
        .navigationTitle("User Details")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await shareProfile() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isGeneratingShareLink)
                .accessibilityLabel("Share profile link")
            }
        }
        .overlay {
            if isGeneratingShareLink {
                ProgressView("Generating link…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { shareSheetURL = nil }) {
            if let shareSheetURL {
                DynamicLinkShareSheet(items: [shareSheetURL, shareMessage(for: shareSheetURL)])
            }
        }
        .alert("Could not share", isPresented: $showShareError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareErrorMessage ?? "Unknown error")
        }
    }

    @MainActor
    private func shareProfile() async {
        guard !isGeneratingShareLink else { return }
        isGeneratingShareLink = true
        defer { isGeneratingShareLink = false }

        do {
            let request = PublicLinkCreateRequest(
                title: user.name,
                description: user.bio,
                iosScheme: ExampleSDKConfiguration.iosScheme,
                data: [
                    "screen": .string("user_detail"),
                    "user_id": .string(user.id),
                ]
            )
            let result = try await linkClient.createPublicLink(request)
            shareSheetURL = result.shareURL
            showShareSheet = true
        } catch {
            shareErrorMessage = error.localizedDescription
            showShareError = true
        }
    }

    private func shareMessage(for url: URL) -> String {
        "Check out \(user.name) on Dynamic Link Example: \(url.absoluteString)"
    }
}
