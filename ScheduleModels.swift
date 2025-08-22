import SwiftUI
import Foundation

// MARK: - Schedule Collection Model
struct ScheduleCollection: Identifiable, Codable {
    var id = UUID()
    var name: String
    var semester: String // e.g., "Fall 2025", "Spring 2024"
    var isActive: Bool = false
    var isArchived: Bool = false // NEW: For archived schedules
    var color: Color = .blue
    var scheduleItems: [ScheduleItem] = []
    var createdDate: Date = Date()
    var lastModified: Date = Date()
    
    // Enhanced properties for new schedule system
    var scheduleType: ScheduleType = .traditional
    var rotationPattern: RotationPattern?
    var academicCalendarID: UUID? // NEW: Reference to academic calendar by ID
    var enhancedScheduleItems: [EnhancedScheduleItem] = []
    
    // DEPRECATED: Keep for backward compatibility, will be migrated
    var academicCalendar: AcademicCalendar?
    
    enum CodingKeys: String, CodingKey {
        case id, name, semester, isActive, isArchived, color, scheduleItems, createdDate, lastModified
        case scheduleType, rotationPattern, academicCalendar, academicCalendarID, enhancedScheduleItems
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(semester, forKey: .semester)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encode(scheduleItems, forKey: .scheduleItems)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(scheduleType, forKey: .scheduleType)
        try container.encodeIfPresent(rotationPattern, forKey: .rotationPattern)
        try container.encodeIfPresent(academicCalendar, forKey: .academicCalendar)
        try container.encodeIfPresent(academicCalendarID, forKey: .academicCalendarID)
        try container.encode(enhancedScheduleItems, forKey: .enhancedScheduleItems)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        semester = try container.decode(String.self, forKey: .semester)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color.blue
        }
        scheduleItems = try container.decode([ScheduleItem].self, forKey: .scheduleItems)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        
        // Enhanced properties with defaults for backward compatibility
        scheduleType = try container.decodeIfPresent(ScheduleType.self, forKey: .scheduleType) ?? .traditional
        rotationPattern = try container.decodeIfPresent(RotationPattern.self, forKey: .rotationPattern)
        academicCalendar = try container.decodeIfPresent(AcademicCalendar.self, forKey: .academicCalendar)
        academicCalendarID = try container.decodeIfPresent(UUID.self, forKey: .academicCalendarID)
        enhancedScheduleItems = try container.decodeIfPresent([EnhancedScheduleItem].self, forKey: .enhancedScheduleItems) ?? []
    }
    
    init(name: String, semester: String, color: Color = .blue, scheduleType: ScheduleType = .traditional) {
        self.id = UUID()
        self.name = name
        self.semester = semester
        self.color = color
        self.scheduleType = scheduleType
        self.scheduleItems = []
        self.enhancedScheduleItems = []
        self.createdDate = Date()
        self.lastModified = Date()
    }
    
    var displayName: String {
        if name.isEmpty {
            return semester
        }
        return "\(name) - \(semester)"
    }
    
    var totalClasses: Int {
        return scheduleItems.count + enhancedScheduleItems.count
    }
    
    var weeklyHours: Double {
        scheduleItems.reduce(0) { $0 + $1.weeklyHours }
    }
    
    func getScheduleItems(for date: Date, usingCalendar calendar: AcademicCalendar? = nil) -> [ScheduleItem] {
        // First check if the date is within the academic calendar bounds
        var effectiveCalendar: AcademicCalendar?
        
        // Use provided calendar, or fall back to embedded calendar for backward compatibility
        if let providedCalendar = calendar {
            effectiveCalendar = providedCalendar
        } else if let legacyCalendar = academicCalendar {
            effectiveCalendar = legacyCalendar
        }
        
        if let calendar = effectiveCalendar {
            // Debug: Check if date is within semester bounds
            let withinSemester = calendar.isWithinSemester(date)
            print("🔍 ScheduleCollection: Date \(date) within semester (\(calendar.startDate) - \(calendar.endDate)): \(withinSemester)")
            
            if !withinSemester {
                print("🔍 ScheduleCollection: No classes - date outside semester bounds")
                return [] // No classes outside semester dates
            }
            
            // Check if date is during a break
            let isBreakDay = calendar.isBreakDay(date)
            print("🔍 ScheduleCollection: Date \(date) is break day: \(isBreakDay)")
            
            if isBreakDay {
                print("🔍 ScheduleCollection: No classes - date is during a break")
                return [] // No classes during breaks
            }
        } else {
            print("🔍 ScheduleCollection: No academic calendar found, proceeding without calendar checks")
        }
        
        let dateCalendar = Calendar.current
        let weekday = dateCalendar.component(.weekday, from: date)
        let dayOfWeek = DayOfWeek.from(weekday: weekday)
        
        // Return classes that are scheduled for this day of the week and not skipped
        let filteredItems = scheduleItems.filter { item in
            // Check if class is scheduled for this day
            guard item.daysOfWeek.contains(dayOfWeek) else { return false }
            
            // Check if this specific instance is skipped
            return !item.isSkipped(onDate: date)
        }
        
        print("🔍 ScheduleCollection: Found \(filteredItems.count) classes for \(dayOfWeek) on \(date)")
        return filteredItems
    }
}

struct ScheduleItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var daysOfWeek: [DayOfWeek] = []
    var location: String = ""
    var instructor: String = ""
    var color: Color = .blue
    var skippedInstanceIdentifiers: Set<String> = []
    var isLiveActivityEnabled: Bool = true
    var reminderTime: ReminderTime = .none
    
    var weeklyHours: Double {
        let duration = endTime.timeIntervalSince(startTime) / 3600.0
        let daysCount = Double(daysOfWeek.count)
        return duration * daysCount
    }
    
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var duration: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        return "\(hours)h \(minutes)m"
    }
    
    var isSkippedToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let identifier = ScheduleItem.instanceIdentifier(for: id, onDate: today)
        return skippedInstanceIdentifiers.contains(identifier)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, daysOfWeek, location, instructor, color, skippedInstanceIdentifiers, isLiveActivityEnabled, reminderTime
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(daysOfWeek, forKey: .daysOfWeek)
        try container.encode(location, forKey: .location)
        try container.encode(instructor, forKey: .instructor)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encode(skippedInstanceIdentifiers, forKey: .skippedInstanceIdentifiers)
        try container.encode(isLiveActivityEnabled, forKey: .isLiveActivityEnabled)
        try container.encode(reminderTime, forKey: .reminderTime)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        daysOfWeek = try container.decode([DayOfWeek].self, forKey: .daysOfWeek)
        location = try container.decode(String.self, forKey: .location)
        instructor = try container.decode(String.self, forKey: .instructor)
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color.blue
        }
        skippedInstanceIdentifiers = try container.decode(Set<String>.self, forKey: .skippedInstanceIdentifiers)
        isLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveActivityEnabled) ?? true
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
    }
    
    static func instanceIdentifier(for id: UUID, onDate date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(id.uuidString)_\(year)-\(month)-\(day)"
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        endTime: Date,
        daysOfWeek: [DayOfWeek],
        location: String = "",
        instructor: String = "",
        color: Color = .blue,
        skippedInstanceIdentifiers: Set<String> = [],
        isLiveActivityEnabled: Bool = true,
        reminderTime: ReminderTime = .none
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.location = location
        self.instructor = instructor
        self.color = color
        self.skippedInstanceIdentifiers = skippedInstanceIdentifiers
        self.isLiveActivityEnabled = isLiveActivityEnabled
        self.reminderTime = reminderTime
    }
}

extension ScheduleItem {
    func isSkipped(onDate date: Date) -> Bool {
        let identifier = ScheduleItem.instanceIdentifier(for: id, onDate: date)
        return skippedInstanceIdentifiers.contains(identifier)
    }
}

// MARK: - Schedule Manager
@MainActor
class ScheduleManager: ObservableObject {
    @Published var scheduleCollections: [ScheduleCollection] = []
    @Published var activeScheduleID: UUID? = nil
    
    private let schedulesKey = "savedScheduleCollections"
    private let activeScheduleKey = "activeScheduleID"
    
    init() {
        print("🔍 ScheduleManager: Initializing...")
        loadSchedules()
        print("🔍 ScheduleManager: Initialized with \(scheduleCollections.count) schedules")
    }
    
    var activeSchedule: ScheduleCollection? {
        guard let activeID = activeScheduleID else { 
            print("🔍 ScheduleManager: No active schedule ID")
            return nil 
        }
        let schedule = scheduleCollections.first { $0.id == activeID && !$0.isArchived }
        print("🔍 ScheduleManager: Active schedule found: \(schedule?.displayName ?? "nil")")
        return schedule
    }
    
    var activeSchedules: [ScheduleCollection] {
        return scheduleCollections.filter { !$0.isArchived }
    }
    
    var archivedSchedules: [ScheduleCollection] {
        return scheduleCollections.filter { $0.isArchived }
    }
    
    func schedule(for id: UUID) -> ScheduleCollection? {
        return scheduleCollections.first { $0.id == id }
    }
    
    func getAcademicCalendar(for schedule: ScheduleCollection, from academicCalendarManager: AcademicCalendarManager) -> AcademicCalendar? {
        if let calendarID = schedule.academicCalendarID {
            return academicCalendarManager.calendar(withID: calendarID)
        } else if let legacyCalendar = schedule.academicCalendar {
            return legacyCalendar
        }
        return nil
    }

    func loadSchedules() {
        print("🔍 ScheduleManager: Loading schedules...")
        if let data = UserDefaults.standard.data(forKey: schedulesKey) {
            do {
                let decoder = JSONDecoder()
                scheduleCollections = try decoder.decode([ScheduleCollection].self, from: data)
                print("🔍 ScheduleManager: Loaded \(scheduleCollections.count) existing schedules")
                
                // Load active schedule ID
                if let activeIDString = UserDefaults.standard.string(forKey: activeScheduleKey),
                   let activeID = UUID(uuidString: activeIDString) {
                    activeScheduleID = activeID
                    print("🔍 ScheduleManager: Loaded active schedule ID: \(activeIDString)")
                }
                
                // Ensure we have an active schedule
                if activeScheduleID == nil || !scheduleCollections.contains(where: { $0.id == activeScheduleID }) {
                    activeScheduleID = scheduleCollections.first?.id
                    print("🔍 ScheduleManager: Set first schedule as active: \(activeScheduleID?.uuidString ?? "nil")")
                }
                
            } catch {
                print("🔍 ScheduleManager: Error loading schedules: \(error)")
                setupDefaultSchedule()
            }
        } else {
            print("🔍 ScheduleManager: No existing schedules found, creating default")
            setupDefaultSchedule()
        }
    }
    
    func saveSchedules() {
        print("🔍 ScheduleManager: Saving \(scheduleCollections.count) schedules...")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scheduleCollections)
            UserDefaults.standard.set(data, forKey: schedulesKey)
            
            if let activeID = activeScheduleID {
                UserDefaults.standard.set(activeID.uuidString, forKey: activeScheduleKey)
                print("🔍 ScheduleManager: Saved active schedule ID: \(activeID.uuidString)")
            }
            print("🔍 ScheduleManager: Schedules saved successfully")
        } catch {
            print("🔍 ScheduleManager: Error saving schedules: \(error)")
        }
    }
    
    private func setupDefaultSchedule() {
        print("🔍 ScheduleManager: Setting up default schedule...")
        let defaultSchedule = ScheduleCollection(
            name: "My Schedule",
            semester: getCurrentSemester(),
            color: .blue
        )
        scheduleCollections = [defaultSchedule]
        activeScheduleID = defaultSchedule.id
        print("🔍 ScheduleManager: Created default schedule: \(defaultSchedule.displayName)")
        saveSchedules()
    }
    
    private func getCurrentSemester() -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        
        if month >= 8 || month <= 1 {
            return "Fall \(year)"
        } else if month >= 2 && month <= 5 {
            return "Spring \(year)"
        } else {
            return "Summer \(year)"
        }
    }
    
    func addSchedule(_ schedule: ScheduleCollection) {
        var newSchedule = schedule
        newSchedule.createdDate = Date()
        newSchedule.lastModified = Date()
        scheduleCollections.append(newSchedule)
        saveSchedules()
    }
    
    func updateSchedule(_ schedule: ScheduleCollection) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == schedule.id }) else { return }
        var updatedSchedule = schedule
        updatedSchedule.lastModified = Date()
        scheduleCollections[index] = updatedSchedule
        saveSchedules()
    }
    
    func archiveSchedule(_ schedule: ScheduleCollection) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == schedule.id }) else { return }
        scheduleCollections[index].isArchived = true
        scheduleCollections[index].lastModified = Date()
        
        // If we archived the active schedule, set a new one
        if activeScheduleID == schedule.id {
            activeScheduleID = activeSchedules.first?.id
        }
        
        // If no active schedules left, create a default one
        if activeSchedules.isEmpty {
            setupDefaultSchedule()
        } else {
            saveSchedules()
        }
    }
    
    func unarchiveSchedule(_ schedule: ScheduleCollection) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == schedule.id }) else { return }
        scheduleCollections[index].isArchived = false
        scheduleCollections[index].lastModified = Date()
        saveSchedules()
    }
    
    func deleteSchedule(_ schedule: ScheduleCollection) {
        scheduleCollections.removeAll { $0.id == schedule.id }
        
        // If we deleted the active schedule, set a new one
        if activeScheduleID == schedule.id {
            activeScheduleID = activeSchedules.first?.id
            print("🔍 ScheduleManager: Deleted active schedule, new active: \(activeScheduleID?.uuidString ?? "nil")")
        }
        
        // If no active schedules left, create a default one
        if activeSchedules.isEmpty {
            print("🔍 ScheduleManager: No schedules left, creating default")
            setupDefaultSchedule()
        } else {
            saveSchedules()
        }
    }
    
    func setActiveSchedule(_ scheduleID: UUID) {
        activeScheduleID = scheduleID
        saveSchedules()
    }
    
    func addScheduleItem(_ item: ScheduleItem, to scheduleID: UUID) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == scheduleID }) else { return }
        scheduleCollections[index].scheduleItems.append(item)
        scheduleCollections[index].lastModified = Date()
        saveSchedules()
    }
    
    func updateScheduleItem(_ item: ScheduleItem, in scheduleID: UUID) {
        guard let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleID }),
              let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        scheduleCollections[scheduleIndex].scheduleItems[itemIndex] = item
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedules()
    }
    
    func deleteScheduleItem(_ item: ScheduleItem, from scheduleID: UUID) {
        guard let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleID }) else { return }
        scheduleCollections[scheduleIndex].scheduleItems.removeAll { $0.id == item.id }
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedules()
    }
    
    func toggleSkip(forItem item: ScheduleItem, onDate date: Date, in scheduleID: UUID) {
        guard let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleID }),
              let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        let identifier = ScheduleItem.instanceIdentifier(for: item.id, onDate: date)
        
        if scheduleCollections[scheduleIndex].scheduleItems[itemIndex].skippedInstanceIdentifiers.contains(identifier) {
            scheduleCollections[scheduleIndex].scheduleItems[itemIndex].skippedInstanceIdentifiers.remove(identifier)
        } else {
            scheduleCollections[scheduleIndex].scheduleItems[itemIndex].skippedInstanceIdentifiers.insert(identifier)
        }
        
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedules()
    }
}

// MARK: - Academic Calendar Extensions - Additional methods only
extension AcademicCalendar {
    func isWithinSemester(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: date)
        let startOnly = calendar.startOfDay(for: startDate)
        let endOnly = calendar.startOfDay(for: endDate)
        
        return dateOnly >= startOnly && dateOnly <= endOnly
    }
    
    func getBreakForDate(_ date: Date) -> AcademicBreak? {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: date)
        
        return breaks.first { breakPeriod in
            let breakStart = calendar.startOfDay(for: breakPeriod.startDate)
            let breakEnd = calendar.startOfDay(for: breakPeriod.endDate)
            return dateOnly >= breakStart && dateOnly <= breakEnd
        }
    }
}