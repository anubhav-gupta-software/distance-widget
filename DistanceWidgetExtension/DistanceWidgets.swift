import DistanceCore
import SwiftUI
import WidgetKit

struct DistanceEntry: TimelineEntry {
    var date: Date
    var reading: DistanceReading
}

struct DistanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> DistanceEntry {
        DistanceEntry(date: Date(), reading: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DistanceEntry) -> Void) {
        let reading = context.isPreview ? DistanceReading.placeholder : SharedStore().reading()
        completion(DistanceEntry(date: Date(), reading: reading))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DistanceEntry>) -> Void) {
        Task {
            let store = SharedStore()
            await refreshPartner(in: store)
            let now = Date()
            let dates = (0..<8).compactMap { step in
                Calendar.current.date(byAdding: .minute, value: step * 30, to: now)
            }
            let entries = dates.map { date in
                DistanceEntry(date: date, reading: store.reading(now: date))
            }
            let followUp = (dates.last ?? now).addingTimeInterval(30 * 60)
            completion(Timeline(entries: entries, policy: .after(followUp)))
        }
    }

    private func refreshPartner(in store: SharedStore) async {
        guard SyncSettings.usesFirebase,
              let pairing = store.pairing,
              let partnerId = pairing.partnerId,
              !pairing.isSample else {
            return
        }
        let client = FirebaseSync(
            baseURL: SyncSettings.firebaseDatabaseURL,
            authToken: SyncSettings.firebaseAuthToken,
            root: SyncSettings.firebaseRootPath
        )
        guard let snapshot = try? await client.loadSnapshot(pairId: pairing.pairId, personId: partnerId) else {
            return
        }
        store.partner = snapshot
    }
}

struct DistanceHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DistanceHome", provider: DistanceProvider()) { entry in
            DistanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Distance")
        .description("How far away they are, their city, and their local time.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct DistanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        DistanceHomeWidget()
    }
}
