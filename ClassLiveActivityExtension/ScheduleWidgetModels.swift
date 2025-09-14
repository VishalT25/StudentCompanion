import Foundation
import SwiftUI

// Must match the app's WidgetBridge models
struct ScheduleWidgetColor: Codable {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
    
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

struct ScheduleWidgetItem: Codable, Identifiable {
    var id: String { "\(title)-\(startISO)" }
    let title: String
    let startISO: String
    let endISO: String
    let location: String?
    let color: ScheduleWidgetColor
}

struct ScheduleWidgetSnapshot: Codable {
    let dateGenerated: String
    let dayTitle: String
    let noEvents: Bool
    let messageLine1: String
    let messageLine2: String?
    let itemsToday: [ScheduleWidgetItem]
    let nextItem: ScheduleWidgetItem?
}

// App Group and key - must match the app
let appGroupID = "group.com.vishal.StuCo"
let snapshotKey = "schedule_widget_snapshot_v1"

extension ISO8601DateFormatter {
    static let widgetISO: ISO8601DateFormatter = {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return df
    }()
}