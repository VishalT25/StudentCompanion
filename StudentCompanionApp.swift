import SwiftUI

@main
struct StudentCompanionApp: App {
    @StateObject private var eventViewModel = EventViewModel()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventViewModel)
                .environmentObject(themeManager)
        }
    }
}
