import Foundation
import UserNotifications
import UIKit

// MARK: - Reminder Time Options
enum ReminderTime: Codable, Equatable, Identifiable {
    case none
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case weeks(Int)
    
    var id: String {
        switch self {
        case .none:
            return "none"
        case .minutes(let m):
            return "minutes-\(m)"
        case .hours(let h):
            return "hours-\(h)"
        case .days(let d):
            return "days-\(d)"
        case .weeks(let w):
            return "weeks-\(w)"
        }
    }
    
    var displayName: String {
        switch self {
        case .none:
            return "No reminder"
        case .minutes(let m):
            return m == 1 ? "1 minute before" : "\(m) minutes before"
        case .hours(let h):
            return h == 1 ? "1 hour before" : "\(h) hours before"
        case .days(let d):
            return d == 1 ? "1 day before" : "\(d) days before"
        case .weeks(let w):
            return w == 1 ? "1 week before" : "\(w) weeks before"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .none:
            return "None"
        case .minutes(let m):
            return "\(m)m"
        case .hours(let h):
            return "\(h)h"
        case .days(let d):
            return "\(d)d"
        case .weeks(let w):
            return "\(w)w"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .none:
            return 0
        case .minutes(let m):
            return TimeInterval(m * 60)
        case .hours(let h):
            return TimeInterval(h * 3600)
        case .days(let d):
            return TimeInterval(d * 86400)
        case .weeks(let w):
            return TimeInterval(w * 604800)
        }
    }
    
    var totalMinutes: Int {
        switch self {
        case .none:
            return 0
        case .minutes(let m):
            return m
        case .hours(let h):
            return h * 60
        case .days(let d):
            return d * 1440
        case .weeks(let w):
            return w * 10080
        }
    }
    
    // Common presets for UI convenience
    static let commonPresets: [ReminderTime] = [
        .none,
        .minutes(1),
        .minutes(5),
        .minutes(10),
        .minutes(15),
        .minutes(30),
        .hours(1),
        .hours(2),
        .days(1),
        .days(2),
        .weeks(1)
    ]
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    enum ReminderType: String, Codable {
        case none, minutes, hours, days, weeks
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ReminderType.self, forKey: .type)
        
        switch type {
        case .none:
            self = .none
        case .minutes:
            let value = try container.decode(Int.self, forKey: .value)
            self = .minutes(value)
        case .hours:
            let value = try container.decode(Int.self, forKey: .value)
            self = .hours(value)
        case .days:
            let value = try container.decode(Int.self, forKey: .value)
            self = .days(value)
        case .weeks:
            let value = try container.decode(Int.self, forKey: .value)
            self = .weeks(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .none:
            try container.encode(ReminderType.none, forKey: .type)
        case .minutes(let value):
            try container.encode(ReminderType.minutes, forKey: .type)
            try container.encode(value, forKey: .value)
        case .hours(let value):
            try container.encode(ReminderType.hours, forKey: .type)
            try container.encode(value, forKey: .value)
        case .days(let value):
            try container.encode(ReminderType.days, forKey: .type)
            try container.encode(value, forKey: .value)
        case .weeks(let value):
            try container.encode(ReminderType.weeks, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
    
    // MARK: - Factory Methods
    static func fromMinutes(_ minutes: Int) -> ReminderTime {
        if minutes == 0 {
            return .none
        } else if minutes < 60 {
            return .minutes(minutes)
        } else if minutes < 1440 && minutes % 60 == 0 {
            return .hours(minutes / 60)
        } else if minutes >= 1440 && minutes % 1440 == 0 {
            let days = minutes / 1440
            if days >= 7 && days % 7 == 0 {
                return .weeks(days / 7)
            } else {
                return .days(days)
            }
        } else {
            return .minutes(minutes)
        }
    }
    
    // For backward compatibility with old enum values
    static func fromLegacyRawValue(_ rawValue: Int) -> ReminderTime {
        switch rawValue {
        case 0: return .none
        case 5: return .minutes(5)
        case 15: return .minutes(15)
        case 30: return .minutes(30)
        case 60: return .hours(1)
        case 120: return .hours(2)
        case 1440: return .days(1)
        case 2880: return .days(2)
        case 10080: return .weeks(1)
        default: return .fromMinutes(rawValue)
        }
    }
}

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var notificationSettings: UNNotificationSettings?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSettings = settings
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Event Notifications
    func scheduleEventNotification(for event: Event, reminderTime: ReminderTime, categories: [Category]) {
        guard reminderTime != .none else { return }
        
        let category = event.category(from: categories)
        let notificationDate = event.date.addingTimeInterval(-reminderTime.timeInterval)
        
        // Don't schedule notifications for past dates
        guard notificationDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event"
        content.body = "\(event.title) starts in \(reminderTime.shortDisplayName)"
        content.sound = .default
        content.badge = 1
        
        // Add category-specific emoji
        let emoji = getEmojiForCategory(category.name)
        content.title = "\(emoji) \(content.title)"
        
        // Create date components for trigger
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let identifier = "event-\(event.id.uuidString)-\(reminderTime.totalMinutes)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling event notification: \(error)")
            } else {
                print("Successfully scheduled notification for event: \(event.title)")
            }
        }
    }
    
    func removeEventNotification(for event: Event, reminderTime: ReminderTime) {
        let identifier = "event-\(event.id.uuidString)-\(reminderTime.totalMinutes)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func removeAllEventNotifications(for event: Event) {
        let reminderTimeOptions: [ReminderTime] = [
            .none, .minutes(5), .minutes(15), .minutes(30), .hours(1), .hours(2), 
            .days(1), .days(2), .weeks(1)
        ]
        let identifiers = reminderTimeOptions.map { "event-\(event.id.uuidString)-\($0.totalMinutes)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Schedule Item Notifications
    func scheduleScheduleItemNotifications(for item: ScheduleItem, reminderTime: ReminderTime) {
        guard reminderTime != .none else { return }
        
        // Remove existing notifications for this item
        removeAllScheduleItemNotifications(for: item)
        
        let calendar = Calendar.current
        let today = Date()
        
        // Schedule notifications for the next 4 weeks
        for weekOffset in 0..<4 {
            for dayOfWeek in item.daysOfWeek {
                if let notificationDate = getNextOccurrence(of: dayOfWeek, 
                                                          at: item.startTime, 
                                                          from: today, 
                                                          weekOffset: weekOffset) {
                    
                    let reminderDate = notificationDate.addingTimeInterval(-reminderTime.timeInterval)
                    
                    // Skip if the reminder date is in the past
                    guard reminderDate > Date() else { continue }
                    
                    // Check if this specific instance is skipped using the new method
                    if item.isSkipped(onDate: notificationDate) { continue }
                    
                    let content = UNMutableNotificationContent()
                    content.title = "📚 Class Starting Soon"
                    content.body = "\(item.title) starts in \(reminderTime.shortDisplayName)"
                    content.sound = .default
                    content.badge = 1
                    
                    let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                    
                    let identifier = "schedule-\(item.id.uuidString)-\(weekOffset)-\(dayOfWeek.rawValue)-\(reminderTime.totalMinutes)"
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    
                    notificationCenter.add(request) { error in
                        if let error = error {
                            print("Error scheduling schedule notification: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    func removeScheduleItemNotification(for item: ScheduleItem, reminderTime: ReminderTime) {
        // Remove notifications for the next 4 weeks
        for weekOffset in 0..<4 {
            for dayOfWeek in item.daysOfWeek {
                let identifier = "schedule-\(item.id.uuidString)-\(weekOffset)-\(dayOfWeek.rawValue)-\(reminderTime.totalMinutes)"
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
            }
        }
    }
    
    func removeAllScheduleItemNotifications(for item: ScheduleItem) {
        let reminderTimeOptions: [ReminderTime] = [
            .none, .minutes(5), .minutes(15), .minutes(30), .hours(1), .hours(2), 
            .days(1), .days(2), .weeks(1)
        ]
        reminderTimeOptions.forEach { reminderTime in
            removeScheduleItemNotification(for: item, reminderTime: reminderTime)
        }
    }
    
    // MARK: - Helper Methods
    private func getNextOccurrence(of dayOfWeek: DayOfWeek, at time: Date, from startDate: Date, weekOffset: Int) -> Date? {
        let calendar = Calendar.current
        
        // Get the target week
        guard let targetWeek = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startDate) else {
            return nil
        }
        
        // Find the specific day in that week
        let weekday = dayOfWeek.rawValue
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetWeek)
        components.weekday = weekday
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        return calendar.date(from: components)
    }
    
    private func getEmojiForCategory(_ categoryName: String) -> String {
        let lowercased = categoryName.lowercased()
        switch lowercased {
        case let name where name.contains("assignment"):
            return "📝"
        case let name where name.contains("exam"):
            return "📊"
        case let name where name.contains("lab"):
            return "🧪"
        case let name where name.contains("personal"):
            return "👤"
        case let name where name.contains("study"):
            return "📖"
        case let name where name.contains("meeting"):
            return "👥"
        default:
            return "📅"
        }
    }
    
    // MARK: - Batch Operations
    func rescheduleAllNotifications(for viewModel: EventViewModel) {
        // Get all pending notifications to avoid duplicates
        notificationCenter.removeAllPendingNotificationRequests()
        
        // Reschedule event notifications
        for event in viewModel.events {
            let reminderTime = getReminderTime(for: event.id, type: .event)
            if reminderTime != .none {
                scheduleEventNotification(for: event, reminderTime: reminderTime, categories: viewModel.categories)
            }
        }
        
        // Reschedule schedule item notifications
        for item in viewModel.scheduleItems {
            let reminderTime = getReminderTime(for: item.id, type: .schedule)
            if reminderTime != .none {
                scheduleScheduleItemNotifications(for: item, reminderTime: reminderTime)
            }
        }
    }
    
    // MARK: - Reminder Preferences Storage
    enum NotificationType {
        case event
        case schedule
    }
    
    func setReminderTime(_ reminderTime: ReminderTime, for id: UUID, type: NotificationType) {
        let key = "\(type == .event ? "event" : "schedule")-reminder-\(id.uuidString)"
        
        // Store as total minutes for simplicity
        UserDefaults.standard.set(reminderTime.totalMinutes, forKey: key)
    }
    
    func getReminderTime(for id: UUID, type: NotificationType) -> ReminderTime {
        let key = "\(type == .event ? "event" : "schedule")-reminder-\(id.uuidString)"
        let minutes = UserDefaults.standard.integer(forKey: key)
        
        // Handle migration from old enum values
        if UserDefaults.standard.object(forKey: key) == nil {
            return .none
        }
        
        return ReminderTime.fromMinutes(minutes)
    }
    
    // MARK: - Debug Methods
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    func printPendingNotifications() {
        Task {
            let pending = await getPendingNotifications()
            print("Pending notifications: \(pending.count)")
            for notification in pending {
                print("- \(notification.identifier): \(notification.content.title)")
            }
        }
    }
}

// MARK: - Notification Helper Extensions
extension NotificationCenter {
    static let courseDataDidChange = Notification.Name("courseDataDidChange")
}
