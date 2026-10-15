import DistanceCore
import SwiftUI
import UIKit

struct PairingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isWorking = false
    @State private var confirmSample: SamplePartner?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Pairing", selection: $model.pairingTab) {
                        Text("Create").tag(PairingTab.create)
                        Text("Join").tag(PairingTab.join)
                    }
                    .pickerStyle(.segmented)

                    if model.pairingTab == .create {
                        createSection
                    } else {
                        joinSection
                    }

                    sampleSection
                }
                .padding(24)
            }
            .background(Palette.paper)
            .navigationTitle("Pairing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.success, trigger: model.joinPulse)
        .task(id: model.pairing?.code) {
            guard model.pairingTab == .create else { return }
            while !Task.isCancelled {
                await model.refreshInvite()
                try? await Task.sleep(for: .seconds(4))
            }
        }
        .onAppear {
            if let pending = model.pendingJoinCode {
                code = InviteCode.spokenGroups(pending)
                model.pairingTab = .join
            }
        }
        .confirmationDialog(
            "Replace your pair with a sample?",
            isPresented: Binding(
                get: { confirmSample != nil },
                set: { if !$0 { confirmSample = nil } }
            ),
            titleVisibility: .visible,
            presenting: confirmSample
        ) { sample in
            Button("Use sample") { model.useSample(sample) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The sample replaces the person you're paired with on this phone.")
        }
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let pairing = model.pairing, !pairing.isSample {
                Text(InviteCode.spokenGroups(pairing.code))
                    .font(.system(size: 48, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Invite code \(pairing.code)")

                if pairing.partnerId == nil {
                    Text("Waiting for them to enter this code.")
                        .font(.body)
                        .foregroundStyle(Palette.muted)
                } else {
                    Text("\(pairing.partnerName ?? "They") joined.")
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                }

                ShareLink(item: shareText(pairing.code)) {
                    Text("Share code")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InkButtonStyle())

                Button("Copy code") {
                    UIPasteboard.general.string = pairing.code
                }
                .buttonStyle(InkButtonStyle(prominent: false))

                Button("Make a new code") {
                    Task {
                        isWorking = true
                        await model.createInvite()
                        isWorking = false
                    }
                }
                .font(.footnote.weight(.semibold))
                .disabled(isWorking)
            } else {
                Text("One code, one person. Read it out or send it.")
                    .font(.body)
                    .foregroundStyle(Palette.muted)
                Button(isWorking ? "Creating…" : "Create a code") {
                    Task {
                        isWorking = true
                        await model.createInvite()
                        isWorking = false
                    }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(isWorking)
            }

            if !SyncSettings.usesFirebase {
                Text("This phone is in local mode. The code is saved here, and another phone can't see it until you set a Firebase URL in SyncSettings.swift.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter their code")
                .font(.title3)
                .foregroundStyle(Palette.ink)
            TextField("K7M Q2P", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.title2, design: .monospaced))
                .padding(16)
                .background(Palette.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                }
                .onChange(of: code) { _, newValue in
                    let normalized = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    if normalized != newValue {
                        code = normalized
                    }
                }
                .submitLabel(.join)
                .onSubmit { join() }

            Button(isWorking ? "Joining…" : "Join") { join() }
                .buttonStyle(InkButtonStyle())
                .disabled(isWorking)
        }
    }

    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("A sample partner is stored only on this phone, so you can see the widget before anyone joins.")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(SamplePartner.all) { sample in
                Button {
                    if model.pairing?.isPaired == true && model.pairing?.isSample != true {
                        confirmSample = sample
                    } else {
                        model.useSample(sample)
                    }
                } label: {
                    HStack {
                        Text(sample.name)
                        Spacer()
                        Text(sample.city)
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.ink)
            }
        }
        .padding(.top, 8)
    }

    private func join() {
        Task {
            isWorking = true
            let ok = await model.join(rawCode: code)
            isWorking = false
            if ok { dismiss() }
        }
    }

    private func shareText(_ code: String) -> String {
        let spoken = InviteCode.spokenGroups(code)
        return "Join me on Distance. Invite code: \(spoken)\ndistancewidget://join/\(code)"
    }
}
