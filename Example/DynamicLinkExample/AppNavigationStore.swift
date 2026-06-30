import DynamicLinkSDK
import Foundation
import SwiftUI

@MainActor
final class AppNavigationStore: ObservableObject {
    @Published var path = NavigationPath()
    @Published var lastURL: String?
    @Published var lastPayload: String?
    @Published var lastResolvedDestination: String?
    @Published var lastError: String?
    @Published var lastRoutedScreen: String?

    func handleDeepLink(_ data: DynamicLinkResponse) {
        lastPayload = DeepLinkRouter.formatPayload(data)
        lastError = nil

        guard let route = DeepLinkRouter.route(from: data) else {
            lastRoutedScreen = "No matching screen in JSON payload"
            return
        }

        path.append(route)
        lastRoutedScreen = route.debugLabel
    }

    func navigate(to route: AppRoute) {
        path.append(route)
        lastRoutedScreen = route.debugLabel
        lastError = nil
    }

    func resetFirstInstallFlag() {
        UserDefaultsFirstInstallStore.resetFirstInstallFlag()
        lastError = nil
        lastPayload = "First-install flag cleared. Reinstall to test deferred deep links."
    }
}

private extension AppRoute {
    var debugLabel: String {
        switch self {
        case .allUsers:
            return "all_users"
        case .userDetail(let userId):
            return "user_detail (\(userId))"
        case .userPortfolio(let userId):
            return "user_portfolio (\(userId))"
        }
    }
}
