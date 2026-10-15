import Foundation

public struct GeoPoint: Codable, Equatable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Two decimal degrees is roughly 1.1 km of latitude. That is the
    /// precision the app is willing to store or send.
    public func rounded(places: Int = 2) -> GeoPoint {
        let factor = pow(10, Double(places))
        return GeoPoint(
            latitude: (latitude * factor).rounded() / factor,
            longitude: (longitude * factor).rounded() / factor
        )
    }
}

public enum DistanceUnit: String, Codable, CaseIterable, Sendable {
    case kilometers
    case miles
}

public struct DistanceText: Equatable, Sendable {
    public var value: String
    public var unit: String
    /// A full phrase, such as "1,842 km".
    public var compact: String
    /// Short enough for a Lock Screen circular widget.
    public var widgetCompact: String

    public init(value: String, unit: String, compact: String, widgetCompact: String) {
        self.value = value
        self.unit = unit
        self.compact = compact
        self.widgetCompact = widgetCompact
    }
}

public enum DistanceMath {
    public static func meters(from start: GeoPoint, to end: GeoPoint) -> Double {
        let earth = 6_371_000.0
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLat = (end.latitude - start.latitude) * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earth * c
    }
}

public enum DistanceFormat {
    public static func text(
        meters: Double,
        unit: DistanceUnit,
        locale: Locale = .current
    ) -> DistanceText {
        let safe = max(0, meters)
        switch unit {
        case .kilometers:
            if safe < 1_000 {
                let rounded = (safe / 10).rounded() * 10
                return make(value: rounded, unit: "m", locale: locale, fractionDigits: 0)
            }
            let kilometers = safe / 1_000
            if kilometers < 10 {
                return make(value: kilometers, unit: "km", locale: locale, fractionDigits: 1)
            }
            return make(value: kilometers.rounded(), unit: "km", locale: locale, fractionDigits: 0)
        case .miles:
            let miles = safe / 1_609.344
            if miles < 0.1 {
                let feet = (safe * 3.28084 / 10).rounded() * 10
                return make(value: feet, unit: "ft", locale: locale, fractionDigits: 0)
            }
            if miles < 10 {
                return make(value: miles, unit: "mi", locale: locale, fractionDigits: 1)
            }
            return make(value: miles.rounded(), unit: "mi", locale: locale, fractionDigits: 0)
        }
    }

    private static func make(
        value: Double,
        unit: String,
        locale: Locale,
        fractionDigits: Int
    ) -> DistanceText {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let rendered = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
        let compact = "\(rendered) \(unit)"
        return DistanceText(
            value: rendered,
            unit: unit,
            compact: compact,
            widgetCompact: circular(value: value, unit: unit, locale: locale)
        )
    }

    private static func circular(value: Double, unit: String, locale: Locale) -> String {
        if value < 1_000 {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let rendered = formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
            return "\(rendered) \(unit)"
        }
        let thousands = value / 1_000
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = thousands < 10 ? 1 : 0
        formatter.maximumFractionDigits = thousands < 10 ? 1 : 0
        let rendered = formatter.string(from: NSNumber(value: thousands)) ?? String(format: "%.1f", thousands)
        return "\(rendered)k \(unit)"
    }
}

public enum RelativeUpdate {
    public static func phrase(from date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 45 {
            return "Just now"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
        }
        let hours = Int(seconds / 3_600)
        if hours < 24 {
            return hours == 1 ? "1 hr ago" : "\(hours) hr ago"
        }
        let days = Int(seconds / 86_400)
        if days == 1 {
            return "Yesterday"
        }
        return "\(days) days ago"
    }
}
