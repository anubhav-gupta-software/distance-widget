import Foundation
import DistanceCore

struct AppSettings: Codable, Equatable {
    var personId: String
    var displayName: String
    var unit: DistanceUnit
    var didFinishOnboarding: Bool
    var shareEnabled: Bool
    var paused: Bool

    static func fresh() -> AppSettings {
        AppSettings(
            personId: UUID().uuidString,
            displayName: "",
            unit: .kilometers,
            didFinishOnboarding: false,
            shareEnabled: false,
            paused: false
        )
    }
}

final class SharedStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.defaults
    }

    var settings: AppSettings {
        get {
            if let stored: AppSettings = decode(Key.settings) {
                return stored
            }
            let fresh = AppSettings.fresh()
            encode(fresh, key: Key.settings)
            return fresh
        }
        set { encode(newValue, key: Key.settings) }
    }

    var me: PlaceSnapshot? {
        get { decode(Key.me) }
        set { write(newValue, key: Key.me) }
    }

    var partner: PlaceSnapshot? {
        get { decode(Key.partner) }
        set { write(newValue, key: Key.partner) }
    }

    var pairing: PairingState? {
        get { decode(Key.pairing) }
        set { write(newValue, key: Key.pairing) }
    }

    func saveInvite(_ invite: InviteRecord) {
        encode(invite, key: Key.invitePrefix + invite.code)
    }

    func loadInvite(code: String) -> InviteRecord? {
        decode(Key.invitePrefix + code)
    }

    func saveRemoteSnapshot(_ snapshot: PlaceSnapshot, pairId: String) {
        encode(snapshot, key: remoteKey(pairId: pairId, personId: snapshot.personId))
    }

    func loadRemoteSnapshot(pairId: String, personId: String) -> PlaceSnapshot? {
        decode(remoteKey(pairId: pairId, personId: personId))
    }

    func reading(now: Date = Date()) -> DistanceReading {
        DistanceReading.make(
            me: me,
            partner: partner,
            isPaired: pairing?.isPaired ?? false,
            isSample: pairing?.isSample ?? false,
            shareEnabled: settings.shareEnabled || pairing?.isSample == true,
            myPaused: settings.paused,
            unit: settings.unit,
            partnerName: pairing?.partnerName ?? partner?.displayName,
            now: now
        )
    }

    func clear() {
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys where key == Key.settings
            || key == Key.me
            || key == Key.partner
            || key == Key.pairing
            || key.hasPrefix(Key.invitePrefix)
            || key.hasPrefix(Key.remotePrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func remoteKey(pairId: String, personId: String) -> String {
        Key.remotePrefix + pairId + "." + personId
    }

    private func write<T: Encodable>(_ value: T?, key: String) {
        if let value {
            encode(value, key: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        guard let data = try? SyncJSON.encoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? SyncJSON.decoder().decode(T.self, from: data)
    }

    private enum Key {
        static let settings = "distance.settings"
        static let me = "distance.me"
        static let partner = "distance.partner"
        static let pairing = "distance.pairing"
        static let invitePrefix = "distance.invite."
        static let remotePrefix = "distance.remote."
    }
}
