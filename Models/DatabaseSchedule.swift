import Foundation
import SwiftUI

/// Database representation of a Schedule (schedules table)
struct DatabaseSchedule: Codable {
    let id: String
    let user_id: String
    let name: String
    let semester: String
    let is_active: Bool
    let is_archived: Bool
    let color_hex: String
    let schedule_type: String
    let academic_calendar_id: String?
    let created_date: String?
    let last_modified: String?
    let created_at: String?
    let updated_at: String?
    
    /// Convert from local ScheduleCollection model
    init(from schedule: ScheduleCollection, userId: String) {
        self.id = schedule.id.uuidString
        self.user_id = userId
        self.name = schedule.name
        self.semester = schedule.semester
        self.is_active = schedule.isActive
        self.is_archived = schedule.isArchived
        self.color_hex = schedule.color.toHex() ?? "007AFF"
        self.schedule_type = schedule.scheduleType.rawValue
        self.academic_calendar_id = schedule.academicCalendarID?.uuidString
        self.created_date = schedule.createdDate.toISOString()
        self.last_modified = schedule.lastModified.toISOString()
        self.created_at = nil // Server will set this
        self.updated_at = nil // Server will set this
    }
    
    /// Convert to local ScheduleCollection model
    func toLocal() -> ScheduleCollection {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdDate = created_date.flatMap { dateString in
            dateFormatter.date(from: dateString) ?? {
                dateFormatter.formatOptions = [.withInternetDateTime]
                return dateFormatter.date(from: dateString)
            }()
        } ?? Date()
        
        let lastModifiedDate = last_modified.flatMap { dateString in
            dateFormatter.date(from: dateString) ?? {
                dateFormatter.formatOptions = [.withInternetDateTime]
                return dateFormatter.date(from: dateString)
            }()
        } ?? Date()
        
        var schedule = ScheduleCollection(
            name: name,
            semester: semester,
            color: Color(hex: color_hex) ?? .blue,
            scheduleType: ScheduleType(rawValue: schedule_type) ?? .traditional
        )
        
        schedule.id = UUID(uuidString: id) ?? UUID()
        schedule.isActive = is_active
        schedule.isArchived = is_archived
        schedule.academicCalendarID = academic_calendar_id.flatMap { UUID(uuidString: $0) }
        schedule.createdDate = createdDate
        schedule.lastModified = lastModifiedDate
        
        return schedule
    }
}
