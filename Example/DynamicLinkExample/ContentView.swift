import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppNavigationStore

    var body: some View {
        NavigationStack(path: $store.path) {
            TabView {
                HomeTabView()
                    .tabItem {
                        Label("Home", systemImage: "link")
                    }

                AllUsersView()
                    .tabItem {
                        Label("Users", systemImage: "person.3")
                    }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .allUsers:
                    AllUsersView()
                case .userDetail(let userId):
                    UserDetailView(userId: userId)
                case .userPortfolio(let userId):
                    UserPortfolioView(userId: userId)
                }
            }
        }
    }
}
