import SwiftUI

struct AppleCalendarSettingsView: View {
    @EnvironmentObject var calendarSyncManager: CalendarSyncManager
    
    var body: some View {
        Form {
            Section(header: Text("Calendar Access")) {
                Button(action: {
                    Task {
                        await calendarSyncManager.requestCalendarAccess()
                    }
                }) {
                    Text("Request Calendar Access")
                }
            }
            
            Section(header: Text("Reminders Access")) {
                Button(action: {
                    Task {
                        await calendarSyncManager.requestRemindersAccess()
                    }
                }) {
                    Text("Request Reminders Access")
                }
            }
        }
        .navigationTitle("Apple Calendar & Reminders")
    }
}