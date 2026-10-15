import Foundation
import XCTest
@testable import DistanceCore

final class DistanceCoreTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    func testRoundingDropsStreetLevelPrecision() {
        let point = GeoPoint(latitude: 38.72231, longitude: -9.13934)
        let rounded = point.rounded()
        XCTAssertEqual(rounded.latitude, 38.72, accuracy: 0.0001)
        XCTAssertEqual(rounded.longitude, -9.14, accuracy: 0.0001)
    }

    func testLondonToParis() {
        let london = GeoPoint(latitude: 51.5074, longitude: -0.1278)
        let paris = GeoPoint(latitude: 48.8566, longitude: 2.3522)
        let meters = DistanceMath.meters(from: london, to: paris)
        XCTAssertEqual(meters / 1000, 343.5, accuracy: 2)
    }

    func testKilometerFormatting() {
        let nearby = DistanceFormat.text(meters: 350, unit: .kilometers, locale: locale)
        XCTAssertEqual(nearby.compact, "350 m")

        let walk = DistanceFormat.text(meters: 3_400, unit: .kilometers, locale: locale)
        XCTAssertEqual(walk.compact, "3.4 km")

        let drive = DistanceFormat.text(meters: 24_200, unit: .kilometers, locale: locale)
        XCTAssertEqual(drive.compact, "24 km")

        let flight = DistanceFormat.text(meters: 1_842_000, unit: .kilometers, locale: locale)
        XCTAssertEqual(flight.compact, "1,842 km")
        XCTAssertEqual(flight.widgetCompact, "1.8k km")
    }

    func testMileFormatting() {
        let feet = DistanceFormat.text(meters: 30, unit: .miles, locale: locale)
        XCTAssertEqual(feet.unit, "ft")

        let miles = DistanceFormat.text(meters: 16_100, unit: .miles, locale: locale)
        XCTAssertEqual(miles.compact, "10 mi")
    }

    func testInviteCodesAreEasyToReadAloud() {
        var rng = SplitMix64(seed: 42)
        let code = InviteCode.generate(using: &rng)
        XCTAssertEqual(code.count, 6)
        XCTAssertNotNil(InviteCode.normalize(code))
        XCTAssertNil(InviteCode.normalize("ABC01"))
        XCTAssertNil(InviteCode.normalize("ABC01O"))
        XCTAssertEqual(InviteCode.normalize("k7m-q2p"), "K7MQ2P")
        XCTAssertEqual(InviteCode.spokenGroups("K7MQ2P"), "K7M Q2P")
    }

    func testStatusFollowsPauseAndDistance() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(
            StatusCopy.line(
                isPaired: false,
                shareEnabled: true,
                myPaused: false,
                partnerPaused: false,
                hasMyCoordinate: false,
                hasPartnerCoordinate: false,
                distanceMeters: nil,
                partnerUpdatedAt: nil,
                now: now
            ),
            "Pair with someone to begin"
        )
        XCTAssertEqual(
            StatusCopy.line(
                isPaired: true,
                shareEnabled: true,
                myPaused: true,
                partnerPaused: false,
                hasMyCoordinate: true,
                hasPartnerCoordinate: true,
                distanceMeters: 1_000,
                partnerUpdatedAt: now,
                now: now
            ),
            "You paused sharing"
        )
        XCTAssertEqual(
            StatusCopy.line(
                isPaired: true,
                shareEnabled: true,
                myPaused: false,
                partnerPaused: true,
                hasMyCoordinate: true,
                hasPartnerCoordinate: false,
                distanceMeters: nil,
                partnerUpdatedAt: now,
                now: now
            ),
            "They paused sharing"
        )
        XCTAssertEqual(
            StatusCopy.line(
                isPaired: true,
                shareEnabled: true,
                myPaused: false,
                partnerPaused: false,
                hasMyCoordinate: true,
                hasPartnerCoordinate: true,
                distanceMeters: 1_200,
                partnerUpdatedAt: now,
                now: now
            ),
            "A short walk apart"
        )
        XCTAssertEqual(
            StatusCopy.line(
                isPaired: true,
                shareEnabled: true,
                myPaused: false,
                partnerPaused: false,
                hasMyCoordinate: true,
                hasPartnerCoordinate: true,
                distanceMeters: 1_842_000,
                partnerUpdatedAt: now.addingTimeInterval(-10 * 3_600),
                now: now
            ),
            "Hasn't updated in a while"
        )
    }

    func testReadingHidesPlaceWhenPartnerPauses() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let me = PlaceSnapshot(
            personId: "me",
            displayName: "Ava",
            city: "Austin",
            timeZoneIdentifier: "America/Chicago",
            coordinate: GeoPoint(latitude: 30.27, longitude: -97.74),
            sharingPaused: false,
            updatedAt: now
        )
        let partner = PlaceSnapshot(
            personId: "them",
            displayName: "Alex",
            city: "Lisbon",
            timeZoneIdentifier: "Europe/Lisbon",
            coordinate: nil,
            sharingPaused: true,
            updatedAt: now
        )
        let reading = DistanceReading.make(
            me: me,
            partner: partner,
            isPaired: true,
            isSample: false,
            shareEnabled: true,
            myPaused: false,
            unit: .kilometers,
            partnerName: "Alex",
            now: now,
            locale: locale
        )
        XCTAssertNil(reading.distanceMeters)
        XCTAssertNil(reading.city)
        XCTAssertEqual(reading.status, "They paused sharing")
    }

    func testReadingMeasuresALivePair() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let me = PlaceSnapshot(
            personId: "me",
            displayName: "Ava",
            city: "Austin",
            timeZoneIdentifier: "America/Chicago",
            coordinate: GeoPoint(latitude: 30.27, longitude: -97.74),
            sharingPaused: false,
            updatedAt: now
        )
        let partner = PlaceSnapshot(
            personId: "them",
            displayName: "Alex",
            city: "Lisbon",
            timeZoneIdentifier: "Europe/Lisbon",
            coordinate: GeoPoint(latitude: 38.72, longitude: -9.14),
            sharingPaused: false,
            updatedAt: now
        )
        let reading = DistanceReading.make(
            me: me,
            partner: partner,
            isPaired: true,
            isSample: false,
            shareEnabled: true,
            myPaused: false,
            unit: .kilometers,
            partnerName: "Alex",
            now: now,
            locale: locale
        )
        XCTAssertEqual(reading.city, "Lisbon")
        XCTAssertNotNil(reading.clock)
        XCTAssertNotNil(reading.dayPart)
        XCTAssertGreaterThan(reading.distanceMeters ?? 0, 2_500_000)
        XCTAssertEqual(reading.status, "Far apart")
        XCTAssertTrue(reading.accessibilityLabel.contains("Alex"))
    }

    func testRelativeUpdatePhrases() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(RelativeUpdate.phrase(from: now.addingTimeInterval(-10), now: now), "Just now")
        XCTAssertEqual(RelativeUpdate.phrase(from: now.addingTimeInterval(-120), now: now), "2 min ago")
        XCTAssertEqual(RelativeUpdate.phrase(from: now.addingTimeInterval(-3_600), now: now), "1 hr ago")
        XCTAssertEqual(RelativeUpdate.phrase(from: now.addingTimeInterval(-86_400), now: now), "Yesterday")
    }

    func testFirebaseURL() {
        let url = FirebaseEndpoint.url(
            base: "https://demo-default-rtdb.firebaseio.com/",
            path: "distanceWidget/v1/invites/K7MQ2P",
            authToken: "secret"
        )
        XCTAssertEqual(
            url?.absoluteString,
            "https://demo-default-rtdb.firebaseio.com/distanceWidget/v1/invites/K7MQ2P.json?auth=secret"
        )
        XCTAssertNil(FirebaseEndpoint.url(base: "   ", path: "x"))
    }

    func testSnapshotJSONRoundTrip() throws {
        let snapshot = PlaceSnapshot(
            personId: "abc",
            displayName: "Alex",
            city: "Lisbon",
            timeZoneIdentifier: "Europe/Lisbon",
            coordinate: GeoPoint(latitude: 38.72, longitude: -9.14),
            sharingPaused: false,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try SyncJSON.encoder().encode(snapshot)
        let decoded = try SyncJSON.decoder().decode(PlaceSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testDayPartUsesTheirTimeZone() {
        guard TimeZone(identifier: "Asia/Tokyo") != nil else { return }
        // 2023-11-14 22:13 UTC is 07:13 the next morning in Tokyo.
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(LocalTimeText.theirDayPart(timeZoneIdentifier: "Asia/Tokyo", now: now), "Their morning")
    }
}

/// Tiny deterministic generator so invite-code tests don't depend on the clock.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
