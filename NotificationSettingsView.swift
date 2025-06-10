import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingSystemSettings = false
    @State private var pendingNotifications: [UNNotificationRequest] = []
    
    var body: some View {
        NavigationView {
            List {
                // Authorization status section
                Section {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notification Status")
                                .font(.headline)
                            Text(notificationManager.isAuthorized ? "Notifications enabled" : "Notifications disabled")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !notificationManager.isAuthorized {
                            Button("Enable") {
                                Task {
                                    let granted = await notificationManager.requestAuthorization()
                                    if !granted {
                                        showingSystemSettings = true
                                    }
                                }
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                } footer: {
                    if !notificationManager.isAuthorized {
                        Text("Enable notifications to get reminders for your events and classes.")
                    }
                }
                
                if notificationManager.isAuthorized {
                    // Event reminders section
                    Section {
                        ForEach(viewModel.events) { event in
                            EventReminderRow(event: event)
                                .environmentObject(viewModel)
                                .environmentObject(notificationManager)
                                .environmentObject(themeManager)
                        }
                    } header: {
                        HStack {
                            Text("Event Reminders")
                            Spacer()
                            Text("\(viewModel.events.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Schedule reminders section
                    Section {
                        ForEach(viewModel.scheduleItems) { item in
                            ScheduleReminderRow(scheduleItem: item)
                                .environmentObject(viewModel)
                                .environmentObject(notificationManager)
                                .environmentObject(themeManager)
                        }
                    } header: {
                        HStack {
                            Text("Class Reminders")
                            Spacer()
                            Text("\(viewModel.scheduleItems.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Debug section
                    Section {
                        HStack {
                            Text("Pending Notifications")
                            Spacer()
                            Text("\(pendingNotifications.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Refresh Count") {
                            Task {
                                pendingNotifications = await notificationManager.getPendingNotifications()
                            }
                        }
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        Button("Print Debug Info") {
                            notificationManager.printPendingNotifications()
                        }
                        .foregroundColor(.secondary)
                    } header: {
                        Text("Debug")
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    pendingNotifications = await notificationManager.getPendingNotifications()
                }
            }
            .alert("Enable Notifications", isPresented: $showingSystemSettings) {
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To receive notifications, please enable them in Settings > Notifications > Student Companion")
            }
        }
    }
}

// MARK: - Event Reminder Row
struct EventReminderRow: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // Event indicator
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: event.date))")
                    .font(.caption.weight(.bold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                Text(monthShort(from: event.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 35)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.primaryColor.opacity(0.1))
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(event.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Reminder picker
            Picker("Reminder", selection: reminderBinding) {
                ForEach(ReminderTime.allCases) { time in
                    Text(time.shortDisplayName).tag(time)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
        }
        .padding(.vertical, 2)
    }
    
    private var reminderBinding: Binding<ReminderTime> {
        Binding(
            get: { event.reminderTime },
            set: { newValue in
                var updatedEvent = event
                updatedEvent.reminderTime = newValue
                viewModel.updateEvent(updatedEvent)
            }
        )
    }
    
    private func monthShort(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Schedule Reminder Row
struct ScheduleReminderRow: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var themeManager: ThemeManager
    let scheduleItem: ScheduleItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(scheduleItem.color)
                .frame(width: 4, height: 35)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(scheduleItem.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(timeString(from: scheduleItem.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(daysString(from: scheduleItem.daysOfWeek))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Reminder picker
            Picker("Reminder", selection: reminderBinding) {
                ForEach(ReminderTime.allCases) { time in
                    Text(time.shortDisplayName).tag(time)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
        }
        .padding(.vertical, 2)
    }
    
    private var reminderBinding: Binding<ReminderTime> {
        Binding(
            get: { scheduleItem.reminderTime },
            set: { newValue in
                var updatedItem = scheduleItem
                updatedItem.reminderTime = newValue
                viewModel.updateScheduleItem(updatedItem)
            }
        )
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func daysString(from days: Set<DayOfWeek>) -> String {
        let sortedDays = days.sorted { $0.rawValue < $1.rawValue }
        return sortedDays.map(\.shortName).joined(separator: ", ")
    }
}

// MARK: - Previews
struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
            .environmentObject(NotificationManager.shared)
            .environmentObject(EventViewModel())
            .environmentObject(ThemeManager())
    }
}