import SwiftUI
import Foundation

// MARK: - Simplified Schedule Type (Traditional Only)
enum ScheduleType: String, Codable, CaseIterable {
    case traditional
    case rotating
    
    var title: String {
        switch self {
        case .traditional: return "Traditional"
        case .rotating: return "Rotating"
        }
    }
    
    var displayName: String {
        switch self {
        case .traditional: return "Weekly Schedule"
        case .rotating: return "Day 1 / Day 2"
        }
    }
    
    var description: String {
        switch self {
        case .traditional: return "Same schedule every week (Monday-Friday)"
        case .rotating: return "Alternate between Day 1 and Day 2 based on date parity"
        }
    }
    
    var icon: String {
        switch self {
        case .traditional: return "calendar"
        case .rotating: return "calendar.day.timeline.left"
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

// MARK: - Academic Calendar Models (Unchanged)
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
    var description: String = ""
    
    init(name: String, type: BreakType, startDate: Date, endDate: Date) {
        self.name = name
        self.type = type
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

struct AcademicCalendar: Codable, Identifiable {
    var id = UUID()
    var name: String
    var academicYear: String
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
    
    func isDateWithinSemester(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: date)
        let startOnly = calendar.startOfDay(for: startDate)
        let endOnly = calendar.startOfDay(for: endDate)
        
        return dateOnly >= startOnly && dateOnly <= endOnly
    }
    
    func isBreakDay(_ date: Date) -> Bool {
        return breaks.contains { $0.contains(date: date) }
    }

    func breakForDate(_ date: Date) -> AcademicBreak? {
        return breaks.first { $0.contains(date: date) }
    }
}

// MARK: - Simplified Schedule Item
struct EnhancedScheduleItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var color: Color
    var reminderTime: ReminderTime = .none
    var isLiveActivityEnabled: Bool = true
    var skippedInstanceIdentifiers: Set<String> = []
    
    // Traditional schedule only
    var daysOfWeek: Set<DayOfWeek> = []
    
    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, color, reminderTime, isLiveActivityEnabled
        case skippedInstanceIdentifiers, daysOfWeek
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
    }
    
    init(title: String, startTime: Date, endTime: Date, color: Color = .blue) {
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
    }
    
    static func instanceIdentifier(for itemID: UUID, onDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(itemID.uuidString)_\(dateFormatter.string(from: onDate))"
    }
}