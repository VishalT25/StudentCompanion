import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu"
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @State private var showingNotificationSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Theme Selection
                themeSelectionSection
                
                notificationSection
                
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
                        
                        // Status indicator
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
}

struct ThemeSelectionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Theme color preview
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(ThemeManager())
                .environmentObject(NotificationManager())
        }
    }
}
