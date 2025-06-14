import Foundation
import UserNotifications
import UIKit

// MARK: - Reminder Time Options
enum ReminderTime: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case oneDay = 1440
    case twoDays = 2880
    case oneWeek = 10080
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "No reminder"
        case .fiveMinutes: return "5 minutes before"
        case .fifteenMinutes: return "15 minutes before"
        case .thirtyMinutes: return "30 minutes before"
        case .oneHour: return "1 hour before"
        case .twoHours: return "2 hours before"
        case .oneDay: return "1 day before"
        case .twoDays: return "2 days before"
        case .oneWeek: return "1 week before"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .none: return "None"
        case .fiveMinutes: return "5m"
        case .fifteenMinutes: return "15m"
        case .thirtyMinutes: return "30m"
        case .oneHour: return "1h"
        case .twoHours: return "2h"
        case .oneDay: return "1d"
        case .twoDays: return "2d"
        case .oneWeek: return "1w"
        }
    }
    
    var timeInterval: TimeInterval {
        TimeInterval(rawValue * 60)
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
        
        let identifier = "event-\(event.id.uuidString)-\(reminderTime.rawValue)"
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
        let identifier = "event-\(event.id.uuidString)-\(reminderTime.rawValue)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func removeAllEventNotifications(for event: Event) {
        let identifiers = ReminderTime.allCases.map { "event-\(event.id.uuidString)-\($0.rawValue)" }
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
                    
                    let identifier = "schedule-\(item.id.uuidString)-\(weekOffset)-\(dayOfWeek.rawValue)-\(reminderTime.rawValue)"
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
                let identifier = "schedule-\(item.id.uuidString)-\(weekOffset)-\(dayOfWeek.rawValue)-\(reminderTime.rawValue)"
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
            }
        }
    }
    
    func removeAllScheduleItemNotifications(for item: ScheduleItem) {
        ReminderTime.allCases.forEach { reminderTime in
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
        UserDefaults.standard.set(reminderTime.rawValue, forKey: key)
    }
    
    func getReminderTime(for id: UUID, type: NotificationType) -> ReminderTime {
        let key = "\(type == .event ? "event" : "schedule")-reminder-\(id.uuidString)"
        let rawValue = UserDefaults.standard.integer(forKey: key)
        return ReminderTime(rawValue: rawValue) ?? .none
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
