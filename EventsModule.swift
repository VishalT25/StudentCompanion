import SwiftUI
import Combine
import UserNotifications
import ActivityKit
import EventKit

// MARK: - Theme System
enum AppTheme: String, CaseIterable, Identifiable {
    case forest = "Forest"
    case ice = "Ice"
    case fire = "Fire"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var alternateIconName: String? {
        switch self {
        case .forest:
            return "ForestThemeIcon"
        case .ice:
            return "IceThemeIcon"
        case .fire:
            return "FireThemeIcon"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 95/255, green: 135/255, blue: 105/255, alpha: 1.0)
                } else {
                    return UIColor(red: 134/255, green: 167/255, blue: 137/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 95/255, green: 135/255, blue: 155/255, alpha: 1.0)
                } else {
                    return UIColor(red: 134/255, green: 167/255, blue: 187/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 155/255, green: 95/255, blue: 105/255, alpha: 1.0)
                } else {
                    return UIColor(red: 187/255, green: 134/255, blue: 147/255, alpha: 1.0)
                }
            })
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 115/255, green: 145/255, blue: 125/255, alpha: 1.0)
                } else {
                    return UIColor(red: 178/255, green: 200/255, blue: 186/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 115/255, green: 145/255, blue: 165/255, alpha: 1.0)
                } else {
                    return UIColor(red: 178/255, green: 200/255, blue: 220/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 165/255, green: 115/255, blue: 125/255, alpha: 1.0)
                } else {
                    return UIColor(red: 220/255, green: 178/255, blue: 186/255, alpha: 1.0)
                }
            })
        }
    }
    
    var tertiaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 135/255, green: 155/255, blue: 145/255, alpha: 1.0)
                } else {
                    return UIColor(red: 210/255, green: 227/255, blue: 200/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 135/255, green: 155/255, blue: 175/255, alpha: 1.0)
                } else {
                    return UIColor(red: 200/255, green: 227/255, blue: 240/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 175/255, green: 135/255, blue: 145/255, alpha: 1.0)
                } else {
                    return UIColor(red: 240/255, green: 210/255, blue: 200/255, alpha: 1.0)
                }
            })
        }
    }
    
    var quaternaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 65/255, green: 75/255, blue: 70/255, alpha: 1.0)
                } else {
                    return UIColor(red: 235/255, green: 243/255, blue: 232/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 65/255, green: 75/255, blue: 85/255, alpha: 1.0)
                } else {
                    return UIColor(red: 232/255, green: 243/255, blue: 252/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 85/255, green: 65/255, blue: 70/255, alpha: 1.0)
                } else {
                    return UIColor(red: 252/255, green: 235/255, blue: 232/255, alpha: 1.0)
                }
            })
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .forest
    
    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
        
        DispatchQueue.main.async {
            let currentIconName = UIApplication.shared.alternateIconName
            let newIconName = theme.alternateIconName
            
            if currentIconName != newIconName {
                UIApplication.shared.setAlternateIconName(newIconName) { error in
                    if let error = error {
                        print("Error setting alternate app icon: \(error.localizedDescription)")
                    } else {
                        print("App icon changed successfully to \(newIconName ?? "Primary").")
                    }
                }
            }
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

struct Event: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var title: String
    var categoryId: UUID
    var reminderTime: ReminderTime = .none
    var isCompleted: Bool = false
    var externalIdentifier: String? = nil
    var sourceName: String? = nil
    
    func category(from categories: [Category]) -> Category {
        categories.first { $0.id == categoryId } ?? Category(name: "Unknown", color: .gray)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, date, title, categoryId, reminderTime, isCompleted, externalIdentifier, sourceName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        title = try container.decode(String.self, forKey: .title)
        categoryId = try container.decode(UUID.self, forKey: .categoryId)
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        externalIdentifier = try container.decodeIfPresent(String.self, forKey: .externalIdentifier)
        sourceName = try container.decodeIfPresent(String.self, forKey: .sourceName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(title, forKey: .title)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(externalIdentifier, forKey: .externalIdentifier)
        try container.encodeIfPresent(sourceName, forKey: .sourceName)
    }
    
    init(id: UUID = UUID(), date: Date, title: String, categoryId: UUID, reminderTime: ReminderTime = .none, isCompleted: Bool = false, externalIdentifier: String? = nil, sourceName: String? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.categoryId = categoryId
        self.reminderTime = reminderTime
        self.isCompleted = isCompleted
        self.externalIdentifier = externalIdentifier
        self.sourceName = sourceName
    }
}

struct ScheduleItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var daysOfWeek: Set<DayOfWeek>
    var color: Color
    var skippedInstanceIdentifiers: Set<String> = []
    var reminderTime: ReminderTime = .none
    var isLiveActivityEnabled: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, daysOfWeek, color, skippedInstanceIdentifiers, reminderTime, isLiveActivityEnabled
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(Array(daysOfWeek), forKey: .daysOfWeek)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encode(Array(skippedInstanceIdentifiers), forKey: .skippedInstanceIdentifiers)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(isLiveActivityEnabled, forKey: .isLiveActivityEnabled)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        daysOfWeek = Set(try container.decode([DayOfWeek].self, forKey: .daysOfWeek))
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
             color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color(UIColor(red: components[0], green: components[0], blue: components[0], alpha: components.count > 1 ? components[1] : 1.0))
        }
        skippedInstanceIdentifiers = Set(try container.decodeIfPresent([String].self, forKey: .skippedInstanceIdentifiers) ?? [])
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
        isLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveActivityEnabled) ?? true
    }
    
    init(title: String, startTime: Date, endTime: Date, daysOfWeek: Set<DayOfWeek>, color: Color = .blue, reminderTime: ReminderTime = .none, isLiveActivityEnabled: Bool = true) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.color = color
        self.skippedInstanceIdentifiers = []
        self.reminderTime = reminderTime
        self.isLiveActivityEnabled = isLiveActivityEnabled
    }
    
    static func instanceIdentifier(for itemID: UUID, onDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(itemID.uuidString)_\(dateFormatter.string(from: onDate))"
    }

    func isSkipped(onDate: Date) -> Bool {
        let identifier = ScheduleItem.instanceIdentifier(for: self.id, onDate: onDate)
        return skippedInstanceIdentifiers.contains(identifier)
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

class EventViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var events: [Event] = []
    @Published var scheduleItems: [ScheduleItem] = []
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshTime: Date?
    
    private let categoriesKey = "savedCategories"
    private let eventsKey = "savedEvents"
    private let scheduleKey = "savedSchedule"
    private let notificationManager = NotificationManager.shared
    
    // Add dependencies for live data
    private var weatherService: WeatherService?
    private var calendarSyncManager: CalendarSyncManager?
    
    private var cancellables = Set<AnyCancellable>() // For Combine subscribers

    init() {
        loadData()
        Task {
            await notificationManager.requestAuthorization()
        }
        // Observe Google Calendar event fetches
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
    
    // MARK: - Pull to Refresh
    func setLiveDataServices(weatherService: WeatherService?, calendarSyncManager: CalendarSyncManager?) {
        self.weatherService = weatherService
        self.calendarSyncManager = calendarSyncManager
    }
    
    @MainActor
    func refreshLiveData() async {
        print("Starting pull-to-refresh for live data...")
        isRefreshing = true
        
        // Create a task group to run all refresh operations concurrently
        await withTaskGroup(of: Void.self) { group in
            // Refresh weather data
            if let weatherService = weatherService {
                group.addTask {
                    print("Refreshing weather data...")
                    await MainActor.run {
                        weatherService.fetchWeatherData()
                    }
                }
            }
            
            // Refresh calendar data
            if let calendarSyncManager = calendarSyncManager {
                group.addTask {
                    print("Refreshing calendar sync data...")
                    await calendarSyncManager.fetchEventsAndUpdatePublishedProperty()
                    await calendarSyncManager.fetchRemindersAndUpdatePublishedProperty()
                    await self.processFetchedCalendarEvents()
                    await self.processFetchedReminders()
                }
            }
            
            // Add a small delay to make refresh feel natural
            group.addTask {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            // Refresh notification permissions status
            group.addTask {
                print("Refreshing notification permissions...")
                await NotificationManager.shared.checkAuthorizationStatus()
            }
            
            // Add task for refreshing any other live data sources
            group.addTask {
                print("Refreshing additional data sources...")
                await self.refreshAdditionalData()
            }
        }
        
        // Update last refresh time
        lastRefreshTime = Date()
        isRefreshing = false
        
        print("Pull-to-refresh completed successfully!")
        
        // Post notification for other parts of the app that might need to update
        NotificationCenter.default.post(name: .liveDataRefreshed, object: nil)
    }
    
    private func refreshAdditionalData() async {
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        print("Additional data sources refreshed")
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
    
    private func saveData() {
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
    
    func addEvent(_ event: Event) {
        events.append(event)
        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }
        saveData()
    }
    
    func updateEvent(_ event: Event) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            let oldEvent = events[idx]
            events[idx] = event
            
            notificationManager.removeAllEventNotifications(for: oldEvent)
            if event.reminderTime != .none {
                notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
            }
            saveData()
        }
    }
    
    func deleteEvent(_ event: Event) {
        events.removeAll { $0.id == event.id }
        notificationManager.removeAllEventNotifications(for: event)
        saveData()
    }
    
    func markEventCompleted(_ event: Event) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx].isCompleted = true
            notificationManager.removeAllEventNotifications(for: event)
            saveData()
        }
    }
    
    func markEventIncomplete(_ event: Event) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx].isCompleted = false
            if event.reminderTime != .none {
                notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
            }
            saveData()
        }
    }
    
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
    
    func addScheduleItem(_ item: ScheduleItem, themeManager: ThemeManager? = nil) {
        scheduleItems.append(item)
        if item.reminderTime != .none {
            notificationManager.scheduleScheduleItemNotifications(for: item, reminderTime: item.reminderTime)
        }
        saveData()
        if let themeManager, item.isLiveActivityEnabled {
            Task { @MainActor in
                self.manageLiveActivities(themeManager: themeManager)
            }
        }
    }
    
    func updateScheduleItem(_ item: ScheduleItem, themeManager: ThemeManager? = nil) {
        if let idx = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            let oldItem = scheduleItems[idx]
            scheduleItems[idx] = item
            
            scheduleItems[idx].skippedInstanceIdentifiers = oldItem.skippedInstanceIdentifiers

            notificationManager.removeAllScheduleItemNotifications(for: oldItem)
            if item.reminderTime != .none {
                notificationManager.scheduleScheduleItemNotifications(for: item, reminderTime: item.reminderTime)
            }
            saveData()

            if let themeManager {
                Task { @MainActor in
                    if !item.isLiveActivityEnabled && oldItem.isLiveActivityEnabled {
                        LiveActivityManager.shared.endActivity(for: item.id.uuidString)
                    } else if item.isLiveActivityEnabled {
                        self.manageLiveActivities(themeManager: themeManager)
                    }
                }
            }
        }
    }
    
    func deleteScheduleItem(_ item: ScheduleItem, themeManager: ThemeManager? = nil) {
        scheduleItems.removeAll { $0.id == item.id }
        notificationManager.removeAllScheduleItemNotifications(for: item)
        Task { @MainActor in
            LiveActivityManager.shared.endActivity(for: item.id.uuidString)
        }
        saveData()
        if let themeManager {
             Task { @MainActor in
                self.manageLiveActivities(themeManager: themeManager)
             }
        }
    }
    
    func toggleSkip(forInstance scheduleItem: ScheduleItem, onDate: Date, themeManager: ThemeManager? = nil) {
        guard let index = scheduleItems.firstIndex(where: { $0.id == scheduleItem.id }) else { return }
        
        let instanceIdentifier = ScheduleItem.instanceIdentifier(for: scheduleItem.id, onDate: onDate)
        
        if scheduleItems[index].skippedInstanceIdentifiers.contains(instanceIdentifier) {
            scheduleItems[index].skippedInstanceIdentifiers.remove(instanceIdentifier)
        } else {
            scheduleItems[index].skippedInstanceIdentifiers.insert(instanceIdentifier)
        }
        
        let updatedItem = scheduleItems[index] 
        
        if updatedItem.reminderTime != .none {
            notificationManager.removeAllScheduleItemNotifications(for: updatedItem) 
            notificationManager.scheduleScheduleItemNotifications(for: updatedItem, reminderTime: updatedItem.reminderTime)
        }
        
        saveData()
        
        if let themeManager {
            Task { @MainActor in
                let now = Date()
                let calendar = Calendar.current
                if calendar.isDate(onDate, inSameDayAs: now) { 
                    if updatedItem.isSkipped(onDate: now) && updatedItem.id == currentActiveClass(at: now)?.id {
                         LiveActivityManager.shared.endActivity(for: updatedItem.id.uuidString)
                    } else {
                        self.manageLiveActivities(themeManager: themeManager)
                    }
                }
            }
        }
    }
    
    func todaysEvents() -> [Event] {
        let calendar = Calendar.current
        return events.filter {
            calendar.isDate($0.date, inSameDayAs: Date()) && !$0.isCompleted
        }.sorted { $0.date < $1.date }
    }
    
    func todaysSchedule() -> [ScheduleItem] {
        let calendar = Calendar.current
        let todayDate = Date()
        let weekday = calendar.component(.weekday, from: todayDate)
        guard let todayDayOfWeek = DayOfWeek(rawValue: weekday) else { return [] }
        
        return scheduleItems
            .filter { $0.daysOfWeek.contains(todayDayOfWeek) && !$0.isSkipped(onDate: todayDate) }
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
    
    func eventsInMonth(_ date: Date) -> [Event] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        return events.filter { event in
            let eventMonth = calendar.component(.month, from: event.date)
            let eventYear = calendar.component(.year, from: event.date)
            return eventMonth == month && eventYear == year
        }
    }
    
    @MainActor
    func manageLiveActivities(themeManager: ThemeManager) {
        let globalLiveActivitiesEnabled = UserDefaults.standard.bool(forKey: "liveActivitiesEnabled")
        
        guard globalLiveActivitiesEnabled else {
            LiveActivityManager.shared.endAllActivities()
            print("Live Activities are disabled globally in settings.")
            return
        }

        LiveActivityManager.shared.cleanupEndedActivities(scheduleItems: self.scheduleItems)

        if let activeClass = currentActiveClass() {
            LiveActivityManager.shared.startActivity(for: activeClass, themeManager: themeManager)
        } else {
            LiveActivityManager.shared.endAllActivities()
        }
    }
    
    func currentActiveClass(at date: Date = Date()) -> ScheduleItem? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        guard let todayDayOfWeek = DayOfWeek(rawValue: currentWeekday) else { return nil }

        return scheduleItems
            .filter { $0.daysOfWeek.contains(todayDayOfWeek) && !$0.isSkipped(onDate: date) }
            .first { item in
                let itemStartTimeToday = LiveActivityManager.shared.getAbsoluteTime(for: item.startTime, on: date)
                let itemEndTimeToday = LiveActivityManager.shared.getAbsoluteTime(for: item.endTime, on: date)
                return date >= itemStartTimeToday && date < itemEndTimeToday
            }
    }

    private func getOrCreateImportedCategory(sourceBaseName: String, defaultColor: Color) -> Category {
        let categoryName: String
        switch sourceBaseName {
        case "Google Calendar":
            categoryName = "GC Imports"
        case "Apple Calendar":
            categoryName = "AC Imports"
        case "Apple Reminders":
            categoryName = "AR Imports"
        default:
            categoryName = "\(sourceBaseName) Imports"
        }
        
        if let existingCategory = categories.first(where: { $0.name == categoryName }) {
            return existingCategory
        } else {
            if let genericImported = categories.first(where: { $0.name == "Imported" && $0.color == defaultColor }) {
                 return genericImported
            }
            let newCategory = Category(name: categoryName, color: defaultColor)
            addCategory(newCategory) // This already saves data
            return newCategory
        }
    }
    
    func removeImportedData(sourcePrefix: String) {
        events.removeAll { event in
            event.sourceName?.hasPrefix(sourcePrefix) == true
        }
        saveData()
        print("Removed imported events with source prefix: \(sourcePrefix)")
    }
    
    @MainActor
    private func processFetchedCalendarEvents() async {
        guard let fetchedEKvents = calendarSyncManager?.appleCalendarEvents, UserDefaults.standard.bool(forKey: "appleCalendarIntegrationEnabled") else {
            return
        }

        print("Processing \(fetchedEKvents.count) fetched Apple Calendar events...")
        let importedCategory = getOrCreateImportedCategory(sourceBaseName: "Apple Calendar", defaultColor: .gray)

        for ekEvent in fetchedEKvents {
            // Avoid adding duplicates if event already exists (check by externalIdentifier)
            if !events.contains(where: { $0.externalIdentifier == ekEvent.eventIdentifier }) {
                guard let startDate = ekEvent.startDate else { continue } // EKEvent must have a start date
                
                let newEvent = Event(
                    date: startDate,
                    title: ekEvent.title ?? "Untitled Calendar Event",
                    categoryId: importedCategory.id,
                    reminderTime: .none, 
                    isCompleted: false, 
                    externalIdentifier: ekEvent.eventIdentifier,
                    sourceName: "Apple Calendar: \(ekEvent.calendar.title)"
                )
                self.events.append(newEvent)
                print("Added calendar event to app: \(newEvent.title)")
            }
        }
        saveData() // Save after processing all
    }

    @MainActor
    private func processFetchedReminders() async {
        guard let fetchedReminders = calendarSyncManager?.appleReminders, UserDefaults.standard.bool(forKey: "appleRemindersIntegrationEnabled") else {
            return
        }
        
        print("Processing \(fetchedReminders.count) fetched Apple Reminders...")
        let importedCategory = getOrCreateImportedCategory(sourceBaseName: "Apple Reminders", defaultColor: .blue) 
        let calendar = Calendar.current

        for ekReminder in fetchedReminders {
            if !events.contains(where: { $0.externalIdentifier == ekReminder.calendarItemIdentifier }) {
                guard let dueDate = ekReminder.dueDateComponents?.date else { continue } 

                let newEvent = Event(
                    date: dueDate,
                    title: ekReminder.title ?? "Untitled Reminder",
                    categoryId: importedCategory.id,
                    reminderTime: .none, 
                    isCompleted: ekReminder.isCompleted,
                    externalIdentifier: ekReminder.calendarItemIdentifier,
                    sourceName: "Apple Reminders: \(ekReminder.calendar.title)"
                )
                self.events.append(newEvent)
                print("Added reminder to app: \(newEvent.title)")
            }
        }
        saveData() // Save after processing all
    }

    @MainActor
    private func processFetchedGoogleCalendarEvents() async {
        guard let googleEvents = calendarSyncManager?.googleCalendarEvents,
              UserDefaults.standard.bool(forKey: "googleCalendarIntegrationEnabled") else { 
            print("Google Calendar integration disabled or no events fetched.")
            return
        }

        print("EventViewModel: Processing \(googleEvents.count) fetched Google Calendar events...")
        let googleCategory = getOrCreateImportedCategory(sourceBaseName: "Google Calendar", defaultColor: Color(red: 66/255, green: 133/255, blue: 244/255)) 

        var newEventsAdded = 0
        var eventsUpdated = 0

        for gEvent in googleEvents {
            guard let eventId = gEvent.identifier, !eventId.isEmpty else {
                print("Skipping Google event with missing ID.")
                continue
            }
            
            let sourceName = "Google Calendar: \(calendarSyncManager?.googleCalendars.first(where: { $0.identifier == gEvent.organizer?.identifier })?.summary ?? gEvent.organizer?.displayName ?? "Default")"
            
            var eventDate: Date?
            if let startDateTime = gEvent.start?.dateTime?.date {
                eventDate = startDateTime
            } else if let startDate = gEvent.start?.date?.date { // All-day event
                eventDate = startDate
            }

            guard let date = eventDate, let title = gEvent.summary, !title.isEmpty else {
                print("Skipping Google event with missing date or title: \(gEvent.summary ?? "No Title")")
                continue
            }

            // Check if event already exists (imported from Google Calendar)
            if let existingEventIndex = events.firstIndex(where: { $0.externalIdentifier == eventId && $0.sourceName?.hasPrefix("Google Calendar") == true }) {
                // Update existing event
                var updatedEvent = events[existingEventIndex]
                updatedEvent.title = title
                updatedEvent.date = date
                updatedEvent.categoryId = googleCategory.id // Ensure category is correct
                // Update other fields as necessary, e.g., completion status if available
                // GTLRCalendar_Event status: "confirmed", "tentative", "cancelled"
                if gEvent.status == "cancelled" {
                    // Decide how to handle cancelled events (e.g., delete them or mark them differently)
                    print("Google event \(title) was cancelled. Deleting from app.")
                    deleteEvent(updatedEvent) // Assuming deleteEvent handles notifications etc.
                    continue
                }
                
                // For simplicity, we are not mapping all GTLRCalendar_Event fields here.
                // Add more mappings if needed (e.g., description, location).
                
                if events[existingEventIndex].title != updatedEvent.title || events[existingEventIndex].date != updatedEvent.date {
                    updateEvent(updatedEvent)
                    eventsUpdated += 1
                }
            } else {
                // Add as new event
                // For now, all Google events become `Event` type in our app.
                // Handling of recurring events to `ScheduleItem` can be added later.
                if gEvent.status == "cancelled" {
                     print("Google event \(title) is cancelled. Skipping add.")
                     continue
                }

                let newAppEvent = Event(
                    date: date,
                    title: title,
                    categoryId: googleCategory.id,
                    reminderTime: .none, // Google Calendar reminders are separate; decide if/how to map them
                    isCompleted: false, // Or map from gEvent.status if applicable
                    externalIdentifier: eventId,
                    sourceName: sourceName
                )
                addEvent(newAppEvent)
                newEventsAdded += 1
            }
        }

        if newEventsAdded > 0 || eventsUpdated > 0 {
            print("Google Calendar Sync: \(newEventsAdded) new events added, \(eventsUpdated) events updated.")
            saveData() // Ensure data is saved after processing
            NotificationCenter.default.post(name: .liveDataRefreshed, object: nil) // Notify UI to refresh
        } else {
            print("Google Calendar Sync: No new events or updates.")
        }
    }
}

// MARK: - Color Palette (Updated to use ThemeManager)
extension Color {
    static let primaryGreen = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 95/255, green: 135/255, blue: 105/255, alpha: 1.0)
        } else {
            return UIColor(red: 134/255, green: 167/255, blue: 137/255, alpha: 1.0)
        }
    })
    
    static let secondaryGreen = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 115/255, green: 145/255, blue: 125/255, alpha: 1.0)
        } else {
            return UIColor(red: 178/255, green: 200/255, blue: 186/255, alpha: 1.0)
        }
    })
    
    static let tertiaryGreen = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 135/255, green: 155/255, blue: 145/255, alpha: 1.0)
        } else {
            return UIColor(red: 210/255, green: 227/255, blue: 200/255, alpha: 1.0)
        }
    })
    
    static let quaternaryGreen = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 65/255, green: 75/255, blue: 70/255, alpha: 1.0)
        } else {
            return UIColor(red: 235/255, green: 243/255, blue: 232/255, alpha: 1.0)
        }
    })
}

// MARK: - Theme-aware color extensions
extension Color {
    static func themePrimary(_ themeManager: ThemeManager) -> Color {
        themeManager.currentTheme.primaryColor
    }
    
    static func themeSecondary(_ themeManager: ThemeManager) -> Color {
        themeManager.currentTheme.secondaryColor
    }
    
    static func themeTertiary(_ themeManager: ThemeManager) -> Color {
        themeManager.currentTheme.tertiaryColor
    }
    
    static func themeQuaternary(_ themeManager: ThemeManager) -> Color {
        themeManager.currentTheme.quaternaryColor
    }
}

// MARK: - EventsPreviewView (Updated to only show upcoming reminders)
struct EventsPreviewView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Reminders")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                NavigationLink(value: AppRoute.events) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                        .background(Circle().fill(Color.white.opacity(0.2)).frame(width: 32, height: 32))
                }
            }
            
            let upcomingEvents = viewModel.upcomingEvents()
            
            if upcomingEvents.isEmpty {
                EmptyEventsView()
            } else {
                VStack(spacing: 8) {
                    ForEach(upcomingEvents.prefix(3)) { event in
                        EventPreviewCard(event: event)
                            .environmentObject(viewModel)
                    }
                    
                    if upcomingEvents.count > 3 {
                        NavigationLink(value: AppRoute.events) {
                             HStack {
                                Spacer()
                                Text("View All \(upcomingEvents.count) Reminders...")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    themeManager.currentTheme.secondaryColor.opacity(0.9),
                    themeManager.currentTheme.secondaryColor
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

struct EmptyEventsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.7))
            
            Text("No upcoming reminders")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Add reminders to stay organized")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text(monthShort(from: event.date))
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.15))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.headline.weight(.medium))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Label(timeString(from: event.date), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text(event.category(from: viewModel.categories).name)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(event.category(from: viewModel.categories).color.opacity(0.2))
                        .foregroundColor(event.category(from: viewModel.categories).color)
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
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

// MARK: - EventsListView with Calendar
struct EventsListView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddEvent = false
    @State private var showingAddCategory = false
    @State private var selectedDate = Date()
    @State private var showCalendarView = false
    @State private var showCategories = false

    var sortedUpcomingEvents: [Event] {
        viewModel.upcomingEvents()
    }
    
    var sortedPastEvents: [Event] {
        viewModel.pastEvents()
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
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button { showingAddEvent = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    Button { showingAddCategory = true } label: {
                        Image(systemName: "tag.circle.fill")
                            .foregroundColor(themeManager.currentTheme.secondaryColor)
                    }
                }
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
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private var listView: some View {
        List {
            if showCategories {
                Section {
                    ForEach(viewModel.categories.indices, id: \.self) { idx in
                        NavigationLink {
                            CategoryEditView(category: $viewModel.categories[idx], isNew: false)
                                .environmentObject(viewModel)
                                .environmentObject(themeManager)
                        } label: {
                            CategoryRow(category: viewModel.categories[idx])
                        }
                    }
                     .onDelete(perform: deleteCategory)
                } header: {
                    HStack {
                        Text("Categories")
                        Spacer()
                        Text("\(viewModel.categories.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !sortedUpcomingEvents.isEmpty {
                Section {
                    ForEach(sortedUpcomingEvents) { event in
                        NavigationLink {
                            EventEditView(event: event, isNew: false)
                                .environmentObject(viewModel)
                                .environmentObject(themeManager)
                        } label: {
                            EnhancedEventRow(event: event)
                                .environmentObject(viewModel)
                                .environmentObject(themeManager)
                        }
                    }
                    .onDelete(perform: deleteUpcomingEvent)
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
                    ForEach(sortedPastEvents.prefix(10)) { event in
                        NavigationLink {
                            EventEditView(event: event, isNew: false)
                                .environmentObject(viewModel)
                                .environmentObject(themeManager)
                        } label: {
                            EnhancedEventRow(event: event, isPast: true)
                                .environmentObject(viewModel)
                                .environmentObject(themeManager)
                        }
                    }
                    .onDelete(perform: deletePastEvent)
                } header: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                        Text("Recent Past Reminders")
                        Spacer()
                        if sortedPastEvents.count > 10 {
                            Text("10+")
                        } else {
                            Text("\(sortedPastEvents.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
    }
    
    private func deleteCategory(at offsets: IndexSet) {
        offsets.forEach { index in
            let categoryToDelete = viewModel.categories[index]
            viewModel.deleteCategory(categoryToDelete)
        }
    }

    private func deleteUpcomingEvent(at offsets: IndexSet) {
        offsets.forEach { index in
            let eventToDelete = sortedUpcomingEvents[index]
            viewModel.deleteEvent(eventToDelete)
        }
    }

    private func deletePastEvent(at offsets: IndexSet) {
        offsets.forEach { index in
            let eventToDelete = sortedPastEvents[index]
            viewModel.deleteEvent(eventToDelete)
        }
    }
    
    private var calendarView: some View {
        ScrollView {
            VStack(spacing: 20) {
                CalendarGridView(selectedDate: $selectedDate)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
                
                if !viewModel.events(for: selectedDate).isEmpty {
                    eventsForSelectedDateView
                } else {
                    VStack(spacing: 8) {
                        Text("No reminders for \(selectedDate, style: .date)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.refreshLiveData()
        }
    }
    
    private var eventsForSelectedDateView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reminders for \(selectedDate, style: .date)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.events(for: selectedDate)) { event in
                    NavigationLink {
                        EventEditView(event: event, isNew: false)
                            .environmentObject(viewModel)
                            .environmentObject(themeManager)
                    } label: {
                        CalendarEventCard(event: event)
                            .environmentObject(viewModel)
                            .environmentObject(themeManager)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Enhanced Event Row
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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPast || event.isCompleted ? Color(.systemGray6) : themeManager.currentTheme.primaryColor.opacity(0.1))
            )
            
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
                        .padding(.vertical, 2)
                        .background(event.category(from: viewModel.categories).color.opacity(0.2))
                        .foregroundColor(event.category(from: viewModel.categories).color)
                        .cornerRadius(8)
                }
            }
            
            if isPast || event.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green.opacity(0.7))
                    .font(.title3)
            } else {
                Button(action: {
                    viewModel.markEventCompleted(event)
                }) {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .opacity(isPast || event.isCompleted ? 0.7 : 1.0)
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

// MARK: - Category Row
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

// MARK: - Calendar Grid View
struct CalendarGridView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date
    @State private var currentMonth = Date()
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(8)
                        .background(Circle().fill(themeManager.currentTheme.primaryColor.opacity(0.1)))
                }
                
                Spacer()
                
                Text(currentMonth, format: .dateTime.month(.wide).year())
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(8)
                        .background(Circle().fill(themeManager.currentTheme.primaryColor.opacity(0.1)))
                }
            }
            
            calendarGrid
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { daySymbol in
                 Text(daySymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(height: 30)
            }
            
            ForEach(calendarDays(), id: \.self) { date in
                CalendarDayView(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                    hasEvents: !viewModel.events(for: date).isEmpty
                ) {
                    selectedDate = date
                }
                .environmentObject(themeManager)
            }
        }
    }
    
    private func calendarDays() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .day, value: -1, to: monthInterval.end)!)
        else { return [] }
        
        var days: [Date] = []
        var date = monthFirstWeek.start
        
        while date < monthLastWeek.end {
            days.append(date)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDay
        }
        
        return days
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let hasEvents: Bool
    let action: () -> Void
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(textColor)
                
                if hasEvents {
                    Circle()
                        .fill(themeManager.currentTheme.secondaryColor)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary.opacity(0.5)
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return themeManager.currentTheme.primaryColor
        } else if hasEvents && isCurrentMonth {
            return themeManager.currentTheme.primaryColor.opacity(0.1)
        } else if calendar.isDateInToday(date) && isCurrentMonth {
            return Color.gray.opacity(0.15)
        }
        else {
            return Color.clear
        }
    }
}

// MARK: - Calendar Event Card
struct CalendarEventCard: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(event.category(from: viewModel.categories).color)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(event.date, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(event.category(from: viewModel.categories).name)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(event.category(from: viewModel.categories).color.opacity(0.2))
                .foregroundColor(event.category(from: viewModel.categories).color)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.tertiarySystemFill))
        .cornerRadius(8)
    }
}

extension EventsListView {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()
}

extension Notification.Name {
    static let liveDataRefreshed = Notification.Name("liveDataRefreshed")
    static let googleCalendarEventsFetched = Notification.Name("googleCalendarEventsFetched")
    static let googleSignInStateChanged = Notification.Name("googleSignInStateChanged")
}

// MARK: - AddEventView (Enhanced)
struct AddEventView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var date = Date()
    @State private var title = ""
    @State private var selectedCategory: Category?
    @State private var reminderTime: ReminderTime = .none
    @State private var showingReminderPicker = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Reminder Title", text: $title)
                        .font(.headline)
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                } header: {
                    Text("Reminder Details")
                }
                
                Section {
                    if viewModel.categories.isEmpty {
                        Text("No categories available. Please add a category first.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Category", selection: $selectedCategory) {
                            Text("None").tag(nil as Category?)
                            ForEach(viewModel.categories) { cat in
                                HStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(cat.color)
                                        .frame(width: 20, height: 20)
                                    Text(cat.name)
                                }
                                .tag(Optional(cat))
                            }
                        }
                        .onAppear {
                            if selectedCategory == nil, let firstCategory = viewModel.categories.first {
                                selectedCategory = firstCategory
                            }
                        }
                    }
                } header: {
                    Text("Category")
                }
                
                Section {
                    Button(action: {
                        showingReminderPicker = true
                    }) {
                        HStack {
                            Text("Reminder")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(reminderTime.displayName)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    if reminderTime != .none {
                        Text("You'll be notified \(reminderTime.displayName.lowercased()) before the reminder.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Toggle("Mark as Completed", isOn: .constant(false))
                        .tint(themeManager.currentTheme.primaryColor)
                } header: {
                    Text("Status")
                } footer: {
                    Text("Note: This is only for adding new reminders. Marking reminders as completed is typically done after they have passed or are completed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let category = selectedCategory else {
                            print("No category selected")
                            return
                        }
                        let newEvent = Event(date: date, title: title.isEmpty ? "Untitled Reminder" : title, categoryId: category.id, reminderTime: reminderTime, isCompleted: false)
                        viewModel.addEvent(newEvent)
                        isPresented = false
                    }
                    .disabled(title.isEmpty || selectedCategory == nil)
                    .foregroundColor((title.isEmpty || selectedCategory == nil) ? .secondary : themeManager.currentTheme.primaryColor)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showingReminderPicker) {
                CustomReminderPickerView(selectedReminder: $reminderTime)
            }
        }
    }
}

// MARK: - AddCategoryView (Enhanced)
struct AddCategoryView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var color: Color = .blue

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Category Name", text: $name)
                        .font(.headline)
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                } header: {
                    Text("Category Details")
                }
                
                Section {
                    HStack {
                        Text("Preview")
                        Spacer()
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(width: 20, height: 20)
                            Text(name.isEmpty ? "Category Name" : name)
                                .foregroundColor(name.isEmpty ? .secondary : .primary)
                        }
                    }
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let cat = Category(name: name.isEmpty ? "Unnamed Category" : name, color: color)
                        viewModel.addCategory(cat)
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(name.isEmpty ? .secondary : themeManager.currentTheme.primaryColor)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - EventEditView (Enhanced)
struct EventEditView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State var event: Event
    @Environment(\.dismiss) var dismiss
    @State private var showingReminderPicker = false
    var isNew: Bool

    var body: some View {
        Form {
            Section {
                TextField("Reminder Title", text: $event.title)
                    .font(.headline)
                
                DatePicker("Date & Time", selection: $event.date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
            } header: {
                Text("Reminder Details")
            }
            
            Section {
                let categoryBinding = Binding<UUID>(
                    get: { event.categoryId },
                    set: { event.categoryId = $0 }
                )
                Picker("Category", selection: categoryBinding) {
                    ForEach(viewModel.categories, id: \.id) { cat in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cat.color)
                                .frame(width: 20, height: 20)
                            Text(cat.name)
                        }
                        .tag(cat.id)
                    }
                }
                 .onAppear {
                    if !viewModel.categories.contains(where: { $0.id == event.categoryId }), let firstCategory = viewModel.categories.first {
                        event.categoryId = firstCategory.id
                    }
                }
            } header: {
                Text("Category")
            }
            
            Section {
                Button(action: {
                    showingReminderPicker = true
                }) {
                    HStack {
                        Text("Reminder")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(event.reminderTime.displayName)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Reminder")
            } footer: {
                if event.reminderTime != .none {
                    Text("You'll be notified \(event.reminderTime.displayName.lowercased()) before the reminder.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Toggle("Mark as Completed", isOn: $event.isCompleted)
                    .tint(themeManager.currentTheme.primaryColor)
            } header: {
                Text("Status")
            } footer: {
                if event.isCompleted {
                    Text("This reminder is marked as completed and won't appear in today's reminders.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !isNew {
                Section {
                    Button(role: .destructive) {
                        viewModel.deleteEvent(event)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete Reminder")
                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle(isNew ? "Add Reminder" : "Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") {
                    if isNew {
                        viewModel.addEvent(event)
                    } else {
                        viewModel.updateEvent(event)
                    }
                    dismiss()
                }
                .disabled(event.title.isEmpty)
                .foregroundColor(event.title.isEmpty ? .secondary : themeManager.currentTheme.primaryColor)
            }
            if isNew {
                 ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                 }
            }
        }
        .sheet(isPresented: $showingReminderPicker) {
            CustomReminderPickerView(selectedReminder: $event.reminderTime)
        }
    }
}

// MARK: - CategoryEditView (Enhanced)
struct CategoryEditView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var category: Category
    @Environment(\.dismiss) var dismiss
    var isNew: Bool

    var body: some View {
        Form {
            Section {
                TextField("Category Name", text: $category.name)
                    .font(.headline)
                ColorPicker("Color", selection: $category.color, supportsOpacity: false)
            } header: {
                Text("Category Details")
            }
            
            Section {
                HStack {
                    Text("Preview")
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(category.color)
                            .frame(width: 20, height: 20)
                        Text(category.name.isEmpty ? "Category Name" : category.name)
                            .foregroundColor(category.name.isEmpty ? .secondary : .primary)
                    }
                }
            }
            
            if !isNew {
                Section {
                    Button(role: .destructive) {
                        viewModel.deleteCategory(category)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete Category")
                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle(isNew ? "Add Category" : "Edit Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") {
                    if isNew {
                        viewModel.addCategory(category)
                    } else {
                        viewModel.updateCategory(category)
                    }
                    dismiss()
                }
                .disabled(category.name.isEmpty)
                .foregroundColor(category.name.isEmpty ? .secondary : themeManager.currentTheme.primaryColor)
            }
             if isNew {
                 ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                 }
            }
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
