import SwiftUI
import MessageUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var realtimeSyncManager: RealtimeSyncManager
    
    @State private var showingThemeSelector = false
    @State private var showingNotificationSettings = false
    @State private var showingGoogleCalendarSettings = false
    @State private var showingAppleCalendarSettings = false
    @State private var showingAcademicCalendarManagement = false
    @State private var showingAuthSheet = false
    @State private var showingAccountManagement = false
    @State private var result: Result<MFMailComposeResult, Error>? = nil
    @State private var isShowingMailView = false
    @State private var showingFeedbackAlert = false
    @State private var showingSyncStats = false
    @State private var syncStats: SyncStats?
    
    var body: some View {
        NavigationView {
            List {
                // Account
                Section(header: Text("Account").font(.forma(.footnote, weight: .medium))) {
                    if supabaseService.isAuthenticated {
                        Button {
                            showingAccountManagement = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(subscriptionGradient)
                                        .frame(width: 44, height: 44)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(displayName)
                                            .font(.forma(.body, weight: .semibold))
                                        
                                        // Subscription Badge
                                        Text(subscriptionDisplayName)
                                            .font(.forma(.caption, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(subscriptionColor.opacity(0.2))
                                            .foregroundColor(subscriptionColor)
                                            .clipShape(Capsule())
                                    }
                                    
                                    Text(supabaseService.currentUser?.email ?? "")
                                        .font(.forma(.subheadline))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    if let subscription = supabaseService.userSubscription,
                                       subscription.isActive && subscription.subscriptionTier != .free {
                                        if let endDate = subscription.subscriptionEndDate {
                                            Text("Active until \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.forma(.caption))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Lifetime Access")
                                                .font(.forma(.caption))
                                                .foregroundColor(subscriptionColor)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.forma(.footnote, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            showingAuthSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Connect Your Account")
                                        .font(.forma(.body, weight: .semibold))
                                    Text("Sync your data across devices")
                                        .font(.forma(.subheadline))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.forma(.footnote, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // NEW: Sync & Data Section
                Section {
                    // Real-time Sync Status
                    HStack {
                        Image(systemName: "cloud.bolt")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Real-time Sync")
                                .font(.forma(.body))
                            
                            Text(realtimeSyncManager.syncStatus.displayName)
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        SyncStatusIndicator()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Tapping opens sync status details
                    }
                    
                    // Manual Sync Button
                    Button(action: {
                        Task {
                            await realtimeSyncManager.refreshAllData()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .frame(width: 24, height: 24)
                            
                            Text("Refresh All Data")
                                .font(.forma(.body))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if realtimeSyncManager.syncStatus.isActive {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(realtimeSyncManager.syncStatus.isActive)
                    
                    if let lastSync = realtimeSyncManager.lastSyncTime {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last Sync")
                                    .font(.forma(.body))
                                
                                Text(lastSync.formatted(.relative(presentation: .numeric)))
                                    .font(.forma(.caption))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                } header: {
                    Text("Sync & Data")
                } footer: {
                    Text("Real-time synchronization keeps your data updated across all devices. Pending operations: \(realtimeSyncManager.pendingSyncCount)")
                }
                
                // Data Sync (only show when authenticated)
                if supabaseService.isAuthenticated {
                    Section(header: Text("Data Sync").font(.forma(.footnote, weight: .medium))) {
                        // Sync Status
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(syncStatusColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sync Status")
                                    .font(.forma(.body, weight: .semibold))
                                Text(syncStatusText)
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if realtimeSyncManager.syncStatus.isActive {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        // Manual Sync Button
                        Button {
                            Task {
                                await realtimeSyncManager.refreshAllData()
                            }
                        } label: {
                            SettingsRow(
                                icon: "arrow.triangle.2.circlepath",
                                iconColor: .blue,
                                title: "Sync Now",
                                subtitle: "Update data from cloud"
                            )
                        }
                        .disabled(realtimeSyncManager.syncStatus.isActive)
                        
                        // Sync Statistics
                        Button {
                            showingSyncStats = true
                            Task {
                                syncStats = await supabaseService.getSyncStats()
                            }
                        } label: {
                            SettingsRow(
                                icon: "chart.bar.fill",
                                iconColor: .green,
                                title: "Sync Statistics",
                                subtitle: "View cloud data summary"
                            )
                        }
                    }
                }
                
                // Appearance
                Section(header: Text("Appearance").font(.forma(.footnote, weight: .medium))) {
                    Button {
                        showingThemeSelector = true
                    } label: {
                        SettingsRow(
                            icon: "paintbrush.pointed", 
                            iconColor: themeManager.currentTheme.primaryColor, 
                            title: "Theme & Appearance", 
                            subtitle: "\(themeManager.currentTheme.rawValue) • \(themeManager.appearanceMode.displayName)"
                        )
                    }
                    
                    Menu {
                        ForEach(AppearanceMode.allCases) { mode in
                            Button {
                                themeManager.setAppearanceMode(mode)
                            } label: {
                                HStack {
                                    Text(mode.displayName)
                                    if themeManager.appearanceMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        SettingsRow(
                            icon: "circle.righthalf.filled", 
                            iconColor: .orange, 
                            title: "Appearance Mode", 
                            subtitle: themeManager.appearanceMode.displayName
                        )
                    }
                }
                
                // Notifications
                Section(header: Text("Notifications").font(.forma(.footnote, weight: .medium))) {
                    Button {
                        showingNotificationSettings = true
                    } label: {
                        SettingsRow(icon: "bell.badge", iconColor: .orange, title: "Notification Settings", subtitle: "Manage alerts and reminders")
                    }
                }
                
                // Calendar Integration
                Section(header: Text("Calendar Integration").font(.forma(.footnote, weight: .medium))) {
                    Button {
                        showingGoogleCalendarSettings = true
                    } label: {
                        SettingsRow(icon: "globe", iconColor: .blue, title: "Google Calendar", subtitle: "Sync with Google services")
                    }
                    
                    Button {
                        showingAppleCalendarSettings = true
                    } label: {
                        SettingsRow(icon: "applelogo", iconColor: .primary, title: "Apple Calendar", subtitle: "Native iOS integration")
                    }
                    
                    Button {
                        showingAcademicCalendarManagement = true
                    } label: {
                        SettingsRow(icon: "graduationcap.fill", iconColor: .purple, title: "Academic Calendars", subtitle: "School schedule management")
                    }
                }
                
                // Support & Feedback
                Section(header: Text("Support & Feedback").font(.forma(.footnote, weight: .medium))) {
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            isShowingMailView = true
                        } else {
                            showingFeedbackAlert = true
                        }
                    } label: {
                        SettingsRow(icon: "envelope.fill", iconColor: .green, title: "Send Feedback", subtitle: "Help us improve the app")
                    }
                    
                    Button {
                        guard let url = URL(string: "https://apps.apple.com/app/id123456789") else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        SettingsRow(icon: "star.fill", iconColor: .yellow, title: "Rate on App Store", subtitle: "Share your experience")
                    }
                }
                
                // About
                Section(header: Text("About").font(.forma(.footnote, weight: .medium))) {
                    HStack {
                        Text("StuCo")
                            .font(.forma(.body, weight: .semibold))
                        Spacer()
                        Text("Version 1.0.0")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                    }
                    Text("Your intelligent student companion for academic success.")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAuthSheet) {
                AuthenticationSheet()
                    .environmentObject(supabaseService)
            }
            .sheet(isPresented: $showingAccountManagement) {
                AccountManagementView()
                    .environmentObject(supabaseService)
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingThemeSelector) {
                ThemeSelectorView()
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
            .sheet(isPresented: $showingGoogleCalendarSettings) {
                GoogleCalendarSettingsView()
            }
            .sheet(isPresented: $showingAppleCalendarSettings) {
                AppleCalendarSettingsView()
            }
            .sheet(isPresented: $showingAcademicCalendarManagement) {
                AcademicCalendarManagementView()
            }
            .sheet(isPresented: $isShowingMailView) {
                MailView(result: $result)
            }
            .sheet(isPresented: $showingSyncStats) {
                SyncStatsView(syncStats: $syncStats)
                    .environmentObject(themeManager)
            }
            .alert("Mail Not Available", isPresented: $showingFeedbackAlert) {
                Button("OK") { }
            } message: {
                Text("Mail is not available on this device. Please configure mail in Settings.")
                    .font(.forma(.body))
            }
        }
        .onAppear {
            Task {
                await supabaseService.refreshSubscription()
            }
        }
    }
    
    // MARK: - Computed Properties for Sync Status
    
    private var syncStatusColor: Color {
        if realtimeSyncManager.syncStatus.isActive {
            return .orange
        } else if case .error(_) = realtimeSyncManager.syncStatus {
            return .red
        } else if supabaseService.isAuthenticated {
            return .green
        } else {
            return .gray
        }
    }
    
    private var syncStatusIcon: String {
        if realtimeSyncManager.syncStatus.isActive {
            return "arrow.triangle.2.circlepath"
        } else if case .error(_) = realtimeSyncManager.syncStatus {
            return "exclamationmark.triangle.fill"
        } else if supabaseService.isAuthenticated {
            return "checkmark.circle.fill"
        } else {
            return "wifi.slash"
        }
    }
    
    private var syncStatusText: String {
        if realtimeSyncManager.syncStatus.isActive {
            return "Syncing..."
        } else if case let .error(error) = realtimeSyncManager.syncStatus {
            return "Sync failed: \(error.localizedDescription)"
        } else if let lastSync = realtimeSyncManager.lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last sync \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else if supabaseService.isAuthenticated {
            return "Ready to sync"
        } else {
            return "Sign in to sync"
        }
    }
    
    // MARK: - Display Properties
    
    private var displayName: String {
        supabaseService.userProfile?.displayName ?? "User"
    }
    
    // MARK: - Subscription Properties
    
    private var subscriptionColor: Color {
        supabaseService.userSubscription?.subscriptionTier.color ?? .gray
    }
    
    private var subscriptionIcon: String {
        supabaseService.userSubscription?.subscriptionTier.icon ?? "person"
    }
    
    private var subscriptionDisplayName: String {
        supabaseService.userSubscription?.subscriptionTier.displayName ?? "Free"
    }
    
    private var subscriptionGradient: LinearGradient {
        let tier = supabaseService.userSubscription?.subscriptionTier ?? .free
        switch tier {
        case .free:
            return LinearGradient(colors: [.gray.opacity(0.7), .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .premium:
            return LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .leading, endPoint: .trailing)
        case .founder:
            return LinearGradient(colors: [.purple.opacity(0.8), .purple, .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Account Management View

struct AccountManagementView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingChangePassword = false
    @State private var showingChangeEmail = false
    @State private var showingEditDisplayName = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(subscriptionGradient)
                                .frame(width: 64, height: 64)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(displayName)
                                    .font(.forma(.title3, weight: .bold))
                                
                                Text(subscriptionDisplayName)
                                    .font(.forma(.caption, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(subscriptionColor.opacity(0.2))
                                    .foregroundColor(subscriptionColor)
                                    .clipShape(Capsule())
                            }
                            
                            Text(supabaseService.currentUser?.email ?? "")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                            
                            if let subscription = supabaseService.userSubscription {
                                Text("Member since \(memberSinceDate(subscription.created_at))")
                                    .font(.forma(.caption))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Account Settings
                Section(header: Text("Account Settings").font(.forma(.footnote, weight: .medium))) {
                    Button {
                        showingEditDisplayName = true
                    } label: {
                        SettingsRow(
                            icon: "person.fill",
                            iconColor: .purple,
                            title: "Display Name",
                            subtitle: displayName
                        )
                    }
                    
                    Button {
                        showingChangeEmail = true
                    } label: {
                        SettingsRow(
                            icon: "envelope.fill",
                            iconColor: .blue,
                            title: "Change Email",
                            subtitle: "Update your email address"
                        )
                    }
                    
                    Button {
                        showingChangePassword = true
                    } label: {
                        SettingsRow(
                            icon: "key.fill",
                            iconColor: .orange,
                            title: "Change Password",
                            subtitle: "Update your password"
                        )
                    }
                }
                
                // Subscription Section
                Section(header: Text("Subscription").font(.forma(.footnote, weight: .medium))) {
                    if let subscription = supabaseService.userSubscription {
                        // Current Plan
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: subscription.subscriptionTier.icon)
                                    .foregroundColor(subscription.subscriptionTier.color)
                                Text("Current Plan: \(subscription.subscriptionTier.displayName)")
                                    .font(.forma(.body, weight: .semibold))
                                Spacer()
                            }
                            
                            if subscription.isActive && subscription.subscriptionTier != .free {
                                if let endDate = subscription.subscriptionEndDate {
                                    Text("Renews on \(endDate.formatted(date: .long, time: .omitted))")
                                        .font(.forma(.subheadline))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Lifetime Access")
                                        .font(.forma(.subheadline))
                                        .foregroundColor(subscriptionColor)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Benefits
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plan Benefits")
                                .font(.forma(.subheadline, weight: .semibold))
                            
                            ForEach(subscription.subscriptionTier.benefits, id: \.self) { benefit in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.forma(.caption))
                                    Text(benefit)
                                        .font(.forma(.caption))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Upgrade/Manage Button
                        Button {
                            openSubscriptionWebsite()
                        } label: {
                            HStack {
                                Image(systemName: subscription.subscriptionTier == .free ? "arrow.up.circle.fill" : "gear")
                                Text(subscription.subscriptionTier == .free ? "Upgrade Plan" : "Manage Subscription")
                                    .font(.forma(.body, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Website Link
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To manage your subscription, billing, or upgrade your plan, please visit the StuCo website.")
                            .font(.forma(.footnote))
                            .foregroundColor(.secondary)
                        
                        Button("Visit StuCo Website") {
                            openSubscriptionWebsite()
                        }
                        .font(.forma(.footnote, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    .padding(.vertical, 4)
                }
                
                // Danger Zone
                Section(header: Text("Account Actions").font(.forma(.footnote, weight: .medium))) {
                    Button(role: .destructive) {
                        Task {
                            await supabaseService.signOut()
                            dismiss()
                        }
                    } label: {
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            iconColor: .red,
                            title: "Sign Out",
                            subtitle: "Sign out of your account"
                        )
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingChangeEmail) {
            ChangeEmailView()
                .environmentObject(supabaseService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
                .environmentObject(supabaseService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingEditDisplayName) {
            EditDisplayNameView()
                .environmentObject(supabaseService)
                .environmentObject(themeManager)
        }
        .onAppear {
            Task {
                await supabaseService.refreshSubscription()
            }
        }
    }
    
    private func openSubscriptionWebsite() {
        guard let url = URL(string: "https://stuco.lovable.app") else { return }
        UIApplication.shared.open(url)
    }
    
    private func memberSinceDate(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return "Unknown"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    // MARK: - Computed Properties
    
    private var displayName: String {
        supabaseService.userProfile?.displayName ?? "User"
    }
    
    // MARK: - Subscription Properties
    
    private var subscriptionColor: Color {
        supabaseService.userSubscription?.subscriptionTier.color ?? .gray
    }
    
    private var subscriptionIcon: String {
        supabaseService.userSubscription?.subscriptionTier.icon ?? "person"
    }
    
    private var subscriptionDisplayName: String {
        supabaseService.userSubscription?.subscriptionTier.displayName ?? "Free"
    }
    
    private var subscriptionGradient: LinearGradient {
        let tier = supabaseService.userSubscription?.subscriptionTier ?? .free
        switch tier {
        case .free:
            return LinearGradient(colors: [.gray.opacity(0.7), .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .premium:
            return LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .founder:
            return LinearGradient(colors: [.purple.opacity(0.8), .purple, .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Edit Display Name View

struct EditDisplayNameView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Display Name")) {
                    TextField("Enter display name", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                
                Section(footer: Text("This is how your name will appear in the app. You can change it anytime.")) {
                    EmptyView()
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.forma(.footnote))
                    }
                }
                
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.forma(.footnote))
                    }
                }
                
                Section {
                    Button {
                        updateDisplayName()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Update Display Name")
                                .font(.forma(.body, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    .disabled(isLoading || displayName.isEmpty || displayName == currentDisplayName)
                }
            }
            .navigationTitle("Edit Display Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            displayName = supabaseService.userProfile?.displayName ?? ""
        }
    }
    
    private var currentDisplayName: String {
        supabaseService.userProfile?.displayName ?? ""
    }
    
    private func updateDisplayName() {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            let result = await supabaseService.updateProfile(displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Display name updated successfully!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Change Email View

struct ChangeEmailView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var newEmail = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Email Address")) {
                    TextField("Enter new email", text: $newEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.forma(.footnote))
                            .foregroundColor(.red)
                    }
                }
                
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .font(.forma(.footnote))
                            .foregroundColor(.green)
                    }
                }
                
                Section {
                    Button {
                        updateEmail()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.primary)
                            }
                            Text("Update Email")
                                .font(.forma(.body, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || newEmail.isEmpty)
                }
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        dismiss() 
                    }
                    .font(.forma(.body))
                }
            }
        }
    }
    
    private func updateEmail() {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            let result = await supabaseService.updateEmail(newEmail)
            
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Email updated successfully! Please check your new email for verification."
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Password")) {
                    SecureField("Enter new password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)
                }
                
                Section(footer: Text("Password must be at least 8 characters with uppercase, lowercase, numbers, and special characters.")) {
                    EmptyView()
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.forma(.footnote))
                    }
                }
                
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.forma(.footnote))
                    }
                }
                
                Section {
                    Button {
                        updatePassword()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.primary)
                            }
                            Text("Update Password")
                                .font(.forma(.body, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updatePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            let result = await supabaseService.updatePassword(newPassword)
            
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Password updated successfully!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Sync Statistics View

struct SyncStatsView: View {
    @Binding var syncStats: SyncStats?
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if let stats = syncStats {
                    Section(header: Text("Cloud Data Summary")) {
                        StatRow(label: "Schedules", count: stats.schedulesCount, icon: "calendar", color: .blue)
                        StatRow(label: "Courses", count: stats.coursesCount, icon: "book.closed", color: .purple)
                        StatRow(label: "Assignments", count: stats.assignmentsCount, icon: "doc.text", color: .orange)
                        StatRow(label: "Events", count: stats.eventsCount, icon: "bell", color: .green)
                        StatRow(label: "Categories", count: stats.categoriesCount, icon: "tag", color: .red)
                    }
                    
                    Section(header: Text("Total")) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                            }
                            Text("Total Items")
                                .font(.forma(.body, weight: .semibold))
                            Spacer()
                            Text("\(stats.totalItems)")
                                .font(.forma(.title3, weight: .bold))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                } else {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Loading statistics...")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Sync Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            Text(label)
                .font(.forma(.body, weight: .medium))
            Spacer()
            Text("\(count)")
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    
    init(icon: String, iconColor: Color, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)
                    .font(.forma(.body, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .foregroundColor(.secondary)
                        .font(.forma(.subheadline))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.forma(.footnote, weight: .semibold))
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Authentication Sheet

struct AuthenticationSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 72, height: 72)
                            Image(systemName: "icloud")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.forma(.title2, weight: .bold))
                        Text(isSignUp ? "Join StuCo to sync your data across devices" : "Sign in to access your synced data")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        CustomTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            icon: "envelope"
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        CustomSecureField(
                            title: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            icon: "lock"
                        )
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.forma(.footnote))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            if isSignUp { signUp() } else { signIn() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                }
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.forma(.headline))
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        
                        Button {
                            isSignUp.toggle()
                            errorMessage = ""
                        } label: {
                            HStack {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.secondary)
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .fontWeight(.semibold)
                            }
                            .font(.forma(.subheadline))
                        }
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        dismiss() 
                    }
                    .font(.forma(.body))
                }
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        Task {
            let result = await supabaseService.signIn(email: email, password: password)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success: dismiss()
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = ""
        Task {
            let result = await supabaseService.signUp(email: email, password: password)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success: dismiss()
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Custom Secure Field

struct CustomSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            SecureField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
        }
    }
}

// MARK: - Mail View

struct MailView: UIViewControllerRepresentable {
    @Binding var result: Result<MFMailComposeResult, Error>?
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var result: Result<MFMailComposeResult, Error>?
        
        init(result: Binding<Result<MFMailComposeResult, Error>?>) {
            _result = result
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer { controller.dismiss(animated: true) }
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            self.result = .success(result)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(result: $result) }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(["support@stucoplanner.com"])
        mailComposer.setSubject("StuCo Feedback")
        mailComposer.setMessageBody("Please share your feedback here...", isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: UIViewControllerRepresentableContext<MailView>) {}
}

// MARK: - Sync Status Indicator

struct SyncStatusIndicator: View {
    @EnvironmentObject var realtimeSyncManager: RealtimeSyncManager
    
    var body: some View {
        HStack {
            if realtimeSyncManager.syncStatus.isActive {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(ThemeManager())
            .environmentObject(NotificationManager.shared)
    }
}