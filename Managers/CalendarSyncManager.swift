import Foundation
import EventKit
import Combine

@MainActor
class CalendarSyncManager: ObservableObject {
    private let eventStore = EKEventStore()

    @Published var isCalendarAccessGranted: Bool = false
    @Published var isRemindersAccessGranted: Bool = false
    @Published var appleCalendarEvents: [EKEvent] = []
    @Published var appleReminders: [EKReminder] = []

    init() {
        if self.checkCalendarAuthorizationStatus() == .fullAccess || self.checkCalendarAuthorizationStatus() == .writeOnly {
            Task {
                await fetchEventsAndUpdatePublishedProperty()
            }
        }
        if self.checkRemindersAuthorizationStatus() == .fullAccess {
            Task {
                await fetchRemindersAndUpdatePublishedProperty()
            }
        }
    }

    func requestCalendarAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            self.isCalendarAccessGranted = granted
            if granted {
                print("Calendar access granted.")
                await fetchEventsAndUpdatePublishedProperty()
            } else {
                print("Calendar access denied.")
                self.appleCalendarEvents = []
            }
        } catch {
            print("Error requesting calendar access: \(error.localizedDescription)")
            self.isCalendarAccessGranted = false
            self.appleCalendarEvents = []
        }
    }

    func checkCalendarAuthorizationStatus() -> EKAuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .writeOnly:
            self.isCalendarAccessGranted = true
            print("Calendar access is granted.")
        case .denied, .restricted:
            self.isCalendarAccessGranted = false
            print("Calendar access is denied or restricted.")
        case .notDetermined:
            self.isCalendarAccessGranted = false
            print("Calendar access not yet requested.")
        @unknown default:
            self.isCalendarAccessGranted = false
            print("Unknown calendar authorization status.")
        }
        return status
    }

    func requestRemindersAccess() async {
         do {
            let granted = try await eventStore.requestFullAccessToReminders()
            self.isRemindersAccessGranted = granted
            if granted {
                print("Reminders access granted.")
                await fetchRemindersAndUpdatePublishedProperty()
            } else {
                print("Reminders access denied.")
                self.appleReminders = []
            }
        } catch {
            print("Error requesting reminders access: \(error.localizedDescription)")
            self.isRemindersAccessGranted = false
            self.appleReminders = []
        }
    }

    func checkRemindersAuthorizationStatus() -> EKAuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .fullAccess:
            self.isRemindersAccessGranted = true
            print("Reminders access is granted.")
        case .denied, .restricted:
            self.isRemindersAccessGranted = false
            print("Reminders access is denied or restricted.")
        case .notDetermined:
            self.isRemindersAccessGranted = false
            print("Reminders access not yet requested.")
        @unknown default:
            self.isRemindersAccessGranted = false
            print("Unknown reminders authorization status.")
        }
        return status
    }
    
    // MARK: - Fetching
    func fetchEventsAndUpdatePublishedProperty() async {
        guard UserDefaults.standard.bool(forKey: "appleCalendarIntegrationEnabled") else {
            print("Apple Calendar integration is disabled by user toggle. Skipping fetch.")
            // Optionally clear existing events if the design requires it when toggle is off
            // However, the current design clears them upon user confirmation in SettingsView.
            // self.appleCalendarEvents = []
            return
        }

        guard isCalendarAccessGranted else {
            print("Cannot fetch events, calendar access not granted.")
            self.appleCalendarEvents = []
            return
        }
        
        let calendars = eventStore.calendars(for: .event)
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let oneYearLater = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        
        let predicate = eventStore.predicateForEvents(withStart: oneMonthAgo, end: oneYearLater, calendars: calendars.filter { !$0.title.contains("Holidays") })
        
        let events = eventStore.events(matching: predicate)
        print("Fetched \(events.count) calendar events.")
        self.appleCalendarEvents = events
    }
    
    func fetchRemindersAndUpdatePublishedProperty() async {
        guard UserDefaults.standard.bool(forKey: "appleRemindersIntegrationEnabled") else {
            print("Apple Reminders integration is disabled by user toggle. Skipping fetch.")
            // self.appleReminders = []
            return
        }

        guard isRemindersAccessGranted else {
            print("Cannot fetch reminders, reminders access not granted.")
            self.appleReminders = []
            return
        }
        
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        
        let fetchedReminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        print("Fetched \(fetchedReminders.count) reminders.")
        self.appleReminders = fetchedReminders
    }
    
    func clearAppleCalendarEventsData() {
        self.appleCalendarEvents = []
        print("Cleared cached Apple Calendar events in CalendarSyncManager.")
    }

    func clearAppleRemindersData() {
        self.appleReminders = []
        print("Cleared cached Apple Reminders data in CalendarSyncManager.")
    }
}
