import SwiftUI
import Combine

@MainActor
class EventViewModel: ObservableObject {
    // Delegate data management to EventOperationsManager
    @Published var eventOperationsManager = EventOperationsManager()
    
    @Published var schedules: [ScheduleItem] = [] 
    @Published var scheduleItems: [ScheduleItem] = [] 
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshTime: Date?
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = "Ready"
    @Published var selectedCategoryFilter: UUID? = nil
    
    private var isUpdatingCoursesFromNotification = false
    @Published var courses: [Course] = [] {
        didSet {
            if !isUpdatingCoursesFromNotification {
                updateSmartEngineWithCourses()
            }
        }
    }
    
    // Computed properties that delegate to EventOperationsManager
    var categories: [Category] {
        eventOperationsManager.categories
    }
    
    var events: [Event] {
        eventOperationsManager.events
    }
    
    private let scheduleKey = "savedSchedule"
    private let coursesKey = "savedCourses"
    private let notificationManager = NotificationManager.shared
    
    private var weatherService: WeatherService?
    private var calendarSyncManager: CalendarSyncManager?
    
    private var cancellables = Set<AnyCancellable>()
    
    private func updateSmartEngineWithCourses() {
        let courseNames = courses.map { $0.name }
    }
    
    init() {
        print(" EventViewModel: Initializing with EventOperationsManager...")
        
        // Set up observation of EventOperationsManager changes to trigger UI updates
        eventOperationsManager.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        eventOperationsManager.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        loadSchedules()
        loadCourses()
        
        Task {
            await notificationManager.requestAuthorization()
        }
        NotificationCenter.default.publisher(for: .googleCalendarEventsFetched)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.processFetchedGoogleCalendarEvents()
                }
            }
            .store(in: &cancellables)
        
        // Listen for data clearing when user signs out
        NotificationCenter.default.publisher(for: .init("UserDataCleared"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print(" EventViewModel: Received UserDataCleared notification")
                self?.clearScheduleData()
            }
            .store(in: &cancellables)
        
        print(" EventViewModel: Initialization complete (delegating to EventOperationsManager)")
    }
    
    // MARK: - Data Clearing
    
    private func clearScheduleData() {
        print(" EventViewModel: Clearing schedule data")
        schedules.removeAll()
        scheduleItems.removeAll()
        courses.removeAll()
        
        // Save empty state
        saveScheduleDataLocally()
        
        print(" EventViewModel: Schedule data cleared")
    }
    
    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: scheduleKey),
           let decodedScheduleItems = try? JSONDecoder().decode([ScheduleItem].self, from: data) {
            scheduleItems = decodedScheduleItems
        }
    }
    
    private func loadCourses() {
        if let data = UserDefaults.standard.data(forKey: coursesKey),
           let decodedCourses = try? JSONDecoder().decode([Course].self, from: data) {
            courses = decodedCourses
        }
    }
    
    private func registerDefaultIntegrationToggles() {
        UserDefaults.standard.register(defaults: [
            "GoogleCalendarIntegrationEnabled": false,
            "AppleCalendarIntegrationEnabled": false,
            "NotificationIntegrationEnabled": true
        ])
    }
    
    private func setupCalendarSyncSubscriptions() {
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshLiveData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func processFetchedGoogleCalendarEvents() async {
        await refreshLiveData()
    }
    
    private func handleCalendarSyncOnUpdate(oldEvent: Event, newEvent: Event) {
        guard let calendarSyncManager = calendarSyncManager else { return }
        
        Task {
            if newEvent.syncToAppleCalendar, let _ = newEvent.appleCalendarIdentifier {
                _ = await calendarSyncManager.updateAppleCalendarEvent(from: newEvent)
            }
            
            if newEvent.syncToGoogleCalendar, newEvent.googleCalendarIdentifier != nil {
                _ = await calendarSyncManager.updateGoogleCalendarEvent(from: newEvent, calendarId: "primary")
            }
        }
    }
    
    @MainActor
    func refreshLiveData() async {
        isRefreshing = true
        
        print(" 📅 EventViewModel: Delegating refreshLiveData to EventOperationsManager...")
        
        // Delegate to EventOperationsManager
        await eventOperationsManager.refreshData()
        
        lastRefreshTime = Date()
        isRefreshing = false
        
        print(" 📅 EventViewModel: refreshLiveData completed - Events: \(events.count), Categories: \(categories.count)")
    }
    
    private func setupSyncStatusObservation() {
        eventOperationsManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isSyncing = isLoading
                self?.syncStatus = isLoading ? "Syncing..." : "Ready"
            }
            .store(in: &cancellables)
    }
    
    private func saveScheduleDataLocally() {
        do {
            let encoder = JSONEncoder()
            let scheduleData = try encoder.encode(scheduleItems)
            let coursesData = try encoder.encode(courses)
            UserDefaults.standard.set(scheduleData, forKey: scheduleKey)
            UserDefaults.standard.set(coursesData, forKey: coursesKey)
        } catch {
            print(" ❌ Failed to save schedule data: \(error)")
        }
    }
    
    private func handleCalendarSyncForNewEvent(_ event: Event) {
        if event.syncToAppleCalendar || event.syncToGoogleCalendar {
            guard let calendarSyncManager = calendarSyncManager else {
                return
            }
            
            Task {
                var eventToUpdate = event
                if event.syncToAppleCalendar {
                    if let newID = await calendarSyncManager.createAppleCalendarEvent(from: event) {
                        eventToUpdate.appleCalendarIdentifier = newID
                    }
                }
                if event.syncToGoogleCalendar {
                    if let newID = await calendarSyncManager.createGoogleCalendarEvent(from: event, calendarId: "primary") {
                        eventToUpdate.googleCalendarIdentifier = newID
                        eventToUpdate.externalIdentifier = newID
                    }
                }
                
                if eventToUpdate.appleCalendarIdentifier != event.appleCalendarIdentifier ||
                   eventToUpdate.googleCalendarIdentifier != event.googleCalendarIdentifier {
                    await MainActor.run {
                        self.eventOperationsManager.updateEvent(eventToUpdate)
                    }
                }
            }
        }
    }
    
    func setLiveDataServices(weatherService: WeatherService, calendarSyncManager: CalendarSyncManager) {
        self.weatherService = weatherService
        self.calendarSyncManager = calendarSyncManager
    }
    
    func manageLiveActivities(themeManager: ThemeManager) {
    }
    
    func todaysEvents() -> [Event] {
        let now = Date()
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.date, inSameDayAs: now) && 
            !event.isCompleted && 
            event.date > now
        }
        .sorted { $0.date < $1.date }
    }
    
    func upcomingEvents() -> [Event] {
        let now = Date()
        let calendar = Calendar.current
        let baseEvents = events.filter { event in
            event.date > now &&
            !calendar.isDate(event.date, inSameDayAs: now) &&
            !event.isCompleted
        }
        
        let filteredEvents = selectedCategoryFilter == nil ? baseEvents : baseEvents.filter { $0.categoryId == selectedCategoryFilter }
        
        return filteredEvents.sorted { $0.date < $1.date }
    }
    
    func pastEvents() -> [Event] {
        let now = Date()
        let baseEvents = events.filter { $0.date <= now || $0.isCompleted }
        
        let filteredEvents = selectedCategoryFilter == nil ? baseEvents : baseEvents.filter { $0.categoryId == selectedCategoryFilter }
        
        return filteredEvents.sorted { $0.date > $1.date }
    }
    
    func events(for date: Date) -> [Event] {
        let calendar = Calendar.current
        let baseEvents = events.filter { calendar.isDate($0.date, inSameDayAs: date) }
        
        // Apply category filter if one is selected
        let filteredEvents = selectedCategoryFilter == nil ? baseEvents : baseEvents.filter { $0.categoryId == selectedCategoryFilter }
        
        return filteredEvents.sorted { $0.date < $1.date }
    }
    
    func bulkDeleteEvents(_ eventIDs: Set<UUID>) {
        let eventsToDelete = events.filter { eventIDs.contains($0.id) }
        for event in eventsToDelete {
            deleteEvent(event)
        }
    }
    
    func bulkDeleteCategories(_ categoryIDs: Set<UUID>) {
        let categoriesToDelete = categories.filter { categoryIDs.contains($0.id) }
        for category in categoriesToDelete {
            deleteCategory(category)
        }
    }
    
    func bulkDeleteScheduleItems(_ scheduleItemIDs: Set<UUID>, themeManager: ThemeManager) {
        let itemsToDelete = scheduleItems.filter { scheduleItemIDs.contains($0.id) }
        for item in itemsToDelete {
            scheduleItems.removeAll { $0.id == item.id }
        }
        saveScheduleDataLocally()
    }
    
    func markEventCompleted(_ event: Event) {
        var updatedEvent = event
        updatedEvent.isCompleted = true
        
        eventOperationsManager.updateEvent(updatedEvent)
        
        notificationManager.removeAllEventNotifications(for: updatedEvent)
    }

    func toggleEventCompleted(_ event: Event) {
        var updated = event
        updated.isCompleted.toggle()
        updateEvent(updated)
        if updated.isCompleted {
            notificationManager.removeAllEventNotifications(for: updated)
        }
    }

    func addEvent(_ event: Event) {
        eventOperationsManager.addEvent(event)
        
        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }
        
        handleCalendarSyncForNewEvent(event)
    }
    
    func updateEvent(_ event: Event) {
        guard let oldEvent = events.first(where: { $0.id == event.id }) else { return }
        
        eventOperationsManager.updateEvent(event)
        
        notificationManager.removeAllEventNotifications(for: oldEvent)
        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }
        
        handleCalendarSyncOnUpdate(oldEvent: oldEvent, newEvent: event)
    }
    
    func deleteEvent(_ event: Event) {
        eventOperationsManager.deleteEvent(event)
        
        notificationManager.removeAllEventNotifications(for: event)
        
        if let calendarSyncManager = calendarSyncManager {
            Task {
                if event.syncToAppleCalendar, let appleId = event.appleCalendarIdentifier {
                    _ = await calendarSyncManager.deleteAppleCalendarEvent(withIdentifier: appleId)
                }
                if event.syncToGoogleCalendar, event.googleCalendarIdentifier != nil {
                    _ = await calendarSyncManager.deleteGoogleCalendarEvent(from: event, calendarId: "primary")
                }
            }
        }
    }
    
    func addCategory(_ category: Category) {
        eventOperationsManager.addCategory(category)
    }
    
    func updateCategory(_ category: Category) {
        eventOperationsManager.updateCategory(category)
    }
    
    func deleteCategory(_ category: Category) {
        eventOperationsManager.deleteCategory(category)
    }
}