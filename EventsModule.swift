import SwiftUI
import Combine

// MARK: - Extensions at file scope
extension Notification.Name {
    static let googleCalendarEventsFetched = Notification.Name("googleCalendarEventsFetched")
}

extension Color {
    static let primaryGreen = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 95/255, green: 135/255, blue: 105/255, alpha: 1.0)
        } else {
            return UIColor(red: 134/255, green: 167/255, blue: 137/255, alpha: 1.0)
        }
    })
}

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
    
    var short: String {
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
    
    var full: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    static func from(weekday: Int) -> DayOfWeek {
        return DayOfWeek(rawValue: weekday) ?? .sunday
    }
}

@MainActor
class EventViewModel: ObservableObject, RealtimeSyncDelegate {
    @Published var categories: [Category] = []
    @Published var events: [Event] = []
    @Published var schedules: [ScheduleItem] = [] 
    @Published var scheduleItems: [ScheduleItem] = [] 
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshTime: Date?
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = "Ready"
    
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
    private let coursesKey = "savedCourses"
    private let notificationManager = NotificationManager.shared
    private let realtimeSyncManager = RealtimeSyncManager.shared
    
    private var weatherService: WeatherService?
    private var calendarSyncManager: CalendarSyncManager?
    
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true
    
    private func updateSmartEngineWithCourses() {
        let courseNames = courses.map { $0.name }
    }
    
    init() {
        realtimeSyncManager.eventsDelegate = self
        
        loadData()
        loadCourses()
        
        setupSyncStatusObservation()
        
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
                Task {
                    await self?.processFetchedGoogleCalendarEvents()
                }
            }
            .store(in: &cancellables)
        
        Task {
            await realtimeSyncManager.ensureStarted()
            await self.refreshLiveData()
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decodedCategories = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decodedCategories
        }
        
        if let data = UserDefaults.standard.data(forKey: eventsKey),
           let decodedEvents = try? JSONDecoder().decode([Event].self, from: data) {
            events = decodedEvents
        }
        
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
    
    func todaysEvents() -> [Event] {
        let today = Date()
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.date, inSameDayAs: today) }
            .sorted { $0.date < $1.date }
    }
    
    func upcomingEvents() -> [Event] {
        let now = Date()
        return events.filter { $0.date > now }.sorted { $0.date < $1.date }
    }
    
    func pastEvents() -> [Event] {
        let now = Date()
        return events.filter { $0.date <= now }.sorted { $0.date > $1.date }
    }
    
    func events(for date: Date) -> [Event] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.date, inSameDayAs: date) }
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
        saveDataLocally()
    }
    
    func markEventCompleted(_ event: Event) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        
        var updatedEvent = event
        updatedEvent.isCompleted = true
        
        events[index] = updatedEvent
        saveDataLocally()
        
        notificationManager.removeAllEventNotifications(for: updatedEvent)
        
        syncEventToDatabase(updatedEvent, action: .update)
    }
    
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        switch (table, action) {
        case ("events", "SYNC"):
            if let eventsData = data["events"] as? [DatabaseEvent] {
                syncEventsFromDatabase(eventsData)
            }
        case ("events", "INSERT"):
            if let eventData = try? JSONSerialization.data(withJSONObject: data),
               let dbEvent = try? JSONDecoder().decode(DatabaseEvent.self, from: eventData) {
                handleEventInsert(dbEvent)
            }
        case ("events", "UPDATE"):
            if let eventData = try? JSONSerialization.data(withJSONObject: data),
               let dbEvent = try? JSONDecoder().decode(DatabaseEvent.self, from: eventData) {
                handleEventUpdate(dbEvent)
            }
        case ("events", "DELETE"):
            if let eventId = data["id"] as? String {
                handleEventDelete(eventId)
            }
            
        case ("categories", "SYNC"):
            if let categoriesData = data["categories"] as? [DatabaseCategory] {
                syncCategoriesFromDatabase(categoriesData)
            }
        case ("categories", "INSERT"):
            if let categoryData = try? JSONSerialization.data(withJSONObject: data),
               let dbCategory = try? JSONDecoder().decode(DatabaseCategory.self, from: categoryData) {
                handleCategoryInsert(dbCategory)
            }
        case ("categories", "UPDATE"):
            if let categoryData = try? JSONSerialization.data(withJSONObject: data),
               let dbCategory = try? JSONDecoder().decode(DatabaseCategory.self, from: categoryData) {
                handleCategoryUpdate(dbCategory)
            }
        case ("categories", "DELETE"):
            if let categoryId = data["id"] as? String {
                handleCategoryDelete(categoryId)
            }
            
        default:
            break
        }
    }
    
    private func syncEventsFromDatabase(_ events: [DatabaseEvent]) {
        let localEvents = events.map { $0.toLocal() }
        
        self.events = localEvents
        
        if !isInitialLoad {
            saveDataLocally() 
        }
    }
    
    private func syncCategoriesFromDatabase(_ categories: [DatabaseCategory]) {
        let localCategories = categories.map { $0.toLocal() }
        
        self.categories = localCategories
        
        if !isInitialLoad {
            saveDataLocally() 
        }
    }
    
    private func handleEventInsert(_ dbEvent: DatabaseEvent) {
        let localEvent = dbEvent.toLocal()
        
        if !events.contains(where: { $0.id == localEvent.id }) {
            events.append(localEvent)
            saveDataLocally()
        }
    }
    
    private func handleEventUpdate(_ dbEvent: DatabaseEvent) {
        let localEvent = dbEvent.toLocal()
        
        if let index = events.firstIndex(where: { $0.id == localEvent.id }) {
            events[index] = localEvent
            saveDataLocally()
        }
    }
    
    private func handleEventDelete(_ eventId: String) {
        if let uuid = UUID(uuidString: eventId),
           let index = events.firstIndex(where: { $0.id == uuid }) {
            let removedEvent = events.remove(at: index)
            saveDataLocally()
        }
    }
    
    private func handleCategoryInsert(_ dbCategory: DatabaseCategory) {
        let localCategory = dbCategory.toLocal()
        
        if !categories.contains(where: { $0.id == localCategory.id }) {
            categories.append(localCategory)
            saveDataLocally()
        }
    }
    
    private func handleCategoryUpdate(_ dbCategory: DatabaseCategory) {
        let localCategory = dbCategory.toLocal()
        
        if let index = categories.firstIndex(where: { $0.id == localCategory.id }) {
            categories[index] = localCategory
            saveDataLocally()
        }
    }
    
    private func handleCategoryDelete(_ categoryId: String) {
        if let uuid = UUID(uuidString: categoryId),
           let index = categories.firstIndex(where: { $0.id == uuid }) {
            let removedCategory = categories.remove(at: index)
            saveDataLocally()
        }
    }
    
    func addEvent(_ event: Event) {
        events.append(event)
        saveDataLocally()
        
        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }
        
        handleCalendarSyncForNewEvent(event)
        
        syncEventToDatabase(event, action: .create)
    }
    
    func updateEvent(_ event: Event) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        
        let oldEvent = events[idx]
        events[idx] = event
        saveDataLocally()
        
        notificationManager.removeAllEventNotifications(for: oldEvent)
        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }
        
        handleCalendarSyncOnUpdate(oldEvent: oldEvent, newEvent: event)
        
        syncEventToDatabase(event, action: .update)
    }
    
    func deleteEvent(_ event: Event) {
        events.removeAll { $0.id == event.id }
        saveDataLocally()
        
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
        
        syncEventToDatabase(event, action: .delete)
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
        saveDataLocally()
        
        syncCategoryToDatabase(category, action: .create)
    }
    
    func updateCategory(_ category: Category) {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
            saveDataLocally()
            
            syncCategoryToDatabase(category, action: .update)
        }
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveDataLocally()
        
        syncCategoryToDatabase(category, action: .delete)
    }
    
    private func syncEventToDatabase(_ event: Event, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            return
        }
        
        let dbEvent = DatabaseEvent(from: event, userId: userId)
        
        do {
            let data = try JSONEncoder().encode(dbEvent)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            let operation = SyncOperation(
                type: .events,
                action: action,
                data: dict
            )
            
            realtimeSyncManager.queueSyncOperation(operation)
        } catch {
        }
    }
    
    private func syncCategoryToDatabase(_ category: Category, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            return
        }
        
        let dbCategory = DatabaseCategory(from: category, userId: userId)
        
        do {
            let data = try JSONEncoder().encode(dbCategory)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            let operation = SyncOperation(
                type: .categories,
                action: action,
                data: dict
            )
            
            realtimeSyncManager.queueSyncOperation(operation)
        } catch {
        }
    }
    
    @MainActor
    func refreshLiveData() async {
        isRefreshing = true
        
        await realtimeSyncManager.refreshAllData()
        
        isInitialLoad = false
        
        lastRefreshTime = Date()
        isRefreshing = false
    }
    
    private func setupSyncStatusObservation() {
        realtimeSyncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status.displayName
                self?.isSyncing = status.isActive
            }
            .store(in: &cancellables)
    }
    
    private func saveDataLocally() {
        do {
            let encoder = JSONEncoder()
            let categoriesData = try encoder.encode(categories)
            let eventsData = try encoder.encode(events)
            let scheduleData = try encoder.encode(scheduleItems)
            let coursesData = try encoder.encode(courses)
            UserDefaults.standard.set(categoriesData, forKey: categoriesKey)
            UserDefaults.standard.set(eventsData, forKey: eventsKey)
            UserDefaults.standard.set(scheduleData, forKey: scheduleKey)
            UserDefaults.standard.set(coursesData, forKey: coursesKey)
        } catch {
        }
    }
    
    private func handleCalendarSyncForNewEvent(_ event: Event) {
        if event.syncToAppleCalendar || event.syncToGoogleCalendar {
            guard let calendarSyncManager = calendarSyncManager else {
                return
            }
            
            Task {
                var eventToUpdate = event
                if let eventIndex = events.firstIndex(where: { $0.id == event.id }) {
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
                    
                    await MainActor.run {
                        self.events[eventIndex] = eventToUpdate
                        self.saveDataLocally()
                        self.syncEventToDatabase(eventToUpdate, action: .update)
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
        let symbols = calendar.shortWeekdaySymbols 
        return HStack {
            ForEach(0..<7, id: \.self) { idx in
                Text(symbols[idx])
                    .font(.forma(.caption2))
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
                    .font(.forma(.subheadline))
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

struct CategoryRow: View {
    let category: Category
    @EnvironmentObject var themeManager: ThemeManager
    
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
                .font(.forma(.subheadline))
            
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
                    .font(.forma(.title3))
                    .foregroundColor(isPast || event.isCompleted ? .secondary : themeManager.currentTheme.primaryColor)
                Text(monthShort(from: event.date))
                    .font(.forma(.caption2))
                    .foregroundColor(.secondary)
            }
            .frame(width: 45)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.forma(.headline))
                    .foregroundColor(isPast || event.isCompleted ? .secondary : .primary)
                    .strikethrough(event.isCompleted)
                
                HStack(spacing: 8) {
                    Label(timeString(from: event.date), systemImage: "clock")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(event.category(from: viewModel.categories).name)
                        .font(.forma(.caption))
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
                Section(header: Text("Details").font(.forma(.caption))) {
                    TextField("Title", text: $title)
                        .font(.forma(.body))
                    DatePicker("Date & Time", selection: $date)
                        .font(.forma(.body))
                }

                Section(header: Text("Category").font(.forma(.caption))) {
                    if viewModel.categories.isEmpty {
                        Text("No categories yet. Create one from the Reminders screen.")
                            .font(.forma(.footnote))
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
                                        .font(.forma(.body))
                                }.tag(Optional(cat.id))
                            }
                        }
                    }
                }

                Section(header: Text("Reminder").font(.forma(.caption))) {
                    Picker("Notify", selection: $reminderTime) {
                        ForEach(ReminderTime.allCases, id: \.self) { rt in
                            Text(rt.displayName)
                                .font(.forma(.body))
                                .tag(rt)
                        }
                    }
                    .font(.forma(.body))
                }

                Section(header: Text("Calendar Sync").font(.forma(.caption))) {
                    Toggle("Sync to Apple Calendar", isOn: $syncToApple)
                        .font(.forma(.body))
                    Toggle("Sync to Google Calendar", isOn: $syncToGoogle)
                        .font(.forma(.body))
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(.forma(.body))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let catId = (categoryId ?? viewModel.categories.first?.id),
                              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        let newEvent = Event(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines), date: date,
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
                    .font(.forma(.body))
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
                Section(header: Text("Category").font(.forma(.caption))) {
                    TextField("Name", text: $name)
                        .font(.forma(.body))
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(.forma(.body))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newCategory = Category(name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color)
                        viewModel.addCategory(newCategory)
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.forma(.body))
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
            Section(header: Text("Details").font(.forma(.caption))) {
                TextField("Title", text: $title)
                    .font(.forma(.body))
                DatePicker("Date & Time", selection: $date)
                    .font(.forma(.body))
                Toggle("Completed", isOn: $isCompleted)
                    .font(.forma(.body))
            }

            Section(header: Text("Category").font(.forma(.caption))) {
                if viewModel.categories.isEmpty {
                    Text("No categories yet. Create one from the Reminders screen.")
                        .font(.forma(.footnote))
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
                                    .font(.forma(.body))
                            }.tag(Optional(cat.id))
                        }
                    }
                }
            }

            Section(header: Text("Reminder").font(.forma(.caption))) {
                Picker("Notify", selection: $reminderTime) {
                    ForEach(ReminderTime.allCases, id: \.self) { rt in
                        Text(rt.displayName)
                            .font(.forma(.body))
                            .tag(rt)
                    }
                }
                .font(.forma(.body))
            }

            Section(header: Text("Calendar Sync").font(.forma(.caption))) {
                Toggle("Sync to Apple Calendar", isOn: $syncToApple)
                    .font(.forma(.body))
                Toggle("Sync to Google Calendar", isOn: $syncToGoogle)
                    .font(.forma(.body))
            }

            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Reminder")
                            .font(.forma(.body, weight: .semibold))
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
                .font(.forma(.body, weight: .semibold))
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
    
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @Environment(\.colorScheme) var colorScheme
    
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
        ZStack {
            VStack(spacing: 0) {
                enhancedHeaderView
                
                if showCalendarView {
                    calendarView
                } else {
                    if sortedUpcomingEvents.isEmpty && sortedPastEvents.isEmpty && !showCategories {
                        ScrollView {
                            spectacularEmptyState
                                .padding(.top, 20)
                                .padding(.horizontal, 20)
                        }
                    } else {
                        listView
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            magicalFloatingButton
        }
        .onAppear {
            startAnimations()
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
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.15
        }
    }

    var enhancedHeaderView: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                Text("My Reminders")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCalendarView = false
                        }
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.forma(.callout, weight: .medium))
                            .foregroundColor(!showCalendarView ? .white : themeManager.currentTheme.primaryColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(!showCalendarView ? themeManager.currentTheme.primaryColor : .clear)
                            )
                            .overlay(
                                Circle()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    .opacity(!showCalendarView ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCalendarView = true
                        }
                    }) {
                        Image(systemName: "calendar")
                            .font(.forma(.callout, weight: .medium))
                            .foregroundColor(showCalendarView ? .white : themeManager.currentTheme.primaryColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(showCalendarView ? themeManager.currentTheme.primaryColor : .clear)
                            )
                            .overlay(
                                Circle()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    .opacity(showCalendarView ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCategories.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "tag")
                            .font(.forma(.subheadline))
                        Text("Categories")
                            .font(.forma(.subheadline, weight: .medium))
                        Image(systemName: showCategories ? "chevron.up" : "chevron.down")
                            .font(.forma(.caption))
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                
                if bulkSelectionManager.isSelecting {
                    Text("\(bulkSelectionManager.selectedCount()) selected")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: bulkSelectionManager.selectedCount())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color.clear)
    }

    var calendarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CalendarMonthView(selectedDate: $selectedDate)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
                    .padding(.horizontal, 16)

                let dayEvents = viewModel.events(for: selectedDate)
                if dayEvents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle")
                            .font(.forma(.title2))
                            .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
                        
                        Text("No reminders on this date")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentTheme.primaryColor.opacity(0.3),
                                                themeManager.currentTheme.secondaryColor.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 12) {
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
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }
    
    var listView: some View {
        List {
            if showCategories {
                Section {
                    if bulkSelectionManager.selectionContext == .categories {
                        ForEach(viewModel.categories) { category in
                            HStack {
                                CategoryRow(category: category)
                                Spacer()
                                Image(systemName: bulkSelectionManager.isSelected(category.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.forma(.title3))
                                    .foregroundColor(bulkSelectionManager.isSelected(category.id) ? themeManager.currentTheme.primaryColor : .secondary)
                                    .animation(.easeInOut(duration: 0.2), value: bulkSelectionManager.isSelected(category.id))
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
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        Text("Categories")
                        Spacer()
                        Button("Add Category", systemImage: "plus") {
                            showingAddCategory = true
                        }
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
            
            if !sortedUpcomingEvents.isEmpty {
                Section {
                    ForEach(upcomingVisible) { event in
                        if bulkSelectionManager.selectionContext == .events {
                            HStack {
                                EnhancedEventRow(event: event)
                                Spacer()
                                Image(systemName: bulkSelectionManager.isSelected(event.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.forma(.title3))
                                    .foregroundColor(bulkSelectionManager.isSelected(event.id) ? themeManager.currentTheme.primaryColor : .secondary)
                                    .animation(.easeInOut(duration: 0.2), value: bulkSelectionManager.isSelected(event.id))
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
                                        .font(.forma(.caption))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                    Image(systemName: showAllUpcoming ? "chevron.up" : "chevron.down")
                                        .font(.forma(.caption))
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
                            .font(.forma(.caption))
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
                                Image(systemName: bulkSelectionManager.isSelected(event.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.forma(.title3))
                                    .foregroundColor(bulkSelectionManager.isSelected(event.id) ? themeManager.currentTheme.primaryColor : .secondary)
                                    .animation(.easeInOut(duration: 0.2), value: bulkSelectionManager.isSelected(event.id))
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
                                        .font(.forma(.caption))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                    Image(systemName: showAllPast ? "chevron.up" : "chevron.down")
                                        .font(.forma(.caption))
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
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .scrollContentBackground(.hidden)
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
    
    var spectacularEmptyState: some View {
        VStack(spacing: 32) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(pulseAnimation + Double(index) * 0.1)
                        .animation(
                            .easeInOut(duration: 3.0 + Double(index) * 0.5)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                Image(systemName: "star.circle")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulseAnimation * 0.95 + 0.05)
            }
            
            VStack(spacing: 16) {
                Text("Stay on top of everything")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Your First Reminder") {
                showingAddEvent = true
            }
            .font(.forma(.headline, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.4),
                    radius: 16, x: 0, y: 8
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.2),
                    radius: 8, x: 0, y: 4
                )
            )
            .buttonStyle(EnhancedButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.1),
                    radius: 24, x: 0, y: 12
                )
        )
    }
    
    var magicalFloatingButton: some View {
        Button(action: { showingAddEvent = true }) {
            Image(systemName: "plus")
                .font(.forma(.title2, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeManager.currentTheme.darkModeAccentHue.opacity(0.6),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .scaleEffect(pulseAnimation * 0.3 + 0.7)
                            .opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity : 0.3)
                        
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.4),
                                        Color.clear,
                                        Color.clear
                                    ],
                                    center: .center,
                                    angle: .degrees(animationOffset * 0.5)
                                )
                            )
                    }
                    .shadow(
                        color: themeManager.currentTheme.primaryColor.opacity(0.4),
                        radius: 20, x: 0, y: 10
                    )
                    .shadow(
                        color: themeManager.currentTheme.darkModeAccentHue.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.6 : 0.2),
                        radius: 12, x: 0, y: 6
                    )
                )
        }
        .buttonStyle(MagicalButtonStyle())
        .padding(.trailing, 24)
        .padding(.bottom, 32)
    }
}

struct EventsModule_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EventsListView()
                .environmentObject(EventViewModel())
                .environmentObject(ThemeManager())
        }
    }
}