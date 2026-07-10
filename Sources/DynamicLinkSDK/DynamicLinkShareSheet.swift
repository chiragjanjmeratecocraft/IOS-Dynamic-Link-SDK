#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// Presents the system share sheet (`UIActivityViewController`) with a generated dynamic link or other items.
public struct DynamicLinkShareSheet: UIViewControllerRepresentable {
    public let items: [Any]
    public var excludedActivityTypes: [UIActivity.ActivityType]?

    public init(items: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
