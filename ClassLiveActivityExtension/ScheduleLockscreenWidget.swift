import WidgetKit
import SwiftUI

// Lock screen widget aligned to shared ScheduleWidgetSnapshot models
private struct LockScheduleEntry: TimelineEntry {
    let date: Date
    let snapshot: ScheduleWidgetSnapshot
}

private struct LockScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScheduleEntry {
        LockScheduleEntry(date: Date(), snapshot: Self.sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScheduleEntry) -> Void) {
        let snap = readSnapshot() ?? Self.sampleSnapshot
        completion(LockScheduleEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScheduleEntry>) -> Void) {
        let snap = readSnapshot() ?? Self.sampleSnapshot
        var entries: [LockScheduleEntry] = []
        let now = Date()
        let iso = ISO8601DateFormatter.widgetISO

        let todayItems = snap.itemsToday
            .compactMap { item -> (start: Date, end: Date, item: ScheduleWidgetItem)? in
                guard let s = iso.date(from: item.startISO), let e = iso.date(from: item.endISO) else { return nil }
                return (start: s, end: e, item: item)
            }
            .sorted(by: { $0.start < $1.start })

        entries.append(LockScheduleEntry(date: now, snapshot: snap))

        let boundaries = todayItems
            .flatMap { [$0.start, $0.end] }
            .filter { $0 >= now }
            .sorted()

        for b in boundaries.prefix(15) {
            entries.append(LockScheduleEntry(date: b, snapshot: snap))
        }

        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) {
            entries.append(LockScheduleEntry(date: tomorrow, snapshot: snap))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func readSnapshot() -> ScheduleWidgetSnapshot? {
        guard let ud = UserDefaults(suiteName: appGroupID),
              let data = ud.data(forKey: snapshotKey),
              let snap = try? JSONDecoder().decode(ScheduleWidgetSnapshot.self, from: data) else {
            return nil
        }
        return snap
    }

    private static var sampleSnapshot: ScheduleWidgetSnapshot {
        let iso = ISO8601DateFormatter.widgetISO
        let now = Date()
        let start1 = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let end1 = Calendar.current.date(bySettingHour: 10, minute: 15, second: 0, of: now) ?? now
        let start2 = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: now) ?? now
        let end2 = Calendar.current.date(bySettingHour: 14, minute: 15, second: 0, of: now) ?? now

        let c1 = ScheduleWidgetColor(r: 0.15, g: 0.55, b: 0.9, a: 1)
        let c2 = ScheduleWidgetColor(r: 0.3, g: 0.7, b: 0.35, a: 1)

        let it1 = ScheduleWidgetItem(title: "Biology 201", startISO: iso.string(from: start1), endISO: iso.string(from: end1), location: "Room 302", color: c1)
        let it2 = ScheduleWidgetItem(title: "Calculus", startISO: iso.string(from: start2), endISO: iso.string(from: end2), location: "Hall B", color: c2)

        return ScheduleWidgetSnapshot(
            dateGenerated: iso.string(from: now),
            dayTitle: DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .none),
            noEvents: false,
            messageLine1: "Up next",
            messageLine2: "Stay on track",
            itemsToday: [it1, it2],
            nextItem: it1
        )
    }
}

// MARK: - Views

private struct LockRectangularView: View {
    let entry: LockScheduleEntry

    var body: some View {
        let now = entry.date
        let iso = ISO8601DateFormatter.widgetISO

        let items = entry.snapshot.itemsToday
            .compactMap { item -> (start: Date, end: Date, item: ScheduleWidgetItem)? in
                guard let s = iso.date(from: item.startISO), let e = iso.date(from: item.endISO) else { return nil }
                return (s, e, item)
            }
            .sorted(by: { $0.start < $1.start })

        let current = items.first { $0.start <= now && now < $0.end }
        let upcoming = items.first { $0.start > now }

        VStack(alignment: .leading, spacing: 2) {
            Text(entry.snapshot.dayTitle)
                .font(WidgetFont.forma(.caption, weight: .semibold))
                .foregroundStyle(.secondary)

            if let c = current {
                Text(c.item.title)
                    .font(WidgetFont.forma(.body, weight: .semibold))
                    .lineLimit(1)
                Text("Ends \(timeString(c.end))")
                    .font(WidgetFont.forma(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let n = upcoming {
                Text(n.item.title)
                    .font(WidgetFont.forma(.body, weight: .semibold))
                    .lineLimit(1)
                Text("\(timeString(n.start))–\(timeString(n.end))")
                    .font(WidgetFont.forma(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No events today")
                    .font(WidgetFont.forma(.body, weight: .semibold))
                    .lineLimit(1)
                Text("Your day is clear")
                    .font(WidgetFont.forma(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: date)
    }
}

private struct LockInlineView: View {
    let entry: LockScheduleEntry

    var body: some View {
        let now = entry.date
        let iso = ISO8601DateFormatter.widgetISO

        let items = entry.snapshot.itemsToday
            .compactMap { item -> (start: Date, end: Date, item: ScheduleWidgetItem)? in
                guard let s = iso.date(from: item.startISO), let e = iso.date(from: item.endISO) else { return nil }
                return (s, e, item)
            }
            .sorted(by: { $0.start < $1.start })

        let current = items.first { $0.start <= now && now < $0.end }
        let upcoming = items.first { $0.start > now }

        HStack(spacing: 4) {
            Image(systemName: "calendar.badge.clock")
            if let c = current {
                Text("\(c.item.title) until \(timeString(c.end))")
                    .lineLimit(1)
            } else if let n = upcoming {
                Text("\(timeString(n.start)): \(n.item.title)")
                    .lineLimit(1)
            } else {
                Text("No events")
                    .lineLimit(1)
            }
        }
        .font(WidgetFont.forma(.caption))
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: date)
    }
}

private struct LockAccessoryRouter: View {
    let entry: LockScheduleEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockRectangularView(entry: entry)
        case .accessoryInline:
            LockInlineView(entry: entry)
        case .systemSmall:
            LockRectangularView(entry: entry)
                .padding(8)
        default:
            LockRectangularView(entry: entry)
        }
    }
}

struct ScheduleLockscreenWidget: Widget {
    let kind: String = "ScheduleLockscreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScheduleProvider()) { entry in
            LockAccessoryRouter(entry: entry)
        }
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall])
        .configurationDisplayName("Schedule")
        .description("See your current and next class, just like Calendar.")
    }
}