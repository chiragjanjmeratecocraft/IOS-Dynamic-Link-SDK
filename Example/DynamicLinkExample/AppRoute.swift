import Foundation

/// Demo navigation targets — match `screen` values in Dynamic Link Tool JSON.
enum AppRoute: Hashable {
    case allUsers
    case userDetail(userId: String)
    case userPortfolio(userId: String)
}
