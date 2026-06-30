import SwiftUI

struct AllUsersView: View {
    var body: some View {
        List(DemoUsers.all) { user in
            NavigationLink(value: AppRoute.userDetail(userId: user.id)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                    Text("\(user.role) · \(user.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("All Users")
    }
}
