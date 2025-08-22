import SwiftUI
import Foundation

// MARK: - Schedule Type Enums
enum ScheduleType: String, Codable, CaseIterable {
    case traditional
    case rotatingDays
    
    var title: String {
        switch self {
        case .traditional: return "Traditional"
        case .rotatingDays: return "Rotating Days"
        }
    }
    
    var displayName: String {
        switch self {
        case .traditional: return "Traditional Weekly"
        case .rotatingDays: return "Rotating Days"
        }
    }
    
    var description: String {
        switch self {
        case .traditional: return "Same schedule every week (Monday-Friday)"
        case .rotatingDays: return "Schedule that rotates through different day types"
        }
    }
    
    var icon: String {
        switch self {
        case .traditional: return "calendar"
        case .rotatingDays: return "arrow.triangle.2.circlepath"
        }
    }
    
    var supportsRotation: Bool {
        switch self {
        case .traditional:
            return false
        case .rotatingDays:
            return true
        }
    }
}

// MARK: - Import Error Enum
enum ImportError: LocalizedError {
    case invalidJSON
    case unsupportedVersion
    case invalidTimeFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format"
        case .unsupportedVersion:
            return "Unsupported calendar version"
        case .invalidTimeFormat:
            return "Invalid date format"
        }
    }
}

// MARK: - Rotation Pattern Models
struct RotationPattern: Codable, Identifiable {
    var id = UUID()
    var type: ScheduleType
    var cycleLength: Int // Number of days in rotation cycle
    var dayLabels: [String] // Labels for each day in cycle (e.g., ["Day 1", "Day 2"] or ["A", "B", "C"])
    var startDate: Date // When the rotation pattern starts
    var skipWeekends: Bool = true
    var skipHolidays: Bool = true
    
    init(type: ScheduleType, cycleLength: Int, dayLabels: [String], startDate: Date) {
        self.type = type
        self.cycleLength = cycleLength
        self.dayLabels = dayLabels
        self.startDate = startDate
    }
    
    // Calculate which day type it is for a given date
    func dayType(for date: Date) -> String? {
        let calendar = Calendar.current
        
        // Skip weekends if configured
        if skipWeekends {
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                return nil
            }
        }
        
        // Calculate days since start (excluding weekends and holidays if configured)
        let daysSinceStart = workingDaysBetween(startDate: startDate, endDate: date)
        let cyclePosition = daysSinceStart % cycleLength
        
        guard cyclePosition >= 0 && cyclePosition < dayLabels.count else {
            return dayLabels.first
        }
        
        return dayLabels[cyclePosition]
    }
    
    private func workingDaysBetween(startDate: Date, endDate: Date) -> Int {
        let calendar = Calendar.current
        var workingDays = 0
        var currentDate = calendar.startOfDay(for: startDate)
        let targetDate = calendar.startOfDay(for: endDate)
        
        while currentDate <= targetDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // Skip weekends if configured
            if !skipWeekends || (weekday != 1 && weekday != 7) {
                if currentDate < targetDate {
                    workingDays += 1
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return workingDays
    }
}

// MARK: - Academic Calendar Models
enum AcademicTermType: String, CaseIterable, Codable {
    case semester = "semester"
    case quarter = "quarter"
    case trimester = "trimester"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .semester:
            return "Semester (Fall/Spring)"
        case .quarter:
            return "Quarter (Fall/Winter/Spring/Summer)"
        case .trimester:
            return "Trimester (3 terms)"
        case .custom:
            return "Custom Terms"
        }
    }
}

struct AcademicTerm: Codable, Identifiable {
    var id = UUID()
    var name: String
    var startDate: Date
    var endDate: Date
    var isActive: Bool = false
    
    init(name: String, startDate: Date, endDate: Date) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
    
    func contains(date: Date) -> Bool {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: date)
        let startOnly = calendar.startOfDay(for: startDate)
        let endOnly = calendar.startOfDay(for: endDate)
        
        return dateOnly >= startOnly && dateOnly <= endOnly
    }
}

enum BreakType: String, CaseIterable, Codable {
    case winterBreak = "winterBreak"
    case springBreak = "springBreak"
    case readingWeek = "readingWeek"
    case examPeriod = "examPeriod"
    case holiday = "holiday"
    case professionalDevelopment = "professionalDevelopment"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .winterBreak:
            return "Winter Break"
        case .springBreak:
            return "Spring Break"
        case .readingWeek:
            return "Reading Week"
        case .examPeriod:
            return "Exam Period"
        case .holiday:
            return "Holiday"
        case .professionalDevelopment:
            return "Professional Development"
        case .custom:
            return "Custom Break"
        }
    }
    
    var icon: String {
        switch self {
        case .winterBreak:
            return "snowflake"
        case .springBreak:
            return "sun.max"
        case .readingWeek:
            return "book.closed"
        case .examPeriod:
            return "doc.text"
        case .holiday:
            return "star"
        case .professionalDevelopment:
            return "person.crop.circle.badge.checkmark"
        case .custom:
            return "calendar.badge.minus"
        }
    }
}

struct AcademicBreak: Codable, Identifiable {
    var id = UUID()
    var name: String
    var type: BreakType
    var startDate: Date
    var endDate: Date
    var affectsRotation: Bool = true // Whether this break affects rotation cycle
    var description: String = ""
    
    init(name: String, type: BreakType, startDate: Date, endDate: Date, affectsRotation: Bool = true) {
        self.name = name
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.affectsRotation = affectsRotation
    }
    
    func contains(date: Date) -> Bool {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: date)
        let startOnly = calendar.startOfDay(for: startDate)
        let endOnly = calendar.startOfDay(for: endDate)
        
        return dateOnly >= startOnly && dateOnly <= endOnly
    }
}

struct AcademicCalendar: Codable, Identifiable {
    var id = UUID()
    var name: String
    var academicYear: String // e.g., "2024-2025"
    var termType: AcademicTermType
    var terms: [AcademicTerm] = []
    var breaks: [AcademicBreak] = []
    var startDate: Date
    var endDate: Date
    
    init(name: String, academicYear: String, termType: AcademicTermType, startDate: Date, endDate: Date) {
        self.name = name
        self.academicYear = academicYear
        self.termType = termType
        self.startDate = startDate
        self.endDate = endDate
    }
    
    func isBreakDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: date)
        
        return breaks.contains { breakPeriod in
            let breakStart = calendar.startOfDay(for: breakPeriod.startDate)
            let breakEnd = calendar.startOfDay(for: breakPeriod.endDate)
            return dateOnly >= breakStart && dateOnly <= breakEnd
        }
    }
    
    func breakName(for date: Date) -> String? {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: date)
        
        return breaks.first { breakPeriod in
            let breakStart = calendar.startOfDay(for: breakPeriod.startDate)
            let breakEnd = calendar.startOfDay(for: breakPeriod.endDate)
            return dateOnly >= breakStart && dateOnly <= breakEnd
        }?.name
    }
    
    func breakForDate(_ date: Date) -> AcademicBreak? {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: date)
        
        return breaks.first { breakPeriod in
            let breakStart = calendar.startOfDay(for: breakPeriod.startDate)
            let breakEnd = calendar.startOfDay(for: breakPeriod.endDate)
            return dateOnly >= breakStart && dateOnly <= breakEnd
        }
    }
}

enum TermType: String, Codable {
    case semester = "semester"
    case quarter = "quarter"
    case trimester = "trimester"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .semester:
            return "Semester (Fall/Spring)"
        case .quarter:
            return "Quarter (Fall/Winter/Spring/Summer)"
        case .trimester:
            return "Trimester (3 terms)"
        case .custom:
            return "Custom Terms"
        }
    }
}

// MARK: - Enhanced Schedule Item
struct EnhancedScheduleItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var color: Color
    var reminderTime: ReminderTime = .none
    var isLiveActivityEnabled: Bool = true
    var skippedInstanceIdentifiers: Set<String> = []
    
    // Enhanced properties for different schedule types
    var daysOfWeek: Set<DayOfWeek> = [] // For traditional schedules
    var rotationDays: Set<String> = [] // For rotating schedules (e.g., ["Day 1", "Day 3"])
    var specificDates: Set<Date> = [] // For one-time or custom schedules
    
    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, color, reminderTime, isLiveActivityEnabled
        case skippedInstanceIdentifiers, daysOfWeek, rotationDays, specificDates
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(isLiveActivityEnabled, forKey: .isLiveActivityEnabled)
        try container.encode(Array(skippedInstanceIdentifiers), forKey: .skippedInstanceIdentifiers)
        try container.encode(Array(daysOfWeek), forKey: .daysOfWeek)
        try container.encode(Array(rotationDays), forKey: .rotationDays)
        try container.encode(Array(specificDates), forKey: .specificDates)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count >= 3 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components.count > 3 ? components[3] : 1.0))
        } else {
            color = Color.blue
        }
        
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
        isLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveActivityEnabled) ?? true
        skippedInstanceIdentifiers = Set(try container.decodeIfPresent([String].self, forKey: .skippedInstanceIdentifiers) ?? [])
        daysOfWeek = Set(try container.decodeIfPresent([DayOfWeek].self, forKey: .daysOfWeek) ?? [])
        rotationDays = Set(try container.decodeIfPresent([String].self, forKey: .rotationDays) ?? [])
        specificDates = Set(try container.decodeIfPresent([Date].self, forKey: .specificDates) ?? [])
    }
    
    init(title: String, startTime: Date, endTime: Date, color: Color = .blue) {
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
    }
    
    // Check if this item occurs on a given date based on schedule type
    func occursOn(date: Date, rotationPattern: RotationPattern?, academicCalendar: AcademicCalendar?) -> Bool {
        if let calendar = academicCalendar, calendar.isBreakDay(date) {
            return false
        }
        
        let identifier = EnhancedScheduleItem.instanceIdentifier(for: id, onDate: date)
        if skippedInstanceIdentifiers.contains(identifier) {
            return false
        }
        
        if specificDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) }) {
            return true
        }
        
        if !rotationDays.isEmpty {
            guard let pattern = rotationPattern,
                  let dayType = pattern.dayType(for: date) else {
                return false
            }
            return rotationDays.contains(dayType)
        }
        
        if !daysOfWeek.isEmpty {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            let dayOfWeek = DayOfWeek.from(weekday: weekday)
            return daysOfWeek.contains(dayOfWeek)
        }
        
        return false
    }
    
    static func instanceIdentifier(for itemID: UUID, onDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(itemID.uuidString)_\(dateFormatter.string(from: onDate))"
    }
}