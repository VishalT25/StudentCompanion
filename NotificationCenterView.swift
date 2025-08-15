import SwiftUI
import UserNotifications

struct NotificationCenterView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var eventViewModel: EventViewModel
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var liveActivities: [LiveActivityInfo] = []
    @State private var upcomingReminders: [Event] = []
    @State private var recentNotifications: [NotificationItem] = []
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Live Activities Section
                    if !liveActivities.isEmpty {
                        NotificationSectionView(
                            title: "Live Activities",
                            subtitle: "Currently active",
                            icon: "sparkles",
                            color: themeManager.currentTheme.primaryColor
                        ) {
                            LazyVStack(spacing: 12) {
                                ForEach(liveActivities, id: \.id) { activity in
                                    LiveActivityCard(activity: activity)
                                        .environmentObject(themeManager)
                                }
                            }
                        }
                    }
                    
                    // Upcoming Reminders Section
                    if !upcomingReminders.isEmpty {
                        NotificationSectionView(
                            title: "Upcoming Reminders",
                            subtitle: "\(upcomingReminders.count) items",
                            icon: "clock.badge.exclamationmark",
                            color: themeManager.currentTheme.secondaryColor
                        ) {
                            LazyVStack(spacing: 12) {
                                ForEach(upcomingReminders.prefix(5), id: \.id) { reminder in
                                    ReminderNotificationCard(reminder: reminder)
                                        .environmentObject(themeManager)
                                        .environmentObject(eventViewModel)
                                }
                            }
                        }
                    }
                    
                    // Recent Notifications Section
                    if !recentNotifications.isEmpty {
                        NotificationSectionView(
                            title: "Recent Notifications",
                            subtitle: "Last 24 hours",
                            icon: "bell.badge",
                            color: themeManager.currentTheme.tertiaryColor
                        ) {
                            LazyVStack(spacing: 12) {
                                ForEach(recentNotifications, id: \.id) { notification in
                                    SystemNotificationCard(notification: notification)
                                        .environmentObject(themeManager)
                                }
                            }
                        }
                    }
                    
                    // Empty State
                    if liveActivities.isEmpty && upcomingReminders.isEmpty && recentNotifications.isEmpty {
                        EmptyNotificationState()
                            .environmentObject(themeManager)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await refreshNotifications()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    .disabled(isRefreshing)
                }
            }
            .refreshable {
                await refreshNotifications()
            }
        }
        .onAppear {
            Task {
                await loadNotifications()
            }
        }
    }
    
    @MainActor
    private func loadNotifications() async {
        isRefreshing = true
        
        // Load live activities
        await loadLiveActivities()
        
        // Load upcoming reminders
        loadUpcomingReminders()
        
        // Load recent notifications
        await loadRecentNotifications()
        
        isRefreshing = false
    }
    
    @MainActor
    private func refreshNotifications() async {
        await loadNotifications()
    }
    
    private func loadLiveActivities() async {
        // Get current live activities from LiveActivityManager
        liveActivities = LiveActivityManager.shared.getCurrentActivities()
    }
    
    private func loadUpcomingReminders() {
        let now = Date()
        let next24Hours = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        
        upcomingReminders = eventViewModel.events
            .filter { event in
                guard event.reminderTime != .none, !event.isCompleted else { return false }
                let reminderDate = event.date.addingTimeInterval(-event.reminderTime.timeInterval)
                return reminderDate >= now && reminderDate <= next24Hours
            }
            .sorted { 
                let date1 = $0.date.addingTimeInterval(-$0.reminderTime.timeInterval)
                let date2 = $1.date.addingTimeInterval(-$1.reminderTime.timeInterval)
                return date1 < date2
            }
    }
    
    private func loadRecentNotifications() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let notifications = try await withUnsafeThrowingContinuation { continuation in
                center.getDeliveredNotifications { notifications in
                    continuation.resume(returning: notifications)
                }
            }
            let last24Hours = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            recentNotifications = notifications
                .compactMap { notification -> NotificationItem? in
                    let request = notification.request
                    let content = request.content
                    
                    // Filter for notifications from the last 24 hours
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                       let triggerDate = trigger.nextTriggerDate(),
                       triggerDate >= last24Hours {
                        
                        return NotificationItem(
                            id: request.identifier,
                            title: content.title,
                            body: content.body,
                            date: triggerDate,
                            categoryIdentifier: content.categoryIdentifier,
                            userInfo: content.userInfo
                        )
                    }
                    
                    return nil
                }
                .sorted { $0.date > $1.date }
        } catch {
            print("Failed to load recent notifications: \(error)")
            recentNotifications = []
        }
    }
}

// MARK: - Notification Section View
struct NotificationSectionView<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, subtitle: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Live Activity Card
struct LiveActivityCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let activity: LiveActivityInfo
    
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 4)
                .fill(activity.color)
                .frame(width: 4, height: 60)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(activity.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
                
                Text(activity.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(activity.timeRange)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let location = activity.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            Button {
                LiveActivityManager.shared.endActivity(activityId: activity.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(activity.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(activity.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Reminder Notification Card
struct ReminderNotificationCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var eventViewModel: EventViewModel
    let reminder: Event
    
    private var reminderDate: Date? {
        guard reminder.reminderTime != .none else { return nil }
        return reminder.date.addingTimeInterval(-reminder.reminderTime.timeInterval)
    }
    
    private var timeUntilReminder: String {
        guard let reminderDate = reminderDate else { return "" }
        let now = Date()
        let timeInterval = reminderDate.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "Overdue"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "in \(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "in \(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "in \(days)d"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 4)
                .fill(reminder.reminderTime.color)
                .frame(width: 4, height: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reminder.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !timeUntilReminder.isEmpty {
                        Text(timeUntilReminder)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeManager.currentTheme.secondaryColor.opacity(0.15))
                            .foregroundColor(themeManager.currentTheme.secondaryColor)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(reminder.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(reminder.reminderTime.shortDisplayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(reminder.reminderTime.color.opacity(0.15))
                        .foregroundColor(reminder.reminderTime.color)
                        .cornerRadius(3)
                    
                    Spacer()
                }
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    eventViewModel.markEventCompleted(reminder)
                }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title3)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - System Notification Card
struct SystemNotificationCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let notification: NotificationItem
    
    private var timeAgo: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(notification.date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            return notification.date.formatted(date: .abbreviated, time: .shortened)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(notification.categoryIdentifier))
                .font(.title3)
                .foregroundColor(themeManager.currentTheme.tertiaryColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(themeManager.currentTheme.tertiaryColor.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(timeAgo)
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
        )
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "REMINDER_CATEGORY":
            return "bell.fill"
        case "SCHEDULE_CATEGORY":
            return "calendar"
        case "GRADE_CATEGORY":
            return "graduationcap.fill"
        default:
            return "app.badge"
        }
    }
}

// MARK: - Empty State
struct EmptyNotificationState: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Notifications")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("When you have reminders, live activities, or other notifications, they'll appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Supporting Models
struct LiveActivityInfo {
    let id: String
    let title: String
    let subtitle: String
    let timeRange: String
    let location: String?
    let color: Color
}

struct NotificationItem {
    let id: String
    let title: String
    let body: String
    let date: Date
    let categoryIdentifier: String
    let userInfo: [AnyHashable: Any]
}

// MARK: - Extensions
extension LiveActivityManager {
    func getCurrentActivities() -> [LiveActivityInfo] {
        // This would need to be implemented in your LiveActivityManager
        // For now, return empty array - you'll need to implement this based on your live activity system
        return []
    }
    
    func endActivity(activityId: String) {
        // Implement activity ending logic
        print("Ending activity: \(activityId)")
    }
}