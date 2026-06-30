import SwiftUI

struct UserDetailView: View {
    let userId: String

    private var user: DemoUser { DemoUsers.find(id: userId) }

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
        }
        .navigationTitle("User Details")
    }
}
