import Foundation

public struct PlaceSnapshot: Codable, Equatable, Sendable {
    public var personId: String
    public var displayName: String
    public var city: String?
    public var timeZoneIdentifier: String?
    public var coordinate: GeoPoint?
    public var sharingPaused: Bool
    public var updatedAt: Date

    public init(
        personId: String,
        displayName: String,
        city: String?,
        timeZoneIdentifier: String?,
        coordinate: GeoPoint?,
        sharingPaused: Bool,
        updatedAt: Date
    ) {
        self.personId = personId
        self.displayName = displayName
        self.city = city
        self.timeZoneIdentifier = timeZoneIdentifier
        self.coordinate = coordinate
        self.sharingPaused = sharingPaused
        self.updatedAt = updatedAt
    }
}

public struct PairingState: Codable, Equatable, Sendable {
    public var code: String
    public var pairId: String
    public var myId: String
    public var myName: String
    public var partnerId: String?
    public var partnerName: String?
    public var isSample: Bool
    public var createdAt: Date

    public init(
        code: String,
        pairId: String,
        myId: String,
        myName: String,
        partnerId: String?,
        partnerName: String?,
        isSample: Bool,
        createdAt: Date
    ) {
        self.code = code
        self.pairId = pairId
        self.myId = myId
        self.myName = myName
        self.partnerId = partnerId
        self.partnerName = partnerName
        self.isSample = isSample
        self.createdAt = createdAt
    }

    public var isPaired: Bool {
        isSample || partnerId != nil
    }
}

public struct InviteRecord: Codable, Equatable, Sendable {
    public var code: String
    public var pairId: String
    public var hostId: String
    public var hostName: String
    public var createdAt: Date
    public var guestId: String?
    public var guestName: String?

    public init(
        code: String,
        pairId: String,
        hostId: String,
        hostName: String,
        createdAt: Date,
        guestId: String? = nil,
        guestName: String? = nil
    ) {
        self.code = code
        self.pairId = pairId
        self.hostId = hostId
        self.hostName = hostName
        self.createdAt = createdAt
        self.guestId = guestId
        self.guestName = guestName
    }
}

public struct DistanceReading: Codable, Equatable, Sendable {
    public var partnerName: String?
    public var city: String?
    public var timeZoneIdentifier: String?
    public var distanceMeters: Double?
    public var status: String
    public var clock: String?
    public var dayPart: String?
    public var isPaired: Bool
    public var isSample: Bool
    public var myPaused: Bool
    public var partnerPaused: Bool
    public var updatedAt: Date?
    public var unit: DistanceUnit

    public init(
        partnerName: String?,
        city: String?,
        timeZoneIdentifier: String?,
        distanceMeters: Double?,
        status: String,
        clock: String?,
        dayPart: String?,
        isPaired: Bool,
        isSample: Bool,
        myPaused: Bool,
        partnerPaused: Bool,
        updatedAt: Date?,
        unit: DistanceUnit
    ) {
        self.partnerName = partnerName
        self.city = city
        self.timeZoneIdentifier = timeZoneIdentifier
        self.distanceMeters = distanceMeters
        self.status = status
        self.clock = clock
        self.dayPart = dayPart
        self.isPaired = isPaired
        self.isSample = isSample
        self.myPaused = myPaused
        self.partnerPaused = partnerPaused
        self.updatedAt = updatedAt
        self.unit = unit
    }

    public static func make(
        me: PlaceSnapshot?,
        partner: PlaceSnapshot?,
        isPaired: Bool,
        isSample: Bool,
        shareEnabled: Bool,
        myPaused: Bool,
        unit: DistanceUnit,
        partnerName: String?,
        now: Date = Date(),
        locale: Locale = .current
    ) -> DistanceReading {
        let partnerPaused = partner?.sharingPaused ?? false
        let showPartnerPlace = isPaired && !partnerPaused && partner?.coordinate != nil
        let meters: Double? = {
            guard let mine = me?.coordinate, let theirs = partner?.coordinate, !partnerPaused else {
                return nil
            }
            return DistanceMath.meters(from: mine, to: theirs)
        }()
        let zone = showPartnerPlace ? partner?.timeZoneIdentifier : nil
        let status = StatusCopy.line(
            isPaired: isPaired,
            shareEnabled: shareEnabled,
            myPaused: myPaused,
            partnerPaused: partnerPaused,
            hasMyCoordinate: me?.coordinate != nil,
            hasPartnerCoordinate: partner?.coordinate != nil && !partnerPaused,
            distanceMeters: meters,
            partnerUpdatedAt: partner?.updatedAt,
            now: now
        )
        return DistanceReading(
            partnerName: partnerName ?? partner?.displayName,
            city: showPartnerPlace ? partner?.city : nil,
            timeZoneIdentifier: zone,
            distanceMeters: meters,
            status: status,
            clock: LocalTimeText.clock(timeZoneIdentifier: zone, now: now, locale: locale),
            dayPart: LocalTimeText.theirDayPart(timeZoneIdentifier: zone, now: now),
            isPaired: isPaired,
            isSample: isSample,
            myPaused: myPaused,
            partnerPaused: partnerPaused,
            updatedAt: partner?.updatedAt,
            unit: unit
        )
    }

    public var distanceText: DistanceText? {
        guard let distanceMeters else { return nil }
        return DistanceFormat.text(meters: distanceMeters, unit: unit)
    }

    public var accessibilityLabel: String {
        var parts: [String] = []
        if let distanceText {
            let unitWord: String
            switch distanceText.unit {
            case "km": unitWord = "kilometers"
            case "m": unitWord = "meters"
            case "mi": unitWord = "miles"
            case "ft": unitWord = "feet"
            default: unitWord = distanceText.unit
            }
            if let partnerName, let city {
                parts.append("\(distanceText.value) \(unitWord) from \(partnerName) in \(city)")
            } else {
                parts.append("\(distanceText.value) \(unitWord) apart")
            }
        } else if let partnerName {
            parts.append(partnerName)
        }
        if let clock {
            parts.append(clock)
        }
        if let dayPart {
            parts.append(dayPart)
        }
        parts.append(status)
        return parts.joined(separator: ". ")
    }

    public static let placeholder = DistanceReading(
        partnerName: "Alex",
        city: "Lisbon",
        timeZoneIdentifier: "Europe/Lisbon",
        distanceMeters: 1_842_000,
        status: "A flight apart",
        clock: "9:41 PM",
        dayPart: "Their evening",
        isPaired: true,
        isSample: false,
        myPaused: false,
        partnerPaused: false,
        updatedAt: nil,
        unit: .kilometers
    )

    public static let empty = DistanceReading(
        partnerName: nil,
        city: nil,
        timeZoneIdentifier: nil,
        distanceMeters: nil,
        status: "Pair with someone to begin",
        clock: nil,
        dayPart: nil,
        isPaired: false,
        isSample: false,
        myPaused: false,
        partnerPaused: false,
        updatedAt: nil,
        unit: .kilometers
    )
}

public enum SyncJSON {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public enum FirebaseEndpoint {
    /// Builds a Realtime Database REST URL. `path` is relative to the database
    /// root and does not need a `.json` suffix.
    public static func url(base: String, path: String, authToken: String = "") -> URL? {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
            return nil
        }
        let extra = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let suffix = extra.hasSuffix(".json") ? extra : extra + ".json"
        let basePath = components.percentEncodedPath
        if basePath.isEmpty || basePath == "/" {
            components.percentEncodedPath = "/" + suffix
        } else {
            let prefix = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
            components.percentEncodedPath = prefix + "/" + suffix
        }
        if !authToken.isEmpty {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "auth", value: authToken))
            components.queryItems = items
        }
        return components.url
    }
}
