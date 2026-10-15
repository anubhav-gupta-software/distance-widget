import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.settings.didFinishOnboarding {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .onOpenURL { model.handle(url: $0) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.refreshPartner() }
        }
    }
}
