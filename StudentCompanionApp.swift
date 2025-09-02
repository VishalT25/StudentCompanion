import SwiftUI

@main
struct StudentCompanionApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var realtimeSyncManager = RealtimeSyncManager.shared
    @StateObject private var eventViewModel = EventViewModel()
    @StateObject private var scheduleManager = ScheduleManager()
    @StateObject private var academicCalendarManager = AcademicCalendarManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(supabaseService)
                .environmentObject(realtimeSyncManager)
                .environmentObject(eventViewModel)
                .environmentObject(scheduleManager)
                .environmentObject(academicCalendarManager)
                .onAppear {
                    // Initialize real-time sync when app starts
                    Task {
                        await realtimeSyncManager.initialize()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Cleanup real-time connections when app terminates
                    Task {
                        await realtimeSyncManager.cleanup()
                    }
                }
        }
    }
}