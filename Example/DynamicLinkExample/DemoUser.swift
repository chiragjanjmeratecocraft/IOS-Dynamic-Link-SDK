import Foundation

struct DemoUser: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let bio: String
}

enum DemoUsers {
    static let all: [DemoUser] = [
        DemoUser(id: "u-101", name: "Ava Chen", role: "Designer", bio: "Product design and UX research."),
        DemoUser(id: "u-102", name: "Noah Patel", role: "Engineer", bio: "iOS and backend integrations."),
        DemoUser(id: "u-103", name: "Mia Johnson", role: "PM", bio: "Roadmaps, releases, and analytics."),
        DemoUser(id: "u-104", name: "Liam Brooks", role: "QA", bio: "Test plans and automation."),
    ]

    static func find(id: String) -> DemoUser {
        all.first { $0.id == id }
            ?? DemoUser(id: id, name: "User \(id)", role: "Guest", bio: "Opened from a dynamic link.")
    }
}
