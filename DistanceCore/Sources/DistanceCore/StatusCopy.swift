import Foundation

public enum StatusCopy {
    public static func line(
        isPaired: Bool,
        shareEnabled: Bool,
        myPaused: Bool,
        partnerPaused: Bool,
        hasMyCoordinate: Bool,
        hasPartnerCoordinate: Bool,
        distanceMeters: Double?,
        partnerUpdatedAt: Date?,
        now: Date
    ) -> String {
        if !isPaired {
            return "Pair with someone to begin"
        }
        if !shareEnabled {
            return "Location sharing is off"
        }
        if myPaused {
            return "You paused sharing"
        }
        if partnerPaused {
            return "They paused sharing"
        }
        if !hasPartnerCoordinate {
            return "Waiting for their location"
        }
        if !hasMyCoordinate {
            return "Share your location to measure the distance"
        }
        if let partnerUpdatedAt {
            let age = now.timeIntervalSince(partnerUpdatedAt)
            if age > 48 * 3_600 {
                return "Their location is out of date"
            }
            if age > 8 * 3_600 {
                return "Hasn't updated in a while"
            }
        }
        guard let distanceMeters else {
            return "Waiting for their location"
        }
        switch distanceMeters {
        case ..<300:
            return "You are in the same place"
        case ..<2_000:
            return "A short walk apart"
        case ..<15_000:
            return "Across town"
        case ..<80_000:
            return "A drive apart"
        case ..<500_000:
            return "A longer trip apart"
        case ..<2_500_000:
            return "A flight apart"
        default:
            return "Far apart"
        }
    }
}

public enum LocalTimeText {
    public static func clock(
        timeZoneIdentifier: String?,
        now: Date = Date(),
        locale: Locale = .current
    ) -> String? {
        guard let timeZone = timeZone(timeZoneIdentifier) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: now)
    }

    /// "Their evening", based on the hour where they are.
    public static func theirDayPart(timeZoneIdentifier: String?, now: Date = Date()) -> String? {
        guard let timeZone = timeZone(timeZoneIdentifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        switch calendar.component(.hour, from: now) {
        case 5..<12:
            return "Their morning"
        case 12..<17:
            return "Their afternoon"
        case 17..<22:
            return "Their evening"
        default:
            return "Their night"
        }
    }

    private static func timeZone(_ identifier: String?) -> TimeZone? {
        guard let identifier, !identifier.isEmpty else { return nil }
        return TimeZone(identifier: identifier)
    }
}
