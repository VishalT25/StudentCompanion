import SwiftUI
import GoogleSignIn

@main
struct StuCoApp: App {
    @StateObject private var eventViewModel: EventViewModel
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var googleCalendarManager = GoogleCalendarManager() // We should review if this is still needed later
    @StateObject private var calendarSyncManager: CalendarSyncManager
    @StateObject private var academicCalendarManager = AcademicCalendarManager() // NEW
    
    // Use ObservedObject for singleton, not StateObject
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    init() {
        let syncManager = CalendarSyncManager()
        _calendarSyncManager = StateObject(wrappedValue: syncManager)
        _eventViewModel = StateObject(wrappedValue: EventViewModel())

        // Make sure to replace "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" with your actual client ID
        // And ensure you have added the necessary URL Scheme to your project's Info settings.
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            fatalError("Google Client ID (GIDClientID) not found in Info.plist. Please add it.")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventViewModel)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .environmentObject(calendarSyncManager)
                .environmentObject(googleCalendarManager)
                .environmentObject(academicCalendarManager) // NEW
                .preferredColorScheme(.light)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    notificationManager.checkAuthorizationStatus()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}