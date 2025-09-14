import WidgetKit
import SwiftUI

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), snapshot: sampleSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(ScheduleEntry(date: Date(), snapshot: loadSnapshot() ?? sampleSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let entry = ScheduleEntry(date: Date(), snapshot: loadSnapshot() ?? sampleSnapshot())
        // Update a few times today to catch transitions if the bridge isn’t triggered
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    
    private func loadSnapshot() -> ScheduleWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(ScheduleWidgetSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
    
    private func sampleSnapshot() -> ScheduleWidgetSnapshot {
        let now = Date()
        let iso = ISO8601DateFormatter.widgetISO
        let start = now.addingTimeInterval(3600)
        let end = start.addingTimeInterval(3600)
        let color = ScheduleWidgetColor(r: 0.2, g: 0.6, b: 0.3, a: 1)
        let item = ScheduleWidgetItem(title: "Sample Class", startISO: iso.string(from: start), endISO: iso.string(from: end), location: "Room 101", color: color)
        return ScheduleWidgetSnapshot(dateGenerated: iso.string(from: now),
                                      dayTitle: DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .none),
                                      noEvents: false,
                                      messageLine1: "1–2 PM",
                                      messageLine2: "Sample Class",
                                      itemsToday: [item],
                                      nextItem: item)
    }
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let snapshot: ScheduleWidgetSnapshot
}

struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetRootView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Schedule")
        .description("See what's next on your schedule.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryRectangular,
            .systemSmall,
            .systemMedium
        ])
    }
}

struct ScheduleWidgetRootView: View {
    let snapshot: ScheduleWidgetSnapshot
    @Environment(\.widgetFamily) private var family
    
    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryInline:
            ScheduleAccessoryInlineView(snapshot: snapshot)
        case .accessoryRectangular:
            ScheduleAccessoryRectangularView(snapshot: snapshot)
        case .systemSmall:
            ScheduleSmallView(snapshot: snapshot)
        case .systemMedium:
            ScheduleMediumView(snapshot: snapshot)
        default:
            ScheduleMediumView(snapshot: snapshot)
        }
    }
}

#Preview(as: .accessoryRectangular) {
    ScheduleWidget()
} timeline: {
    let iso = ISO8601DateFormatter.widgetISO
    let now = Date()
    let color = ScheduleWidgetColor(r: 0.25, g: 0.65, b: 0.35, a: 1)
    let it = ScheduleWidgetItem(title: "Starship Launch", startISO: iso.string(from: now.addingTimeInterval(3600)), endISO: iso.string(from: now.addingTimeInterval(7200)), location: nil, color: color)
    let snap = ScheduleWidgetSnapshot(dateGenerated: iso.string(from: now), dayTitle: "Sat, Sep 13", noEvents: false, messageLine1: "7–8 PM", messageLine2: "Starship Launch", itemsToday: [it], nextItem: it)
    ScheduleEntry(date: now, snapshot: snap)
}