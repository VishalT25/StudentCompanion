import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var pendingNotificationsCount = 0
    
    var body: some View {
        NavigationView {
            List {
                Section("Notification Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(notificationManager.authorizationStatusText)
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                    }
                    
                    if !notificationManager.isAuthorized {
                        Button("Enable Notifications") {
                            notificationManager.openNotificationSettings()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Notification Settings") {
                    HStack {
                        Text("Notifications Enabled")
                        Spacer()
                        // FIXED: Use the property directly, not as a binding for display
                        Text(notificationManager.isAuthorized ? "Yes" : "No")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                    }
                    
                    if notificationManager.isAuthorized {
                        HStack {
                            Text("Pending Notifications")
                            Spacer()
                            Text("\(pendingNotificationsCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Refresh Pending Count") {
                            Task {
                                pendingNotificationsCount = await notificationManager.getPendingNotificationsCount()
                            }
                        }
                        
                        Button("Clear All Notifications") {
                            notificationManager.cancelAllNotifications()
                            pendingNotificationsCount = 0
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Debug") {
                    Button("Check Authorization Status") {
                        notificationManager.checkAuthorizationStatus()
                    }
                    
                    Button("Request Authorization") {
                        Task {
                            await notificationManager.requestAuthorization()
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .onAppear {
                notificationManager.checkAuthorizationStatus()
                Task {
                    pendingNotificationsCount = await notificationManager.getPendingNotificationsCount()
                }
            }
        }
    }
}
