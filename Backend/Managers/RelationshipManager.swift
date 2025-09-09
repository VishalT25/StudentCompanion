import Foundation
import SwiftUI
import Combine

// MARK: - Cross-Table Relationship Manager
@MainActor
class RelationshipManager: ObservableObject {
    
    // MARK: - Dependencies
    private let courseManager: CourseOperationsManager
    private let eventManager: EventOperationsManager
    private let scheduleManager: ScheduleManager
    private let academicCalendarManager: AcademicCalendarManager
    
    // MARK: - Published State
    @Published private(set) var relationshipIssues: [RelationshipIssue] = []
    @Published private(set) var lastValidationTime: Date?
    @Published private(set) var isValidating = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    init(
        courseManager: CourseOperationsManager,
        eventManager: EventOperationsManager,
        scheduleManager: ScheduleManager,
        academicCalendarManager: AcademicCalendarManager
    ) {
        self.courseManager = courseManager
        self.eventManager = eventManager
        self.scheduleManager = scheduleManager
        self.academicCalendarManager = academicCalendarManager
        
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Listen for changes in any manager
        Publishers.CombineLatest4(
            courseManager.$courses,
            eventManager.$events,
            scheduleManager.$scheduleCollections,
            academicCalendarManager.$academicCalendars
        )
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            Task {
                await self?.validateRelationships()
            }
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Relationship Validation
    
    func validateRelationships() async {
        isValidating = true
        relationshipIssues.removeAll()
        
        // Validate course-schedule relationships
        await validateCourseScheduleRelationships()
        
        // Validate event-course relationships
        await validateEventCourseRelationships()
        
        // Validate event-category relationships
        await validateEventCategoryRelationships()
        
        // Validate schedule-academic calendar relationships
        await validateScheduleCalendarRelationships()
        
        // Validate schedule item-course synchronization
        await validateScheduleItemCourseSync()
        
        lastValidationTime = Date()
        isValidating = false
        
        print("🔗 RelationshipManager: Validation complete - \(relationshipIssues.count) issues found")
    }
    
    private func validateCourseScheduleRelationships() async {
        let scheduleIds = Set(scheduleManager.scheduleCollections.map { $0.id })
        
        for course in courseManager.courses {
            if !scheduleIds.contains(course.scheduleId) {
                relationshipIssues.append(RelationshipIssue(
                    type: .orphanedReference,
                    description: "Course '\(course.name)' references non-existent schedule",
                    sourceTable: "courses",
                    sourceId: course.id.uuidString,
                    targetTable: "schedules",
                    targetId: course.scheduleId.uuidString,
                    severity: .critical,
                    autoFixable: true
                ))
            }
        }
    }
    
    private func validateEventCourseRelationships() async {
        let courseIds = Set(courseManager.courses.map { $0.id })
        
        for event in eventManager.events {
            if let courseId = event.courseId, !courseIds.contains(courseId) {
                relationshipIssues.append(RelationshipIssue(
                    type: .orphanedReference,
                    description: "Event '\(event.title)' references non-existent course",
                    sourceTable: "events",
                    sourceId: event.id.uuidString,
                    targetTable: "courses",
                    targetId: courseId.uuidString,
                    severity: .medium,
                    autoFixable: true
                ))
            }
        }
    }
    
    private func validateEventCategoryRelationships() async {
        let categoryIds = Set(eventManager.categories.map { $0.id })
        
        for event in eventManager.events {
            if let categoryId = event.categoryId, !categoryIds.contains(categoryId) {
                relationshipIssues.append(RelationshipIssue(
                    type: .orphanedReference,
                    description: "Event '\(event.title)' references non-existent category",
                    sourceTable: "events",
                    sourceId: event.id.uuidString,
                    targetTable: "categories",
                    targetId: categoryId.uuidString,
                    severity: .low,
                    autoFixable: true
                ))
            }
        }
    }
    
    private func validateScheduleCalendarRelationships() async {
        let calendarIds = Set(academicCalendarManager.academicCalendars.map { $0.id })
        
        for schedule in scheduleManager.scheduleCollections {
            if let calendarId = schedule.academicCalendarID, !calendarIds.contains(calendarId) {
                relationshipIssues.append(RelationshipIssue(
                    type: .orphanedReference,
                    description: "Schedule '\(schedule.displayName)' references non-existent academic calendar",
                    sourceTable: "schedules",
                    sourceId: schedule.id.uuidString,
                    targetTable: "academic_calendars",
                    targetId: calendarId.uuidString,
                    severity: .medium,
                    autoFixable: true
                ))
            }
        }
    }
    
    private func validateScheduleItemCourseSync() async {
        // Check for schedule items without corresponding courses
        for schedule in scheduleManager.scheduleCollections {
            let scheduleItemIds = Set(schedule.scheduleItems.map { $0.id })
            let scheduleCourseIds = Set(courseManager.getCourses(for: schedule.id).map { $0.id })
            
            // Find schedule items without corresponding courses
            for scheduleItem in schedule.scheduleItems {
                if !scheduleCourseIds.contains(scheduleItem.id) {
                    relationshipIssues.append(RelationshipIssue(
                        type: .syncMismatch,
                        description: "Schedule item '\(scheduleItem.title)' has no corresponding course",
                        sourceTable: "schedule_items",
                        sourceId: scheduleItem.id.uuidString,
                        targetTable: "courses",
                        targetId: scheduleItem.id.uuidString,
                        severity: .medium,
                        autoFixable: true
                    ))
                }
            }
            
            // Find courses without corresponding schedule items
            for course in courseManager.getCourses(for: schedule.id) {
                if course.hasScheduleInfo && !scheduleItemIds.contains(course.id) {
                    relationshipIssues.append(RelationshipIssue(
                        type: .syncMismatch,
                        description: "Course '\(course.name)' has schedule info but no schedule item",
                        sourceTable: "courses",
                        sourceId: course.id.uuidString,
                        targetTable: "schedule_items",
                        targetId: course.id.uuidString,
                        severity: .medium,
                        autoFixable: true
                    ))
                }
            }
        }
    }
    
    // MARK: - Auto-Fix Operations
    
    func autoFixAllIssues() async {
        let fixableIssues = relationshipIssues.filter { $0.autoFixable }
        
        print("🔧 RelationshipManager: Auto-fixing \(fixableIssues.count) issues...")
        
        var fixedCount = 0
        
        for issue in fixableIssues {
            let success = await autoFixIssue(issue)
            if success {
                fixedCount += 1
                relationshipIssues.removeAll { $0.id == issue.id }
            }
        }
        
        print("🔧 RelationshipManager: Auto-fixed \(fixedCount)/\(fixableIssues.count) issues")
        
        // Re-validate after fixes
        await validateRelationships()
    }
    
    func autoFixIssue(_ issue: RelationshipIssue) async -> Bool {
        switch issue.type {
        case .orphanedReference:
            return await fixOrphanedReference(issue)
        case .syncMismatch:
            return await fixSyncMismatch(issue)
        case .duplicateData:
            return await fixDuplicateData(issue)
        case .inconsistentData:
            return await fixInconsistentData(issue)
        }
    }
    
    private func fixOrphanedReference(_ issue: RelationshipIssue) async -> Bool {
        switch (issue.sourceTable, issue.targetTable) {
        case ("events", "courses"):
            // Remove course reference from event
            if let eventId = UUID(uuidString: issue.sourceId),
               let event = eventManager.getEvent(by: eventId) {
                var updatedEvent = event
                updatedEvent.courseId = nil
                eventManager.updateEvent(updatedEvent)
                return true
            }
            
        case ("events", "categories"):
            // Remove category reference from event
            if let eventId = UUID(uuidString: issue.sourceId),
               let event = eventManager.getEvent(by: eventId) {
                var updatedEvent = event
                updatedEvent.categoryId = nil
                eventManager.updateEvent(updatedEvent)
                return true
            }
            
        case ("courses", "schedules"):
            // Move course to active schedule or create new schedule
            if let courseId = UUID(uuidString: issue.sourceId),
               let course = courseManager.getCourse(by: courseId) {
                
                if let activeSchedule = scheduleManager.activeSchedule {
                    var updatedCourse = course
                    updatedCourse.scheduleId = activeSchedule.id
                    courseManager.updateCourse(updatedCourse)
                    return true
                } else {
                    // Create a new schedule for orphaned courses
                    let newSchedule = ScheduleCollection(
                        name: "Default Schedule",
                        semester: getCurrentSemester(),
                        color: .blue
                    )
                    scheduleManager.addSchedule(newSchedule)
                    scheduleManager.setActiveSchedule(newSchedule.id)
                    
                    var updatedCourse = course
                    updatedCourse.scheduleId = newSchedule.id
                    courseManager.updateCourse(updatedCourse)
                    return true
                }
            }
            
        case ("schedules", "academic_calendars"):
            // Remove academic calendar reference from schedule
            if let scheduleId = UUID(uuidString: issue.sourceId),
               let schedule = scheduleManager.schedule(for: scheduleId) {
                var updatedSchedule = schedule
                updatedSchedule.academicCalendarID = nil
                scheduleManager.updateSchedule(updatedSchedule)
                return true
            }
            
        default:
            break
        }
        
        return false
    }
    
    private func fixSyncMismatch(_ issue: RelationshipIssue) async -> Bool {
        switch (issue.sourceTable, issue.targetTable) {
        case ("schedule_items", "courses"):
            // Create course from schedule item
            if let scheduleItemId = UUID(uuidString: issue.sourceId) {
                for schedule in scheduleManager.scheduleCollections {
                    if let scheduleItem = schedule.scheduleItems.first(where: { $0.id == scheduleItemId }) {
                        let course = Course.from(scheduleItem: scheduleItem, scheduleId: schedule.id)
                        courseManager.addCourse(course)
                        return true
                    }
                }
            }
            
        case ("courses", "schedule_items"):
            // Create schedule item from course
            if let courseId = UUID(uuidString: issue.sourceId),
               let course = courseManager.getCourse(by: courseId),
               course.hasScheduleInfo {
                let scheduleItem = course.toScheduleItem()
                scheduleManager.addScheduleItem(scheduleItem, to: course.scheduleId)
                return true
            }
            
        default:
            break
        }
        
        return false
    }
    
    private func fixDuplicateData(_ issue: RelationshipIssue) async -> Bool {
        // Implementation for fixing duplicate data
        return false
    }
    
    private func fixInconsistentData(_ issue: RelationshipIssue) async -> Bool {
        // Implementation for fixing inconsistent data
        return false
    }
    
    // MARK: - Relationship Operations
    
    func linkEventToCourse(_ event: Event, course: Course) {
        var updatedEvent = event
        updatedEvent.courseId = course.id
        eventManager.updateEvent(updatedEvent)
    }
    
    func linkEventToCategory(_ event: Event, category: Category) {
        var updatedEvent = event
        updatedEvent.categoryId = category.id
        eventManager.updateEvent(updatedEvent)
    }
    
    func unlinkEventFromCourse(_ event: Event) {
        var updatedEvent = event
        updatedEvent.courseId = nil
        eventManager.updateEvent(updatedEvent)
    }
    
    func unlinkEventFromCategory(_ event: Event) {
        var updatedEvent = event
        updatedEvent.categoryId = nil
        eventManager.updateEvent(updatedEvent)
    }
    
    func syncCourseWithScheduleItem(_ course: Course) {
        guard course.hasScheduleInfo else { return }
        
        let scheduleItem = course.toScheduleItem()
        
        // Check if schedule item already exists
        if let schedule = scheduleManager.schedule(for: course.scheduleId),
           let existingItem = schedule.scheduleItems.first(where: { $0.id == course.id }) {
            // Update existing schedule item
            scheduleManager.updateScheduleItem(scheduleItem, in: course.scheduleId)
        } else {
            // Create new schedule item
            scheduleManager.addScheduleItem(scheduleItem, to: course.scheduleId)
        }
    }
    
    func syncScheduleItemWithCourse(_ scheduleItem: ScheduleItem, scheduleId: UUID) {
        // Check if course already exists
        if let existingCourse = courseManager.getCourse(by: scheduleItem.id) {
            // Update existing course with schedule item data
            var updatedCourse = existingCourse
            updatedCourse.name = scheduleItem.title
            updatedCourse.startTime = scheduleItem.startTime
            updatedCourse.endTime = scheduleItem.endTime
            updatedCourse.daysOfWeek = scheduleItem.daysOfWeek
            updatedCourse.location = scheduleItem.location
            updatedCourse.instructor = scheduleItem.instructor
            updatedCourse.colorHex = scheduleItem.color.toHex() ?? updatedCourse.colorHex
            courseManager.updateCourse(updatedCourse)
        } else {
            // Create new course from schedule item
            let course = Course.from(scheduleItem: scheduleItem, scheduleId: scheduleId)
            courseManager.addCourse(course)
        }
    }
    
    // MARK: - Batch Operations
    
    func cascadeDeleteCourse(_ course: Course) {
        // Delete all assignments for the course
        let courseAssignments = courseManager.getAssignments(for: course.id)
        for assignment in courseAssignments {
            courseManager.deleteAssignment(assignment)
        }
        
        // Remove course reference from events
        let courseEvents = eventManager.getEvents(for: course.id)
        for event in courseEvents {
            unlinkEventFromCourse(event)
        }
        
        // Remove schedule item if it exists
        if let schedule = scheduleManager.schedule(for: course.scheduleId),
           let scheduleItem = schedule.scheduleItems.first(where: { $0.id == course.id }) {
            scheduleManager.deleteScheduleItem(scheduleItem, from: course.scheduleId)
        }
        
        // Finally delete the course
        courseManager.deleteCourse(course)
    }
    
    func cascadeDeleteCategory(_ category: Category) {
        // Remove category reference from all events
        let categoryEvents = eventManager.getEvents(for: category.id)
        for event in categoryEvents {
            unlinkEventFromCategory(event)
        }
        
        // Finally delete the category
        eventManager.deleteCategory(category)
    }
    
    // MARK: - Utilities
    
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
    
    // MARK: - Statistics
    
    var relationshipHealth: RelationshipHealth {
        let totalIssues = relationshipIssues.count
        let criticalIssues = relationshipIssues.filter { $0.severity == .critical }.count
        let autoFixableIssues = relationshipIssues.filter { $0.autoFixable }.count
        
        var healthScore = 1.0
        if totalIssues > 0 {
            healthScore = max(0.0, 1.0 - (Double(criticalIssues * 3 + totalIssues) / 100.0))
        }
        
        return RelationshipHealth(
            totalIssues: totalIssues,
            criticalIssues: criticalIssues,
            autoFixableIssues: autoFixableIssues,
            healthScore: healthScore,
            lastValidation: lastValidationTime
        )
    }
}

// MARK: - Supporting Types

enum RelationshipIssueType {
    case orphanedReference
    case syncMismatch
    case duplicateData
    case inconsistentData
    
    var displayName: String {
        switch self {
        case .orphanedReference: return "Orphaned Reference"
        case .syncMismatch: return "Sync Mismatch"
        case .duplicateData: return "Duplicate Data"
        case .inconsistentData: return "Inconsistent Data"
        }
    }
}

enum RelationshipSeverity {
    case low, medium, high, critical
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct RelationshipIssue: Identifiable {
    let id = UUID()
    let type: RelationshipIssueType
    let description: String
    let sourceTable: String
    let sourceId: String
    let targetTable: String
    let targetId: String
    let severity: RelationshipSeverity
    let autoFixable: Bool
    let timestamp = Date()
}

struct RelationshipHealth {
    let totalIssues: Int
    let criticalIssues: Int
    let autoFixableIssues: Int
    let healthScore: Double
    let lastValidation: Date?
    
    var healthGrade: String {
        switch healthScore {
        case 0.9...1.0: return "A"
        case 0.8..<0.9: return "B"
        case 0.7..<0.8: return "C"
        case 0.6..<0.7: return "D"
        default: return "F"
        }
    }
    
    var healthColor: Color {
        switch healthScore {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .yellow
        case 0.5..<0.7: return .orange
        default: return .red
        }
    }
    
    var isHealthy: Bool {
        criticalIssues == 0 && healthScore > 0.8
    }
}