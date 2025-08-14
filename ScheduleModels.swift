import SwiftUI
import Foundation

// MARK: - Schedule Collection Model
struct ScheduleCollection: Identifiable, Codable {
    var id = UUID()
    var name: String
    var semester: String // e.g., "Fall 2025", "Spring 2024"
    var isActive: Bool = false
    var color: Color = .blue
    var scheduleItems: [ScheduleItem] = []
    var createdDate: Date = Date()
    var lastModified: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case id, name, semester, isActive, color, scheduleItems, createdDate, lastModified
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(semester, forKey: .semester)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encode(scheduleItems, forKey: .scheduleItems)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(lastModified, forKey: .lastModified)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        semester = try container.decode(String.self, forKey: .semester)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color.blue
        }
        scheduleItems = try container.decode([ScheduleItem].self, forKey: .scheduleItems)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
    }
    
    init(name: String, semester: String, color: Color = .blue) {
        self.id = UUID()
        self.name = name
        self.semester = semester
        self.color = color
        self.scheduleItems = []
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
        scheduleItems.count
    }
    
    var weeklyHours: Double {
        scheduleItems.reduce(0) { total, item in
            let duration = item.endTime.timeIntervalSince(item.startTime) / 3600.0 // Convert to hours
            let daysCount = Double(item.daysOfWeek.count)
            return total + (duration * daysCount)
        }
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
        let schedule = scheduleCollections.first { $0.id == activeID }
        print("🔍 ScheduleManager: Active schedule found: \(schedule?.displayName ?? "nil")")
        return schedule
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
    
    func deleteSchedule(_ schedule: ScheduleCollection) {
        scheduleCollections.removeAll { $0.id == schedule.id }
        
        // If we deleted the active schedule, set a new one
        if activeScheduleID == schedule.id {
            activeScheduleID = scheduleCollections.first?.id
            print("🔍 ScheduleManager: Deleted active schedule, new active: \(activeScheduleID?.uuidString ?? "nil")")
        }
        
        // If no schedules left, create a default one
        if scheduleCollections.isEmpty {
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