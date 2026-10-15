import CoreLocation
import DistanceCore
import Foundation
import Observation
import UIKit
import WidgetKit

enum PairingTab: String {
    case create
    case join
}

struct SamplePartner: Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var city: String
    var timeZoneIdentifier: String
    var latitude: Double
    var longitude: Double

    static let all: [SamplePartner] = [
        SamplePartner(id: "lisbon", name: "Alex", city: "Lisbon", timeZoneIdentifier: "Europe/Lisbon", latitude: 38.72, longitude: -9.14),
        SamplePartner(id: "tokyo", name: "Jordan", city: "Tokyo", timeZoneIdentifier: "Asia/Tokyo", latitude: 35.68, longitude: 139.65),
        SamplePartner(id: "mexico", name: "Riley", city: "Mexico City", timeZoneIdentifier: "America/Mexico_City", latitude: 19.43, longitude: -99.13),
        SamplePartner(id: "nairobi", name: "Sam", city: "Nairobi", timeZoneIdentifier: "Africa/Nairobi", latitude: -1.29, longitude: 36.82)
    ]
}

@MainActor
@Observable
final class AppModel {
    private(set) var settings: AppSettings
    private(set) var me: PlaceSnapshot?
    private(set) var partner: PlaceSnapshot?
    private(set) var pairing: PairingState?
    private(set) var authorization: CLAuthorizationStatus
    private(set) var banner: String?
    private(set) var joinPulse = 0
    var isPairingPresented = false
    var isPrivacyPresented = false
    var pairingTab: PairingTab = .create
    var pendingJoinCode: String?

    private let store: SharedStore
    private let sync: any PairSyncing
    private let location: LocationService
    private let geocoder = CLGeocoder()

    init() {
        let store = SharedStore()
        self.store = store
        settings = store.settings
        me = store.me
        partner = store.partner
        pairing = store.pairing
        sync = SyncFactory.make(store: store)
        let location = LocationService()
        self.location = location
        authorization = location.authorization
        location.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.authorization = status
                self?.alignLocationUpdates()
            }
        }
        location.onLocation = { [weak self] fix in
            Task { @MainActor in
                await self?.apply(location: fix)
            }
        }
        alignLocationUpdates()
    }

    var reading: DistanceReading {
        DistanceReading.make(
            me: me,
            partner: partner,
            isPaired: pairing?.isPaired ?? false,
            isSample: pairing?.isSample ?? false,
            shareEnabled: settings.shareEnabled || pairing?.isSample == true,
            myPaused: settings.paused,
            unit: settings.unit,
            partnerName: pairing?.partnerName ?? partner?.displayName
        )
    }

    var syncLabel: String {
        SyncSettings.usesFirebase ? "Firebase" : "On this phone only"
    }

    var widgetSharingAvailable: Bool { AppGroup.isShared }

    var authorizationLabel: String {
        switch authorization {
        case .authorizedAlways:
            return "Updates in the background. iOS keeps the location arrow visible."
        case .authorizedWhenInUse:
            return "Updates while Distance is open."
        case .denied, .restricted:
            return "Location is off for Distance in Settings."
        case .notDetermined:
            return "Distance hasn't asked yet."
        @unknown default:
            return "Location access is unknown."
        }
    }

    func finishOnboarding(name: String, share: Bool) {
        settings.displayName = cleanedName(name)
        settings.didFinishOnboarding = true
        settings.shareEnabled = share
        settings.paused = false
        store.settings = settings
        if share {
            location.requestPermission()
        }
        alignLocationUpdates()
        if pendingJoinCode != nil {
            pairingTab = .join
            isPairingPresented = true
        }
    }

    func setShareEnabled(_ enabled: Bool) {
        settings.shareEnabled = enabled
        if !enabled {
            settings.paused = false
        }
        store.settings = settings
        if enabled, authorization == .notDetermined {
            location.requestPermission()
        }
        alignLocationUpdates()
        Task { await publishMySnapshot() }
        reloadWidget()
    }

    func setPaused(_ paused: Bool) {
        settings.paused = paused
        store.settings = settings
        alignLocationUpdates()
        Task { await publishMySnapshot() }
        reloadWidget()
    }

    func setUnit(_ unit: DistanceUnit) {
        settings.unit = unit
        store.settings = settings
        reloadWidget()
    }

    func setName(_ name: String) {
        let cleaned = cleanedName(name)
        guard cleaned != settings.displayName else { return }
        settings.displayName = cleaned
        store.settings = settings
        if var snapshot = me {
            snapshot.displayName = cleaned
            me = snapshot
            store.me = snapshot
        }
        Task { await publishMySnapshot() }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func dismissBanner() {
        banner = nil
    }

    func handle(url: URL) {
        guard url.scheme == "distancewidget", url.host == "join" else { return }
        let raw = url.path.replacingOccurrences(of: "/", with: "")
        guard let code = InviteCode.normalize(raw) else { return }
        pendingJoinCode = code
        pairingTab = .join
        if settings.didFinishOnboarding {
            isPairingPresented = true
        }
    }

    func presentPairing(_ tab: PairingTab) {
        pairingTab = tab
        isPairingPresented = true
    }

    @discardableResult
    func createInvite() async -> Bool {
        for _ in 0..<5 {
            let code = InviteCode.generate()
            let hostName = settings.displayName.isEmpty ? "Friend" : settings.displayName
            let invite = InviteRecord(
                code: code,
                pairId: UUID().uuidString,
                hostId: settings.personId,
                hostName: hostName,
                createdAt: Date()
            )
            do {
                if let existing = try await sync.loadInvite(code: code), existing.hostId != settings.personId {
                    continue
                }
                try await sync.saveInvite(invite)
                pairing = PairingState(
                    code: code,
                    pairId: invite.pairId,
                    myId: settings.personId,
                    myName: hostName,
                    partnerId: nil,
                    partnerName: nil,
                    isSample: false,
                    createdAt: invite.createdAt
                )
                partner = nil
                store.pairing = pairing
                store.partner = nil
                banner = nil
                reloadWidget()
                return true
            } catch {
                banner = message(for: error)
                return false
            }
        }
        banner = "Couldn't find a free invite code. Try again."
        return false
    }

    @discardableResult
    func join(rawCode: String) async -> Bool {
        guard let code = InviteCode.normalize(rawCode) else {
            banner = "Enter the six character code."
            return false
        }
        do {
            guard var invite = try await sync.loadInvite(code: code) else {
                throw SyncFailure.inviteNotFound
            }
            if invite.hostId == settings.personId {
                banner = "That's your own code. Send it to the other person."
                return false
            }
            if let guestId = invite.guestId, guestId != settings.personId {
                throw SyncFailure.inviteTaken
            }
            let guestName = settings.displayName.isEmpty ? "Friend" : settings.displayName
            invite.guestId = settings.personId
            invite.guestName = guestName
            try await sync.saveInvite(invite)
            pairing = PairingState(
                code: code,
                pairId: invite.pairId,
                myId: settings.personId,
                myName: guestName,
                partnerId: invite.hostId,
                partnerName: invite.hostName,
                isSample: false,
                createdAt: invite.createdAt
            )
            store.pairing = pairing
            pendingJoinCode = nil
            banner = nil
            joinPulse += 1
            await refreshPartner()
            await publishMySnapshot()
            reloadWidget()
            return true
        } catch {
            banner = message(for: error)
            return false
        }
    }

    func refreshInvite() async {
        guard let current = pairing, current.partnerId == nil, !current.isSample else { return }
        guard let invite = try? await sync.loadInvite(code: current.code) else { return }
        guard let guestId = invite.guestId, guestId != settings.personId else { return }
        var updated = current
        updated.partnerId = guestId
        updated.partnerName = invite.guestName
        pairing = updated
        store.pairing = updated
        joinPulse += 1
        await refreshPartner()
        await publishMySnapshot()
        reloadWidget()
    }

    func refreshPartner() async {
        guard let current = pairing, let partnerId = current.partnerId, !current.isSample else { return }
        do {
            guard let snapshot = try await sync.loadSnapshot(pairId: current.pairId, personId: partnerId) else {
                return
            }
            partner = snapshot
            store.partner = snapshot
            if current.partnerName == nil || current.partnerName != snapshot.displayName {
                var updated = current
                updated.partnerName = snapshot.displayName
                pairing = updated
                store.pairing = updated
            }
            banner = nil
            reloadWidget()
        } catch {
            banner = message(for: error)
        }
    }

    func useSample(_ sample: SamplePartner) {
        let now = Date()
        pairing = PairingState(
            code: "SAMPLE",
            pairId: "sample-\(sample.id)",
            myId: settings.personId,
            myName: settings.displayName,
            partnerId: "sample-\(sample.id)",
            partnerName: sample.name,
            isSample: true,
            createdAt: now
        )
        partner = PlaceSnapshot(
            personId: "sample-\(sample.id)",
            displayName: sample.name,
            city: sample.city,
            timeZoneIdentifier: sample.timeZoneIdentifier,
            coordinate: GeoPoint(latitude: sample.latitude, longitude: sample.longitude),
            sharingPaused: false,
            updatedAt: now
        )
        store.pairing = pairing
        store.partner = partner
        banner = nil
        reloadWidget()
    }

    func unpair() {
        pairing = nil
        partner = nil
        store.pairing = nil
        store.partner = nil
        banner = nil
        reloadWidget()
    }

    func erase() {
        location.stop()
        store.clear()
        settings = store.settings
        me = nil
        partner = nil
        pairing = nil
        banner = nil
        pendingJoinCode = nil
        reloadWidget()
    }

    private func apply(location fix: CLLocation) async {
        guard settings.shareEnabled, !settings.paused else { return }
        let rounded = GeoPoint(
            latitude: fix.coordinate.latitude,
            longitude: fix.coordinate.longitude
        ).rounded()
        if me?.coordinate == rounded,
           me?.city != nil,
           let updated = me?.updatedAt,
           Date().timeIntervalSince(updated) < 10 * 60 {
            return
        }
        let place = await reverseGeocode(fix)
        var snapshot = me ?? PlaceSnapshot(
            personId: settings.personId,
            displayName: settings.displayName,
            city: nil,
            timeZoneIdentifier: nil,
            coordinate: nil,
            sharingPaused: false,
            updatedAt: Date()
        )
        snapshot.personId = settings.personId
        snapshot.displayName = settings.displayName
        snapshot.coordinate = rounded
        snapshot.sharingPaused = false
        if let city = place.city {
            snapshot.city = city
        }
        if let zone = place.timeZoneIdentifier {
            snapshot.timeZoneIdentifier = zone
        }
        snapshot.updatedAt = Date()
        me = snapshot
        store.me = snapshot
        await publishMySnapshot()
        reloadWidget()
    }

    private func publishMySnapshot() async {
        guard let current = pairing, current.isPaired, !current.isSample else { return }
        guard let outgoing = outgoingSnapshot() else { return }
        do {
            try await sync.saveSnapshot(outgoing, pairId: current.pairId)
        } catch {
            banner = message(for: error)
        }
    }

    private func outgoingSnapshot() -> PlaceSnapshot? {
        let hidden = settings.paused || !settings.shareEnabled
        var snapshot = me ?? PlaceSnapshot(
            personId: settings.personId,
            displayName: settings.displayName,
            city: nil,
            timeZoneIdentifier: nil,
            coordinate: nil,
            sharingPaused: hidden,
            updatedAt: Date()
        )
        snapshot.personId = settings.personId
        snapshot.displayName = settings.displayName.isEmpty ? "Friend" : settings.displayName
        snapshot.sharingPaused = hidden
        snapshot.updatedAt = Date()
        if hidden {
            snapshot.coordinate = nil
            snapshot.city = nil
            snapshot.timeZoneIdentifier = nil
        }
        return snapshot
    }

    private func reverseGeocode(_ location: CLLocation) async -> (city: String?, timeZoneIdentifier: String?) {
        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }
        do {
            let marks = try await geocoder.reverseGeocodeLocation(location)
            let place = marks.first
            let city = place?.locality ?? place?.subAdministrativeArea ?? place?.administrativeArea
            return (city, place?.timeZone?.identifier)
        } catch {
            return (nil, nil)
        }
    }

    private func alignLocationUpdates() {
        let allowed: Bool = {
            switch authorization {
            case .authorizedAlways, .authorizedWhenInUse:
                return true
            default:
                return false
            }
        }()
        if settings.shareEnabled, !settings.paused, allowed {
            location.start()
        } else {
            location.stop()
        }
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func cleanedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Me" }
        return String(trimmed.prefix(24))
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong while syncing."
    }
}
