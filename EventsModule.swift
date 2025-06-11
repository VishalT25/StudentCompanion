import SwiftUI
import Combine
import UserNotifications
import ActivityKit

// MARK: - Theme System
enum AppTheme: String, CaseIterable, Identifiable {
    case forest = "Forest"
    case ice = "Ice"
    case fire = "Fire"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
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
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color) // Provide default if components nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            // Handle cases where color components might not be as expected, e.g. grayscale
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

    func category(from categories: [Category]) -> Category {
        categories.first { $0.id == categoryId } ?? Category(name: "Unknown", color: .gray)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, date, title, categoryId, reminderTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        title = try container.decode(String.self, forKey: .title)
        categoryId = try container.decode(UUID.self, forKey: .categoryId)
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(title, forKey: .title)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(reminderTime, forKey: .reminderTime)
    }
    
    init(date: Date, title: String, categoryId: UUID, reminderTime: ReminderTime = .none) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.categoryId = categoryId
        self.reminderTime = reminderTime
    }
}

struct ScheduleItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var daysOfWeek: Set<DayOfWeek>
    var color: Color
    var skippedWeeks: Set<String> = [] // Store week identifiers (e.g., "2024-W01")
    var reminderTime: ReminderTime = .none
    
    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, daysOfWeek, color, skippedWeeks, reminderTime
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(Array(daysOfWeek), forKey: .daysOfWeek)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color) // Provide default
        try container.encode(Array(skippedWeeks), forKey: .skippedWeeks)
        try container.encode(reminderTime, forKey: .reminderTime)
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
        skippedWeeks = Set(try container.decodeIfPresent([String].self, forKey: .skippedWeeks) ?? [])
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
    }
    
    init(title: String, startTime: Date, endTime: Date, daysOfWeek: Set<DayOfWeek>, color: Color = .blue, reminderTime: ReminderTime = .none) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.color = color
        self.skippedWeeks = []
        self.reminderTime = reminderTime
    }
    
    func isSkippedForCurrentWeek() -> Bool {
        let weekIdentifier = ScheduleItem.sharedForWeekIdentifier.getCurrentWeekIdentifier() // Use shared utility
        return skippedWeeks.contains(weekIdentifier)
    }
}

fileprivate struct ScheduleItemWeekIdentifierFetcher {
    static let shared = ScheduleItemWeekIdentifierFetcher()
    private init() {}

    func getCurrentWeekIdentifier() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let week = calendar.component(.weekOfYear, from: Date())
        return "\(year)-W\(String(format: "%02d", week))"
    }
}
extension ScheduleItem {
    // Make it static or provide a mechanism for ScheduleItem to call it
    fileprivate static var sharedForWeekIdentifier = ScheduleItemWeekIdentifierFetcher.shared
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
    
    private let categoriesKey = "savedCategories"
    private let eventsKey = "savedEvents"
    private let scheduleKey = "savedSchedule"
    private let notificationManager = NotificationManager.shared // Assuming NotificationManager is a singleton
    
    init() {
        loadData()
        Task {
            await notificationManager.requestAuthorization()
        }
    }
    
    private func loadData() {
        // ... (existing loadData implementation, ensure Color decoding is robust)
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
            Category(name: "Personal", color: .purple)
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
    
    // MARK: - Live Activity Management
    func currentActiveClass(at date: Date = Date()) -> ScheduleItem? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        guard let todayDayOfWeek = DayOfWeek(rawValue: currentWeekday) else { return nil }

        return scheduleItems
            .filter { $0.daysOfWeek.contains(todayDayOfWeek) && !$0.isSkippedForCurrentWeek() }
            .first { item in
                let itemStartTimeToday = LiveActivityManager.shared.getAbsoluteTime(for: item.startTime, on: date)
                let itemEndTimeToday = LiveActivityManager.shared.getAbsoluteTime(for: item.endTime, on: date)
                return date >= itemStartTimeToday && date < itemEndTimeToday
            }
    }

    @MainActor
    func manageLiveActivities(themeManager: ThemeManager) {
        // Reading directly from UserDefaults. Ensure "liveActivitiesEnabled" is the correct key used in SettingsView's AppStorage.
        let liveActivitiesEnabled = UserDefaults.standard.bool(forKey: "liveActivitiesEnabled")

        guard liveActivitiesEnabled else {
            LiveActivityManager.shared.endAllActivities() // End all if setting is off
            print("Live Activities are disabled in settings.")
            return
        }

        LiveActivityManager.shared.cleanupEndedActivities(scheduleItems: self.scheduleItems)

        if let activeClass = currentActiveClass() { // 'activeClass' implies schedule item, consistent with current implementation
            LiveActivityManager.shared.startActivity(for: activeClass, themeManager: themeManager)
        } else {
            // Logic for when no class is active
            // Optional: If no class is active, one might ensure all *class* activities are ended.
            // LiveActivityManager.shared.endAllActivities() // Or a more specific "endAllClassActivities()"
            // However, cleanupEndedActivities and the guard for liveActivitiesEnabled should mostly cover this.
        }
    }
    
    func addScheduleItem(_ item: ScheduleItem, themeManager: ThemeManager? = nil) {
        scheduleItems.append(item)
        if item.reminderTime != .none {
            notificationManager.scheduleScheduleItemNotifications(for: item, reminderTime: item.reminderTime)
        }
        saveData()
        if let themeManager {
            Task { @MainActor in
                self.manageLiveActivities(themeManager: themeManager)
            }
        }
    }
    
    func updateScheduleItem(_ item: ScheduleItem, themeManager: ThemeManager? = nil) {
        if let idx = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            let oldItem = scheduleItems[idx]
            scheduleItems[idx] = item
            
            notificationManager.removeAllScheduleItemNotifications(for: oldItem)
            if item.reminderTime != .none {
                notificationManager.scheduleScheduleItemNotifications(for: item, reminderTime: item.reminderTime)
            }
            saveData()
            if let themeManager {
                Task { @MainActor in
                    LiveActivityManager.shared.updateActivity(for: item, themeManager: themeManager) // Update existing
                    self.manageLiveActivities(themeManager: themeManager) // Re-evaluate current overall
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
    
    func toggleSkipForCurrentWeek(scheduleItem: ScheduleItem, themeManager: ThemeManager? = nil) {
        if let index = scheduleItems.firstIndex(where: { $0.id == scheduleItem.id }) {
            let weekIdentifier = self.getCurrentWeekIdentifier() // Call within EventViewModel
            if scheduleItems[index].skippedWeeks.contains(weekIdentifier) {
                scheduleItems[index].skippedWeeks.remove(weekIdentifier)
            } else {
                scheduleItems[index].skippedWeeks.insert(weekIdentifier)
            }
            
            let item = scheduleItems[index]
            if item.reminderTime != .none {
                notificationManager.removeAllScheduleItemNotifications(for: item)
                notificationManager.scheduleScheduleItemNotifications(for: item, reminderTime: item.reminderTime)
            }
            saveData()
            if let themeManager {
                 Task { @MainActor in
                    // If the currently active class is the one being skipped/unskipped, its activity needs to end or restart.
                    // manageLiveActivities will handle this logic.
                    if scheduleItem.id == currentActiveClass()?.id {
                        // End the specific activity if it was the one active and is now skipped
                        if item.isSkippedForCurrentWeek() {
                             LiveActivityManager.shared.endActivity(for: item.id.uuidString)
                        }
                    }
                    self.manageLiveActivities(themeManager: themeManager)
                 }
            }
        }
    }
    
    func todaysSchedule() -> [ScheduleItem] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        guard let today = DayOfWeek(rawValue: weekday) else { return [] }
        
        return scheduleItems
            .filter { $0.daysOfWeek.contains(today) && !$0.isSkippedForCurrentWeek() }
            .sorted { $0.startTime < $1.startTime }
    }
    
    func todaysEvents() -> [Event] {
        let calendar = Calendar.current
        return events.filter {
            calendar.isDate($0.date, inSameDayAs: Date())
        }.sorted { $0.date < $1.date }
    }
    
    func upcomingEvents() -> [Event] {
        let now = Date()
        return events.filter { $0.date > now }
            .sorted { $0.date < $1.date }
    }
    
    func pastEvents() -> [Event] {
        let now = Date()
        return events.filter { $0.date <= now }
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

    private func getCurrentWeekIdentifier() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let week = calendar.component(.weekOfYear, from: Date())
        return "\(year)-W\(String(format: "%02d", week))"
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

// MARK: - EventsPreviewView (Updated to only show upcoming events)
struct EventsPreviewView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    // Removed 'let events: [Event]' as it's fetched from viewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Events")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                NavigationLink(value: AppRoute.events) { // Assuming AppRoute is defined elsewhere
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
                            .environmentObject(viewModel) // Already available via @EnvironmentObject
                    }
                    
                    if upcomingEvents.count > 3 {
                        // NavigationLink or Button to navigate to full events list
                        NavigationLink(value: AppRoute.events) { // Assuming AppRoute
                             HStack {
                                Spacer()
                                Text("View All \(upcomingEvents.count) Events...")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                            }
                            .padding(.top, 4)
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
            
            Text("No upcoming events")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Add events to stay organized")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct EventPreviewCard: View {
    @EnvironmentObject var viewModel: EventViewModel
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: event.date))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text(monthShort(from: event.date))
                    .font(.caption.weight(.medium))
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
                Text(timeString(from: event.date))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 3)
                .fill(event.category(from: viewModel.categories).color)
                .frame(width: 4, height: 35)
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

// MARK: - Enhanced EventsListView with Calendar
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
        .navigationTitle("Events")
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
            AddEventView(isPresented: $showingAddEvent) // Pass ThemeManager if needed directly
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(isPresented: $showingAddCategory) // Pass ThemeManager if needed directly
                .environmentObject(viewModel)
                .environmentObject(themeManager)
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
            .padding(.top, 8) // Added padding to top
            
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
        .background(Color(.systemGroupedBackground)) // Or systemBackground for theme consistency
    }
    
    private var listView: some View {
        List {
            if showCategories {
                Section {
                    ForEach(viewModel.categories.indices, id: \.self) { idx in
                        // Use a stable ID if categories can be reordered/deleted often, otherwise index is fine for now
                        NavigationLink {
                            CategoryEditView(category: $viewModel.categories[idx], isNew: false)
                                .environmentObject(viewModel) // Already available
                                .environmentObject(themeManager) // Already available
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
                        Text("Upcoming Events")
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
                        Text("Recent Past Events")
                        Spacer()
                        if sortedPastEvents.count > 10 {
                            Text("10+") // Or actual count if preferred
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                    Text("No events found. Tap '+' to add a new event.")
                        .foregroundColor(.secondary)
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
            let eventToDelete = sortedPastEvents[index] // Be careful with prefix(10) if indices don't match
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
                    Text("No events for \(selectedDate, style: .date)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var eventsForSelectedDateView: some View { // Renamed from eventsForSelectedDate
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Events for \(selectedDate, style: .date)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVStack(spacing: 8) { // Changed to LazyVStack
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
        .background(Color(.secondarySystemGroupedBackground)) // Slightly different background
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
                    .foregroundColor(isPast ? .secondary : themeManager.currentTheme.primaryColor)
                Text(monthShort(from: event.date))
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 45)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPast ? Color(.systemGray6) : themeManager.currentTheme.primaryColor.opacity(0.1))
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(isPast ? .secondary : .primary)
                
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
            
            if isPast {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green.opacity(0.7))
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .opacity(isPast ? 0.7 : 1.0)
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
                        .stroke(Color(.systemBackground), lineWidth: 2) // Use systemBackground for better adaptability
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
    
    private var calendar: Calendar { Calendar.current } // Make it a computed property
    
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
        .background(Color(.systemBackground)) // Or secondarySystemGroupedBackground
        .cornerRadius(16)
    }
    
    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { daySymbol in
                 Text(daySymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(height: 30) // Ensure consistent height
            }
            
            ForEach(calendarDays(), id: \.self) { date in // Call calendarDays()
                CalendarDayView(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                    hasEvents: !viewModel.events(for: date).isEmpty
                ) {
                    selectedDate = date
                }
                .environmentObject(themeManager) // Pass if needed, or ensure it's inherited
            }
        }
    }
    
    private func calendarDays() -> [Date] { // Changed to a function
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              // Ensure monthInterval.end - 1 is valid, or just use monthInterval.end for the last week
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .day, value: -1, to: monthInterval.end)!) 
        else { return [] }
        
        var days: [Date] = []
        var date = monthFirstWeek.start
        
        // Loop through days from the start of the first week to the end of the last week
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
                    Circle() // Keep for layout consistency
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40) // Make it flexible and ensure min height
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
            return .secondary.opacity(0.5) // Dim non-current month days more
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return themeManager.currentTheme.primaryColor
        } else if hasEvents && isCurrentMonth {
            return themeManager.currentTheme.primaryColor.opacity(0.1)
        } else if calendar.isDateInToday(date) && isCurrentMonth { // Highlight today
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
        .background(Color(.tertiarySystemFill)) // Use semantic color
        .cornerRadius(8)
    }
}

extension EventsListView { // Kept for DateFormatter, though not directly used in visible code
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()
}

// MARK: - AddEventView (Enhanced)
struct AddEventView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var date = Date()
    @State private var title = ""
    @State private var selectedCategory: Category? // Use optional Category
    @State private var reminderTime: ReminderTime = .none

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Event Title", text: $title)
                        .font(.headline)
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical) // Or .compact
                } header: {
                    Text("Event Details")
                }
                
                Section {
                    // Ensure categories are loaded for the picker
                    if viewModel.categories.isEmpty {
                        Text("No categories available. Please add a category first.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Category", selection: $selectedCategory) {
                            Text("None").tag(nil as Category?) // Option for no category
                            ForEach(viewModel.categories) { cat in
                                HStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(cat.color)
                                        .frame(width: 20, height: 20)
                                    Text(cat.name)
                                }
                                .tag(Optional(cat)) // Tag as Optional<Category>
                            }
                        }
                        .onAppear { // Set default selection
                            if selectedCategory == nil, let firstCategory = viewModel.categories.first {
                                selectedCategory = firstCategory
                            }
                        }
                    }
                } header: {
                    Text("Category")
                }
                
                Section {
                    Picker("Reminder", selection: $reminderTime) {
                        ForEach(ReminderTime.allCases) { time in
                            Text(time.displayName).tag(time)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Reminder")
                } footer: {
                    if reminderTime != .none {
                        Text("You'll be notified \(reminderTime.displayName.lowercased()) before the event.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let category = selectedCategory else {
                            // Handle case where no category is selected, if required
                            // For now, assume a category must be selected or use a default
                            print("No category selected")
                            return
                        }
                        let newEvent = Event(date: date, title: title.isEmpty ? "Untitled Event" : title, categoryId: category.id, reminderTime: reminderTime)
                        viewModel.addEvent(newEvent)
                        isPresented = false
                    }
                    .disabled(title.isEmpty || selectedCategory == nil) // Disable if no title or category
                    .foregroundColor((title.isEmpty || selectedCategory == nil) ? .secondary : themeManager.currentTheme.primaryColor)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.secondary) // Standard cancel color
                }
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
    @State private var color: Color = .blue // Default color

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
                    .disabled(name.isEmpty) // Disable if name is empty
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
    @State var event: Event // Use @State for mutable copy
    @Environment(\.dismiss) var dismiss // Use new dismiss
    var isNew = false // This determines if we are adding or editing

    // Initializer to handle both new and existing events if needed,
    // or rely on how this view is presented.
    // For simplicity, assuming `event` is appropriately set before this view appears.

    var body: some View {
        Form {
            Section {
                TextField("Event Title", text: $event.title)
                    .font(.headline)
                
                DatePicker("Date & Time", selection: $event.date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical) // Or .compact
            } header: {
                Text("Event Details")
            }
            
            Section {
                // Binding for Picker requires Category to be Hashable if used directly
                // We use categoryId and find the category.
                let categoryBinding = Binding<UUID>(
                    get: { event.categoryId },
                    set: { event.categoryId = $0 }
                )
                Picker("Category", selection: categoryBinding) {
                    ForEach(viewModel.categories, id: \.id) { cat in // Use id for Hashable
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cat.color)
                                .frame(width: 20, height: 20)
                            Text(cat.name)
                        }
                        .tag(cat.id) // Tag with ID
                    }
                }
                 .onAppear { // Ensure categoryId matches an existing category or set a default
                    if !viewModel.categories.contains(where: { $0.id == event.categoryId }), let firstCategory = viewModel.categories.first {
                        event.categoryId = firstCategory.id
                    }
                }
            } header: {
                Text("Category")
            }
            
            Section {
                Picker("Reminder", selection: $event.reminderTime) {
                    ForEach(ReminderTime.allCases) { time in
                        Text(time.displayName).tag(time)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Reminder")
            } footer: {
                if event.reminderTime != .none {
                    Text("You'll be notified \(event.reminderTime.displayName.lowercased()) before the event.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !isNew { // Show delete only if editing an existing event
                Section {
                    Button(role: .destructive) {
                        viewModel.deleteEvent(event)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete Event")
                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle(isNew ? "Add Event" : "Edit Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") {
                    if isNew { // Logic based on how this view is presented
                        viewModel.addEvent(event)
                    } else {
                        viewModel.updateEvent(event)
                    }
                    dismiss()
                }
                .disabled(event.title.isEmpty) // Basic validation
                .foregroundColor(event.title.isEmpty ? .secondary : themeManager.currentTheme.primaryColor)
            }
            if isNew { // Show cancel only if adding a new event
                 ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                 }
            }
        }
    }
}

// MARK: - CategoryEditView (Enhanced)
struct CategoryEditView: View {
    @EnvironmentObject var viewModel: EventViewModel // Not strictly needed if only mutating binding
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var category: Category // Use Binding to directly mutate the source
    @Environment(\.dismiss) var dismiss
    var isNew: Bool // To control "Add" vs "Save" and "Delete" button

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
            
            if !isNew { // Show delete only if editing an existing category
                Section {
                    Button(role: .destructive) {
                        viewModel.deleteCategory(category) // Use viewModel to handle deletion from the source
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
                        // If it's a new category, it should have been added via AddCategoryView.
                        // This view with isNew=true might be part of a different flow.
                        // For now, assume if isNew, the category is transient and needs to be added.
                        // However, AddCategoryView handles new category creation.
                        // This `isNew` here usually means this view is FOR a new category before adding it.
                        // The viewModel.addCategory might be called by the presenting view.
                        // If `isNew` means "create and dismiss", then:
                        // if isNew { viewModel.addCategory(category) } else { viewModel.updateCategory(category) }
                        // This depends on how CategoryEditView is used for "new" categories.
                        // For simplicity, let's assume `updateCategory` is for existing, and if `isNew` were true,
                        // it's added *before* this view or by a different mechanism.
                        // The current structure where CategoryRow navigates here implies it's for editing.
                        viewModel.updateCategory(category) // Existing categories are updated
                    } else {
                         viewModel.updateCategory(category)
                    }
                    dismiss()
                }
                .disabled(category.name.isEmpty)
                .foregroundColor(category.name.isEmpty ? .secondary : themeManager.currentTheme.primaryColor)
            }
             if isNew { // Show cancel only if presented for a new, unadded category
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
        // Create a sample EventViewModel for previews
        let sampleViewModel = EventViewModel()
        // Optionally populate with more specific sample data if needed for previewing states
        
        return NavigationView {
            EventsListView()
                .environmentObject(sampleViewModel)
                .environmentObject(ThemeManager()) // Assuming ThemeManager can be initialized simply
        }
    }
}
