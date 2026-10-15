import Foundation

enum AppIdentity {
    /// Read from Info.plist so the widget and the app stay on the same group
    /// after you change Config/Shared.xcconfig.
    static var groupID: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.contains("$(") {
                return trimmed
            }
        }
        return "group.com.yourname.distancewidget"
    }
}

enum AppGroup {
    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppIdentity.groupID
        )
    }

    static var isShared: Bool { containerURL != nil }

    static var defaults: UserDefaults {
        if isShared, let suite = UserDefaults(suiteName: AppIdentity.groupID) {
            return suite
        }
        return .standard
    }
}
