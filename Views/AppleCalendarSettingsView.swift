import SwiftUI

struct AppleCalendarSettingsView: View {
    @EnvironmentObject var calendarSyncManager: CalendarSyncManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEnabled: Bool = UserDefaults.standard.bool(forKey: "appleRemindersIntegrationEnabled")
    @State private var isRequesting = false
    @State private var statusText: String = ""
    @State private var isAuthorized: Bool = false
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            SpectacularBackground(themeManager: themeManager)
            
            ScrollView {
                VStack(spacing: 24) {
                    header
                    statusCard
                    toggleCard
                    actionButtons
                    footerNote
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .top) {
            ZStack {
                Text("Apple Reminders")
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
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.clear)
        }
        .onAppear {
            refreshAuthorizationStatus()
            isEnabled = UserDefaults.standard.bool(forKey: "appleRemindersIntegrationEnabled")
        }
        .onChange(of: isEnabled) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "appleRemindersIntegrationEnabled")
            if newValue && isAuthorized {
                Task { await calendarSyncManager.fetchRemindersAndUpdatePublishedProperty() }
            } else if !newValue {
                calendarSyncManager.clearAppleRemindersData()
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.9),
                        themeManager.currentTheme.secondaryColor.opacity(0.9)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.35), radius: 16, x: 0, y: 8)
                Image(systemName: "applelogo")
                    .foregroundColor(.white)
                    .font(.system(size: 36, weight: .bold))
            }
            Text("Connect Apple Reminders")
                .font(.forma(.title2, weight: .bold))
            Text("Use the native Reminders app to keep your tasks and due dates in sync with StuCo.")
                .font(.forma(.subheadline))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }
    
    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((isAuthorized ? Color.green : Color.red).opacity(0.15))
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(isAuthorized ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Permission Status")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                Text(statusText)
                    .font(.forma(.body, weight: .semibold))
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Integration")
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.secondary)
            HStack {
                Text("Enable Apple Reminders")
                    .font(.forma(.body, weight: .semibold))
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
            .padding(12)
            .background(themeManager.currentTheme.primaryColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                requestReminders()
            } label: {
                HStack {
                    if isRequesting {
                        ProgressView().tint(.white)
                    }
                    Text(isAuthorized ? "Recheck Reminders Access" : "Grant Reminders Access")
                        .font(.forma(.body, weight: .bold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(LinearGradient(colors: [
                    themeManager.currentTheme.primaryColor,
                    themeManager.currentTheme.secondaryColor
                ], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isRequesting)
            
            Button {
                openAppSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                    Text("Open iOS Settings")
                        .font(.forma(.body, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .background(themeManager.currentTheme.primaryColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var footerNote: some View {
        Text("StuCo reads your Reminders to help you stay on top of tasks. We never modify or delete anything without your action.")
            .font(.forma(.footnote))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
    
    private func refreshAuthorizationStatus() {
        let status = calendarSyncManager.checkRemindersAuthorizationStatus()
        switch status {
        case .fullAccess:
            isAuthorized = true
            statusText = "Allowed"
        case .denied:
            isAuthorized = false
            statusText = "Denied"
        case .restricted:
            isAuthorized = false
            statusText = "Restricted"
        case .notDetermined:
            isAuthorized = false
            statusText = "Not Determined"
        @unknown default:
            isAuthorized = false
            statusText = "Unknown"
        }
    }
    
    private func requestReminders() {
        isRequesting = true
        Task {
            await calendarSyncManager.requestRemindersAccess()
            await MainActor.run {
                isRequesting = false
                refreshAuthorizationStatus()
                if isEnabled && isAuthorized {
                    Task { await calendarSyncManager.fetchRemindersAndUpdatePublishedProperty() }
                }
            }
        }
    }
    
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}