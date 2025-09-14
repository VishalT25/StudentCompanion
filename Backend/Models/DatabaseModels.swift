import Foundation
import SwiftUI

// MARK: - Helper Extensions & Utilities
extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
    
    static func fromISOString(_ string: String) -> Date? {
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatterWithFractional.date(from: string) {
            return date
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    func toDateOnlyString() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: self)
    }
    
    static func fromDateOnlyString(_ string: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: string)
    }
    
    static func fromFlexibleString(_ string: String) -> Date? {
        if let d = fromISOString(string) { return d }
        if let d = fromDateOnlyString(string) { return d }
        return nil
    }
    
    func toTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: self)
    }
    
    static func fromTimeString(_ time: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        
        guard let timeDate = formatter.date(from: time) else { return Date() }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
        
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        
        return calendar.date(from: components) ?? Date()
    }
}

extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1]) 
        let b = Float(components[2])
        
        return String(format: "%02lX%02lX%02lX", 
                     lroundf(r * 255), 
                     lroundf(g * 255), 
                     lroundf(b * 255))
    }
    
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)  
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Database Protocol
protocol DatabaseModel: Codable, Identifiable {
    associatedtype LocalModel
    
    static var tableName: String { get }
    var id: String { get }
    var user_id: String? { get }
    var created_at: String? { get }
    var updated_at: String? { get }
    
    func toLocal() -> LocalModel
    init(from local: LocalModel, userId: String)
}

// MARK: - Academic Calendars Table
struct DatabaseAcademicCalendar: DatabaseModel {
    static let tableName = "academic_calendars"
    
    let id: String
    let user_id: String?
    let name: String
    let academic_year: String
    let term_type: String  // 'semester', 'quarter', 'trimester'
    let start_date: String  // date format
    let end_date: String    // date format
    let breaks: [DatabaseAcademicBreak]
    let created_at: String?
    let updated_at: String?
    
    func toLocal() -> AcademicCalendar {
        let startDate = Date.fromFlexibleString(start_date) ?? Date()
        let endDate = Date.fromFlexibleString(end_date) ?? Date()
        let termType = AcademicTermType(rawValue: term_type) ?? .semester
        
        var calendar = AcademicCalendar(
            name: name,
            academicYear: academic_year,
            termType: termType,
            startDate: startDate,
            endDate: endDate
        )
        
        calendar.id = UUID(uuidString: id) ?? UUID()
        calendar.breaks = breaks.map { $0.toLocal() }
        
        return calendar
    }
    
    init(from local: AcademicCalendar, userId: String) {
        self.id = local.id.uuidString
        self.user_id = userId
        self.name = local.name
        self.academic_year = local.academicYear
        self.term_type = local.termType.rawValue
        self.start_date = local.startDate.toDateOnlyString()
        self.end_date = local.endDate.toDateOnlyString()
        self.breaks = local.breaks.map { DatabaseAcademicBreak(from: $0) }
        self.created_at = nil
        self.updated_at = nil
    }
}

struct DatabaseAcademicBreak: Codable {
    let id: String
    let name: String
    let start_date: String
    let end_date: String
    let break_type: String
    
    func toLocal() -> AcademicBreak {
        let startDate = Date.fromISOString(start_date) ?? Date()
        let endDate = Date.fromISOString(end_date) ?? Date()
        let type = BreakType(rawValue: break_type) ?? .custom
        
        var breakPeriod = AcademicBreak(
            name: name,
            type: type,
            startDate: startDate,
            endDate: endDate
        )
        
        breakPeriod.id = UUID(uuidString: id) ?? UUID()
        return breakPeriod
    }
    
    init(from local: AcademicBreak) {
        self.id = local.id.uuidString
        self.name = local.name
        self.start_date = local.startDate.toISOString()
        self.end_date = local.endDate.toISOString()
        self.break_type = local.type.rawValue
    }
}

// MARK: - Assignments Table
struct DatabaseAssignment: DatabaseModel {
    static let tableName = "assignments"
    
    let id: String
    let course_id: String?
    let name: String
    let grade: String
    let weight: String
    let notes: String
    let created_at: String?
    let updated_at: String?
    let user_id: String?
    
    func toLocal() -> Assignment {
        let assignment = Assignment(
            id: UUID(uuidString: id) ?? UUID(),
            courseId: course_id.flatMap { UUID(uuidString: $0) } ?? UUID(),
            name: name,
            grade: grade,
            weight: weight,
            notes: notes
        )
        return assignment
    }
    
    init(from local: Assignment, userId: String) {
        self.id = local.id.uuidString
        self.course_id = local.courseId.uuidString
        self.name = local.name
        self.grade = local.grade
        self.weight = local.weight
        self.notes = local.notes
        self.created_at = nil
        self.updated_at = nil
        self.user_id = userId
    }
}

// MARK: - Categories Table
struct DatabaseCategory: DatabaseModel {
    static let tableName = "categories"
    
    let id: String
    let user_id: String?
    let name: String
    let color_hex: String
    let created_at: String?
    
    var updated_at: String? { nil }
    
    func toLocal() -> Category {
        var category = Category(
            name: name,
            color: Color(hex: color_hex) ?? .blue
        )
        category.id = UUID(uuidString: id) ?? UUID()
        return category
    }
    
    init(from local: Category, userId: String) {
        self.id = local.id.uuidString
        self.user_id = userId
        self.name = local.name
        self.color_hex = local.color.toHex() ?? "007AFF"
        self.created_at = nil
    }
}

// MARK: - Courses Table (Simplified for Traditional Schedules Only)
struct DatabaseCourse: DatabaseModel {
    static let tableName = "courses"
    
    let id: String
    let schedule_id: String?
    let user_id: String?
    let name: String
    let icon_name: String
    let color_hex: String
    let final_grade_goal: String?
    let weight_of_remaining_tasks: String?
    let start_time: String?
    let end_time: String?
    let days_of_week: [Int]?
    let location: String?
    let instructor: String?
    let skipped_instances: [String]?
    let reminder_time: Int?
    let is_live_activity_enabled: Bool?
    let is_rotating: Bool?
    let day1_start_time: String?
    let day1_end_time: String?
    let day2_start_time: String?
    let day2_end_time: String?
    // KEEP: rotating_day for legacy compatibility
    let rotating_day: Int?
    let created_at: String?
    let updated_at: String?
    
    func toLocal() -> Course {
        let scheduleId = schedule_id.flatMap { UUID(uuidString: $0) } ?? UUID()
        
        let course = Course(
            id: UUID(uuidString: id) ?? UUID(),
            scheduleId: scheduleId,
            name: name,
            iconName: icon_name,
            colorHex: color_hex,
            assignments: [],
            finalGradeGoal: final_grade_goal ?? "",
            weightOfRemainingTasks: weight_of_remaining_tasks ?? "",
            startTime: start_time.flatMap { Date.fromTimeString($0) },
            endTime: end_time.flatMap { Date.fromTimeString($0) },
            daysOfWeek: (days_of_week ?? []).compactMap { DayOfWeek(rawValue: $0) },
            location: location ?? "",
            instructor: instructor ?? "",
            creditHours: 3.0,
            courseCode: "",
            section: "",
            isRotating: is_rotating ?? false,
            day1StartTime: day1_start_time.flatMap { Date.fromTimeString($0) },
            day1EndTime: day1_end_time.flatMap { Date.fromTimeString($0) },
            day2StartTime: day2_start_time.flatMap { Date.fromTimeString($0) },
            day2EndTime: day2_end_time.flatMap { Date.fromTimeString($0) }
        )
        
        course.skippedInstanceIdentifiers = Set(skipped_instances ?? [])
        course.reminderTime = reminder_time.flatMap { ReminderTime(rawValue: $0) } ?? .none
        course.isLiveActivityEnabled = is_live_activity_enabled ?? true
        
        return course
    }
    
    init(from local: Course, userId: String) {
        self.id = local.id.uuidString
        self.schedule_id = local.scheduleId.uuidString
        self.user_id = userId
        self.name = local.name
        self.icon_name = local.iconName
        self.color_hex = local.colorHex
        self.final_grade_goal = local.finalGradeGoal
        self.weight_of_remaining_tasks = local.weightOfRemainingTasks
        self.start_time = local.isRotating ? nil : local.startTime?.toTimeString()
        self.end_time = local.isRotating ? nil : local.endTime?.toTimeString()
        self.days_of_week = local.isRotating ? [] : local.daysOfWeek.map { $0.rawValue }
        self.location = local.location
        self.instructor = local.instructor
        self.skipped_instances = Array(local.skippedInstanceIdentifiers)
        self.reminder_time = local.reminderTime.rawValue
        self.is_live_activity_enabled = local.isLiveActivityEnabled
        self.is_rotating = local.isRotating
        self.day1_start_time = local.day1StartTime?.toTimeString()
        self.day1_end_time = local.day1EndTime?.toTimeString()
        self.day2_start_time = local.day2StartTime?.toTimeString()
        self.day2_end_time = local.day2EndTime?.toTimeString()
        self.rotating_day = nil
        self.created_at = nil
        self.updated_at = nil
    }
}

// MARK: - Events Table
struct DatabaseEvent: DatabaseModel {
    static let tableName = "events"
    
    let id: String
    let user_id: String?
    let course_id: String?
    let title: String
    let description: String?
    let event_date: String
    let is_completed: Bool
    let notes: String?
    let event_type: String
    let reminder_time: Int
    let category_id: String?
    let external_identifier: String?
    let source_name: String?
    let sync_to_apple_calendar: Bool
    let sync_to_google_calendar: Bool
    let created_at: String?
    let updated_at: String?
    
    func toLocal() -> Event {
        let eventDate = Date.fromISOString(event_date) ?? Date()
        let reminderTime = ReminderTime(rawValue: reminder_time) ?? .none
        let type = Event.EventType(rawValue: event_type) ?? .generic
        
        var event = Event(
            title: title,
            date: eventDate,
            courseId: course_id.flatMap { UUID(uuidString: $0) },
            categoryId: category_id.flatMap { UUID(uuidString: $0) },
            reminderTime: reminderTime,
            isCompleted: is_completed,
            externalIdentifier: external_identifier,
            sourceName: source_name,
            syncToAppleCalendar: sync_to_apple_calendar,
            syncToGoogleCalendar: sync_to_google_calendar
        )
        
        event.id = UUID(uuidString: id) ?? UUID()
        event.description = description
        event.notes = notes
        event.eventType = type
        
        return event
    }
    
    init(from local: Event, userId: String) {
        self.id = local.id.uuidString
        self.user_id = userId
        self.course_id = local.courseId?.uuidString
        self.title = local.title
        self.description = local.description
        self.event_date = local.date.toISOString()
        self.is_completed = local.isCompleted
        self.notes = local.notes
        self.event_type = local.eventType.rawValue
        self.reminder_time = local.reminderTime.rawValue
        self.category_id = local.categoryId?.uuidString
        self.external_identifier = local.externalIdentifier
        self.source_name = local.sourceName
        self.sync_to_apple_calendar = local.syncToAppleCalendar
        self.sync_to_google_calendar = local.syncToGoogleCalendar
        self.created_at = nil
        self.updated_at = nil
    }
}

// MARK: - Profiles Table
struct DatabaseProfile: DatabaseModel {
    static let tableName = "profiles"
    
    let id: String
    let user_id: String?
    let display_name: String?
    let avatar_url: String?
    let bio: String?
    let created_at: String?
    let updated_at: String?
    
    func toLocal() -> UserProfile {
        return UserProfile(
            id: id,
            user_id: user_id ?? "",
            display_name: display_name,
            avatar_url: avatar_url,
            bio: bio,
            created_at: created_at ?? Date().toISOString(),
            updated_at: updated_at ?? Date().toISOString()
        )
    }
    
    init(from local: UserProfile, userId: String) {
        self.id = local.id
        self.user_id = userId
        self.display_name = local.display_name
        self.avatar_url = local.avatar_url
        self.bio = local.bio
        self.created_at = local.created_at
        self.updated_at = Date().toISOString()
    }
}

// MARK: - Schedule Items Table
struct DatabaseScheduleItem: DatabaseModel {
    static let tableName = "schedule_items"
    
    let id: String
    let schedule_id: String
    let course_id: String?
    let title: String
    let start_time: String  // "HH:mm:ss" format
    let end_time: String    // "HH:mm:ss" format
    let days_of_week: [Int]
    let location: String
    let instructor: String
    let color_hex: String
    let reminder_time: Int
    let is_live_activity_enabled: Bool
    let skipped_instances: [String]
    let created_at: String?
    let updated_at: String?
    
    // Protocol conformance
    var user_id: String? { nil } // schedule items are linked via schedule
    
    func toLocal() -> ScheduleItem {
        let startTime = Date.fromTimeString(start_time)
        let endTime = Date.fromTimeString(end_time)
        let daysOfWeek = days_of_week.compactMap { DayOfWeek(rawValue: $0) }
        let reminderTime = ReminderTime(rawValue: reminder_time) ?? .none
        let color = Color(hex: color_hex) ?? .blue
        
        let scheduleItem = ScheduleItem(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            startTime: startTime,
            endTime: endTime,
            daysOfWeek: daysOfWeek,
            location: location,
            instructor: instructor,
            color: color,
            skippedInstanceIdentifiers: Set(skipped_instances),
            isLiveActivityEnabled: is_live_activity_enabled,
            reminderTime: reminderTime
        )
        
        return scheduleItem
    }
    
    init(from local: ScheduleItem, userId: String, scheduleId: String, courseId: String? = nil) {
        self.id = local.id.uuidString
        self.schedule_id = scheduleId
        self.course_id = courseId
        self.title = local.title
        self.start_time = local.startTime.toTimeString()
        self.end_time = local.endTime.toTimeString()
        self.days_of_week = local.daysOfWeek.map { $0.rawValue }
        self.location = local.location
        self.instructor = local.instructor
        self.color_hex = local.color.toHex() ?? "007AFF"
        self.reminder_time = local.reminderTime.rawValue
        self.is_live_activity_enabled = local.isLiveActivityEnabled
        self.skipped_instances = Array(local.skippedInstanceIdentifiers)
        self.created_at = nil
        self.updated_at = nil
    }
}

extension DatabaseScheduleItem {
    init(from local: ScheduleItem, userId: String) {
        self.init(from: local, userId: userId, scheduleId: "", courseId: nil)
    }
}

// MARK: - Schedules Table
struct DatabaseSchedule: DatabaseModel {
    static let tableName = "schedules"
    
    let id: String
    let user_id: String?
    let name: String
    let semester: String
    let is_active: Bool
    let is_archived: Bool
    let color_hex: String?
    let is_rotating: Bool?
    // Optional legacy support
    let schedule_type: String?
    let academic_calendar_id: String?
    let created_date: String?
    let last_modified: String?
    let updated_at: String?
    let semester_start_date: String?
    let semester_end_date: String?
    
    var created_at: String? { created_date }
    
    enum CodingKeys: String, CodingKey {
        case id, user_id, name, semester, is_active, is_archived, color_hex, is_rotating, schedule_type, academic_calendar_id, created_date, last_modified, updated_at, semester_start_date, semester_end_date
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        user_id = try c.decodeIfPresent(String.self, forKey: .user_id)
        name = try c.decode(String.self, forKey: .name)
        semester = try c.decode(String.self, forKey: .semester)
        is_active = try c.decode(Bool.self, forKey: .is_active)
        is_archived = try c.decode(Bool.self, forKey: .is_archived)
        color_hex = try c.decodeIfPresent(String.self, forKey: .color_hex)
        is_rotating = try c.decodeIfPresent(Bool.self, forKey: .is_rotating)
        schedule_type = try c.decodeIfPresent(String.self, forKey: .schedule_type)
        academic_calendar_id = try c.decodeIfPresent(String.self, forKey: .academic_calendar_id)
        created_date = try c.decodeIfPresent(String.self, forKey: .created_date)
        last_modified = try c.decodeIfPresent(String.self, forKey: .last_modified)
        updated_at = try c.decodeIfPresent(String.self, forKey: .updated_at)
        semester_start_date = try c.decodeIfPresent(String.self, forKey: .semester_start_date)
        semester_end_date = try c.decodeIfPresent(String.self, forKey: .semester_end_date)
    }
    
    func toLocal() -> ScheduleCollection {
        let color = Color(hex: color_hex ?? "007AFF") ?? .blue
        let rotating = is_rotating ?? (ScheduleType(rawValue: schedule_type ?? "") == .rotating)
        let scheduleType: ScheduleType = rotating ? .rotating : .traditional
        let createdDate = created_date.flatMap { Date.fromISOString($0) } ?? Date()
        let lastModified = last_modified.flatMap { Date.fromISOString($0) } ?? Date()
        let academicCalendarID = academic_calendar_id.flatMap { UUID(uuidString: $0) }
        let startDate = semester_start_date.flatMap { Date.fromDateOnlyString($0) }
        let endDate = semester_end_date.flatMap { Date.fromDateOnlyString($0) }
        
        var schedule = ScheduleCollection(
            name: name,
            semester: semester,
            color: color,
            scheduleType: scheduleType
        )
        
        schedule.id = UUID(uuidString: id) ?? UUID()
        schedule.isActive = is_active
        schedule.isArchived = is_archived
        schedule.createdDate = createdDate
        schedule.lastModified = lastModified
        schedule.academicCalendarID = academicCalendarID
        schedule.semesterStartDate = startDate
        schedule.semesterEndDate = endDate
        
        return schedule
    }
    
    init(from local: ScheduleCollection, userId: String) {
        self.id = local.id.uuidString
        self.user_id = userId
        self.name = local.name
        self.semester = local.semester
        self.is_active = local.isActive
        self.is_archived = local.isArchived
        self.color_hex = nil
        self.is_rotating = (local.scheduleType == .rotating)
        self.schedule_type = nil
        self.academic_calendar_id = local.academicCalendarID?.uuidString
        self.created_date = local.createdDate.toISOString()
        self.last_modified = local.lastModified.toISOString()
        self.updated_at = Date().toISOString()
        self.semester_start_date = local.semesterStartDate?.toDateOnlyString()
        self.semester_end_date = local.semesterEndDate?.toDateOnlyString()
    }
}

// MARK: - Subscribers Table  
struct DatabaseSubscriber: DatabaseModel {
    static let tableName = "subscribers"
    
    let id: String
    let user_id: String?
    let email: String
    let stripe_customer_id: String?
    let subscribed: Bool
    let subscription_tier: String
    let role: String
    let subscription_end: String?
    let updated_at: String?
    let created_at: String?
    
    func toLocal() -> UserSubscription {
        let subscriptionEnd = subscription_end.flatMap { Date.fromISOString($0) }?.toISOString()
        
        return UserSubscription(
            id: id,
            user_id: user_id ?? "",
            email: email,
            stripe_customer_id: stripe_customer_id,
            subscribed: subscribed,
            subscription_tier: subscription_tier,
            role: role,
            subscription_end: subscriptionEnd,
            updated_at: updated_at ?? Date().toISOString(),
            created_at: created_at ?? Date().toISOString()
        )
    }
    
    init(from local: UserSubscription, userId: String) {
        self.id = local.id
        self.user_id = userId
        self.email = local.email
        self.stripe_customer_id = local.stripe_customer_id
        self.subscribed = local.subscribed
        self.subscription_tier = local.subscription_tier
        self.role = local.role
        self.subscription_end = local.subscription_end
        self.updated_at = Date().toISOString()
        self.created_at = local.created_at
    }
}

// MARK: - Supporting Models
struct UserProfile: Codable {
    let id: String
    let user_id: String
    let display_name: String?
    let avatar_url: String?
    let bio: String?
    let created_at: String
    let updated_at: String
    
    var displayName: String {
        display_name ?? "User"
    }
    
    var createdDate: Date? {
        Date.fromISOString(created_at)
    }
    
    var updatedDate: Date? {
        Date.fromISOString(updated_at)
    }
}

struct UserSubscription: Codable {
    let id: String
    let user_id: String
    let email: String
    let stripe_customer_id: String?
    let subscribed: Bool
    let subscription_tier: String
    let role: String
    let subscription_end: String?
    let updated_at: String
    let created_at: String
    
    var subscriptionTier: SubscriptionTier {
        SubscriptionTier(rawValue: subscription_tier) ?? .free
    }
    
    var userRole: UserRole {
        UserRole(rawValue: role) ?? .free
    }
    
    var isActive: Bool {
        guard subscribed else { return false }
        
        if let endDateString = subscription_end,
           let endDate = Date.fromISOString(endDateString) {
            return Date() < endDate
        }
        
        return subscribed
    }
    
    var subscriptionEndDate: Date? {
        guard let endDateString = subscription_end else { return nil }
        return Date.fromISOString(endDateString)
    }
}

enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    case founder = "founder"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .founder: return "Founder"
        }
    }
    
    var color: Color {
        switch self {
        case .free: return .gray
        case .premium: return .blue
        case .founder: return .purple
        }
    }
}

enum UserRole: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    case founder = "founder"
    
    var subscriptionTier: SubscriptionTier {
        switch self {
        case .free: return .free
        case .premium: return .premium
        case .founder: return .founder
        }
    }
}

struct DatabaseCourseMeeting: DatabaseModel {
    static let tableName = "course_meetings"
    
    let id: String
    let user_id: String?
    let course_id: String
    let schedule_id: String?
    let rotation_label: String?
    let rotation_index: Int?
    let start_time: String
    let end_time: String
    let location: String?
    let instructor: String?
    let reminder_time: Int?
    let is_live_activity_enabled: Bool?
    let skipped_instances: [String]?
    let created_at: String?
    let updated_at: String?
    
    func toLocal() -> CourseMeeting {
        CourseMeeting(
            id: UUID(uuidString: id) ?? UUID(),
            userId: user_id.flatMap { UUID(uuidString: $0) },
            courseId: UUID(uuidString: course_id) ?? UUID(),
            scheduleId: schedule_id.flatMap { UUID(uuidString: $0) },
            rotationLabel: rotation_label,
            rotationIndex: rotation_index,
            startTime: Date.fromTimeString(start_time),
            endTime: Date.fromTimeString(end_time),
            location: location ?? "",
            instructor: instructor ?? "",
            reminderTime: reminder_time.flatMap { ReminderTime(rawValue: $0) } ?? .none,
            isLiveActivityEnabled: is_live_activity_enabled ?? true,
            skippedInstanceIdentifiers: Set(skipped_instances ?? [])
        )
    }
    
    init(from local: CourseMeeting, userId: String) {
        self.id = local.id.uuidString
        self.user_id = userId
        self.course_id = local.courseId.uuidString
        self.schedule_id = local.scheduleId?.uuidString
        self.rotation_label = local.rotationLabel
        self.rotation_index = local.rotationIndex
        self.start_time = local.startTime.toTimeString()
        self.end_time = local.endTime.toTimeString()
        self.location = local.location
        self.instructor = local.instructor
        self.reminder_time = local.reminderTime.rawValue
        self.is_live_activity_enabled = local.isLiveActivityEnabled
        self.skipped_instances = Array(local.skippedInstanceIdentifiers)
        self.created_at = nil
        self.updated_at = nil
    }
}