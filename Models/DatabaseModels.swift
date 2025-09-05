import Foundation
import SwiftUI

// MARK: - Helpers
private let isoFormatterWithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private func parseISODate(_ s: String) -> Date? {
    if let d = isoFormatterWithFractional.date(from: s) { return d }
    return isoFormatter.date(from: s)
}

private func timeString(from date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = "HH:mm:ss"
    return df.string(from: date)
}

// Create a Date anchored to today with the given time string (HH:mm:ss)
private func dateFromTime(_ time: String) -> Date {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = "HH:mm:ss"
    let today = Date()
    guard let t = df.date(from: time) else { return today }
    var comps = Calendar.current.dateComponents([.year, .month, .day], from: today)
    let timeComps = Calendar.current.dateComponents([.hour, .minute, .second], from: t)
    comps.hour = timeComps.hour
    comps.minute = timeComps.minute
    comps.second = timeComps.second
    return Calendar.current.date(from: comps) ?? today
}

// MARK: - Database Models for Supabase Sync

// events table
struct DatabaseEvent: Codable {
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
    
    init(from event: Event, userId: String) {
        self.id = event.id.uuidString
        self.user_id = userId
        self.course_id = event.courseId?.uuidString
        self.title = event.title
        self.description = event.description
        self.event_date = event.date.toISOString()
        self.is_completed = event.isCompleted
        self.notes = event.notes
        self.event_type = event.eventType.rawValue
        self.reminder_time = event.reminderTime.rawValue
        self.category_id = event.categoryId?.uuidString
        self.external_identifier = event.externalIdentifier
        self.source_name = event.sourceName
        self.sync_to_apple_calendar = event.syncToAppleCalendar
        self.sync_to_google_calendar = event.syncToGoogleCalendar
        self.created_at = nil
        self.updated_at = nil
    }
    
    func toLocal() -> Event {
        let d = parseISODate(event_date) ?? Date()
        var ev = Event(
            title: title,
            date: d,
            courseId: course_id.flatMap { UUID(uuidString: $0) },
            categoryId: category_id.flatMap { UUID(uuidString: $0) },
            reminderTime: ReminderTime(rawValue: reminder_time) ?? .none,
            isCompleted: is_completed,
            externalIdentifier: external_identifier,
            sourceName: source_name,
            syncToAppleCalendar: sync_to_apple_calendar,
            syncToGoogleCalendar: sync_to_google_calendar
        )
        ev.id = UUID(uuidString: id) ?? UUID()
        ev.description = description
        ev.notes = notes
        ev.eventType = Event.EventType(rawValue: event_type) ?? .generic
        return ev
    }
}

// categories table
struct DatabaseCategory: Codable {
    let id: String
    let user_id: String?
    let name: String
    let color_hex: String
    let created_at: String?
    let updated_at: String?
    
    init(from category: Category, userId: String) {
        self.id = category.id.uuidString
        self.user_id = userId
        self.name = category.name
        self.color_hex = category.color.toHex() ?? "007AFF"
        self.created_at = nil
        self.updated_at = nil
    }
    
    func toLocal() -> Category {
        var c = Category(name: name, color: Color(hex: color_hex) ?? .blue)
        c.id = UUID(uuidString: id) ?? UUID()
        return c
    }
}

// schedule_items table
struct DatabaseScheduleItem: Codable {
    let id: String
    let schedule_id: String
    let course_id: String?
    let title: String
    let start_time: String // "HH:mm:ss"
    let end_time: String   // "HH:mm:ss"
    let days_of_week: [Int]
    let location: String
    let instructor: String
    let color_hex: String
    let reminder_time: Int
    let is_live_activity_enabled: Bool
    let skipped_instances: [String]
    let created_at: String?
    let updated_at: String?
    
    init(from scheduleItem: ScheduleItem, scheduleId: String, courseId: String? = nil) {
        self.id = scheduleItem.id.uuidString
        self.schedule_id = scheduleId
        self.course_id = courseId
        self.title = scheduleItem.title
        self.start_time = timeString(from: scheduleItem.startTime)
        self.end_time = timeString(from: scheduleItem.endTime)
        self.days_of_week = scheduleItem.daysOfWeek.map { $0.rawValue }
        self.location = scheduleItem.location
        self.instructor = scheduleItem.instructor
        self.color_hex = scheduleItem.color.toHex() ?? "007AFF"
        self.reminder_time = scheduleItem.reminderTime.rawValue
        self.is_live_activity_enabled = scheduleItem.isLiveActivityEnabled
        self.skipped_instances = Array(scheduleItem.skippedInstanceIdentifiers)
        self.created_at = nil
        self.updated_at = nil
    }
    
    func toLocal() -> ScheduleItem {
        let startDate = dateFromTime(start_time)
        let endDate = dateFromTime(end_time)
        let days = days_of_week.compactMap { DayOfWeek(rawValue: $0) }
        return ScheduleItem(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            startTime: startDate,
            endTime: endDate,
            daysOfWeek: days,
            location: location,
            instructor: instructor,
            color: Color(hex: color_hex) ?? .blue,
            skippedInstanceIdentifiers: Set(skipped_instances),
            isLiveActivityEnabled: is_live_activity_enabled,
            reminderTime: ReminderTime(rawValue: reminder_time) ?? .none
        )
    }
}

// courses table
struct DatabaseCourse: Codable {
    let id: String
    let user_id: String?
    let schedule_id: String?
    let name: String
    let icon_name: String
    let color_hex: String
    let final_grade_goal: String?
    let weight_of_remaining_tasks: String?
    let created_at: String?
    let updated_at: String?
    
    init(from course: Course, userId: String) {
        self.id = course.id.uuidString
        self.user_id = userId
        self.schedule_id = course.scheduleId.uuidString
        self.name = course.name
        self.icon_name = course.iconName
        self.color_hex = course.colorHex
        self.final_grade_goal = course.finalGradeGoal
        self.weight_of_remaining_tasks = course.weightOfRemainingTasks
        self.created_at = nil
        self.updated_at = nil
    }
    
    func toLocal() -> Course {
        if let scheduleIdStr = schedule_id, let schedUUID = UUID(uuidString: scheduleIdStr) {
            return Course(
                id: UUID(uuidString: id) ?? UUID(),
                scheduleId: schedUUID,
                name: name,
                iconName: icon_name,
                colorHex: color_hex,
                assignments: [],
                finalGradeGoal: final_grade_goal ?? "",
                weightOfRemainingTasks: weight_of_remaining_tasks ?? ""
            )
        } else {
            return Course(
                id: UUID(uuidString: id) ?? UUID(),
                scheduleId: UUID(),
                name: name,
                iconName: icon_name,
                colorHex: color_hex,
                assignments: [],
                finalGradeGoal: final_grade_goal ?? "",
                weightOfRemainingTasks: weight_of_remaining_tasks ?? ""
            )
        }
    }
}

// assignments table
struct DatabaseAssignment: Codable {
    let id: String
    let course_id: String
    let name: String
    let grade: String
    let weight: String
    let created_at: String?
    let updated_at: String?
    
    init(from assignment: Assignment, courseId: String) {
        self.id = assignment.id.uuidString
        self.course_id = courseId
        self.name = assignment.name
        self.grade = assignment.grade
        self.weight = assignment.weight
        self.created_at = nil
        self.updated_at = nil
    }
    
    func toLocal() -> Assignment {
        Assignment(
            id: UUID(uuidString: id) ?? UUID(),
            courseId: UUID(uuidString: course_id) ?? UUID(),
            name: name,
            grade: grade,
            weight: weight
        )
    }
}

// academic_calendars table
struct DatabaseAcademicCalendar: Codable {
    let id: String
    let user_id: String?
    let name: String
    let academic_year: String
    let term_type: String
    let start_date: String
    let end_date: String
    let breaks: [DatabaseAcademicBreak]
    let created_at: String?
    let updated_at: String?
    
    init(from calendar: AcademicCalendar, userId: String) {
        self.id = calendar.id.uuidString
        self.user_id = userId
        self.name = calendar.name
        self.academic_year = calendar.academicYear
        self.term_type = calendar.termType.rawValue
        self.start_date = calendar.startDate.toISOString()
        self.end_date = calendar.endDate.toISOString()
        self.breaks = calendar.breaks.map { DatabaseAcademicBreak(from: $0) }
        self.created_at = nil
        self.updated_at = nil
    }
    
    func toLocal() -> AcademicCalendar {
        let sd = parseISODate(start_date) ?? Date()
        let ed = parseISODate(end_date) ?? Date()
        var cal = AcademicCalendar(
            name: name,
            academicYear: academic_year,
            termType: AcademicTermType(rawValue: term_type) ?? .semester,
            startDate: sd,
            endDate: ed
        )
        cal.id = UUID(uuidString: id) ?? UUID()
        cal.breaks = breaks.map { $0.toLocal() }
        return cal
    }
}

struct DatabaseAcademicBreak: Codable {
    let id: String
    let name: String
    let start_date: String
    let end_date: String
    let break_type: String
    
    init(from academicBreak: AcademicBreak) {
        self.id = academicBreak.id.uuidString
        self.name = academicBreak.name
        self.start_date = academicBreak.startDate.toISOString()
        self.end_date = academicBreak.endDate.toISOString()
        self.break_type = academicBreak.type.rawValue
    }
    
    func toLocal() -> AcademicBreak {
        let sd = parseISODate(start_date) ?? Date()
        let ed = parseISODate(end_date) ?? Date()
        var b = AcademicBreak(
            name: name,
            type: BreakType(rawValue: break_type) ?? .custom,
            startDate: sd,
            endDate: ed
        )
        b.id = UUID(uuidString: id) ?? UUID()
        return b
    }
}

// MARK: - ReminderTime <-> Database
extension ReminderTime {
    var rawInt: Int { rawValue }
    static func fromInt(_ value: Int) -> ReminderTime {
        ReminderTime(rawValue: value) ?? .none
    }
}