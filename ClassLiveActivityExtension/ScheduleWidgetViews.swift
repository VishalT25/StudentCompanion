import UIKit
import SwiftUI
import WidgetKit

// MARK: - Forma helpers (fallback to system if not present)
enum WidgetFont {
    static func forma(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        // Try a few likely Forma names; fallback to system
        let candidates: [String] = [
            "FormaDJRText-Regular",
            "FormaDJRText-Medium",
            "FormaDJRText-Bold"
        ]
        let size: CGFloat
        switch style {
        case .largeTitle: size = 34
        case .title: size = 28
        case .title2: size = 22
        case .title3: size = 20
        case .headline: size = 17
        case .body: size = 17
        case .callout: size = 16
        case .subheadline: size = 15
        case .footnote: size = 13
        case .caption: size = 12
        case .caption2: size = 11
        @unknown default: size = 17
        }
        for name in candidates {
            if UIFont(name: name, size: size) != nil {
                return Font.custom(name, size: size).weight(weight)
            }
        }
        return Font.system(style, design: .rounded).weight(weight)
    }
}

// MARK: - Lock Screen AccessoryInline
struct ScheduleAccessoryInlineView: View {
    let snapshot: ScheduleWidgetSnapshot
    
    var body: some View {
        if let next = snapshot.nextItem {
            HStack(spacing: 6) {
                Capsule()
                    .fill(next.color.color)
                    .frame(width: 3, height: 10)
                Text("\(widgetTimeRangeText(next)) \(next.title)")
                    .font(WidgetFont.forma(.caption))
                    .lineLimit(1)
            }
        } else {
            Text("No events")
                .font(WidgetFont.forma(.caption))
        }
    }
}

// MARK: - Lock Screen AccessoryRectangular
struct ScheduleAccessoryRectangularView: View {
    let snapshot: ScheduleWidgetSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.dayTitle)
                .font(WidgetFont.forma(.caption, weight: .semibold))
                .foregroundColor(.secondary)
                .widgetAccentable()
            Text(snapshot.messageLine1)
                .font(WidgetFont.forma(.body, weight: .semibold))
                .widgetAccentable()
                .lineLimit(1)
            if let m2 = snapshot.messageLine2 {
                Text(m2)
                    .font(WidgetFont.forma(.caption))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Home screen widgets
struct ScheduleSmallView: View {
    let snapshot: ScheduleWidgetSnapshot
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(white: 0.96), Color(white: 0.92)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 6) {
                Text("Next")
                    .font(WidgetFont.forma(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
                if let next = snapshot.nextItem {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(next.color.color)
                            .frame(width: 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.title)
                                .font(WidgetFont.forma(.body, weight: .semibold))
                                .lineLimit(2)
                            Text(widgetTimeRangeText(next))
                                .font(WidgetFont.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No events today")
                        .font(WidgetFont.forma(.body, weight: .semibold))
                    Text("Your day is clear")
                        .font(WidgetFont.forma(.caption))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
        }
    }
}

struct ScheduleMediumView: View {
    let snapshot: ScheduleWidgetSnapshot
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(white: 0.96), Color(white: 0.92)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snapshot.dayTitle)
                        .font(WidgetFont.forma(.headline, weight: .bold))
                    Spacer()
                }
                if snapshot.itemsToday.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No events today")
                            .font(WidgetFont.forma(.body, weight: .semibold))
                        Text("Your day is clear")
                            .font(WidgetFont.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(snapshot.itemsToday.prefix(3)) { item in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(item.color.color)
                                .frame(width: 4, height: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(WidgetFont.forma(.body, weight: .semibold))
                                    .lineLimit(1)
                                Text("\(widgetTimeRangeText(item))\(widgetLocationSuffix(item.location))")
                                    .font(WidgetFont.forma(.caption))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                Spacer()
            }
            .padding(12)
        }
    }
}

private func widgetTimeRangeText(_ item: ScheduleWidgetItem) -> String {
    let df = DateFormatter()
    df.timeStyle = .short
    let start = ISO8601DateFormatter.widgetISO.date(from: item.startISO) ?? Date()
    let end = ISO8601DateFormatter.widgetISO.date(from: item.endISO) ?? Date()
    return "\(df.string(from: start))–\(df.string(from: end))"
}

private func widgetLocationSuffix(_ location: String?) -> String {
    guard let loc = location, !loc.isEmpty else { return "" }
    return " · \(loc)"
}