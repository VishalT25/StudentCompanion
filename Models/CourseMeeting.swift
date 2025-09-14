import Foundation
import SwiftUI

// MARK: - REWRITTEN: Simple, Clean Course Meeting Model
struct CourseMeeting: Identifiable, Codable, Hashable, Equatable {
    var id = UUID()
    var userId: UUID?
    var courseId: UUID
    var scheduleId: UUID?
    
    // Rotation properties - simplified
    var rotationLabel: String? // e.g., "Day 1", "Day 2"
    var rotationIndex: Int? // 1-based index (1, 2, 3, etc.)
    
    // Time and location
    var startTime: Date
    var endTime: Date
    var location: String
    var instructor: String
    
    // Settings
    var reminderTime: ReminderTime
    var isLiveActivityEnabled: Bool
    var skippedInstanceIdentifiers: Set<String>
    
    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        courseId: UUID,
        scheduleId: UUID? = nil,
        rotationLabel: String? = nil,
        rotationIndex: Int? = nil,
        startTime: Date,
        endTime: Date,
        location: String = "",
        instructor: String = "",
        reminderTime: ReminderTime = .none,
        isLiveActivityEnabled: Bool = true,
        skippedInstanceIdentifiers: Set<String> = []
    ) {
        self.id = id
        self.userId = userId
        self.courseId = courseId
        self.scheduleId = scheduleId
        self.rotationLabel = rotationLabel
        self.rotationIndex = rotationIndex
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.instructor = instructor
        self.reminderTime = reminderTime
        self.isLiveActivityEnabled = isLiveActivityEnabled
        self.skippedInstanceIdentifiers = skippedInstanceIdentifiers
    }
    
    // MARK: - Simplified Schedule Integration
    func toScheduleItem(using course: Course) -> ScheduleItem {
        ScheduleItem(
            id: id,
            title: course.name,
            startTime: startTime,
            endTime: endTime,
            daysOfWeek: [], // Rotation meetings don't use days of week
            location: location.isEmpty ? course.location : location,
            instructor: instructor.isEmpty ? course.instructor : instructor,
            color: course.color,
            skippedInstanceIdentifiers: skippedInstanceIdentifiers,
            isLiveActivityEnabled: isLiveActivityEnabled,
            reminderTime: reminderTime
        )
    }
    
    // MARK: - Skip Handling
    func isSkipped(onDate date: Date) -> Bool {
        let identifier = CourseMeeting.instanceIdentifier(for: id, onDate: date)
        return skippedInstanceIdentifiers.contains(identifier)
    }
    
    static func instanceIdentifier(for id: UUID, onDate date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(id.uuidString)_\(dateFormatter.string(from: date))"
    }
    
    // MARK: - Equatable
    static func == (lhs: CourseMeeting, rhs: CourseMeeting) -> Bool {
        return lhs.id == rhs.id &&
               lhs.courseId == rhs.courseId &&
               lhs.rotationIndex == rhs.rotationIndex &&
               lhs.rotationLabel == rhs.rotationLabel &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(courseId)
        hasher.combine(rotationIndex)
        hasher.combine(rotationLabel)
    }
    
    // MARK: - Debug Description
    var debugDescription: String {
        return "CourseMeeting(id: \(id.uuidString.prefix(8)), rotationLabel: '\(rotationLabel ?? "nil")', rotationIndex: \(rotationIndex ?? -1), time: \(startTime.formatted(date: .omitted, time: .shortened))-\(endTime.formatted(date: .omitted, time: .shortened)))"
    }
}

// MARK: - Helper Extensions
extension Array where Element == CourseMeeting {
    var debugDescription: String {
        return "[\n" + self.map { "  \($0.debugDescription)" }.joined(separator: ",\n") + "\n]"
    }
}