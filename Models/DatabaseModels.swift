import Foundation
import SwiftUI

// MARK: - Database Models for Supabase Sync

/// Database representation of an Event
struct DatabaseEvent: Codable {
    let id: String
    let user_id: String
    let course_id: String?
    let title: String
    let description: String?
    let date: String // ISO 8601 format
    let is_completed: Bool
    let notes: String?
    let event_type: String
    let reminder_time: String
    let category_id: String?
    let apple_calendar_identifier: String?
    let google_calendar_identifier: String?
    let external_identifier: String?
    let source_name: String?
    let sync_to_apple_calendar: Bool
    let sync_to_google_calendar: Bool
    let created_at: String?
    let updated_at: String?
    
    /// Convert from local Event model
    init(from event: Event, userId: String) {
        self.id = event.id.uuidString
        self.user_id = userId
        self.course_id = event.courseId?.uuidString
        self.title = event.title
        self.description = event.description
        self.date = event.date.toISOString()
        self.is_completed = event.isCompleted
        self.notes = event.notes
        self.event_type = event.eventType.rawValue
        self.reminder_time = event.reminderTime.stringValue
        self.category_id = event.categoryId?.uuidString
        self.apple_calendar_identifier = event.appleCalendarIdentifier
        self.google_calendar_identifier = event.googleCalendarIdentifier
        self.external_identifier = event.externalIdentifier
        self.source_name = event.sourceName
        self.sync_to_apple_calendar = event.syncToAppleCalendar
        self.sync_to_google_calendar = event.syncToGoogleCalendar
        self.created_at = nil // Server will set this
        self.updated_at = nil // Server will set this
    }
    
    /// Convert to local Event model
    func toLocal() -> Event {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let eventDate = dateFormatter.date(from: date) ?? {
            // Fallback without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            return dateFormatter.date(from: date)
        }() ?? Date()
        
        var event = Event(
            title: title,
            date: eventDate,
            courseId: course_id.flatMap { UUID(uuidString: $0) },
            categoryId: category_id.flatMap { UUID(uuidString: $0) },
            reminderTime: ReminderTime.fromString(reminder_time) ?? .none,
            isCompleted: is_completed,
            externalIdentifier: external_identifier,
            sourceName: source_name,
            syncToAppleCalendar: sync_to_apple_calendar,
            syncToGoogleCalendar: sync_to_google_calendar
        )
        
        event.id = UUID(uuidString: id) ?? UUID()
        event.description = description
        event.notes = notes
        event.eventType = Event.EventType(rawValue: event_type) ?? .generic
        event.appleCalendarIdentifier = apple_calendar_identifier
        event.googleCalendarIdentifier = google_calendar_identifier
        
        return event
    }
}

/// Database representation of a Category
struct DatabaseCategory: Codable {
    let id: String
    let user_id: String
    let name: String
    let color: String // Hex color
    let created_at: String?
    let updated_at: String?
    
    /// Convert from local Category model
    init(from category: Category, userId: String) {
        self.id = category.id.uuidString
        self.user_id = userId
        self.name = category.name
        self.color = category.color.toHex() ?? "007AFF"
        self.created_at = nil // Server will set this
        self.updated_at = nil // Server will set this
    }
    
    /// Convert to local Category model
    func toLocal() -> Category {
        var category = Category(
            name: name,
            color: Color(hex: color) ?? .blue
        )
        category.id = UUID(uuidString: id) ?? UUID()
        return category
    }
}

/// Database representation of a ScheduleItem
struct DatabaseScheduleItem: Codable {
    let id: String
    let user_id: String
    let schedule_id: String
    let title: String
    let start_time: String // ISO 8601 format
    let end_time: String // ISO 8601 format
    let days_of_week: [Int] // Array of DayOfWeek raw values
    let location: String
    let instructor: String
    let color: String // Hex color
    let skipped_instances: [String] // Array of skipped instance identifiers
    let is_live_activity_enabled: Bool
    let reminder_time: String
    let created_at: String?
    let updated_at: String?
    
    /// Convert from local ScheduleItem model
    init(from scheduleItem: ScheduleItem, userId: String, scheduleId: String) {
        self.id = scheduleItem.id.uuidString
        self.user_id = userId
        self.schedule_id = scheduleId
        self.title = scheduleItem.title
        self.start_time = scheduleItem.startTime.toISOString()
        self.end_time = scheduleItem.endTime.toISOString()
        self.days_of_week = scheduleItem.daysOfWeek.map { $0.rawValue }
        self.location = scheduleItem.location
        self.instructor = scheduleItem.instructor
        self.color = scheduleItem.color.toHex() ?? "007AFF"
        self.skipped_instances = Array(scheduleItem.skippedInstanceIdentifiers)
        self.is_live_activity_enabled = scheduleItem.isLiveActivityEnabled
        self.reminder_time = scheduleItem.reminderTime.stringValue
        self.created_at = nil // Server will set this
        self.updated_at = nil // Server will set this
    }
    
    /// Convert to local ScheduleItem model
    func toLocal() -> ScheduleItem {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let startDate = dateFormatter.date(from: start_time) ?? {
            dateFormatter.formatOptions = [.withInternetDateTime]
            return dateFormatter.date(from: start_time)
        }() ?? Date()
        
        let endDate = dateFormatter.date(from: end_time) ?? {
            dateFormatter.formatOptions = [.withInternetDateTime]
            return dateFormatter.date(from: end_time)
        }() ?? Date()
        
        let daysOfWeek = days_of_week.compactMap { DayOfWeek(rawValue: $0) }
        
        return ScheduleItem(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            startTime: startDate,
            endTime: endDate,
            daysOfWeek: daysOfWeek,
            location: location,
            instructor: instructor,
            color: Color(hex: color) ?? .blue,
            skippedInstanceIdentifiers: Set(skipped_instances),
            isLiveActivityEnabled: is_live_activity_enabled,
            reminderTime: ReminderTime.fromString(reminder_time) ?? .none
        )
    }
}

/// Database representation of a Course
struct DatabaseCourse: Codable {
    let id: String
    let user_id: String
    let schedule_id: String
    let name: String
    let icon_name: String
    let color_hex: String
    let final_grade_goal: String
    let weight_of_remaining_tasks: String
    let created_at: String?
    let updated_at: String?
    
    /// Convert from local Course model
    init(from course: Course, userId: String) {
        self.id = course.id.uuidString
        self.user_id = userId
        self.schedule_id = course.scheduleId.uuidString
        self.name = course.name
        self.icon_name = course.iconName
        self.color_hex = course.colorHex
        self.final_grade_goal = course.finalGradeGoal
        self.weight_of_remaining_tasks = course.weightOfRemainingTasks
        self.created_at = nil // Server will set this
        self.updated_at = nil // Server will set this
    }
    
    /// Convert to local Course model
    func toLocal() -> Course {
        return Course(
            id: UUID(uuidString: id) ?? UUID(),
            scheduleId: UUID(uuidString: schedule_id) ?? UUID(),
            name: name,
            iconName: icon_name,
            colorHex: color_hex,
            assignments: [], // Assignments are loaded separately
            finalGradeGoal: final_grade_goal,
            weightOfRemainingTasks: weight_of_remaining_tasks
        )
    }
}

/// Database representation of an Assignment
struct DatabaseAssignment: Codable {
    let id: String
    let user_id: String
    let course_id: String
    let name: String
    let grade: String
    let weight: String
    let created_at: String?
    let updated_at: String?
    
    /// Convert from local Assignment model
    init(from assignment: Assignment, userId: String, courseId: String) {
        self.id = assignment.id.uuidString
        self.user_id = userId
        self.course_id = courseId
        self.name = assignment.name
        self.grade = assignment.grade
        self.weight = assignment.weight
        self.created_at = nil // Server will set this
        self.updated_at = nil // Server will set this
    }
    
    /// Convert to local Assignment model
    func toLocal() -> Assignment {
        return Assignment(
            id: UUID(uuidString: id) ?? UUID(),
            courseId: UUID(uuidString: course_id) ?? UUID(),
            name: name,
            grade: grade,
            weight: weight
        )
    }
}

/// Database representation of an AcademicCalendar
struct DatabaseAcademicCalendar: Codable {
    let id: String
    let user_id: String
    let name: String
    let academic_year: String
    let term_type: String
    let start_date: String // ISO 8601 format
    let end_date: String // ISO 8601 format
    let breaks: [DatabaseAcademicBreak]
    let created_at: String?
    let updated_at: String?
    
    /// Convert from local AcademicCalendar model
    init(from calendar: AcademicCalendar, userId: String) {
        self.id = calendar.id.uuidString
        self.user_id = userId
        self.name = calendar.name
        self.academic_year = calendar.academicYear
        self.term_type = calendar.termType.rawValue
        self.start_date = calendar.startDate.toISOString()
        self.end_date = calendar.endDate.toISOString()
        self.breaks = calendar.breaks.map { DatabaseAcademicBreak(from: $0) }
        self.created_at = nil // Server will set this
        self.updated_at = nil // Server will set this
    }
    
    /// Convert to local AcademicCalendar model
    func toLocal() -> AcademicCalendar {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let startDate = dateFormatter.date(from: start_date) ?? {
            dateFormatter.formatOptions = [.withInternetDateTime]
            return dateFormatter.date(from: start_date)
        }() ?? Date()
        
        let endDate = dateFormatter.date(from: end_date) ?? {
            dateFormatter.formatOptions = [.withInternetDateTime]
            return dateFormatter.date(from: end_date)
        }() ?? Date()
        
        var calendar = AcademicCalendar(
            name: name,
            academicYear: academic_year,
            termType: AcademicTermType(rawValue: term_type) ?? .semester,
            startDate: startDate,
            endDate: endDate
        )
        
        // Set the ID and breaks after initialization
        calendar.id = UUID(uuidString: id) ?? UUID()
        calendar.breaks = breaks.map { $0.toLocal() }
        
        return calendar
    }
}

/// Database representation of an AcademicBreak
struct DatabaseAcademicBreak: Codable {
    let id: String
    let name: String
    let start_date: String // ISO 8601 format
    let end_date: String // ISO 8601 format
    let break_type: String
    
    /// Convert from local AcademicBreak model
    init(from academicBreak: AcademicBreak) {
        self.id = academicBreak.id.uuidString
        self.name = academicBreak.name
        self.start_date = academicBreak.startDate.toISOString()
        self.end_date = academicBreak.endDate.toISOString()
        self.break_type = academicBreak.type.rawValue
    }
    
    /// Convert to local AcademicBreak model
    func toLocal() -> AcademicBreak {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let startDate = dateFormatter.date(from: start_date) ?? {
            dateFormatter.formatOptions = [.withInternetDateTime]
            return dateFormatter.date(from: start_date)
        }() ?? Date()
        
        let endDate = dateFormatter.date(from: end_date) ?? {
            dateFormatter.formatOptions = [.withInternetDateTime]
            return dateFormatter.date(from: end_date)
        }() ?? Date()
        
        var academicBreak = AcademicBreak(
            name: name,
            type: BreakType(rawValue: break_type) ?? .custom,
            startDate: startDate,
            endDate: endDate
        )
        
        // Set the ID after initialization
        academicBreak.id = UUID(uuidString: id) ?? UUID()
        
        return academicBreak
    }
}

// MARK: - ReminderTime Extension for Database Sync

extension ReminderTime {
    var stringValue: String {
        return String(self.rawValue)
    }
    
    static func fromString(_ string: String) -> ReminderTime? {
        guard let rawValue = Int(string) else { return nil }
        return ReminderTime(rawValue: rawValue)
    }
}