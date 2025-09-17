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
        ZStack {
            SpectacularBackground(themeManager: themeManager)
            
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    accountSection
                    if calendarSyncManager.isGoogleCalendarAccessGranted {
                        calendarSelectionSection
                        if !selectedCalendarIDs.isEmpty {
                            syncStatusSection
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .safeAreaInset(edge: .top) {
            ZStack {
                Text("Google Calendar")
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if calendarSyncManager.isGoogleCalendarAccessGranted && !selectedCalendarIDs.isEmpty {
                        Button {
                            performManualSync()
                        } label: {
                            if isPerformingSync {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(themeManager.currentTheme.primaryColor)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.forma(.body, weight: .medium))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isPerformingSync)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.clear)
        }
        .onAppear {
            if calendarSyncManager.isGoogleCalendarAccessGranted && calendarSyncManager.googleCalendars.isEmpty {
                Task { await calendarSyncManager.fetchGoogleCalendarList() }
            }
            selectedCalendarIDs = calendarSyncManager.selectedGoogleCalendarIDs
        }
        .onChange(of: selectedCalendarIDs) { _, newValue in
            calendarSyncManager.selectedGoogleCalendarIDs = newValue
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [
                        themeManager.currentTheme.primaryColor,
                        themeManager.currentTheme.secondaryColor
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.35), radius: 16, x: 0, y: 8)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(spacing: 8) {
                Text("Google Calendar Integration")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Import your Google Calendar events and keep them synchronized with your student schedule.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.forma(.title3, weight: .bold))
                .foregroundColor(.primary)
            
            if calendarSyncManager.isGoogleCalendarAccessGranted {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(LinearGradient(
                                colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text((calendarSyncManager.signedInGoogleUser?.profile?.name ?? "G").prefix(1))
                                    .font(.forma(.title3, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(calendarSyncManager.signedInGoogleUser?.profile?.name ?? "Google User")
                                .font(.forma(.headline, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(calendarSyncManager.signedInGoogleUser?.profile?.email ?? "Connected")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.forma(.caption, weight: .medium))
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
                                .font(.forma(.subheadline, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color(.systemBackground).opacity(0.95))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        Text("Connect Your Google Account")
                            .font(.forma(.headline, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Sign in to access your Google Calendars and import events.")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    
                    Button {
                        if let presentingViewController = getRootViewController() {
                            calendarSyncManager.signInWithGoogle(presentingViewController: presentingViewController)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Sign in with Google")
                                .font(.forma(.subheadline, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color(.systemBackground).opacity(0.95))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            }
        }
    }
    
    private var calendarSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Calendars")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !calendarSyncManager.googleCalendars.isEmpty {
                    Text("\(selectedCalendarIDs.count) of \(calendarSyncManager.googleCalendars.count)")
                        .font(.forma(.caption, weight: .medium))
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
            .background(Color(.systemBackground).opacity(0.95))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
    }
    
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Status")
                .font(.forma(.title3, weight: .bold))
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
            .background(Color(.systemBackground).opacity(0.95))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            
            if !selectedCalendarIDs.isEmpty {
                Text("Events from selected calendars will be imported and synchronized automatically.")
                    .font(.forma(.caption))
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
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? themeManager.primaryColor : .secondary)
                
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
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let calendarDescription = calendar.descriptionProperty, !calendarDescription.isEmpty {
                        Text(calendarDescription)
                            .font(.forma(.caption))
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
                .font(.forma(.subheadline))
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
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Make sure you have calendars in your Google account and try refreshing.")
                    .font(.forma(.caption))
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
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(8)
    }
}

extension ThemeManager {
    var primaryColor: Color { currentTheme.primaryColor }
    var secondaryColor: Color { currentTheme.secondaryColor }
}