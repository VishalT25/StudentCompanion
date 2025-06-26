import Foundation
import EventKit
import Combine
import GoogleSignIn
import GoogleAPIClientForREST_Calendar

@MainActor
class CalendarSyncManager: ObservableObject {
    private let eventStore = EKEventStore()
    private let googleCalendarService = GTLRCalendarService()

    @Published var isCalendarAccessGranted: Bool = false
    @Published var isRemindersAccessGranted: Bool = false
    @Published var appleCalendarEvents: [EKEvent] = []
    @Published var appleReminders: [EKReminder] = []
    @Published var signedInGoogleUser: GIDGoogleUser?
    @Published var isGoogleCalendarAccessGranted: Bool = false
    @Published var googleCalendars: [GTLRCalendar_CalendarListEntry] = []
    @Published var googleCalendarEvents: [GTLRCalendar_Event] = []
    @Published var selectedGoogleCalendarIDs: [String] = [] {
        didSet {
            UserDefaults.standard.set(selectedGoogleCalendarIDs, forKey: "selectedGoogleCalendarIDs")
            if isGoogleCalendarAccessGranted {
                Task {
                    await fetchGoogleCalendarEvents()
                }
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

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
        restoreGoogleSignIn()
        loadSelectedGoogleCalendarIDs()
    }

    private func loadSelectedGoogleCalendarIDs() {
        self.selectedGoogleCalendarIDs = UserDefaults.standard.stringArray(forKey: "selectedGoogleCalendarIDs") ?? []
    }

    func signInWithGoogle(presentingViewController: UIViewController) {
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] signInResult, error in
            guard let self else { return }
            if let error {
                print("Google Sign-In error: \(error.localizedDescription)")
                self.isGoogleCalendarAccessGranted = false
                return
            }
            guard let user = signInResult?.user else {
                print("Google Sign-In error: User not found.")
                self.isGoogleCalendarAccessGranted = false
                return
            }

            print("Google Sign-In successful for user: \(user.profile?.name ?? "Unknown")")
            self.signedInGoogleUser = user
            
            let grantedScopes = user.grantedScopes
            let calendarScope = kGTLRAuthScopeCalendar
            if grantedScopes?.contains(calendarScope) == true {
                print("Google Calendar scope granted.")
                self.isGoogleCalendarAccessGranted = true
                self.googleCalendarService.authorizer = user.fetcherAuthorizer
                Task {
                    await self.fetchGoogleCalendarList()
                    await self.fetchGoogleCalendarEvents()
                }
            } else {
                print("Google Calendar scope NOT granted. Requesting...")
                let additionalScopes = [kGTLRAuthScopeCalendar]
                user.addScopes(additionalScopes, presenting: presentingViewController) { [weak self] signInResult, error in
                    guard let self else { return }
                     if let error {
                        print("Error adding Google Calendar scope: \(error.localizedDescription)")
                        self.isGoogleCalendarAccessGranted = false
                        return
                    }
                    guard let updatedUser = signInResult?.user,
                          let grantedScopes = updatedUser.grantedScopes,
                          grantedScopes.contains(kGTLRAuthScopeCalendar) else {
                        print("Google Calendar scope still not granted after request.")
                        self.isGoogleCalendarAccessGranted = false
                        return
                    }
                    print("Google Calendar scope granted after additional request.")
                    self.signedInGoogleUser = updatedUser
                    self.isGoogleCalendarAccessGranted = true
                    self.googleCalendarService.authorizer = updatedUser.fetcherAuthorizer
                    Task {
                        await self.fetchGoogleCalendarList()
                        await self.fetchGoogleCalendarEvents()
                    }
                }
            }
        }
    }

    func restoreGoogleSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            guard let self else { return }
            if let error {
                print("Google Restore Sign-In error: \(error.localizedDescription)")
                self.isGoogleCalendarAccessGranted = false
                return
            }
            guard let user else {
                print("No previous Google Sign-In found.")
                self.isGoogleCalendarAccessGranted = false
                return
            }

            print("Restored Google Sign-In for user: \(user.profile?.name ?? "Unknown")")
            self.signedInGoogleUser = user
            
            let grantedScopes = user.grantedScopes
            let calendarScope = kGTLRAuthScopeCalendar
            if grantedScopes?.contains(calendarScope) == true {
                self.isGoogleCalendarAccessGranted = true
                self.googleCalendarService.authorizer = user.fetcherAuthorizer
                Task {
                    await self.fetchGoogleCalendarList()
                    await self.fetchGoogleCalendarEvents()
                }
            } else {
                print("Restored user does not have calendar scope.")
                self.isGoogleCalendarAccessGranted = false
            }
        }
    }

    func signOutFromGoogle() {
        GIDSignIn.sharedInstance.signOut()
        self.signedInGoogleUser = nil
        self.isGoogleCalendarAccessGranted = false
        self.googleCalendars = []
        self.googleCalendarEvents = []
        self.googleCalendarService.authorizer = nil
        print("Signed out from Google.")
    }

    func fetchGoogleCalendarList() async {
        guard isGoogleCalendarAccessGranted, let authorizer = googleCalendarService.authorizer else {
            print("CalendarSyncManager: Cannot fetch Google Calendar list: Not signed in or no authorizer. isGoogleCalendarAccessGranted = \(isGoogleCalendarAccessGranted), authorizer is nil = \(googleCalendarService.authorizer == nil)")
            self.googleCalendars = []
            return
        }
        
        print("CalendarSyncManager: Fetching Google Calendar list...")
        let query = GTLRCalendarQuery_CalendarListList.query()
        query.showHidden = true
        query.showDeleted = false
        
        print("CalendarSyncManager: Querying for all available calendars (including hidden) without access role restriction")

        do {
            print("CalendarSyncManager: About to execute query for calendar list using withCheckedThrowingContinuation. Authorizer: \(String(describing: googleCalendarService.authorizer))")
            
            let calendarList: GTLRCalendar_CalendarList = try await withCheckedThrowingContinuation { continuation in
                googleCalendarService.executeQuery(query) { (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                    if let error = error {
                        print("CalendarSyncManager.fetchGoogleCalendarList: Error executing query: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let list = object as? GTLRCalendar_CalendarList {
                        continuation.resume(returning: list)
                    } else {
                        print("CalendarSyncManager.fetchGoogleCalendarList: Unexpected response object type or nil. Expected GTLRCalendar_CalendarList, got \(type(of: object ?? "nil")).")
                        continuation.resume(throwing: NSError(domain: "CalendarSyncManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response object type or nil for calendar list."]))
                    }
                }
            }
            
            print("CalendarSyncManager: Successfully fetched GTLRCalendar_CalendarList. Type: \(type(of: calendarList))")

            if let items = calendarList.items, !items.isEmpty {
                let visibleCalendars = items.filter { calendar in
                    let isDeleted = calendar.deleted?.boolValue ?? false
                    let summary = calendar.summary ?? "No Name"
                    let accessRole = calendar.accessRole ?? "No Access"
                    let hidden = calendar.hidden?.boolValue ?? false
                    
                    print("Calendar: \(summary) - Access: \(accessRole) - Hidden: \(hidden) - Deleted: \(isDeleted)")
                    
                    return !isDeleted // Only filter out deleted calendars
                }
                
                self.googleCalendars = visibleCalendars
                print("CalendarSyncManager: Successfully populated \(visibleCalendars.count) Google Calendars (filtered \(items.count - visibleCalendars.count) deleted calendars).")
                
                let existingCalendarIDs = visibleCalendars.compactMap { $0.identifier }
                self.selectedGoogleCalendarIDs = self.selectedGoogleCalendarIDs.filter { existingCalendarIDs.contains($0) }
            } else {
                self.googleCalendars = []
                if calendarList.items == nil {
                    print("CalendarSyncManager: No Google Calendars found - calendarList.items is nil.")
                } else if calendarList.items?.isEmpty == true {
                     print("CalendarSyncManager: No Google Calendars found - calendarList.items is empty.")
                }
            }
        } catch {
            print("CalendarSyncManager: Error executing fetchGoogleCalendarList query: \(error.localizedDescription)")
            self.googleCalendars = []
        }
    }

    func fetchGoogleCalendarEvents() async {
        guard isGoogleCalendarAccessGranted, let authorizer = googleCalendarService.authorizer else {
            print("Cannot fetch Google Calendar events: Not signed in or no authorizer.")
            self.googleCalendarEvents = []
            return
        }

        guard !selectedGoogleCalendarIDs.isEmpty else {
            print("No Google Calendars selected to fetch events from.")
            self.googleCalendarEvents = []
            return
        }

        print("Fetching Google Calendar events for selected calendars: \(selectedGoogleCalendarIDs)...")
        var allFetchedEvents: [GTLRCalendar_Event] = []
        let group = DispatchGroup()

        let timeMin = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let timeMax = Calendar.current.date(byAdding: .year, value: 1, to: Date())!

        for calendarId in selectedGoogleCalendarIDs {
            group.enter()
            let query = GTLRCalendarQuery_EventsList.query(withCalendarId: calendarId)
            query.timeMin = GTLRDateTime(date: timeMin)
            query.timeMax = GTLRDateTime(date: timeMax)
            query.singleEvents = true
            query.orderBy = "startTime"

            googleCalendarService.executeQuery(query) { [weak self] (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                defer { group.leave() }
                guard self != nil else { return }

                if let error = error {
                    print("Error fetching events for calendar \(calendarId): \(error.localizedDescription)")
                    return
                }

                if let events = (object as? GTLRCalendar_Events)?.items {
                    print("Fetched \(events.count) events from calendar: \(calendarId)")
                    allFetchedEvents.append(contentsOf: events)
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.googleCalendarEvents = allFetchedEvents.sorted { event1, event2 in
                guard let date1 = event1.start?.dateTime?.date ?? event1.start?.date?.date,
                      let date2 = event2.start?.dateTime?.date ?? event2.start?.date?.date else {
                    return false
                }
                return date1 < date2
            }
            print("Finished fetching all Google Calendar events. Total: \(self.googleCalendarEvents.count)")
            NotificationCenter.default.post(name: .googleCalendarEventsFetched, object: nil)
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
    
    func fetchEventsAndUpdatePublishedProperty() async {
        guard UserDefaults.standard.bool(forKey: "appleCalendarIntegrationEnabled") else {
            print("Apple Calendar integration is disabled by user toggle. Skipping fetch.")
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

    func createGoogleCalendarEvent(event: GTLRCalendar_Event, calendarId: String = "primary") async throws -> GTLRCalendar_Event? {
        guard isGoogleCalendarAccessGranted, googleCalendarService.authorizer != nil else {
            throw NSError(domain: "CalendarSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed into Google or no authorizer."])
        }
        let query = GTLRCalendarQuery_EventsInsert.query(withObject: event, calendarId: calendarId)
        print("Creating Google Calendar event: \(event.summary ?? "Untitled") on calendar: \(calendarId)")
        do {
            let createdEvent: GTLRCalendar_Event = try await withCheckedThrowingContinuation { continuation in
                googleCalendarService.executeQuery(query) { (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                    if let error = error {
                        print("CalendarSyncManager.createGoogleCalendarEvent: Error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let evt = object as? GTLRCalendar_Event {
                        continuation.resume(returning: evt)
                    } else {
                        print("CalendarSyncManager.createGoogleCalendarEvent: Unexpected response type or nil. Expected GTLRCalendar_Event, got \(type(of: object ?? "nil")).")
                        continuation.resume(throwing: NSError(domain: "CalendarSyncManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response type for create event."]))
                    }
                }
            }

            print("Successfully created Google event with ID: \(createdEvent.identifier ?? "N/A")")
            await fetchGoogleCalendarEvents()
            return createdEvent
        } catch {
            print("Error creating Google Calendar event: \(error.localizedDescription)")
            throw error
        }
    }

    func updateGoogleCalendarEvent(event: GTLRCalendar_Event, calendarId: String = "primary") async throws -> GTLRCalendar_Event? {
        guard isGoogleCalendarAccessGranted, googleCalendarService.authorizer != nil, let eventId = event.identifier else {
            throw NSError(domain: "CalendarSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed into Google, no authorizer, or event ID missing."])
        }
        let query = GTLRCalendarQuery_EventsUpdate.query(withObject: event, calendarId: calendarId, eventId: eventId)
        print("Updating Google Calendar event: \(event.summary ?? "Untitled") (ID: \(eventId)) on calendar: \(calendarId)")
        do {
            let updatedEvent: GTLRCalendar_Event = try await withCheckedThrowingContinuation { continuation in
                googleCalendarService.executeQuery(query) { (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                    if let error = error {
                        print("CalendarSyncManager.updateGoogleCalendarEvent: Error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let evt = object as? GTLRCalendar_Event {
                        continuation.resume(returning: evt)
                    } else {
                         print("CalendarSyncManager.updateGoogleCalendarEvent: Unexpected response type or nil. Expected GTLRCalendar_Event, got \(type(of: object ?? "nil")).")
                        continuation.resume(throwing: NSError(domain: "CalendarSyncManagerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unexpected response type for update event."]))
                    }
                }
            }

            print("Successfully updated Google event with ID: \(updatedEvent.identifier ?? "N/A")")
            await fetchGoogleCalendarEvents()
            return updatedEvent
        } catch {
            print("Error updating Google Calendar event: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteGoogleCalendarEvent(eventId: String, calendarId: String = "primary") async throws {
        guard isGoogleCalendarAccessGranted, googleCalendarService.authorizer != nil else {
            throw NSError(domain: "CalendarSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed into Google or no authorizer."])
        }
        let query = GTLRCalendarQuery_EventsDelete.query(withCalendarId: calendarId, eventId: eventId)
        print("Deleting Google Calendar event ID: \(eventId) from calendar: \(calendarId)")
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
                googleCalendarService.executeQuery(query) { (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                    if let error = error {
                        print("CalendarSyncManager.deleteGoogleCalendarEvent: Error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            
            print("Successfully deleted Google event with ID: \(eventId)")
            await fetchGoogleCalendarEvents() // Refresh local cache
        } catch {
            print("Error deleting Google Calendar event: \(error.localizedDescription)")
            throw error
        }
    }
}
