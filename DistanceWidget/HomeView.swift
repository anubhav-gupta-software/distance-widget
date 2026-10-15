import DistanceCore
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 84

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let banner = model.banner {
                        bannerView(banner)
                    }
                    if model.pairing?.isPaired == true {
                        pairedContent
                    } else {
                        emptyContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(Palette.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Distance")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Palette.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.presentPairing(.create)
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Pairing")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.isPrivacyPresented = true
                    } label: {
                        Image(systemName: "hand.raised")
                    }
                    .accessibilityLabel("Privacy")
                }
            }
            .sheet(isPresented: $model.isPairingPresented) {
                PairingView()
                    .environment(model)
            }
            .sheet(isPresented: $model.isPrivacyPresented) {
                PrivacyView()
                    .environment(model)
            }
        }
    }

    private var pairedContent: some View {
        let reading = model.reading
        return VStack(alignment: .leading, spacing: 28) {
            DistanceMark()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(reading.partnerName ?? "Partner")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    if reading.isSample {
                        Text("Sample")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.line)
                            .clipShape(Capsule())
                    }
                }
                if let city = reading.city {
                    Text(city)
                        .font(.title3)
                        .foregroundStyle(Palette.muted)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Approximate")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.muted)
                    .textCase(.uppercase)
                    .tracking(1.2)
                if let text = reading.distanceText {
                    Text(text.value)
                        .font(.system(size: numberSize, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    Text(unitName(text.unit))
                        .font(.title3)
                        .foregroundStyle(Palette.muted)
                } else {
                    Text("—")
                        .font(.system(size: numberSize, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .accessibilityLabel("No distance yet")
                }
            }
            .accessibilityElement(children: .combine)

            if reading.clock != nil || reading.dayPart != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let clock = reading.clock {
                        Text(clock)
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(Palette.ink)
                    }
                    if let dayPart = reading.dayPart {
                        Text(dayPart)
                            .font(.body)
                            .foregroundStyle(Palette.muted)
                    }
                }
            }

            Text(reading.status)
                .font(.title3)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            sharingControl

            VStack(alignment: .leading, spacing: 6) {
                if let updated = reading.updatedAt {
                    Text("Updated \(RelativeUpdate.phrase(from: updated))")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                }
                Text("Rounded to about a kilometer. Your street never leaves this phone.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            DistanceMark()
            Text("No one paired yet")
                .font(.system(size: 36, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ink)
            Text("Create a code and send it to one person, or enter the code they sent you. The widget fills in once you're paired.")
                .font(.body)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button("Create an invite") { model.presentPairing(.create) }
                .buttonStyle(InkButtonStyle())
            Button("I have a code") { model.presentPairing(.join) }
                .buttonStyle(InkButtonStyle(prominent: false))

            if !SyncSettings.usesFirebase {
                Text("Sync is still local, so a code won't reach another phone until you add a database URL. You can preview a sample partner in Pairing.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sharingControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.settings.shareEnabled {
                Button("Share approximate location") {
                    model.setShareEnabled(true)
                }
                .buttonStyle(InkButtonStyle())
            } else if model.settings.paused {
                Button("Resume sharing") {
                    model.setPaused(false)
                }
                .buttonStyle(InkButtonStyle())
            } else {
                Button("Pause sharing") {
                    model.setPaused(true)
                }
                .buttonStyle(InkButtonStyle(prominent: false))
            }

            if model.settings.shareEnabled && !isAuthorized {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.authorizationLabel)
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                    if model.authorization == .denied || model.authorization == .restricted {
                        Button("Open Settings") { model.openSystemSettings() }
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
        }
    }

    private var isAuthorized: Bool {
        switch model.authorization {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private func bannerView(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                model.dismissBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
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
}
