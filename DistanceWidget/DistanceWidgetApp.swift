import SwiftUI

@main
struct DistanceWidgetApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Palette.ink)
        }
    }
}
