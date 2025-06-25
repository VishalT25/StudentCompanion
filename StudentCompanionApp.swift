import SwiftUI

@main
struct StudentCompanionApp: App {
    @StateObject private var eventViewModel: EventViewModel
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var notificationManager = NotificationManager.shared
    
    @StateObject private var calendarSyncManager: CalendarSyncManager
    
    init() {
        let syncManager = CalendarSyncManager()
        _calendarSyncManager = StateObject(wrappedValue: syncManager)
        _eventViewModel = StateObject(wrappedValue: EventViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventViewModel)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .environmentObject(calendarSyncManager)
                .preferredColorScheme(.light)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    notificationManager.checkAuthorizationStatus()
                }
        }
    }
}
