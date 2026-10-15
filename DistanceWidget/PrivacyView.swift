import DistanceCore
import SwiftUI

struct PrivacyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmUnpair = false
    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    sharingSection
                    nameSection
                    unitsSection
                    explained
                    statusSection
                    dangerSection
                }
                .padding(24)
            }
            .background(Palette.paper)
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        model.setName(name)
                        dismiss()
                    }
                }
            }
        }
        .onAppear { name = model.settings.displayName }
        .confirmationDialog("Stop sharing with them?", isPresented: $confirmUnpair, titleVisibility: .visible) {
            Button("Unpair", role: .destructive) { model.unpair() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This phone forgets the pair. If you use a sync server, their copy of your last update stays there until you delete it.")
        }
        .confirmationDialog("Erase Distance on this phone?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase", role: .destructive) {
                model.erase()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your name, the pair, and the saved location from this phone. It does not delete a copy already stored on a sync server.")
        }
    }

    private var sharingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(
                get: { model.settings.shareEnabled },
                set: { model.setShareEnabled($0) }
            )) {
                Text("Share approximate location")
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.coral)

            Toggle(isOn: Binding(
                get: { model.settings.paused },
                set: { model.setPaused($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause")
                        .foregroundStyle(Palette.ink)
                    Text("Stops sending updates. Your widget can still show the last distance.")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                }
            }
            .tint(Palette.coral)
            .disabled(!model.settings.shareEnabled)
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name they see")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
                .padding(16)
                .background(Palette.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                }
                .onSubmit { model.setName(name) }
        }
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Units")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Picker("Units", selection: Binding(
                get: { model.settings.unit },
                set: { model.setUnit($0) }
            )) {
                Text("Kilometers").tag(DistanceUnit.kilometers)
                Text("Miles").tag(DistanceUnit.miles)
            }
            .pickerStyle(.segmented)
        }
    }

    private var explained: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What leaves this phone")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            labeled("A location rounded to about a kilometer")
            labeled("Your city and time zone")
            labeled("Your name, and whether sharing is paused")
            Text("Not your street, not a map pin, and not the weather.")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                .padding(.top, 4)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.authorizationLabel)
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            if model.authorization == .denied || model.authorization == .restricted {
                Button("Open Settings") { model.openSystemSettings() }
                    .font(.footnote.weight(.semibold))
            }
            Text("Sync: \(model.syncLabel)")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
            Text(model.widgetSharingAvailable
                 ? "The widget can read the shared App Group."
                 : "The widget can't see this phone's data yet. Check that both targets use the same App Group.")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.pairing != nil {
                Button("Unpair") { confirmUnpair = true }
                    .buttonStyle(InkButtonStyle(prominent: false))
            }
            Button("Erase on this phone") { confirmErase = true }
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.coral)
        }
    }

    private func labeled(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Palette.coral)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
        }
    }
}
