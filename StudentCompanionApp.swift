import SwiftUI

@main
struct StudentCompanionApp: App {
    @StateObject private var eventViewModel = EventViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventViewModel)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .preferredColorScheme(.light)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    notificationManager.checkAuthorizationStatus()
                }
        }
    }
}
