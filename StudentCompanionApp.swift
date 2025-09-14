import SwiftUI
import WidgetKit

@main
struct StudentCompanionApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var realtimeSyncManager = RealtimeSyncManager.shared
    @StateObject private var eventViewModel = EventViewModel()
    @StateObject private var scheduleManager = ScheduleManager()
    @StateObject private var academicCalendarManager = AcademicCalendarManager()
    @StateObject private var unifiedCourseManager = UnifiedCourseManager()
    @StateObject private var eventOperationsManager = EventOperationsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(supabaseService)
                .environmentObject(realtimeSyncManager)
                .environmentObject(eventViewModel)
                .environmentObject(scheduleManager)
                .environmentObject(academicCalendarManager)
                .environmentObject(unifiedCourseManager)
                .environmentObject(eventOperationsManager)
                .onAppear {
                    // Initialize real-time sync when app starts
                    Task {
                        print("📱 App: Starting RealtimeSyncManager initialization")
                        await realtimeSyncManager.initialize()
                        print("📱 App: RealtimeSyncManager initialization completed")
                    }
                    
                    // Set up cross-manager relationships
                    setupManagerRelationships()
                    
                    print("📱 App: Managers initialized:")
                    print("   - scheduleManager: \(scheduleManager.scheduleCollections.count) schedules")
                    print("   - academicCalendarManager: \(academicCalendarManager.academicCalendars.count) calendars") 
                    print("   - unifiedCourseManager: \(unifiedCourseManager.courses.count) courses")
                    print("   - eventOperationsManager: \(eventOperationsManager.eventCount) events")
                    print("   - eventViewModel: \(eventViewModel.events.count) events")
                    
                    ScheduleWidgetBridge.pushTodaySnapshot(scheduleManager: scheduleManager)
                }

                .onChange(
                    of: scheduleManager.scheduleCollections.map {
                        "\($0.id.uuidString)|\($0.lastModified.timeIntervalSince1970)|\($0.scheduleItems.count)|\($0.enhancedScheduleItems.count)"
                    }
                ) { _, _ in
                    ScheduleWidgetBridge.pushTodaySnapshot(scheduleManager: scheduleManager)
                }

                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    ScheduleWidgetBridge.pushTodaySnapshot(scheduleManager: scheduleManager)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    ScheduleWidgetBridge.pushTodaySnapshot(scheduleManager: scheduleManager)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Cleanup real-time connections when app terminates
                    Task {
                        await realtimeSyncManager.cleanup()
                    }
                }
        }
    }
    
    private func setupManagerRelationships() {
        // Connect course manager to schedule manager for schedule item synchronization
        unifiedCourseManager.setScheduleManager(scheduleManager)
        scheduleManager.setCourseManager(unifiedCourseManager)
    }
}