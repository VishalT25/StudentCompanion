import SwiftUI

@main
struct StudentCompanionApp: App {
    @StateObject private var eventViewModel = EventViewModel()
    
    var body: some Scene {
        WindowGroup {
            SplashLoadingView()
                .environmentObject(eventViewModel)
        }
    }
}
