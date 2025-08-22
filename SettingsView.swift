import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var calendarSyncManager: CalendarSyncManager
    @EnvironmentObject var weatherService: WeatherService
    @StateObject private var scheduleManager = ScheduleManager()
    @StateObject private var academicCalendarManager = AcademicCalendarManager()
    
    @State private var showingThemeSelector = false
    @State private var showingNotificationSettings = false
    @State private var showingGoogleCalendarSettings = false
    @State private var showingAcademicCalendarManagement = false
    
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu"
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Settings")
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Customize your Student Companion experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Appearance Section
                    SettingsSection(title: "Appearance", icon: "paintbrush.fill", color: .purple) {
                        SettingsToggleRow(
                            title: "Dark Mode",
                            subtitle: "Switch between light and dark themes",
                            icon: isDarkMode ? "moon.fill" : "sun.max.fill",
                            isOn: $isDarkMode
                        )
                        
                        SettingsNavigationRow(
                            title: "App Theme",
                            subtitle: "Choose your preferred color scheme",
                            icon: "palette.fill",
                            action: { showingThemeSelector = true }
                        )
                    }
                    
                    // Integrations Section
                    SettingsSection(title: "Integrations", icon: "link", color: .blue) {
                        SettingsNavigationRow(
                            title: "Apple Calendar & Reminders",
                            subtitle: "Sync your classes and assignments",
                            icon: "calendar",
                            destination: AnyView(
                                AppleCalendarSettingsView()
                                    .environmentObject(calendarSyncManager)
                            )
                        )
                        
                        SettingsNavigationRow(
                            title: "Google Calendar",
                            subtitle: "Connect your Google account",
                            icon: "calendar.badge.plus",
                            action: { showingGoogleCalendarSettings = true }
                        )
                        
                        SettingsNavigationRow(
                            title: "Weather",
                            subtitle: "Location and weather preferences",
                            icon: "cloud.sun.fill",
                            destination: AnyView(
                                WeatherSettingsView()
                                    .environmentObject(weatherService)
                            )
                        )
                    }
                    
                    // Academics Section
                    SettingsSection(title: "Academics", icon: "graduationcap.fill", color: .green) {
                        SettingsNavigationRow(
                            title: "Academic Calendars",
                            subtitle: "\(academicCalendarManager.academicCalendars.count) calendar\(academicCalendarManager.academicCalendars.count == 1 ? "" : "s") configured",
                            icon: "calendar.badge.clock",
                            action: { showingAcademicCalendarManagement = true }
                        )
                        
                        SettingsTextFieldRow(
                            title: "D2L Link",
                            subtitle: "Your university's D2L portal URL",
                            icon: "link.circle.fill",
                            text: $d2lLink,
                            placeholder: "https://d2l.youruniversity.edu"
                        )
                    }
                    
                    // Notifications Section
                    SettingsSection(title: "Notifications", icon: "bell.fill", color: .orange) {
                        SettingsToggleRow(
                            title: "Live Activities",
                            subtitle: "Show current class on lock screen",
                            icon: "iphone",
                            isOn: $liveActivitiesEnabled
                        )
                        
                        SettingsNavigationRow(
                            title: "Notification Settings",
                            subtitle: "Manage reminders and alerts",
                            icon: "bell.badge.fill",
                            action: { showingNotificationSettings = true }
                        )
                    }
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("Student Companion")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        
                        Text("Made with ❤️ for students")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingThemeSelector) {
            ThemeSelectorView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .sheet(isPresented: $showingGoogleCalendarSettings) {
            GoogleCalendarSettingsView()
                .environmentObject(calendarSyncManager)
        }
        .sheet(isPresented: $showingAcademicCalendarManagement) {
            AcademicCalendarManagementView()
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
                .environmentObject(scheduleManager)
        }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, 20)
        }
    }
}

struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var destination: AnyView?
    var action: (() -> Void)?
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Group {
            if let destination = destination {
                NavigationLink(destination: destination) {
                    rowContent
                }
            } else {
                Button(action: action ?? {}) {
                    rowContent
                }
            }
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct SettingsTextFieldRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var text: String
    let placeholder: String
    
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 44) // Align with text above
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}