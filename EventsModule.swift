import SwiftUI
import Combine
import UserNotifications
import ActivityKit
import EventKit

// MARK: - Bulk Selection Manager
class BulkSelectionManager: ObservableObject {
    @Published var isSelecting = false
    @Published var selectionContext: SelectionContext = .none
    @Published var selectedEventIDs: Set<UUID> = []
    @Published var selectedCategoryIDs: Set<UUID> = []
    @Published var selectedScheduleItemIDs: Set<UUID> = []
    
    enum SelectionContext {
        case none
        case events
        case categories
        case scheduleItems
    }
    
    func startSelection(_ context: SelectionContext, initialID: UUID? = nil) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectionContext = context
            isSelecting = true
            
            clearAllSelections()
            
            if let id = initialID {
                switch context {
                case .events:
                    selectedEventIDs.insert(id)
                case .categories:
                    selectedCategoryIDs.insert(id)
                case .scheduleItems:
                    selectedScheduleItemIDs.insert(id)
                case .none:
                    break
                }
            }
        }
    }
    
    func endSelection() {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectionContext = .none
            isSelecting = false
            clearAllSelections()
        }
    }
    
    func toggleSelection(_ id: UUID) {
        switch selectionContext {
        case .events:
            if selectedEventIDs.contains(id) {
                selectedEventIDs.remove(id)
            } else {
                selectedEventIDs.insert(id)
            }
        case .categories:
            if selectedCategoryIDs.contains(id) {
                selectedCategoryIDs.remove(id)
            } else {
                selectedCategoryIDs.insert(id)
            }
        case .scheduleItems:
            if selectedScheduleItemIDs.contains(id) {
                selectedScheduleItemIDs.remove(id)
            } else {
                selectedScheduleItemIDs.insert(id)
            }
        case .none:
            break
        }
    }
    
    func selectAll<T: Identifiable>(items: [T]) where T.ID == UUID {
        let allIDs = Set(items.map { $0.id })
        switch selectionContext {
        case .events:
            selectedEventIDs = allIDs
        case .categories:
            selectedCategoryIDs = allIDs
        case .scheduleItems:
            selectedScheduleItemIDs = allIDs
        case .none:
            break
        }
    }
    
    func deselectAll() {
        switch selectionContext {
        case .events:
            selectedEventIDs.removeAll()
        case .categories:
            selectedCategoryIDs.removeAll()
        case .scheduleItems:
            selectedScheduleItemIDs.removeAll()
        case .none:
            break
        }
    }
    
    private func clearAllSelections() {
        selectedEventIDs.removeAll()
        selectedCategoryIDs.removeAll()
        selectedScheduleItemIDs.removeAll()
    }
    
    func selectedCount() -> Int {
        switch selectionContext {
        case .events:
            return selectedEventIDs.count
        case .categories:
            return selectedCategoryIDs.count
        case .scheduleItems:
            return selectedScheduleItemIDs.count
        case .none:
            return 0
        }
    }
    
    func isSelected(_ id: UUID) -> Bool {
        switch selectionContext {
        case .events:
            return selectedEventIDs.contains(id)
        case .categories:
            return selectedCategoryIDs.contains(id)
        case .scheduleItems:
            return selectedScheduleItemIDs.contains(id)
        case .none:
            return false
        }
    }
}

// MARK: - Models & ViewModel
struct Category: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var color: Color
    
    enum CodingKeys: String, CodingKey {
        case id, name, color
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color(UIColor(red: components[0], green: components[0], blue: components[0], alpha: components.count > 1 ? components[1] : 1.0))
        }
    }
    
    init(name: String, color: Color) {
        self.id = UUID()
        self.name = name
        self.color = color
    }
}

enum DayOfWeek: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

@MainActor
class EventViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var events: [Event] = []
    @Published var scheduleItems: [ScheduleItem] = []
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshTime: Date?
    private var isUpdatingCoursesFromNotification = false
    @Published var courses: [Course] = [] {
        didSet {
            if !isUpdatingCoursesFromNotification {
                updateSmartEngineWithCourses()
            }
        }
    }
    
    private let categoriesKey = "savedCategories"
    private let eventsKey = "savedEvents"
    private let scheduleKey = "savedSchedule"
    private let notificationManager = NotificationManager.shared
    
    private var weatherService: WeatherService?
    private var calendarSyncManager: CalendarSyncManager?
    
    private var cancellables = Set<AnyCancellable>()
    
    private func updateSmartEngineWithCourses() {
        let courseNames = courses.map { $0.name }
        print("🔍 EventViewModel: Updating SmartEngine with courses: \(courseNames)")
        print("🟦 [SmartInput] Updating SmartInputEngine with courses: \(courseNames)")
    }
    
    init() {
        loadData()
        loadCourses()
        
        registerDefaultIntegrationToggles()
        
        let manager = CalendarSyncManager()
        self.calendarSyncManager = manager
        setupCalendarSyncSubscriptions()
        Task {
            await manager.requestCalendarAccess()
            await manager.requestRemindersAccess()
        }
        
        Task {
            await notificationManager.requestAuthorization()
        }
        NotificationCenter.default.publisher(for: .googleCalendarEventsFetched)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("EventViewModel received googleCalendarEventsFetched notification.")
                Task {
                    await self?.processFetchedGoogleCalendarEvents()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadCourses() {
        self.courses = CourseStorage.load()
        print("EventViewModel: Loaded \(courses.count) courses from CourseStorage")
        for course in courses {
            print("EventViewModel: Course '\(course.name)' with \(course.assignments.count) assignments")
        }
        updateSmartEngineWithCourses()
    }
    
    private func loadData() {
        if let categoriesData = UserDefaults.standard.data(forKey: categoriesKey),
           let eventsData = UserDefaults.standard.data(forKey: eventsKey),
           let scheduleData = UserDefaults.standard.data(forKey: scheduleKey) {
            do {
                let decoder = JSONDecoder()
                categories = try decoder.decode([Category].self, from: categoriesData)
                events = try decoder.decode([Event].self, from: eventsData)
                scheduleItems = try decoder.decode([ScheduleItem].self, from: scheduleData)
            } catch {
                print("Error loading data: \(error). Using default data.")
                setupDefaultData()
            }
        } else {
            setupDefaultData()
        }
    }
    
    private func setupDefaultData() {
        categories = [
            Category(name: "Assignment", color: .primaryGreen),
            Category(name: "Lab", color: .orange),
            Category(name: "Exam", color: .red),
            Category(name: "Personal", color: .purple),
            Category(name: "Imported", color: .gray)
        ]
        
        guard let defaultCatID = categories.first?.id,
              let labCatID = categories.dropFirst().first?.id else {
            print("Default categories not set up correctly.")
            return
        }
        
        events = [
            Event(date: Date(), title: "Math assignment due", categoryId: defaultCatID),
            Event(date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!, title: "Physics lab", categoryId: labCatID),
            Event(date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!, title: "History essay draft", categoryId: defaultCatID)
        ]
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        
        components.hour = 9; components.minute = 0
        let mathStart = calendar.date(from: components)!
        components.hour = 10; components.minute = 15
        let mathEnd = calendar.date(from: components)!
        
        components.hour = 14; components.minute = 0
        let gymStart = calendar.date(from: components)!
        components.hour = 15; components.minute = 30
        let gymEnd = calendar.date(from: components)!
        
        scheduleItems = [
            ScheduleItem(title: "Math 101",
                         startTime: mathStart,
                         endTime: mathEnd,
                         daysOfWeek: [.monday, .wednesday, .friday],
                         color: .blue),
            ScheduleItem(title: "Gym",
                         startTime: gymStart,
                         endTime: gymEnd,
                         daysOfWeek: [.tuesday, .thursday],
                         color: .orange)
        ]
        
        saveData()
    }
    
    func saveData() {
        do {
            let encoder = JSONEncoder()
            let categoriesData = try encoder.encode(categories)
            let eventsData = try encoder.encode(events)
            let scheduleData = try encoder.encode(scheduleItems)
            UserDefaults.standard.set(categoriesData, forKey: categoriesKey)
            UserDefaults.standard.set(eventsData, forKey: eventsKey)
            UserDefaults.standard.set(scheduleData, forKey: scheduleKey)
        } catch {
            print("Error saving data: \(error)")
        }
    }
    
    // MARK: - Bulk Delete Operations
    func bulkDeleteEvents(_ eventIDs: Set<UUID>) {
        let eventsToDelete = events.filter { eventIDs.contains($0.id) }
        
        for event in eventsToDelete {
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
            
            notificationManager.removeAllEventNotifications(for: event)
        }
        
        events.removeAll { eventIDs.contains($0.id) }
        saveData()
    }
    
    func bulkDeleteCategories(_ categoryIDs: Set<UUID>) {
        categories.removeAll { categoryIDs.contains($0.id) }
        saveData()
    }
    
    func bulkDeleteScheduleItems(_ scheduleItemIDs: Set<UUID>, themeManager: ThemeManager? = nil) {
        let itemsToDelete = scheduleItems.filter { scheduleItemIDs.contains($0.id) }
        
        for item in itemsToDelete {
            notificationManager.removeAllScheduleItemNotifications(for: item)
            Task { @MainActor in
                LiveActivityManager.shared.endActivity(for: item.id.uuidString)
            }
        }
        
        scheduleItems.removeAll { scheduleItemIDs.contains($0.id) }
        saveData()
        
        if let themeManager {
            Task { @MainActor in
                self.manageLiveActivities(themeManager: themeManager)
            }
        }
    }
    
    private func dayOfWeek(for date: Date) -> DayOfWeek? {
        DayOfWeek(rawValue: Calendar.current.component(.weekday, from: date))
    }
    
    // MARK: - Schedule Item Operations
    func addScheduleItem(_ item: ScheduleItem, themeManager: ThemeManager) {
        scheduleItems.append(item)
        if item.reminderTime != .none {
            notificationManager.scheduleScheduleItemNotifications(for: item, reminderTime: item.reminderTime)
        }
        handleLiveActivityForItemIfNeeded(item, themeManager: themeManager)
        saveData()
    }
    
    @MainActor
    func updateScheduleItem(_ item: ScheduleItem, themeManager: ThemeManager) async {
        guard let idx = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        let oldItem = scheduleItems[idx]
        
        notificationManager.removeAllScheduleItemNotifications(for: oldItem)
        scheduleItems[idx] = item
        
        if item.reminderTime != .none {
            notificationManager.scheduleScheduleItemNotifications(for: item, reminderTime: item.reminderTime)
        }
        
        handleLiveActivityForItemIfNeeded(item, themeManager: themeManager)
        saveData()
    }
    
    func deleteScheduleItem(_ item: ScheduleItem, themeManager: ThemeManager) {
        notificationManager.removeAllScheduleItemNotifications(for: item)
        Task { @MainActor in
            LiveActivityManager.shared.endActivity(for: item.id.uuidString)
        }
        scheduleItems.removeAll { $0.id == item.id }
        saveData()
        Task { @MainActor in
            self.manageLiveActivities(themeManager: themeManager)
        }
    }
    
    func toggleSkip(forInstance item: ScheduleItem, onDate date: Date, themeManager: ThemeManager) {
        guard let idx = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        let identifier = ScheduleItem.instanceIdentifier(for: item.id, onDate: date)
        
        if scheduleItems[idx].skippedInstanceIdentifiers.contains(identifier) {
            scheduleItems[idx].skippedInstanceIdentifiers.remove(identifier)
        } else {
            scheduleItems[idx].skippedInstanceIdentifiers.insert(identifier)
        }
        
        // Live Activity management for today's instance
        let isToday = Calendar.current.isDateInToday(date)
        if isToday {
            let now = Date()
            let startToday = LiveActivityManager.shared.getAbsoluteTime(for: item.startTime, on: now)
            let endToday = LiveActivityManager.shared.getAbsoluteTime(for: item.endTime, on: now)
            let isSkippedNow = scheduleItems[idx].isSkipped(onDate: now)
            
            Task { @MainActor in
                if isSkippedNow {
                    LiveActivityManager.shared.endActivity(for: item.id.uuidString)
                } else if now < endToday {
                    LiveActivityManager.shared.startActivity(for: scheduleItems[idx], themeManager: themeManager)
                }
            }
        }
        
        saveData()
        Task { @MainActor in
            self.manageLiveActivities(themeManager: themeManager)
        }
    }
    
    private func handleLiveActivityForItemIfNeeded(_ item: ScheduleItem, themeManager: ThemeManager) {
        let now = Date()

        // End all existing activities first
//        for item in scheduleItems {
//            LiveActivityManager.shared.endActivity(for: item.id.uuidString)
//        }

        // Start Live Activities for relevant schedule items
        for item in scheduleItems {
            guard let todayDOW = dayOfWeek(for: now),
                  item.daysOfWeek.contains(todayDOW),
                  !item.isSkipped(onDate: now)
            else { continue }

            let endToday = LiveActivityManager.shared.getAbsoluteTime(for: item.endTime, on: now)
            if now < endToday {
                LiveActivityManager.shared.startActivity(for: item, themeManager: themeManager)
            }
        }

    }
    
    // MARK: - Event Operations
    func addEvent(_ event: Event) {
        events.append(event)
        guard let eventIndex = events.firstIndex(where: { $0.id == event.id }) else { return }
        
        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }
        
        if event.syncToAppleCalendar || event.syncToGoogleCalendar {
            guard let calendarSyncManager = calendarSyncManager else {
                print("CalendarSyncManager is nil when trying to add an event.")
                saveData()
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
                        eventToUpdate.externalIdentifier       = newID
                    }
                }
                
                await MainActor.run {
                    self.events[eventIndex] = eventToUpdate
                    self.saveData()
                }
            }
        }
        
        saveData()
    }
    
    func updateEvent(_ event: Event) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        
        let oldEvent = events[idx]
        events[idx] = event
        
        notificationManager.removeAllEventNotifications(for: oldEvent)
        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }
        
        handleCalendarSyncOnUpdate(oldEvent: oldEvent, newEvent: event)
        
        saveData()
    }
    
    func deleteEvent(_ event: Event) {
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
        
        events.removeAll { $0.id == event.id }
        notificationManager.removeAllEventNotifications(for: event)
        saveData()
    }
    
    func markEventCompleted(_ event: Event) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        var updated = events[idx]
        updated.isCompleted = true
        events[idx] = updated
        notificationManager.removeAllEventNotifications(for: updated)
        saveData()
    }
    
    // MARK: - Category Operations
    func addCategory(_ category: Category) {
        categories.append(category)
        saveData()
    }
    
    func updateCategory(_ category: Category) {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
            saveData()
        }
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveData()
    }
    
    func removeImportedData(sourcePrefix: String) {
        let toRemove = events.filter { ($0.sourceName ?? "").hasPrefix(sourcePrefix) }
        for evt in toRemove {
            notificationManager.removeAllEventNotifications(for: evt)
        }
        events.removeAll { ($0.sourceName ?? "").hasPrefix(sourcePrefix) }
        saveData()
    }
    
    // MARK: - Helper Functions
    func todaysEvents() -> [Event] {
        let calendar = Calendar.current
        return events.filter {
            calendar.isDate($0.date, inSameDayAs: Date()) && !$0.isCompleted
        }.sorted { $0.date < $1.date }
    }
    
    func todaysSchedule() -> [ScheduleItem] {
        guard let todayDOW = dayOfWeek(for: Date()) else { return [] }
        return scheduleItems
            .filter { $0.daysOfWeek.contains(todayDOW) }
            .sorted { $0.startTime < $1.startTime }
    }
    
    func upcomingEvents() -> [Event] {
        let now = Date()
        return events.filter { $0.date > now && !$0.isCompleted }
            .sorted { $0.date < $1.date }
    }
    
    func pastEvents() -> [Event] {
        let now = Date()
        return events.filter { ($0.date <= now || $0.isCompleted) }
            .sorted { $0.date > $1.date }
    }
    
    func events(for date: Date) -> [Event] {
        let calendar = Calendar.current
        return events.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Live Data Services (Placeholder functions)
    func setLiveDataServices(weatherService: WeatherService?, calendarSyncManager: CalendarSyncManager?) {
        self.weatherService = weatherService
        self.calendarSyncManager = calendarSyncManager
        setupCalendarSyncSubscriptions()
    }
    
    @MainActor
    func refreshLiveData() async {
        isRefreshing = true
        // Placeholder for refresh logic
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        lastRefreshTime = Date()
        isRefreshing = false
    }
    
    func handleCalendarSyncOnUpdate(oldEvent: Event, newEvent: Event) {
        // Subscriptions to CalendarSyncManager updates
        guard let calendarSyncManager = self.calendarSyncManager else { return }
        Task {
            // Apple Calendar
            if newEvent.syncToAppleCalendar {
                if oldEvent.syncToAppleCalendar == false || oldEvent.appleCalendarIdentifier == nil {
                    if let newID = await calendarSyncManager.createAppleCalendarEvent(from: newEvent) {
                        await MainActor.run {
                            if let idx = self.events.firstIndex(where: { $0.id == newEvent.id }) {
                                self.events[idx].appleCalendarIdentifier = newID
                            }
                        }
                    }
                } else {
                    _ = await calendarSyncManager.updateAppleCalendarEvent(from: newEvent)
                }
            } else if oldEvent.syncToAppleCalendar, let appleId = oldEvent.appleCalendarIdentifier {
                _ = await calendarSyncManager.deleteAppleCalendarEvent(withIdentifier: appleId)
                await MainActor.run {
                    if let idx = self.events.firstIndex(where: { $0.id == newEvent.id }) {
                        self.events[idx].appleCalendarIdentifier = nil
                    }
                }
            }
            
            // Google Calendar
            if newEvent.syncToGoogleCalendar {
                if oldEvent.syncToGoogleCalendar == false || oldEvent.googleCalendarIdentifier == nil {
                    if let newID = await calendarSyncManager.createGoogleCalendarEvent(from: newEvent, calendarId: "primary") {
                        await MainActor.run {
                            if let idx = self.events.firstIndex(where: { $0.id == newEvent.id }) {
                                self.events[idx].googleCalendarIdentifier = newID
                                self.events[idx].externalIdentifier = newID
                            }
                        }
                    }
                } else {
                    _ = await calendarSyncManager.updateGoogleCalendarEvent(from: newEvent, calendarId: "primary")
                }
            } else if oldEvent.syncToGoogleCalendar, let gid = oldEvent.googleCalendarIdentifier {
                _ = try? await calendarSyncManager.deleteGoogleCalendarEvent(eventId: gid, calendarId: "primary")
                await MainActor.run {
                    if let idx = self.events.firstIndex(where: { $0.id == newEvent.id }) {
                        self.events[idx].googleCalendarIdentifier = nil
                    }
                }
            }
            
            await MainActor.run {
                self.saveData()
            }
        }
    }
    
    private func getOrCreateImportedCategory() -> UUID {
        if let imported = categories.first(where: { $0.name == "Imported" }) {
            return imported.id
        } else {
            let cat = Category(name: "Imported", color: .gray)
            categories.append(cat)
            saveData()
            return cat.id
        }
    }
    
    func processFetchedGoogleCalendarEvents() async {
        guard let manager = calendarSyncManager else { return }
        let importedCatId = getOrCreateImportedCategory()
        
        // Clear previous Google imports to avoid duplicates, then import fresh
        removeImportedData(sourcePrefix: "GoogleCalendar")
        
        var imported: [Event] = []
        for gEvent in manager.googleCalendarEvents {
            let title = gEvent.summary ?? "Untitled"
            let startDate = gEvent.start?.dateTime?.date ?? gEvent.start?.date?.date ?? Date()
            let id = gEvent.identifier ?? UUID().uuidString
            let evt = Event(
                date: startDate,
                title: title,
                categoryId: importedCatId,
                reminderTime: .none,
                isCompleted: false,
                externalIdentifier: id,
                sourceName: "GoogleCalendar"
            )
            imported.append(evt)
        }
        
        if !imported.isEmpty {
            events.append(contentsOf: imported)
            saveData()
        }
    }
    
    func manageLiveActivities(themeManager: ThemeManager) {
        let now = Date()

        // End all existing activities first
        for item in scheduleItems {
            LiveActivityManager.shared.endActivity(for: item.id.uuidString)
        }

        // Start Live Activities for relevant schedule items
        for item in scheduleItems {
            guard let todayDOW = dayOfWeek(for: now),
                  item.daysOfWeek.contains(todayDOW),
                  !item.isSkipped(onDate: now)
            else { continue }

            let endToday = LiveActivityManager.shared.getAbsoluteTime(for: item.endTime, on: now)
            if now < endToday {
                LiveActivityManager.shared.startActivity(for: item, themeManager: themeManager)
            }
        }

    }
    
    private func processFetchedAppleCalendarEvents() {
        guard let manager = calendarSyncManager else { return }
        let importedCatId = getOrCreateImportedCategory()
        
        removeImportedData(sourcePrefix: "AppleCalendar")
        
        var imported: [Event] = []
        for ek in manager.appleCalendarEvents {
            let start = ek.startDate ?? Date()
            let title = ek.title ?? "Untitled"
            let externalId = ek.eventIdentifier ?? UUID().uuidString
            imported.append(Event(
                date: start,
                title: title,
                categoryId: importedCatId,
                reminderTime: .none,
                isCompleted: false,
                externalIdentifier: externalId,
                sourceName: "AppleCalendar"
            ))
        }
        
        if !imported.isEmpty {
            events.append(contentsOf: imported)
            saveData()
        }
    }
    
    private func processFetchedAppleReminders() {
        guard let manager = calendarSyncManager else { return }
        let importedCatId = getOrCreateImportedCategory()
        
        removeImportedData(sourcePrefix: "AppleReminders")
        
        var imported: [Event] = []
        for reminder in manager.appleReminders {
            guard let comps = reminder.dueDateComponents,
                  let date = Calendar.current.date(from: comps) else { continue }
            let title = reminder.title ?? "Reminder"
            let externalId = reminder.calendarItemIdentifier
            imported.append(Event(
                date: date,
                title: title,
                categoryId: importedCatId,
                reminderTime: .none,
                isCompleted: reminder.isCompleted,
                externalIdentifier: externalId,
                sourceName: "AppleReminders"
            ))
        }
        
        if !imported.isEmpty {
            events.append(contentsOf: imported)
            saveData()
        }
    }
    
    // MARK: - Setup default integration toggles
    private func registerDefaultIntegrationToggles() {
        UserDefaults.standard.register(defaults: [
            "appleCalendarIntegrationEnabled": true,
            "appleRemindersIntegrationEnabled": true
        ])
    }
    
    // MARK: - Subscriptions to CalendarSyncManager updates
    private func setupCalendarSyncSubscriptions() {
        guard let calendarSyncManager = self.calendarSyncManager else { return }
        
        calendarSyncManager.$googleCalendarEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.processFetchedGoogleCalendarEvents()
                }
            }
            .store(in: &cancellables)
        
        calendarSyncManager.$appleCalendarEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.processFetchedAppleCalendarEvents()
            }
            .store(in: &cancellables)
        
        calendarSyncManager.$appleReminders
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.processFetchedAppleReminders()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - EventsPreviewView
    struct EventsPreviewView: View {
        @EnvironmentObject var viewModel: EventViewModel
        @EnvironmentObject var themeManager: ThemeManager
        
        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Upcoming Reminders")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    NavigationLink(value: AppRoute.events) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .font(.title2)
                    }
                }
                
                let upcomingEvents = viewModel.upcomingEvents()
                
                if upcomingEvents.isEmpty {
                    EmptyEventsView()
                } else {
                    VStack(spacing: 12) {
                        ForEach(upcomingEvents.prefix(3)) { event in
                            EventPreviewCard(event: event)
                                .environmentObject(viewModel)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.currentTheme.quaternaryColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    struct EmptyEventsView: View {
        @EnvironmentObject var themeManager: ThemeManager
        
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "bell.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("No upcoming reminders")
                        .font(.headline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text("Add reminders to stay organized")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.tertiaryColor.opacity(0.5))
            )
        }
    }
    
    struct EventPreviewCard: View {
        @EnvironmentObject var viewModel: EventViewModel
        @EnvironmentObject var themeManager: ThemeManager
        let event: Event
        
        var body: some View {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(Calendar.current.component(.day, from: event.date))")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    Text(monthShort(from: event.date))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary.opacity(0.9))
                }
                .frame(width: 60)
                .padding(.vertical, 6)
                .background(themeManager.currentTheme.primaryColor.opacity(0.12))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Label(timeString(from: event.date), systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(event.category(from: viewModel.categories).name)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.tertiaryColor.opacity(0.6))
                            )
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.tertiaryColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.currentTheme.secondaryColor.opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        
        private func monthShort(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
        
        private func timeString(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    // MARK: - EventsListView with Enhanced Bulk Selection
    struct EventsListView: View {
        @EnvironmentObject var viewModel: EventViewModel
        @EnvironmentObject var themeManager: ThemeManager
        @StateObject private var bulkSelectionManager = BulkSelectionManager()
        @State private var showingAddEvent = false
        @State private var showingAddCategory = false
        @State private var selectedDate = Date()
        @State private var showCalendarView = false
        @State private var showCategories = false
        @State private var pendingCategoryDeletion: Category?
        @State private var showDeleteCategoryAlert = false
        @State private var pendingEventDeletion: Event?
        @State private var showDeleteEventAlert = false
        @State private var showBulkDeleteAlert = false
        
        @State private var showAllUpcoming = false
        @State private var showAllPast = false
        
        var sortedUpcomingEvents: [Event] {
            viewModel.upcomingEvents()
        }
        
        var sortedPastEvents: [Event] {
            viewModel.pastEvents()
        }
        
        var upcomingVisible: [Event] {
            showAllUpcoming ? sortedUpcomingEvents : Array(sortedUpcomingEvents.prefix(5))
        }
        
        var pastVisible: [Event] {
            showAllPast ? sortedPastEvents : Array(sortedPastEvents.prefix(5))
        }
        
        var body: some View {
            VStack(spacing: 0) {
                headerView
                
                if showCalendarView {
                    calendarView
                } else {
                    listView
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(isPresented: $showingAddEvent)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView(isPresented: $showingAddCategory)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            }
            .refreshable {
                await viewModel.refreshLiveData()
            }
            .overlay(alignment: .bottomTrailing) {
                if !bulkSelectionManager.isSelecting {
                    VStack(spacing: 12) {
                        Button(action: { showingAddCategory = true }) {
                            Image(systemName: "tag.fill")
                                .font(.headline.bold())
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .padding(14)
                                .background(Circle().fill(themeManager.currentTheme.secondaryColor.opacity(0.2)))
                                .overlay(Circle().stroke(themeManager.currentTheme.secondaryColor.opacity(0.4), lineWidth: 1))
                                .shadow(color: themeManager.currentTheme.secondaryColor.opacity(0.2), radius: 6, x: 0, y: 3)
                        }
                        
                        Button(action: { showingAddEvent = true }) {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .padding(20)
                                .background(Circle().fill(themeManager.currentTheme.primaryColor))
                                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if bulkSelectionManager.isSelecting {
                        Button("Cancel") {
                            bulkSelectionManager.endSelection()
                        }
                        .foregroundColor(.secondary)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if bulkSelectionManager.isSelecting {
                        Button(selectionAllButtonTitle()) {
                            toggleSelectAll()
                        }
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        Button(role: .destructive) {
                            showBulkDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(bulkSelectionManager.selectedCount() == 0)
                        .foregroundColor(bulkSelectionManager.selectedCount() == 0 ? .secondary : .red)
                    }
                }
            }
            .alert("Delete Selected?", isPresented: $showBulkDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performBulkDelete()
                }
            } message: {
                Text("This will permanently delete \(bulkSelectionManager.selectedCount()) item(s).")
            }
        }
        
        private func selectionAllButtonTitle() -> String {
            switch bulkSelectionManager.selectionContext {
            case .events:
                let total = upcomingVisible.count + pastVisible.count
                let selected = bulkSelectionManager.selectedCount()
                return selected == total && total > 0 ? "Deselect All" : "Select All"
            case .categories:
                let total = viewModel.categories.count
                let selected = bulkSelectionManager.selectedCount()
                return selected == total && total > 0 ? "Deselect All" : "Select All"
            default:
                return "Select All"
            }
        }
        
        private func toggleSelectAll() {
            switch bulkSelectionManager.selectionContext {
            case .events:
                let visibleEvents = upcomingVisible + pastVisible
                let allIDs = Set(visibleEvents.map { $0.id })
                if bulkSelectionManager.selectedEventIDs == allIDs {
                    bulkSelectionManager.deselectAll()
                } else {
                    bulkSelectionManager.selectedEventIDs = allIDs
                }
            case .categories:
                let allIDs = Set(viewModel.categories.map { $0.id })
                if bulkSelectionManager.selectedCategoryIDs.count == allIDs.count {
                    bulkSelectionManager.deselectAll()
                } else {
                    bulkSelectionManager.selectedCategoryIDs = allIDs
                }
            default:
                break
            }
        }
        
        private func performBulkDelete() {
            switch bulkSelectionManager.selectionContext {
            case .events:
                viewModel.bulkDeleteEvents(bulkSelectionManager.selectedEventIDs)
            case .categories:
                viewModel.bulkDeleteCategories(bulkSelectionManager.selectedCategoryIDs)
            case .scheduleItems:
                viewModel.bulkDeleteScheduleItems(bulkSelectionManager.selectedScheduleItemIDs, themeManager: themeManager)
            case .none:
                break
            }
            bulkSelectionManager.endSelection()
        }
        
        private var headerView: some View {
            VStack(spacing: 8) {
                HStack {
                    Picker("View Mode", selection: $showCalendarView) {
                        Text("List").tag(false)
                        Text("Calendar").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                
                if !showCalendarView {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCategories.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .font(.subheadline)
                                Text("Categories")
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: showCategories ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        if bulkSelectionManager.isSelecting {
                            Text("\(bulkSelectionManager.selectedCount()) selected")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                                .animation(.easeInOut(duration: 0.2), value: bulkSelectionManager.selectedCount())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
        
        private var calendarView: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CalendarMonthView(selectedDate: $selectedDate)
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .padding(.horizontal)

                    let dayEvents = viewModel.events(for: selectedDate)
                    if dayEvents.isEmpty {
                        VStack(spacing: 8) {
                            Text("No reminders on this date")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(dayEvents) { event in
                                NavigationLink {
                                    EventEditView(event: event, isNew: false)
                                        .environmentObject(viewModel)
                                        .environmentObject(themeManager)
                                } label: {
                                    EnhancedEventRow(event: event, isPast: event.date < Date())
                                        .environmentObject(viewModel)
                                        .environmentObject(themeManager)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
            .background(Color(.systemGroupedBackground))
        }
        
        private var listView: some View {
            List {
                if showCategories {
                    Section {
                        if bulkSelectionManager.selectionContext == .categories {
                            ForEach(viewModel.categories) { category in
                                HStack {
                                    CategoryRow(category: category)
                                    Spacer()
                                    selectionIndicator(isSelected: bulkSelectionManager.isSelected(category.id))
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    bulkSelectionManager.toggleSelection(category.id)
                                }
                            }
                        } else {
                            ForEach(viewModel.categories) { category in
                                CategoryRow(category: category)
                                    .contextMenu {
                                        Button("Select Multiple", systemImage: "checkmark.circle") {
                                            bulkSelectionManager.startSelection(.categories, initialID: category.id)
                                        }
                                        Button("Delete Category", systemImage: "trash", role: .destructive) {
                                            pendingCategoryDeletion = category
                                            showDeleteCategoryAlert = true
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.6)
                                            .onEnded { _ in
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                impactFeedback.impactOccurred()
                                                bulkSelectionManager.startSelection(.categories, initialID: category.id)
                                            }
                                    )
                            }
                        }
                    } header: {
                        Text("Categories")
                    }
                }
                
                if !sortedUpcomingEvents.isEmpty {
                    Section {
                        ForEach(upcomingVisible) { event in
                            if bulkSelectionManager.selectionContext == .events {
                                HStack {
                                    EnhancedEventRow(event: event)
                                    Spacer()
                                    selectionIndicator(isSelected: bulkSelectionManager.isSelected(event.id))
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    bulkSelectionManager.toggleSelection(event.id)
                                }
                            } else {
                                NavigationLink {
                                    EventEditView(event: event, isNew: false)
                                        .environmentObject(viewModel)
                                        .environmentObject(themeManager)
                                } label: {
                                    EnhancedEventRow(event: event)
                                }
                                .contextMenu {
                                    Button("Select Multiple", systemImage: "checkmark.circle") {
                                        bulkSelectionManager.startSelection(.events, initialID: event.id)
                                    }
                                    Button("Delete Reminder", systemImage: "trash", role: .destructive) {
                                        pendingEventDeletion = event
                                        showDeleteEventAlert = true
                                    }
                                }
                                .contentShape(Rectangle())
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.6)
                                        .onEnded { _ in
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                            impactFeedback.impactOccurred()
                                            bulkSelectionManager.startSelection(.events, initialID: event.id)
                                        }
                                )
                            }
                        }
                        
                        if sortedUpcomingEvents.count > 5 {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        showAllUpcoming.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(showAllUpcoming ? "Show less" : "Show all (\(sortedUpcomingEvents.count))")
                                            .font(.caption.weight(.semibold))
                                        Image(systemName: showAllUpcoming ? "chevron.up" : "chevron.down")
                                            .font(.caption.weight(.bold))
                                    }
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(themeManager.currentTheme.primaryColor.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                            Text("Upcoming Reminders")
                            Spacer()
                            Text("\(sortedUpcomingEvents.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !sortedPastEvents.isEmpty {
                    Section {
                        ForEach(pastVisible) { event in
                            if bulkSelectionManager.selectionContext == .events {
                                HStack {
                                    EnhancedEventRow(event: event, isPast: true)
                                    Spacer()
                                    selectionIndicator(isSelected: bulkSelectionManager.isSelected(event.id))
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    bulkSelectionManager.toggleSelection(event.id)
                                }
                            } else {
                                NavigationLink {
                                    EventEditView(event: event, isNew: false)
                                        .environmentObject(viewModel)
                                        .environmentObject(themeManager)
                                } label: {
                                    EnhancedEventRow(event: event, isPast: true)
                                }
                                .contextMenu {
                                    Button("Select Multiple", systemImage: "checkmark.circle") {
                                        bulkSelectionManager.startSelection(.events, initialID: event.id)
                                    }
                                    Button("Delete Reminder", systemImage: "trash", role: .destructive) {
                                        pendingEventDeletion = event
                                        showDeleteEventAlert = true
                                    }
                                }
                                .contentShape(Rectangle())
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.6)
                                        .onEnded { _ in
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                            impactFeedback.impactOccurred()
                                            bulkSelectionManager.startSelection(.events, initialID: event.id)
                                        }
                                )
                            }
                        }
                        
                        if sortedPastEvents.count > 5 {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        showAllPast.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(showAllPast ? "Show less" : "Show all (\(sortedPastEvents.count))")
                                            .font(.caption.weight(.semibold))
                                        Image(systemName: showAllPast ? "chevron.up" : "chevron.down")
                                            .font(.caption.weight(.bold))
                                    }
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(themeManager.currentTheme.primaryColor.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                            Text("Past Reminders")
                            Spacer()
                            Text("\(sortedPastEvents.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if sortedUpcomingEvents.isEmpty && sortedPastEvents.isEmpty && !showCategories {
                    Section {
                        VStack(spacing: 12) {
                            Text("No reminders found. Tap '+' to add a new reminder.")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .alert("Delete Category?", isPresented: $showDeleteCategoryAlert) {
                Button("Cancel", role: .cancel) { pendingCategoryDeletion = nil }
                Button("Delete", role: .destructive) {
                    if let cat = pendingCategoryDeletion {
                        viewModel.deleteCategory(cat)
                    }
                    pendingCategoryDeletion = nil
                }
            } message: {
                Text("This will remove the category from StuCo.")
            }
            .alert("Delete Reminder?", isPresented: $showDeleteEventAlert) {
                Button("Cancel", role: .cancel) { pendingEventDeletion = nil }
                Button("Delete", role: .destructive) {
                    if let evt = pendingEventDeletion {
                        viewModel.deleteEvent(evt)
                    }
                    pendingEventDeletion = nil
                }
            } message: {
                Text("This will delete the reminder and cancel its notifications.")
            }
        }
        
        private func selectionIndicator(isSelected: Bool) -> some View {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? themeManager.currentTheme.primaryColor : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
    
    // MARK: - Supporting Views
    struct CategoryRow: View {
        let category: Category
        
        var body: some View {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(category.color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
    
    struct EnhancedEventRow: View {
        @EnvironmentObject var viewModel: EventViewModel
        @EnvironmentObject var themeManager: ThemeManager
        let event: Event
        var isPast: Bool = false
        
        var body: some View {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(Calendar.current.component(.day, from: event.date))")
                        .font(.title3.weight(.bold))
                        .foregroundColor(isPast || event.isCompleted ? .secondary : themeManager.currentTheme.primaryColor)
                    Text(monthShort(from: event.date))
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 45)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(isPast || event.isCompleted ? .secondary : .primary)
                        .strikethrough(event.isCompleted)
                    
                    HStack(spacing: 8) {
                        Label(timeString(from: event.date), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(event.category(from: viewModel.categories).name)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(event.category(from: viewModel.categories).color.opacity(0.2))
                            .foregroundColor(event.category(from: viewModel.categories).color)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 4)
            .opacity(isPast || event.isCompleted ? 0.7 : 1.0)
        }
        
        private var backgroundColor: Color {
            if isPast || event.isCompleted {
                return Color(.systemGray6)
            } else {
                return themeManager.currentTheme.primaryColor.opacity(0.1)
            }
        }
        
        private func monthShort(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
        
        private func timeString(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Placeholder Views
    struct AddEventView: View {
        @Binding var isPresented: Bool
        @EnvironmentObject var viewModel: EventViewModel
        @EnvironmentObject var themeManager: ThemeManager

        @State private var title: String = ""
        @State private var date: Date = Date()
        @State private var categoryId: UUID?
        @State private var reminderTime: ReminderTime = .none
        @State private var syncToApple = false
        @State private var syncToGoogle = false

        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Details")) {
                        TextField("Title", text: $title)
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)
                        DatePicker("Date & Time", selection: $date)
                    }

                    Section(header: Text("Category")) {
                        if viewModel.categories.isEmpty {
                            Text("No categories yet. Create one from the Reminders screen.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Category", selection: Binding(
                                get: { categoryId ?? viewModel.categories.first?.id },
                                set: { categoryId = $0 }
                            )) {
                                ForEach(viewModel.categories) { cat in
                                    HStack {
                                        Circle().fill(cat.color).frame(width: 10, height: 10)
                                        Text(cat.name)
                                    }.tag(Optional(cat.id))
                                }
                            }
                        }
                    }

                    Section(header: Text("Reminder")) {
                        Picker("Notify", selection: $reminderTime) {
                            ForEach(ReminderTime.allCases, id: \.self) { rt in
                                Text(rt.displayName).tag(rt)
                            }
                        }
                    }

                    Section(header: Text("Calendar Sync")) {
                        Toggle("Sync to Apple Calendar", isOn: $syncToApple)
                        Toggle("Sync to Google Calendar", isOn: $syncToGoogle)
                    }
                }
                .navigationTitle("Add Reminder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let catId = (categoryId ?? viewModel.categories.first?.id),
                                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            let newEvent = Event(
                                date: date,
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                categoryId: catId,
                                reminderTime: reminderTime,
                                isCompleted: false,
                                externalIdentifier: nil,
                                sourceName: nil,
                                syncToAppleCalendar: syncToApple,
                                syncToGoogleCalendar: syncToGoogle
                            )
                            viewModel.addEvent(newEvent)
                            isPresented = false
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (viewModel.categories.isEmpty && categoryId == nil))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
                .onAppear {
                    if categoryId == nil {
                        categoryId = viewModel.categories.first?.id
                    }
                }
            }
        }
    }

    struct AddCategoryView: View {
        @Binding var isPresented: Bool
        @EnvironmentObject var viewModel: EventViewModel
        @EnvironmentObject var themeManager: ThemeManager

        @State private var name: String = ""
        @State private var color: Color = .blue

        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Category")) {
                        TextField("Name", text: $name)
                        ColorPicker("Color", selection: $color, supportsOpacity: false)
                    }
                }
                .navigationTitle("Add Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let newCategory = Category(name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color)
                            viewModel.addCategory(newCategory)
                            isPresented = false
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
        }
    }

    struct EventEditView: View {
        let event: Event
        let isNew: Bool
        @EnvironmentObject var viewModel: EventViewModel
        @EnvironmentObject var themeManager: ThemeManager
        @Environment(\.dismiss) private var dismiss

        @State private var title: String = ""
        @State private var date: Date = Date()
        @State private var categoryId: UUID?
        @State private var reminderTime: ReminderTime = .none
        @State private var isCompleted: Bool = false
        @State private var syncToApple = false
        @State private var syncToGoogle = false
        @State private var showDeleteAlert = false

        var body: some View {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $title)
                    DatePicker("Date & Time", selection: $date)
                    Toggle("Completed", isOn: $isCompleted)
                }

                Section(header: Text("Category")) {
                    if viewModel.categories.isEmpty {
                        Text("No categories yet. Create one from the Reminders screen.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Category", selection: Binding(
                            get: { categoryId ?? event.categoryId },
                            set: { categoryId = $0 }
                        )) {
                            ForEach(viewModel.categories) { cat in
                                HStack {
                                    Circle().fill(cat.color).frame(width: 10, height: 10)
                                    Text(cat.name)
                                }.tag(Optional(cat.id))
                            }
                        }
                    }
                }

                Section(header: Text("Reminder")) {
                    Picker("Notify", selection: $reminderTime) {
                        ForEach(ReminderTime.allCases, id: \.self) { rt in
                            Text(rt.displayName).tag(rt)
                        }
                    }
                }

                Section(header: Text("Calendar Sync")) {
                    Toggle("Sync to Apple Calendar", isOn: $syncToApple)
                    Toggle("Sync to Google Calendar", isOn: $syncToGoogle)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Reminder")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let catId = (categoryId ?? event.categoryId) as UUID? else { return }
                        var updated = event
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.date = date
                        updated.categoryId = catId
                        updated.reminderTime = reminderTime
                        updated.isCompleted = isCompleted
                        updated.syncToAppleCalendar = syncToApple
                        updated.syncToGoogleCalendar = syncToGoogle
                        viewModel.updateEvent(updated)
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Reminder?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteEvent(event)
                    dismiss()
                }
            } message: {
                Text("This will delete the reminder and cancel its notifications.")
            }
            .onAppear {
                title = event.title
                date = event.date
                categoryId = event.categoryId
                reminderTime = event.reminderTime
                isCompleted = event.isCompleted
                syncToApple = event.syncToAppleCalendar
                syncToGoogle = event.syncToGoogleCalendar
            }
        }
    }

    // MARK: - Previews
    struct EventsModule_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                EventsListView()
                    .environmentObject(EventViewModel())
                    .environmentObject(ThemeManager())
            }
        }
    }
}

// MARK: - Expose nested views as top-level typealiases for use across the app
typealias EventsPreviewView = EventViewModel.EventsPreviewView
typealias EventsListView = EventViewModel.EventsListView

extension Color {
    static let primaryGreen = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 95/255, green: 135/255, blue: 105/255, alpha: 1.0)
        } else {
            return UIColor(red: 134/255, green: 167/255, blue: 137/255, alpha: 1.0)
        }
    })
}

extension Notification.Name {
    static let googleCalendarEventsFetched = Notification.Name("googleCalendarEventsFetched")
}

private struct CalendarMonthView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date

    @State private var currentMonthStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

    private var calendar: Calendar { Calendar.current }

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        if let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedDate.wrappedValue)) {
            _currentMonthStart = State(initialValue: start)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            monthGrid
        }
    }

    private var header: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }

            Spacer()

            Text(monthTitle(for: currentMonthStart))
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? currentMonthStart
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
        }
        .padding(.horizontal, 4)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols // starts with Sun
        return HStack {
            ForEach(0..<7, id: \.self) { idx in
                Text(symbols[idx])
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let days = daysInMonth(startingAt: currentMonthStart)
        let firstWeekdayIndex = (calendar.component(.weekday, from: currentMonthStart) - calendar.firstWeekday + 7) % 7
        let totalCells = days.count + firstWeekdayIndex
        let rows = Int(ceil(Double(totalCells) / 7.0))

        return VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        if index < firstWeekdayIndex {
                            Spacer().frame(maxWidth: .infinity)
                        } else {
                            let dayIndex = index - firstWeekdayIndex
                            if dayIndex < days.count {
                                let date = days[dayIndex]
                                dayCell(for: date)
                            } else {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasEvents = !viewModel.events(for: date).isEmpty

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity, minHeight: 24)

                Circle()
                    .fill(isSelected ? Color.white : (hasEvents ? themeManager.currentTheme.primaryColor : Color.clear))
                    .frame(width: 5, height: 5)
                    .opacity(hasEvents ? 1.0 : 0.0)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme.primaryColor)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.4), lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func monthTitle(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: date)
    }

    private func daysInMonth(startingAt start: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: start),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: start))
        else { return [] }

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }
}