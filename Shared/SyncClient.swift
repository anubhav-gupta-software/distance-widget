import Foundation
import DistanceCore

enum SyncFailure: LocalizedError {
    case notConfigured
    case inviteNotFound
    case inviteTaken
    case refused(String)
    case network

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add a database URL in SyncSettings.swift before syncing."
        case .inviteNotFound:
            return "That code doesn't match an invite."
        case .inviteTaken:
            return "Someone already used that code."
        case .refused(let message):
            return message
        case .network:
            return "Couldn't reach the sync server."
        }
    }
}

protocol PairSyncing {
    func saveInvite(_ invite: InviteRecord) async throws
    func loadInvite(code: String) async throws -> InviteRecord?
    func saveSnapshot(_ snapshot: PlaceSnapshot, pairId: String) async throws
    func loadSnapshot(pairId: String, personId: String) async throws -> PlaceSnapshot?
}

struct LocalPairSync: PairSyncing {
    var store: SharedStore

    func saveInvite(_ invite: InviteRecord) async throws {
        store.saveInvite(invite)
    }

    func loadInvite(code: String) async throws -> InviteRecord? {
        store.loadInvite(code: code)
    }

    func saveSnapshot(_ snapshot: PlaceSnapshot, pairId: String) async throws {
        store.saveRemoteSnapshot(snapshot, pairId: pairId)
    }

    func loadSnapshot(pairId: String, personId: String) async throws -> PlaceSnapshot? {
        store.loadRemoteSnapshot(pairId: pairId, personId: personId)
    }
}

struct FirebaseSync: PairSyncing {
    var baseURL: String
    var authToken: String
    var root: String

    func saveInvite(_ invite: InviteRecord) async throws {
        try await put(path: "\(root)/invites/\(invite.code)", body: invite)
    }

    func loadInvite(code: String) async throws -> InviteRecord? {
        try await get(path: "\(root)/invites/\(code)")
    }

    func saveSnapshot(_ snapshot: PlaceSnapshot, pairId: String) async throws {
        try await put(path: "\(root)/pairs/\(pairId)/members/\(snapshot.personId)", body: snapshot)
    }

    func loadSnapshot(pairId: String, personId: String) async throws -> PlaceSnapshot? {
        try await get(path: "\(root)/pairs/\(pairId)/members/\(personId)")
    }

    private func put<T: Encodable>(path: String, body: T) async throws {
        let request = try makeRequest(path: path, method: "PUT")
        var mutable = request
        mutable.httpBody = try SyncJSON.encoder().encode(body)
        try await send(mutable)
    }

    private func get<T: Decodable>(path: String) async throws -> T? {
        let request = try makeRequest(path: path, method: "GET")
        let data = try await send(request)
        if data.isEmpty || data == Data("null".utf8) {
            return nil
        }
        do {
            return try SyncJSON.decoder().decode(T.self, from: data)
        } catch {
            throw SyncFailure.refused("The sync server returned something I couldn't read.")
        }
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = FirebaseEndpoint.url(base: baseURL, path: path, authToken: authToken) else {
            throw SyncFailure.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    @discardableResult
    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SyncFailure.network
        }
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw SyncFailure.refused("The database refused the request. Check the URL and the rules.")
            }
            let snippet = String(data: data, encoding: .utf8)?.prefix(160) ?? ""
            if snippet.isEmpty {
                throw SyncFailure.refused("The sync server returned \(http.statusCode).")
            }
            throw SyncFailure.refused(String(snippet))
        }
        return data
    }
}

enum SyncFactory {
    static func make(store: SharedStore) -> any PairSyncing {
        if SyncSettings.usesFirebase {
            return FirebaseSync(
                baseURL: SyncSettings.firebaseDatabaseURL,
                authToken: SyncSettings.firebaseAuthToken,
                root: SyncSettings.firebaseRootPath
            )
        }
        return LocalPairSync(store: store)
    }
}
