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
                self.isGoogleCalendarAccessGranted = false
                return
            }
            guard let user = signInResult?.user else {
                self.isGoogleCalendarAccessGranted = false
                return
            }

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
                let additionalScopes = [kGTLRAuthScopeCalendar]
                user.addScopes(additionalScopes, presenting: presentingViewController) { [weak self] signInResult, error in
                    guard let self else { return }
                     if let error {
                        self.isGoogleCalendarAccessGranted = false
                        return
                    }
                    guard let updatedUser = signInResult?.user,
                          let grantedScopes = updatedUser.grantedScopes,
                          grantedScopes.contains(kGTLRAuthScopeCalendar) else {
                        self.isGoogleCalendarAccessGranted = false
                        return
                    }
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
                self.isGoogleCalendarAccessGranted = false
                return
            }
            guard let user else {
                self.isGoogleCalendarAccessGranted = false
                return
            }

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
    }

    func fetchGoogleCalendarList() async {
        guard isGoogleCalendarAccessGranted, let authorizer = googleCalendarService.authorizer else {
            self.googleCalendars = []
            return
        }
        
        let query = GTLRCalendarQuery_CalendarListList.query()
        query.showHidden = true
        query.showDeleted = false
        

        do {
            
            let calendarList: GTLRCalendar_CalendarList = try await withCheckedThrowingContinuation { continuation in
                googleCalendarService.executeQuery(query) { (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let list = object as? GTLRCalendar_CalendarList {
                        continuation.resume(returning: list)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CalendarSyncManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response object type or nil for calendar list."]))
                    }
                }
            }
            

            if let items = calendarList.items, !items.isEmpty {
                let visibleCalendars = items.filter { calendar in
                    let isDeleted = calendar.deleted?.boolValue ?? false
                    let summary = calendar.summary ?? "No Name"
                    let accessRole = calendar.accessRole ?? "No Access"
                    let hidden = calendar.hidden?.boolValue ?? false
                    
                    
                    return !isDeleted // Only filter out deleted calendars
                }
                
                self.googleCalendars = visibleCalendars
                
                let existingCalendarIDs = visibleCalendars.compactMap { $0.identifier }
                self.selectedGoogleCalendarIDs = self.selectedGoogleCalendarIDs.filter { existingCalendarIDs.contains($0) }
            } else {
                self.googleCalendars = []
                if calendarList.items == nil {
                } else if calendarList.items?.isEmpty == true {
                }
            }
        } catch {
            self.googleCalendars = []
        }
    }

    func fetchGoogleCalendarEvents() async {
        guard isGoogleCalendarAccessGranted, let authorizer = googleCalendarService.authorizer else {
            self.googleCalendarEvents = []
            return
        }

        guard !selectedGoogleCalendarIDs.isEmpty else {
            self.googleCalendarEvents = []
            return
        }

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
                    return
                }

                if let events = (object as? GTLRCalendar_Events)?.items {
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
            NotificationCenter.default.post(name: .googleCalendarEventsFetched, object: nil)
        }
    }

    func requestCalendarAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            self.isCalendarAccessGranted = granted
            if granted {
                await fetchEventsAndUpdatePublishedProperty()
            } else {
                self.appleCalendarEvents = []
            }
        } catch {
            self.isCalendarAccessGranted = false
            self.appleCalendarEvents = []
        }
    }

    func checkCalendarAuthorizationStatus() -> EKAuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .writeOnly:
            self.isCalendarAccessGranted = true
        case .denied, .restricted:
            self.isCalendarAccessGranted = false
        case .notDetermined:
            self.isCalendarAccessGranted = false
        @unknown default:
            self.isCalendarAccessGranted = false
        }
        return status
    }

    func requestRemindersAccess() async {
         do {
            let granted = try await eventStore.requestFullAccessToReminders()
            self.isRemindersAccessGranted = granted
            if granted {
                await fetchRemindersAndUpdatePublishedProperty()
            } else {
                self.appleReminders = []
            }
        } catch {
            self.isRemindersAccessGranted = false
            self.appleReminders = []
        }
    }

    func checkRemindersAuthorizationStatus() -> EKAuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .fullAccess:
            self.isRemindersAccessGranted = true
        case .denied, .restricted:
            self.isRemindersAccessGranted = false
        case .notDetermined:
            self.isRemindersAccessGranted = false
        @unknown default:
            self.isRemindersAccessGranted = false
        }
        return status
    }
    
    func fetchEventsAndUpdatePublishedProperty() async {
        guard UserDefaults.standard.bool(forKey: "appleCalendarIntegrationEnabled") else {
            return
        }

        guard isCalendarAccessGranted else {
            self.appleCalendarEvents = []
            return
        }
        
        let calendars = eventStore.calendars(for: .event)
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let oneYearLater = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        
        let predicate = eventStore.predicateForEvents(withStart: oneMonthAgo, end: oneYearLater, calendars: calendars.filter { !$0.title.contains("Holidays") })
        
        let events = eventStore.events(matching: predicate)
        self.appleCalendarEvents = events
    }
    
    func fetchRemindersAndUpdatePublishedProperty() async {
        guard UserDefaults.standard.bool(forKey: "appleRemindersIntegrationEnabled") else {
            return
        }

        guard isRemindersAccessGranted else {
            self.appleReminders = []
            return
        }
        
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        
        let fetchedReminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        self.appleReminders = fetchedReminders
    }
    
    func clearAppleCalendarEventsData() {
        self.appleCalendarEvents = []
    }

    func clearAppleRemindersData() {
        self.appleReminders = []
    }

    func createAppleCalendarEvent(from event: Event) async -> String? {
        guard isCalendarAccessGranted else {
            return nil
        }
        
        let newEKEvent = EKEvent(eventStore: eventStore)
        newEKEvent.title = event.title
        newEKEvent.startDate = event.date
        newEKEvent.endDate = event.date.addingTimeInterval(3600) // Default 1-hour duration
        newEKEvent.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(newEKEvent, span: .thisEvent, commit: true)
            return newEKEvent.eventIdentifier
        } catch {
            return nil
        }
    }

    func updateAppleCalendarEvent(from event: Event) async -> Bool {
        guard isCalendarAccessGranted, let eventIdentifier = event.appleCalendarIdentifier,
              let ekEvent = eventStore.event(withIdentifier: eventIdentifier) else {
            return false
        }
        
        ekEvent.title = event.title
        ekEvent.startDate = event.date
        ekEvent.endDate = event.date.addingTimeInterval(3600) // Assuming 1-hour duration
        
        do {
            try eventStore.save(ekEvent, span: .thisEvent, commit: true)
            return true
        } catch {
            return false
        }
    }

    func deleteAppleCalendarEvent(withIdentifier identifier: String) async -> Bool {
        guard isCalendarAccessGranted, let ekEvent = eventStore.event(withIdentifier: identifier) else {
            return false
        }
        
        do {
            try eventStore.remove(ekEvent, span: .thisEvent, commit: true)
            return true
        } catch {
            return false
        }
    }

    func createGoogleCalendarEvent(event: GTLRCalendar_Event, calendarId: String = "primary") async throws -> GTLRCalendar_Event? {
        guard isGoogleCalendarAccessGranted, googleCalendarService.authorizer != nil else {
            throw NSError(domain: "CalendarSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed into Google or no authorizer."])
        }
        
        let query = GTLRCalendarQuery_EventsInsert.query(withObject: event, calendarId: calendarId)
        do {
            let createdEvent: GTLRCalendar_Event = try await withCheckedThrowingContinuation { continuation in
                googleCalendarService.executeQuery(query) { (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let evt = object as? GTLRCalendar_Event {
                        continuation.resume(returning: evt)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CalendarSyncManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response type for create event."]))
                    }
                }
            }

            await fetchGoogleCalendarEvents()
            return createdEvent
        } catch {
            throw error
        }
    }

    func updateGoogleCalendarEvent(event: GTLRCalendar_Event, calendarId: String = "primary") async throws -> GTLRCalendar_Event? {
        guard isGoogleCalendarAccessGranted, googleCalendarService.authorizer != nil, let eventId = event.identifier else {
            throw NSError(domain: "CalendarSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed into Google, no authorizer, or event ID missing."])
        }
        let query = GTLRCalendarQuery_EventsUpdate.query(withObject: event, calendarId: calendarId, eventId: eventId)
        do {
            let updatedEvent: GTLRCalendar_Event = try await withCheckedThrowingContinuation { continuation in
                googleCalendarService.executeQuery(query) { (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let evt = object as? GTLRCalendar_Event {
                        continuation.resume(returning: evt)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CalendarSyncManagerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unexpected response type for update event."]))
                    }
                }
            }

            await fetchGoogleCalendarEvents()
            return updatedEvent
        } catch {
            throw error
        }
    }

    func deleteGoogleCalendarEvent(eventId: String, calendarId: String = "primary") async throws {
        guard isGoogleCalendarAccessGranted, googleCalendarService.authorizer != nil else {
            throw NSError(domain: "CalendarSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed into Google or no authorizer."])
        }
        let query = GTLRCalendarQuery_EventsDelete.query(withCalendarId: calendarId, eventId: eventId)
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
                googleCalendarService.executeQuery(query) { (ticket: GTLRServiceTicket?, object: Any?, error: Error?) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            
            await fetchGoogleCalendarEvents() // Refresh local cache
        } catch {
            throw error
        }
    }

    func createGoogleCalendarEvent(from event: Event, calendarId: String = "primary") async -> String? {
        let googleEvent = GTLRCalendar_Event()
        googleEvent.summary = event.title
        let startDateTime = GTLRDateTime(date: event.date)
        let endDateTime = GTLRDateTime(date: event.date.addingTimeInterval(3600)) // 1 hr duration
        googleEvent.start = GTLRCalendar_EventDateTime()
        googleEvent.start?.dateTime = startDateTime
        googleEvent.end = GTLRCalendar_EventDateTime()
        googleEvent.end?.dateTime = endDateTime

        do {
            let createdEvent = try await createGoogleCalendarEvent(event: googleEvent, calendarId: calendarId)
            return createdEvent?.identifier
        } catch {
            return nil
        }
    }

    @discardableResult
    func updateGoogleCalendarEvent(from event: Event,
                                   calendarId: String = "primary") async -> Bool {

        guard let eventId = event.googleCalendarIdentifier else {
            return false
        }

        let gEvent           = GTLRCalendar_Event()
        gEvent.identifier    = eventId
        gEvent.summary       = event.title
        gEvent.start         = GTLRCalendar_EventDateTime()
        gEvent.start?.dateTime = GTLRDateTime(date: event.date)
        gEvent.end           = GTLRCalendar_EventDateTime()
        gEvent.end?.dateTime   = GTLRDateTime(date: event.date.addingTimeInterval(3600))

        do {
            // ── Google call ───────────────────────────────────────────────────────────
            let result = try await updateGoogleCalendarEvent(event: gEvent,
                                                             calendarId: calendarId)
            // `result` is GTLRCalendar_Event
            if let updated = result as? GTLRCalendar_Event,
               let updatedId = updated.identifier {
                EventStore.setGoogleId(updatedId, forLocalId: event.id, in: EventViewModel())
            }
            return true
        } catch {
            return false
        }
    }


    func deleteGoogleCalendarEvent(from event: Event, calendarId: String = "primary") async -> Bool {
        guard let eventId = event.googleCalendarIdentifier else {
            return false
        }
        do {
            try await deleteGoogleCalendarEvent(eventId: eventId, calendarId: calendarId)
            return true
        } catch {
            return false
        }
    }
}
