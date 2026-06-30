import SwiftUI

struct UserPortfolioView: View {
    let userId: String

    private var user: DemoUser { DemoUsers.find(id: userId) }

    var body: some View {
        List {
            Section("Owner") {
                LabeledContent("Name", value: user.name)
                LabeledContent("User ID", value: user.id)
            }
            Section("Portfolio items") {
                Label("Mobile app redesign", systemImage: "iphone")
                Label("Brand guidelines", systemImage: "paintpalette")
                Label("Analytics dashboard", systemImage: "chart.bar")
            }
        }
        .navigationTitle("Portfolio")
    }
}
