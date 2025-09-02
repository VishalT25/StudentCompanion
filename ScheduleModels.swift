import SwiftUI
import Foundation
import Combine

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

// MARK: - Enhanced Schedule Manager with Real-time Sync
@MainActor
class ScheduleManager: ObservableObject, RealtimeSyncDelegate {
    @Published var scheduleCollections: [ScheduleCollection] = []
    @Published var activeScheduleID: UUID? = nil
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = "Ready"
    @Published var lastSyncTime: Date?
    
    private let schedulesKey = "savedScheduleCollections"
    private let activeScheduleKey = "activeScheduleID"
    private let realtimeSyncManager = RealtimeSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true
    
    init() {
        print("🔍 ScheduleManager: Initializing...")
        
        // Set up real-time sync delegate
        realtimeSyncManager.schedulesDelegate = self
        
        // Load local data first for offline support
        loadSchedules()
        
        // Setup sync status observation
        setupSyncStatusObservation()
        
        print("🔍 ScheduleManager: Initialized with \(scheduleCollections.count) schedules")
    }
    
    // MARK: - RealtimeSyncDelegate
    
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        print("🔄 ScheduleManager: Received real-time update for table: \(table), action: \(action)")
        
        switch (table, action) {
        case ("schedule_items", "SYNC"):
            if let scheduleItemsData = data["schedule_items"] as? [DatabaseScheduleItem] {
                syncScheduleItemsFromDatabase(scheduleItemsData)
            }
        case ("schedule_items", "INSERT"):
            if let scheduleItemData = try? JSONSerialization.data(withJSONObject: data),
               let dbScheduleItem = try? JSONDecoder().decode(DatabaseScheduleItem.self, from: scheduleItemData) {
                handleScheduleItemInsert(dbScheduleItem)
            }
        case ("schedule_items", "UPDATE"):
            if let scheduleItemData = try? JSONSerialization.data(withJSONObject: data),
               let dbScheduleItem = try? JSONDecoder().decode(DatabaseScheduleItem.self, from: scheduleItemData) {
                handleScheduleItemUpdate(dbScheduleItem)
            }
        case ("schedule_items", "DELETE"):
            if let scheduleItemId = data["id"] as? String {
                handleScheduleItemDelete(scheduleItemId)
            }
            
        case ("academic_calendars", "SYNC"):
            if let calendarsData = data["academic_calendars"] as? [DatabaseAcademicCalendar] {
                syncAcademicCalendarsFromDatabase(calendarsData)
            }
        case ("academic_calendars", "INSERT"):
            if let calendarData = try? JSONSerialization.data(withJSONObject: data),
               let dbCalendar = try? JSONDecoder().decode(DatabaseAcademicCalendar.self, from: calendarData) {
                handleAcademicCalendarInsert(dbCalendar)
            }
        case ("academic_calendars", "UPDATE"):
            if let calendarData = try? JSONSerialization.data(withJSONObject: data),
               let dbCalendar = try? JSONDecoder().decode(DatabaseAcademicCalendar.self, from: calendarData) {
                handleAcademicCalendarUpdate(dbCalendar)
            }
        case ("academic_calendars", "DELETE"):
            if let calendarId = data["id"] as? String {
                handleAcademicCalendarDelete(calendarId)
            }
            
        default:
            print("🔄 ScheduleManager: Unhandled real-time update: \(table) - \(action)")
        }
    }
    
    // MARK: - Real-time Schedule Item Handlers
    
    private func syncScheduleItemsFromDatabase(_ scheduleItems: [DatabaseScheduleItem]) {
        print("🔄 ScheduleManager: Syncing \(scheduleItems.count) schedule items from database")
        
        // Group schedule items by schedule_id
        let groupedItems = Dictionary(grouping: scheduleItems) { $0.schedule_id }
        
        for (scheduleIdString, items) in groupedItems {
            guard let scheduleId = UUID(uuidString: scheduleIdString),
                  let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleId }) else {
                print("🔄 ScheduleManager: Schedule not found for items: \(scheduleIdString)")
                continue
            }
            
            let localItems = items.map { $0.toLocal() }
            scheduleCollections[scheduleIndex].scheduleItems = localItems
        }
        
        if !isInitialLoad {
            saveSchedulesLocally() // Cache for offline use
        }
        
        print("🔄 ScheduleManager: Schedule items sync complete")
    }
    
    private func handleScheduleItemInsert(_ dbScheduleItem: DatabaseScheduleItem) {
        let localScheduleItem = dbScheduleItem.toLocal()
        
        guard let scheduleId = UUID(uuidString: dbScheduleItem.schedule_id),
              let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleId }) else {
            print("🔄 ScheduleManager: Schedule not found for new item: \(dbScheduleItem.schedule_id)")
            return
        }
        
        // Check if schedule item already exists locally
        if !scheduleCollections[scheduleIndex].scheduleItems.contains(where: { $0.id == localScheduleItem.id }) {
            scheduleCollections[scheduleIndex].scheduleItems.append(localScheduleItem)
            scheduleCollections[scheduleIndex].lastModified = Date()
            saveSchedulesLocally()
            print("🔄 ScheduleManager: Added new schedule item from real-time: \(localScheduleItem.title)")
        }
    }
    
    private func handleScheduleItemUpdate(_ dbScheduleItem: DatabaseScheduleItem) {
        let localScheduleItem = dbScheduleItem.toLocal()
        
        guard let scheduleId = UUID(uuidString: dbScheduleItem.schedule_id),
              let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleId }),
              let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == localScheduleItem.id }) else {
            print("🔄 ScheduleManager: Schedule or item not found for update: \(dbScheduleItem.id)")
            return
        }
        
        scheduleCollections[scheduleIndex].scheduleItems[itemIndex] = localScheduleItem
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedulesLocally()
        print("🔄 ScheduleManager: Updated schedule item from real-time: \(localScheduleItem.title)")
    }
    
    private func handleScheduleItemDelete(_ scheduleItemId: String) {
        guard let uuid = UUID(uuidString: scheduleItemId) else { return }
        
        for scheduleIndex in scheduleCollections.indices {
            if let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == uuid }) {
                let removedItem = scheduleCollections[scheduleIndex].scheduleItems.remove(at: itemIndex)
                scheduleCollections[scheduleIndex].lastModified = Date()
                saveSchedulesLocally()
                print("🔄 ScheduleManager: Deleted schedule item from real-time: \(removedItem.title)")
                break
            }
        }
    }
    
    // MARK: - Real-time Academic Calendar Handlers
    
    private func syncAcademicCalendarsFromDatabase(_ calendars: [DatabaseAcademicCalendar]) {
        print("🔄 ScheduleManager: Syncing \(calendars.count) academic calendars from database")
        
        // Academic calendars are managed separately now, but we need to update
        // any embedded legacy calendars in schedule collections for backward compatibility
        
        if !isInitialLoad {
            saveSchedulesLocally() // Cache for offline use
        }
        
        print("🔄 ScheduleManager: Academic calendars sync complete")
    }
    
    private func handleAcademicCalendarInsert(_ dbCalendar: DatabaseAcademicCalendar) {
        let localCalendar = dbCalendar.toLocal()
        print("🔄 ScheduleManager: Added new academic calendar from real-time: \(localCalendar.name)")
    }
    
    private func handleAcademicCalendarUpdate(_ dbCalendar: DatabaseAcademicCalendar) {
        let localCalendar = dbCalendar.toLocal()
        print("🔄 ScheduleManager: Updated academic calendar from real-time: \(localCalendar.name)")
    }
    
    private func handleAcademicCalendarDelete(_ calendarId: String) {
        print("🔄 ScheduleManager: Deleted academic calendar from real-time: \(calendarId)")
    }
    
    // MARK: - Enhanced Schedule Operations with Sync
    
    func addSchedule(_ schedule: ScheduleCollection) {
        var newSchedule = schedule
        newSchedule.createdDate = Date()
        newSchedule.lastModified = Date()
        
        // Add locally for immediate UI update
        scheduleCollections.append(newSchedule)
        saveSchedulesLocally()
        
        print("🔍 ScheduleManager: Added new schedule locally: \(newSchedule.displayName)")
        
        // Note: Individual schedule collections aren't synced to database yet
        // Only schedule items are synced. This could be enhanced in the future.
    }
    
    func updateSchedule(_ schedule: ScheduleCollection) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == schedule.id }) else { return }
        var updatedSchedule = schedule
        updatedSchedule.lastModified = Date()
        
        // Update locally for immediate UI update
        scheduleCollections[index] = updatedSchedule
        saveSchedulesLocally()
        
        print("🔍 ScheduleManager: Updated schedule locally: \(updatedSchedule.displayName)")
    }
    
    func addScheduleItem(_ item: ScheduleItem, to scheduleID: UUID) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == scheduleID }) else { return }
        
        // Add locally for immediate UI update
        scheduleCollections[index].scheduleItems.append(item)
        scheduleCollections[index].lastModified = Date()
        saveSchedulesLocally()
        
        // Sync to database
        syncScheduleItemToDatabase(item, scheduleId: scheduleID, action: .create)
        
        print("🔍 ScheduleManager: Added schedule item: \(item.title) to schedule: \(scheduleID)")
    }
    
    func updateScheduleItem(_ item: ScheduleItem, in scheduleID: UUID) {
        guard let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleID }),
              let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        // Update locally for immediate UI update
        scheduleCollections[scheduleIndex].scheduleItems[itemIndex] = item
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedulesLocally()
        
        // Sync to database
        syncScheduleItemToDatabase(item, scheduleId: scheduleID, action: .update)
        
        print("🔍 ScheduleManager: Updated schedule item: \(item.title)")
    }
    
    func deleteScheduleItem(_ item: ScheduleItem, from scheduleID: UUID) {
        guard let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleID }) else { return }
        
        // Remove locally for immediate UI update
        scheduleCollections[scheduleIndex].scheduleItems.removeAll { $0.id == item.id }
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedulesLocally()
        
        // Sync to database
        syncScheduleItemToDatabase(item, scheduleId: scheduleID, action: .delete)
        
        print("🔍 ScheduleManager: Deleted schedule item: \(item.title)")
    }
    
    func toggleSkip(forItem item: ScheduleItem, onDate date: Date, in scheduleID: UUID) {
        guard let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleID }),
              let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        let identifier = ScheduleItem.instanceIdentifier(for: item.id, onDate: date)
        
        // Update locally for immediate UI update
        if scheduleCollections[scheduleIndex].scheduleItems[itemIndex].skippedInstanceIdentifiers.contains(identifier) {
            scheduleCollections[scheduleIndex].scheduleItems[itemIndex].skippedInstanceIdentifiers.remove(identifier)
        } else {
            scheduleCollections[scheduleIndex].scheduleItems[itemIndex].skippedInstanceIdentifiers.insert(identifier)
        }
        
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedulesLocally()
        
        // Sync to database
        let updatedItem = scheduleCollections[scheduleIndex].scheduleItems[itemIndex]
        syncScheduleItemToDatabase(updatedItem, scheduleId: scheduleID, action: .update)
        
        print("🔍 ScheduleManager: Toggled skip for: \(item.title) on \(date)")
    }
    
    // MARK: - Database Sync Operations
    
    private func syncScheduleItemToDatabase(_ item: ScheduleItem, scheduleId: UUID, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("🔄 ScheduleManager: Cannot sync - user not authenticated")
            return
        }
        
        let dbScheduleItem = DatabaseScheduleItem(
            from: item, 
            userId: userId, 
            scheduleId: scheduleId.uuidString
        )
        
        do {
            let data = try JSONEncoder().encode(dbScheduleItem)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            let operation = SyncOperation(
                type: .scheduleItems,
                action: action,
                data: dict
            )
            
            realtimeSyncManager.queueSyncOperation(operation)
        } catch {
            print("🔄 ScheduleManager: Failed to prepare schedule item sync: \(error)")
        }
    }
    
    // MARK: - Enhanced Refresh with Sync
    
    func refreshScheduleData() async {
        isSyncing = true
        
        // Refresh real-time sync data
        await realtimeSyncManager.refreshAllData()
        
        // Mark as no longer initial load after first refresh
        isInitialLoad = false
        
        lastSyncTime = Date()
        isSyncing = false
    }
    
    // MARK: - Sync Status Observation
    
    private func setupSyncStatusObservation() {
        realtimeSyncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status.displayName
                self?.isSyncing = status.isActive
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Save locally for offline support
    
    private func saveSchedulesLocally() {
        print("🔍 ScheduleManager: Saving \(scheduleCollections.count) schedules locally...")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scheduleCollections)
            UserDefaults.standard.set(data, forKey: schedulesKey)
            
            if let activeID = activeScheduleID {
                UserDefaults.standard.set(activeID.uuidString, forKey: activeScheduleKey)
                print("🔍 ScheduleManager: Saved active schedule ID: \(activeID.uuidString)")
            }
            print("🔍 ScheduleManager: Schedules saved locally successfully")
        } catch {
            print("🔍 ScheduleManager: Error saving schedules locally: \(error)")
        }
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
        saveSchedulesLocally()
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
            saveSchedulesLocally()
        }
    }
    
    func unarchiveSchedule(_ schedule: ScheduleCollection) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == schedule.id }) else { return }
        scheduleCollections[index].isArchived = false
        scheduleCollections[index].lastModified = Date()
        saveSchedulesLocally()
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
            saveSchedulesLocally()
        }
    }
    
    func setActiveSchedule(_ scheduleID: UUID) {
        activeScheduleID = scheduleID
        saveSchedulesLocally()
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