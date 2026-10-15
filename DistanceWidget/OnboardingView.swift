import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var step = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DistanceMark()
                .padding(.top, 28)

            Spacer(minLength: 20)

            if step == 0 {
                intro
            } else {
                locationStep
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.paper)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("How far apart")
                .font(.system(size: 40, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ink)

            Text("A home screen and Lock Screen widget for two people. It shows the distance, their city, and their local time.")
                .font(.body)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your name")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                TextField("Alex", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding(16)
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Palette.line, lineWidth: 1)
                    }
                    .focused($nameFocused)
                    .submitLabel(.continue)
                    .onSubmit { step = 1 }
            }

            Button("Continue") { step = 1 }
                .buttonStyle(InkButtonStyle())
        }
        .onAppear { nameFocused = true }
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Approximate, on purpose")
                .font(.system(size: 40, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ink)

            Text("Distance rounds your location to about a kilometer and shares the city, not the street. There is a pause switch, and you can erase it later.")
                .font(.body)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button("Share approximate location") {
                model.finishOnboarding(name: name, share: true)
            }
            .buttonStyle(InkButtonStyle())

            Button("Not now") {
                model.finishOnboarding(name: name, share: false)
            }
            .buttonStyle(InkButtonStyle(prominent: false))
        }
    }
}
