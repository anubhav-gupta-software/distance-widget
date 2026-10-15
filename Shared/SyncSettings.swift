import Foundation
import DistanceCore

enum SyncBackend: String {
    case local
    case firebase
}

/// Flip `backend` and fill in the database URL when you want two phones to sync.
/// Local mode needs no account and no keys. It can still preview a sample partner.
enum SyncSettings {
    static let backend: SyncBackend = .local

    /// Example: https://your-project-default-rtdb.firebaseio.com
    static let firebaseDatabaseURL = ""

    /// Optional. A database secret or auth token. Leave this empty when the
    /// rules in firebase/database.rules.json are in place for a private test.
    static let firebaseAuthToken = ""

    static let firebaseRootPath = "distanceWidget/v1"

    static var usesFirebase: Bool {
        guard backend == .firebase else { return false }
        return FirebaseEndpoint.url(base: firebaseDatabaseURL, path: firebaseRootPath) != nil
    }
}
