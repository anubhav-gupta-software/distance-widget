import DistanceCore
import SwiftUI
import WidgetKit

struct DistanceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DistanceEntry

    var body: some View {
        content
            .widgetURL(URL(string: "distancewidget://open"))
            .containerBackground(for: .widget) {
                switch family {
                case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                    Color.clear
                default:
                    Palette.paper
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            MediumDistanceView(reading: entry.reading)
        case .systemLarge:
            LargeDistanceView(reading: entry.reading)
        case .accessoryCircular:
            CircularDistanceView(reading: entry.reading)
        case .accessoryRectangular:
            RectangularDistanceView(reading: entry.reading)
        case .accessoryInline:
            InlineDistanceView(reading: entry.reading)
        default:
            SmallDistanceView(reading: entry.reading)
        }
    }
}

private struct SmallDistanceView: View {
    var reading: DistanceReading

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(primary)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(secondary)
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
            if let clock = reading.clock {
                Text(clock)
                    .font(.caption)
                    .foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityLabel(reading.accessibilityLabel)
    }

    private var primary: String {
        reading.distanceText?.compact ?? "Distance"
    }

    private var secondary: String {
        if let city = reading.city { return city }
        return reading.status
    }
}

private struct MediumDistanceView: View {
    var reading: DistanceReading

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reading.distanceText?.value ?? "—")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(reading.distanceText.map { unitName($0.unit) } ?? "kilometers")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(reading.partnerName ?? "Distance")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if let city = reading.city {
                    Text(city)
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                if let clock = reading.clock {
                    Text(clock)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                }
                Text(reading.status)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityLabel(reading.accessibilityLabel)
    }
}

private struct LargeDistanceView: View {
    var reading: DistanceReading

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DistanceMark(height: 56)
            Text(reading.partnerName ?? "Distance")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            if let city = reading.city {
                Text(city)
                    .font(.title3)
                    .foregroundStyle(Palette.muted)
            }
            Text(reading.distanceText?.compact ?? "—")
                .font(.system(size: 48, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if let clock = reading.clock {
                Text([clock, reading.dayPart].compactMap { $0 }.joined(separator: " · "))
                    .font(.body)
                    .foregroundStyle(Palette.ink)
            }
            Text(reading.status)
                .font(.body)
                .foregroundStyle(Palette.muted)
            if let updated = reading.updatedAt {
                Text("Updated \(RelativeUpdate.phrase(from: updated, now: Date()))")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityLabel(reading.accessibilityLabel)
    }
}

private struct CircularDistanceView: View {
    var reading: DistanceReading

    var body: some View {
        VStack(spacing: 0) {
            Text(reading.distanceText?.widgetCompact ?? "—")
                .font(.system(size: 14, weight: .semibold))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(reading.accessibilityLabel)
    }
}

private struct RectangularDistanceView: View {
    var reading: DistanceReading

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(reading.distanceText?.compact ?? reading.status)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityLabel(reading.accessibilityLabel)
    }

    private var detail: String {
        let parts = [reading.city, reading.clock].compactMap { $0 }
        if parts.isEmpty { return reading.status }
        return parts.joined(separator: " · ")
    }
}

private struct InlineDistanceView: View {
    var reading: DistanceReading

    var body: some View {
        Text(line)
            .widgetAccentable()
            .accessibilityLabel(reading.accessibilityLabel)
    }

    private var line: String {
        var parts: [String] = []
        if let compact = reading.distanceText?.compact {
            parts.append(compact)
        }
        if let city = reading.city {
            parts.append(city)
        }
        if let clock = reading.clock {
            parts.append(clock)
        }
        if parts.isEmpty {
            return reading.status
        }
        return parts.joined(separator: " · ")
    }
}

private func unitName(_ unit: String) -> String {
    switch unit {
    case "km": return "kilometers"
    case "m": return "meters"
    case "mi": return "miles"
    case "ft": return "feet"
    default: return unit
    }
}
