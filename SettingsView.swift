import SwiftUI
import Combine
import EventKit

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var notificationManager: StudentCompanion.NotificationManager
    @EnvironmentObject private var calendarSyncManager: CalendarSyncManager
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true
    @EnvironmentObject private var eventViewModel: EventViewModel

    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu"
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @State private var showingNotificationSettings = false

    // State properties for authorization statuses
    @State private var calendarAuthStatus: EKAuthorizationStatus = .notDetermined
    @State private var remindersAuthStatus: EKAuthorizationStatus = .notDetermined

    @AppStorage("appleCalendarIntegrationEnabled") private var appleCalendarIntegrationEnabled: Bool = true
    @AppStorage("appleRemindersIntegrationEnabled") private var appleRemindersIntegrationEnabled: Bool = true

    @State private var showingRemoveCalendarDataAlert = false
    @State private var showingRemoveRemindersDataAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Theme Selection
                themeSelectionSection
                
                notificationSection

                liveActivitySection
                
                calendarIntegrationSection

                remindersIntegrationSection
                
                // Grade Display Settings
                gradeDisplaySection
                
                // D2L Configuration
                d2lConfigSection
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
                .environmentObject(notificationManager)
        }
        .onChange(of: liveActivitiesEnabled) { oldValue, newValue in
            Task { @MainActor in
                if !newValue {
                    LiveActivityManager.shared.endAllActivities()
                } else {
                    eventViewModel.manageLiveActivities(themeManager: themeManager)
                }
            }
        }
    }
    
    private var liveActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Activities")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            SettingToggleRow(
                title: "Show Current Event",
                subtitle: "Display ongoing schedule items in the Dynamic Island and on the Lock Screen.",
                isOn: $liveActivitiesEnabled,
                icon: "sparkles",
                color: themeManager.currentTheme.secondaryColor
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                Button {
                    showingNotificationSettings = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Notifications")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Text(notificationManager.isAuthorized ? "Notifications enabled" : "Notifications disabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(notificationManager.isAuthorized ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var themeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Theme")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeSelectionRow(
                        theme: theme,
                        isSelected: themeManager.currentTheme == theme
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.setTheme(theme)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var gradeDisplaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grade Display")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                SettingToggleRow(
                    title: "Show Current Grade",
                    subtitle: "Display your current grade on the Courses button",
                    isOn: $showCurrentGPA,
                    icon: "graduationcap.fill",
                    color: themeManager.currentTheme.primaryColor
                )
                
                if showCurrentGPA {
                    SettingToggleRow(
                        title: "Use Percentage Grades",
                        subtitle: "Show percentages instead of GPA scale",
                        isOn: $usePercentageGrades,
                        icon: "percent",
                        color: themeManager.currentTheme.secondaryColor
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var d2lConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("D2L Configuration")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("D2L Portal URL")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                TextField("Enter D2L URL", text: $d2lLink)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                
                Text("Ensure the URL starts with 'https://' or 'http://'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var calendarIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar Integrations")
                .font(.title3.bold())
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                SettingToggleRow(
                    title: "Sync Apple Calendar",
                    subtitle: appleCalendarIntegrationEnabled ? (calendarSyncManager.isCalendarAccessGranted ? "Syncing enabled" : "Tap to grant access") : "Sync disabled",
                    isOn: $appleCalendarIntegrationEnabled,
                    icon: "calendar",
                    color: appleCalendarIntegrationEnabled && calendarSyncManager.isCalendarAccessGranted ? .green : themeManager.currentTheme.primaryColor
                )
                .onChange(of: appleCalendarIntegrationEnabled) { oldValue, newValue in
                    if newValue {
                        // Turning ON
                        Task {
                            if !calendarSyncManager.isCalendarAccessGranted {
                                await calendarSyncManager.requestCalendarAccess() // This will also trigger a fetch if access is granted
                            } else {
                                // Already has permission, trigger a fetch manually
                                await calendarSyncManager.fetchEventsAndUpdatePublishedProperty()
                            }
                            // Update local auth status for UI
                            self.calendarAuthStatus = calendarSyncManager.checkCalendarAuthorizationStatus()
                        }
                    } else {
                        // Turning OFF - Ask to remove data
                        showingRemoveCalendarDataAlert = true
                    }
                }

                // Display system permission status if toggle is on but access is denied
                if appleCalendarIntegrationEnabled && (calendarAuthStatus == .denied || calendarAuthStatus == .restricted) {
                     Text("Calendar access was denied at the system level. Please enable it in the Settings app.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 42) // Align with toggle text
                }
                
                // Keep the text for fetched events for now, or remove if too cluttered
                if appleCalendarIntegrationEnabled && calendarSyncManager.isCalendarAccessGranted && !calendarSyncManager.appleCalendarEvents.isEmpty {
                    Text("Last sync: \(calendarSyncManager.appleCalendarEvents.count) calendar events.")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.leading, 42)
                } else if appleCalendarIntegrationEnabled && calendarSyncManager.isCalendarAccessGranted && calendarSyncManager.appleCalendarEvents.isEmpty && calendarAuthStatus != .notDetermined {
                    Text("No calendar events found in the selected range or an error occurred.")
                         .font(.caption)
                         .foregroundColor(.orange)
                         .padding(.leading, 42)
                }

                // Google Calendar button remains for future implementation
                SettingButtonRow(
                    title: "Connect Google Calendar",
                    icon: "calendar",
                    color: .blue,
                    action: {
                        print("Connect Google Calendar tapped")
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .onAppear {
            self.calendarAuthStatus = calendarSyncManager.checkCalendarAuthorizationStatus()
            // If toggle is on but access not granted, it will show in subtitle
        }
        .alert("Remove Calendar Data?", isPresented: $showingRemoveCalendarDataAlert) {
            Button("Remove Imported Data", role: .destructive) {
                eventViewModel.removeImportedData(sourcePrefix: "Apple Calendar -")
                calendarSyncManager.clearAppleCalendarEventsData() // New method to add in CalendarSyncManager
                print("User opted to remove Apple Calendar data.")
            }
            Button("Keep Data", role: .cancel) {
                 print("User opted to keep Apple Calendar data despite disabling sync.")
            }
        } message: {
            Text("Disabling Apple Calendar sync. Would you also like to remove calendar events previously imported from Apple Calendar from this app?")
        }
    }

    private var remindersIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reminders Integration")
                .font(.title3.bold())
                .foregroundColor(.primary)

            SettingToggleRow(
                title: "Sync Apple Reminders",
                subtitle: appleRemindersIntegrationEnabled ? (calendarSyncManager.isRemindersAccessGranted ? "Syncing enabled" : "Tap to grant access") : "Sync disabled",
                isOn: $appleRemindersIntegrationEnabled,
                icon: "list.bullet.clipboard",
                color: appleRemindersIntegrationEnabled && calendarSyncManager.isRemindersAccessGranted ? .green : themeManager.currentTheme.secondaryColor
            )
            .onChange(of: appleRemindersIntegrationEnabled) { oldValue, newValue in
                if newValue {
                    // Turning ON
                    Task {
                        if !calendarSyncManager.isRemindersAccessGranted {
                            await calendarSyncManager.requestRemindersAccess()
                        } else {
                            await calendarSyncManager.fetchRemindersAndUpdatePublishedProperty()
                        }
                        self.remindersAuthStatus = calendarSyncManager.checkRemindersAuthorizationStatus()
                    }
                } else {
                    // Turning OFF
                    showingRemoveRemindersDataAlert = true
                }
            }
            
            if appleRemindersIntegrationEnabled && (remindersAuthStatus == .denied || remindersAuthStatus == .restricted) {
                 Text("Reminders access was denied at the system level. Please enable it in the Settings app.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 42)
            }

            if appleRemindersIntegrationEnabled && calendarSyncManager.isRemindersAccessGranted && !calendarSyncManager.appleReminders.isEmpty {
                Text("Last sync: \(calendarSyncManager.appleReminders.count) reminders.")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.leading, 42)
            } else if appleRemindersIntegrationEnabled && calendarSyncManager.isRemindersAccessGranted && calendarSyncManager.appleReminders.isEmpty && remindersAuthStatus != .notDetermined {
                 Text("No incomplete reminders found or an error occurred.")
                     .font(.caption)
                     .foregroundColor(.orange)
                     .padding(.leading, 42)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .onAppear {
            self.remindersAuthStatus = calendarSyncManager.checkRemindersAuthorizationStatus()
        }
        .alert("Remove Reminders Data?", isPresented: $showingRemoveRemindersDataAlert) {
            Button("Remove Imported Data", role: .destructive) {
                eventViewModel.removeImportedData(sourcePrefix: "Apple Reminders -")
                calendarSyncManager.clearAppleRemindersData() // New method to add
                print("User opted to remove Apple Reminders data.")
            }
            Button("Keep Data", role: .cancel) {
                print("User opted to keep Apple Reminders data despite disabling sync.")
            }
        } message: {
            Text("Disabling Apple Reminders sync. Would you also like to remove reminders previously imported from Apple Reminders from this app?")
        }
    }
}

struct ThemeSelectionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(theme.primaryColor)
                        .frame(width: 16, height: 16)
                    Circle()
                        .fill(theme.secondaryColor)
                        .frame(width: 16, height: 16)
                    Circle()
                        .fill(theme.tertiaryColor)
                        .frame(width: 16, height: 16)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(themeDescription(for: theme))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.primaryColor)
                        .font(.title3)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? theme.primaryColor.opacity(0.1) : Color(.systemGray6).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.primaryColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func themeDescription(for theme: AppTheme) -> String {
        switch theme {
        case .forest:
            return "Calming green tones inspired by nature"
        case .ice:
            return "Cool blue tones for a crisp, clean feel"
        case .fire:
            return "Warm red tones for energy and passion"
        }
    }
}

struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

struct SettingButtonRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let action: () -> Void

    init(title: String, subtitle: String? = nil, icon: String, color: Color, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)

                    
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let previewCalendarSyncManager = CalendarSyncManager()
        let previewEventViewModel = EventViewModel()

        return NavigationView {
            SettingsView()
                .environmentObject(ThemeManager())
                .environmentObject(StudentCompanion.NotificationManager.shared)
                .environmentObject(previewEventViewModel)
                .environmentObject(previewCalendarSyncManager)
        }
    }
}
