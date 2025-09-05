import SwiftUI
import GoogleSignIn
import GoogleAPIClientForREST_Calendar 
import UIKit

struct GoogleCalendarSettingsView: View {
    @EnvironmentObject private var calendarSyncManager: CalendarSyncManager
    @EnvironmentObject private var themeManager: ThemeManager 
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCalendarIDs: [String] = []
    @State private var showingSyncStatus = false
    @State private var isPerformingSync = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                headerSection
                
                // Account Section
                accountSection
                
                // Calendar Selection Section
                if calendarSyncManager.isGoogleCalendarAccessGranted {
                    calendarSelectionSection
                }
                
                // Sync Status Section
                if calendarSyncManager.isGoogleCalendarAccessGranted && !selectedCalendarIDs.isEmpty {
                    syncStatusSection
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Google Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if calendarSyncManager.isGoogleCalendarAccessGranted && !selectedCalendarIDs.isEmpty {
                    Button {
                        performManualSync()
                    } label: {
                        if isPerformingSync {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                    .disabled(isPerformingSync)
                }
            }
        }
        .onAppear {
            if calendarSyncManager.isGoogleCalendarAccessGranted && calendarSyncManager.googleCalendars.isEmpty {
                Task {
                    await calendarSyncManager.fetchGoogleCalendarList()
                }
            }
            self.selectedCalendarIDs = calendarSyncManager.selectedGoogleCalendarIDs
        }
        .onChange(of: selectedCalendarIDs) { oldValue, newValue in
            calendarSyncManager.selectedGoogleCalendarIDs = newValue
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .background(
                    Circle()
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                )
            
            VStack(spacing: 8) {
                Text("Google Calendar Integration")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("Import your Google Calendar events and keep them synchronized with your student schedule")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 20)
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            if calendarSyncManager.isGoogleCalendarAccessGranted {
                // Signed In State
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // Profile Picture Placeholder
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text((calendarSyncManager.signedInGoogleUser?.profile?.name ?? "G").prefix(1))
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(calendarSyncManager.signedInGoogleUser?.profile?.name ?? "Google User")
                                .font(.headline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Text(calendarSyncManager.signedInGoogleUser?.profile?.email ?? "Connected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Connection Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button {
                        calendarSyncManager.signOutFromGoogle()
                        selectedCalendarIDs = []
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            } else {
                // Sign In State
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        Text("Connect Your Google Account")
                            .font(.headline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Text("Sign in to access your Google Calendars and import events")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    
                    Button {
                        if let presentingViewController = getRootViewController() {
                            calendarSyncManager.signInWithGoogle(presentingViewController: presentingViewController)
                        } else {
                             ("Error: Could not get presenting view controller for Google Sign-In.")
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Sign in with Google")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            }
        }
    }
    
    private var calendarSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Calendars")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !calendarSyncManager.googleCalendars.isEmpty {
                    Text("\(selectedCalendarIDs.count) of \(calendarSyncManager.googleCalendars.count)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            VStack(spacing: 12) {
                if calendarSyncManager.googleCalendars.isEmpty {
                    EmptyCalendarsView()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(calendarSyncManager.googleCalendars, id: \.identifier) { calendar in
                            GoogleCalendarRow(
                                calendar: calendar,
                                isSelected: selectedCalendarIDs.contains(calendar.identifier ?? ""),
                                themeManager: themeManager
                            ) {
                                if let id = calendar.identifier {
                                    if selectedCalendarIDs.contains(id) {
                                        selectedCalendarIDs.removeAll { $0 == id }
                                    } else {
                                        selectedCalendarIDs.append(id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        }
    }
    
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Status")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                SyncStatusCard(
                    title: "Selected Calendars",
                    value: "\(selectedCalendarIDs.count)",
                    icon: "calendar.badge.checkmark",
                    color: themeManager.currentTheme.primaryColor
                )
                
                SyncStatusCard(
                    title: "Events Synced",
                    value: "\(calendarSyncManager.googleCalendarEvents.count)",
                    icon: "clock.badge.checkmark",
                    color: themeManager.currentTheme.secondaryColor
                )
                
                SyncStatusCard(
                    title: "Status",
                    value: "Up to date",
                    icon: "checkmark.circle",
                    color: .green
                )
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            
            if !selectedCalendarIDs.isEmpty {
                Text("Events from selected calendars will be imported and synchronized automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private func performManualSync() {
        isPerformingSync = true
        Task {
            await calendarSyncManager.fetchGoogleCalendarEvents()
            isPerformingSync = false
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return rootViewController.presentedViewController ?? rootViewController
    }
}

// MARK: - Supporting Views

struct GoogleCalendarRow: View {
    let calendar: GTLRCalendar_CalendarListEntry
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? themeManager.primaryColor : .secondary)
                
                // Calendar Color Indicator
                if let hexColor = calendar.backgroundColor {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: hexColor) ?? .gray)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(.systemBackground), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray)
                        .frame(width: 20, height: 20)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.summary ?? "Unnamed Calendar")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let calendarDescription = calendar.descriptionProperty, !calendarDescription.isEmpty {
                        Text(calendarDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? themeManager.primaryColor.opacity(0.1) : Color(.systemGray6).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? themeManager.primaryColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LoadingCalendarsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading your calendars...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct EmptyCalendarsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Calendars Found")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text("Make sure you have calendars in your Google account and try refreshing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct SyncStatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isAnimated: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
                .rotationEffect(isAnimated ? .degrees(360) : .degrees(0))
                .animation(isAnimated ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isAnimated)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(8)
    }
}

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - ThemeManager Extension for Color Access
extension ThemeManager {
    var primaryColor: Color {
        currentTheme.primaryColor
    }
    
    var secondaryColor: Color {
        currentTheme.secondaryColor
    }
}

struct GoogleCalendarSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let calendarManager = CalendarSyncManager()
        calendarManager.isGoogleCalendarAccessGranted = true
        
        let calendar1 = GTLRCalendar_CalendarListEntry()
        calendar1.identifier = "cal1_id_preview"
        calendar1.summary = "Primary Calendar"
        calendar1.backgroundColor = "#7986CB"
        calendar1.descriptionProperty = "Your main calendar"

        let calendar2 = GTLRCalendar_CalendarListEntry()
        calendar2.identifier = "cal2_id_preview"
        calendar2.summary = "Work Calendar"
        calendar2.backgroundColor = "#E67C73"

        let calendar3 = GTLRCalendar_CalendarListEntry()
        calendar3.identifier = "cal3_id_preview"
        calendar3.summary = "Holidays in United States"
        calendar3.backgroundColor = "#009688"

        calendarManager.googleCalendars = [calendar1, calendar2, calendar3]
        calendarManager.selectedGoogleCalendarIDs = ["cal1_id_preview", "cal3_id_preview"]

        return NavigationView {
            GoogleCalendarSettingsView()
                .environmentObject(calendarManager)
                .environmentObject(ThemeManager())
        }
    }
}
