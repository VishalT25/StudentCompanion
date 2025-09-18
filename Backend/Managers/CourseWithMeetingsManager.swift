import Foundation
import SwiftUI
import Combine

// MARK: - Course with Meetings Manager
@MainActor
class CourseWithMeetingsManager: ObservableObject {
    @Published private(set) var courses: [Course] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastSyncTime: Date?
    
    // Dependencies
    private let courseRepository: CourseRepository
    private let courseMeetingRepository: CourseMeetingRepository
    private let assignmentRepository: AssignmentRepository
    private let supabaseService = SupabaseService.shared
    private let realtimeSyncManager = RealtimeSyncManager.shared
    private let authPromptHandler = AuthenticationPromptHandler.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        courseRepository = CourseRepository()
        courseMeetingRepository = CourseMeetingRepository()
        assignmentRepository = AssignmentRepository()
        
        setupAuthenticationObserver()
        setupRealtimeSync()
        
        Task {
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        guard supabaseService.isAuthenticated else { return }
        
        isLoading = true
        
        do {
            await loadCoursesWithMeetings()
            lastSyncTime = Date()
            print("✅ CourseWithMeetingsManager: Initialized with \(courses.count) courses")
        } catch {
            print("❌ CourseWithMeetingsManager: Failed to initialize: \(error)")
        }
        
        isLoading = false
    }
    
    private func setupAuthenticationObserver() {
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task { 
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                        await self?.initialize() 
                    }
                } else {
                    self?.clearData()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(
            forName: .init("UserSignedInDataRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshData() }
        }
    }
    
    private func setupRealtimeSync() {
        // Set up realtime sync for courses and meetings
        realtimeSyncManager.courseDelegate = self
        // We'll handle meetings through course updates
    }
    
    private func clearData() {
        courses.removeAll()
        lastSyncTime = nil
    }
    
    // MARK: - Data Loading
    
    private func loadCoursesWithMeetings() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        do {
            print("📥 Loading courses...")
            let loadedCourses = try await courseRepository.readAll(userId: userId)
            print("📥 Loaded \(loadedCourses.count) courses")
            
            print("📥 Loading assignments...")
            let allAssignments = try await assignmentRepository.readAll(userId: userId)
            print("📥 Loaded \(allAssignments.count) assignments")
            
            print("📥 Loading course meetings...")
            var coursesWithMeetings: [Course] = []
            
            for course in loadedCourses {
                var enrichedCourse = course
                
                // Load meetings for this course
                let meetings = try await courseMeetingRepository.findByCourse(course.id.uuidString, userId: userId)
                enrichedCourse.meetings = meetings
                print("📥 Course '\(course.name)' has \(meetings.count) meetings")
                
                // Load assignments for this course
                let courseAssignments = allAssignments.filter { $0.courseId == course.id }
                enrichedCourse.assignments = courseAssignments
                enrichedCourse.refreshObservationsAndSignalChange()
                
                coursesWithMeetings.append(enrichedCourse)
            }
            
            courses = coursesWithMeetings
            print("✅ Loaded \(courses.count) courses with meetings and assignments")
            
        } catch {
            print("❌ Failed to load courses with meetings: \(error)")
        }
    }
    
    // MARK: - Course Operations
    
    func createCourseWithMeetings(_ course: Course, meetings: [CourseMeeting]) async throws {
        print("🔄 Creating course '\(course.name)' with \(meetings.count) meetings")
        
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Create Course",
                description: "create your course"
            ) { [weak self] in
                Task { try await self?.createCourseWithMeetings(course, meetings: meetings) }
            }
            throw CourseError.notAuthenticated
        }
        
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw CourseError.noUserId
        }
        
        do {
            // 1. Create the course first
            let createdCourse = try await courseRepository.create(course, userId: userId)
            print("✅ Created course: \(createdCourse.name)")
            
            // 2. Create meetings for the course
            var savedMeetings: [CourseMeeting] = []
            for var meeting in meetings {
                meeting.userId = UUID(uuidString: userId)
                meeting.courseId = createdCourse.id
                meeting.scheduleId = meeting.scheduleId ?? createdCourse.scheduleId
                
                let savedMeeting = try await courseMeetingRepository.create(meeting, userId: userId)
                savedMeetings.append(savedMeeting)
                print("✅ Created meeting: \(savedMeeting.displayName) for course \(createdCourse.name)")
            }
            
            // 3. Update local course with meetings
            var courseWithMeetings = createdCourse
            courseWithMeetings.meetings = savedMeetings
            courseWithMeetings.refreshObservationsAndSignalChange()
            
            // 4. Add to local collection
            courses.append(courseWithMeetings)
            
            print("✅ Successfully created course '\(createdCourse.name)' with \(savedMeetings.count) meetings")
            
        } catch {
            print("❌ Failed to create course with meetings: \(error)")
            throw error
        }
    }
    
    func updateCourse(_ course: Course) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw CourseError.noUserId
        }
        
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else {
            throw CourseError.courseNotFound
        }
        
        do {
            // Update course metadata
            let updatedCourse = try await courseRepository.update(course, userId: userId)
            
            // Preserve meetings and assignments
            var courseWithData = updatedCourse
            courseWithData.meetings = course.meetings
            courseWithData.assignments = course.assignments
            courseWithData.refreshObservationsAndSignalChange()
            
            courses[index] = courseWithData
            
            print("✅ Updated course: \(updatedCourse.name)")
            
        } catch {
            print("❌ Failed to update course: \(error)")
            throw error
        }
    }
    
    func deleteCourse(_ courseId: UUID) async throws {
        guard let course = courses.first(where: { $0.id == courseId }) else {
            throw CourseError.courseNotFound
        }
        
        do {
            // Delete all meetings first
            for meeting in course.meetings {
                try await courseMeetingRepository.delete(id: meeting.id.uuidString)
            }
            
            // Delete all assignments
            for assignment in course.assignments {
                try await assignmentRepository.delete(id: assignment.id.uuidString)
            }
            
            // Delete the course
            try await courseRepository.delete(id: courseId.uuidString)
            
            // Remove from local collection
            courses.removeAll { $0.id == courseId }
            
            print("✅ Deleted course and all related data: \(course.name)")
            
        } catch {
            print("❌ Failed to delete course: \(error)")
            throw error
        }
    }
    
    // MARK: - Meeting Operations
    
    func addMeeting(_ meeting: CourseMeeting, to courseId: UUID) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw CourseError.noUserId
        }
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
            throw CourseError.courseNotFound
        }
        
        do {
            var meetingToCreate = meeting
            meetingToCreate.userId = UUID(uuidString: userId)
            meetingToCreate.courseId = courseId
            
            let savedMeeting = try await courseMeetingRepository.create(meetingToCreate, userId: userId)
            
            // Add to course
            courses[courseIndex].meetings.append(savedMeeting)
            
            print("✅ Added meeting '\(savedMeeting.displayName)' to course '\(courses[courseIndex].name)'")
            
        } catch {
            print("❌ Failed to add meeting: \(error)")
            throw error
        }
    }
    
    func updateMeeting(_ meeting: CourseMeeting) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw CourseError.noUserId
        }
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == meeting.courseId }),
              let meetingIndex = courses[courseIndex].meetings.firstIndex(where: { $0.id == meeting.id }) else {
            throw CourseError.meetingNotFound
        }
        
        do {
            let updatedMeeting = try await courseMeetingRepository.update(meeting, userId: userId)
            
            courses[courseIndex].meetings[meetingIndex] = updatedMeeting
            
            print("✅ Updated meeting '\(updatedMeeting.displayName)'")
            
        } catch {
            print("❌ Failed to update meeting: \(error)")
            throw error
        }
    }
    
    func deleteMeeting(_ meetingId: UUID, from courseId: UUID) async throws {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
            throw CourseError.courseNotFound
        }
        
        guard let meetingIndex = courses[courseIndex].meetings.firstIndex(where: { $0.id == meetingId }) else {
            throw CourseError.meetingNotFound
        }
        
        do {
            try await courseMeetingRepository.delete(id: meetingId.uuidString)
            
            let removedMeeting = courses[courseIndex].meetings.remove(at: meetingIndex)
            
            print("✅ Deleted meeting '\(removedMeeting.displayName)' from course '\(courses[courseIndex].name)'")
            
        } catch {
            print("❌ Failed to delete meeting: \(error)")
            throw error
        }
    }
    
    // MARK: - Assignment Operations
    
    func addAssignment(_ assignment: Assignment, to courseId: UUID) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw CourseError.noUserId
        }
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
            throw CourseError.courseNotFound
        }
        
        do {
            var assignmentToCreate = assignment
            assignmentToCreate.courseId = courseId
            
            let savedAssignment = try await assignmentRepository.create(assignmentToCreate, userId: userId)
            
            courses[courseIndex].addAssignment(savedAssignment)
            
            print("✅ Added assignment '\(savedAssignment.name)' to course '\(courses[courseIndex].name)'")
            
        } catch {
            print("❌ Failed to add assignment: \(error)")
            throw error
        }
    }
    
    func updateAssignment(_ assignment: Assignment) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw CourseError.noUserId
        }
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == assignment.courseId }),
              let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == assignment.id }) else {
            throw CourseError.assignmentNotFound
        }
        
        do {
            let updatedAssignment = try await assignmentRepository.update(assignment, userId: userId)
            
            courses[courseIndex].assignments[assignmentIndex] = updatedAssignment
            
            print("✅ Updated assignment '\(updatedAssignment.name)'")
            
        } catch {
            print("❌ Failed to update assignment: \(error)")
            throw error
        }
    }
    
    func deleteAssignment(_ assignmentId: UUID, from courseId: UUID) async throws {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
            throw CourseError.courseNotFound
        }
        
        do {
            try await assignmentRepository.delete(id: assignmentId.uuidString)
            
            courses[courseIndex].removeAssignment(withId: assignmentId)
            
            print("✅ Deleted assignment from course '\(courses[courseIndex].name)'")
            
        } catch {
            print("❌ Failed to delete assignment: \(error)")
            throw error
        }
    }
    
    // MARK: - Query Operations
    
    func getCourse(by id: UUID) -> Course? {
        return courses.first { $0.id == id }
    }
    
    func getCourses(for scheduleId: UUID) -> [Course] {
        return courses.filter { $0.scheduleId == scheduleId }
    }
    
    func getMeetings(for courseId: UUID) -> [CourseMeeting] {
        return getCourse(by: courseId)?.meetings ?? []
    }
    
    func getMeetingsForSchedule(_ scheduleId: UUID) -> [CourseMeeting] {
        let scheduleCourses = getCourses(for: scheduleId)
        return scheduleCourses.flatMap { $0.meetings }
    }
    
    func getScheduleItems(for date: Date, scheduleId: UUID, calendar: AcademicCalendar?) -> [ScheduleItem] {
        let scheduleCourses = getCourses(for: scheduleId)
        var items: [ScheduleItem] = []
        
        // Create a minimal schedule collection for the meeting checks
        let scheduleCollection = ScheduleCollection(name: "", semester: "")
        var tempSchedule = scheduleCollection
        tempSchedule.id = scheduleId
        
        for course in scheduleCourses {
            for meeting in course.meetings {
                if meeting.shouldAppear(on: date, in: tempSchedule, calendar: calendar) {
                    let item = meeting.toScheduleItem(using: course)
                    items.append(item)
                }
            }
        }
        
        return items.sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - Analytics
    
    func calculateOverallGPA() -> Double? {
        let coursesWithGrades = courses.filter { course in
            course.assignments.contains { !$0.grade.isEmpty }
        }
        
        guard !coursesWithGrades.isEmpty else { return nil }
        
        var totalPoints = 0.0
        var totalHours = 0.0
        
        for course in coursesWithGrades {
            if let gpaPoints = course.gpaPoints {
                totalPoints += gpaPoints * course.creditHours
                totalHours += course.creditHours
            }
        }
        
        guard totalHours > 0 else { return nil }
        return totalPoints / totalHours
    }
    
    func getTotalWeeklyHours() -> Double {
        return courses.reduce(0) { total, course in
            total + course.meetings.totalWeeklyHours
        }
    }
    
    func getMeetingTypeSummary() -> [MeetingType: Int] {
        var summary: [MeetingType: Int] = [:]
        
        for course in courses {
            for meeting in course.meetings {
                summary[meeting.meetingType, default: 0] += 1
            }
        }
        
        return summary
    }
    
    // MARK: - Data Refresh
    
    func refreshData() async {
        isLoading = true
        
        do {
            await loadCoursesWithMeetings()
            lastSyncTime = Date()
        } catch {
            print("❌ Failed to refresh data: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        courses.isEmpty
    }
    
    var courseCount: Int {
        courses.count
    }
    
    var totalMeetings: Int {
        courses.reduce(0) { $0 + $1.meetings.count }
    }
    
    var totalAssignments: Int {
        courses.reduce(0) { $0 + $1.assignments.count }
    }
}

// MARK: - RealtimeSyncDelegate Implementation
extension CourseWithMeetingsManager: RealtimeSyncDelegate {
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        Task { @MainActor in
            switch (table, action) {
            case ("courses", "INSERT"), ("courses", "UPDATE"):
                await handleCourseUpdate(data)
            case ("courses", "DELETE"):
                await handleCourseDelete(data)
            case ("course_meetings", "INSERT"), ("course_meetings", "UPDATE"):
                await handleMeetingUpdate(data)
            case ("course_meetings", "DELETE"):
                await handleMeetingDelete(data)
            case ("assignments", "INSERT"), ("assignments", "UPDATE"):
                await handleAssignmentUpdate(data)
            case ("assignments", "DELETE"):
                await handleAssignmentDelete(data)
            default:
                break
            }
            
            lastSyncTime = Date()
        }
    }
    
    private func handleCourseUpdate(_ data: [String: Any]) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let dbCourse = try JSONDecoder().decode(DatabaseCourse.self, from: jsonData)
            let course = dbCourse.toLocal()
            
            if let existingIndex = courses.firstIndex(where: { $0.id == course.id }) {
                // Preserve meetings and assignments
                var updatedCourse = course
                updatedCourse.meetings = courses[existingIndex].meetings
                updatedCourse.assignments = courses[existingIndex].assignments
                updatedCourse.refreshObservationsAndSignalChange()
                courses[existingIndex] = updatedCourse
            } else {
                // Load meetings for new course
                if let userId = supabaseService.currentUser?.id.uuidString {
                    do {
                        let meetings = try await courseMeetingRepository.findByCourse(course.id.uuidString, userId: userId)
                        var newCourse = course
                        newCourse.meetings = meetings
                        newCourse.refreshObservationsAndSignalChange()
                        courses.append(newCourse)
                    } catch {
                        courses.append(course)
                    }
                } else {
                    courses.append(course)
                }
            }
        } catch {
            print("❌ Failed to handle course update: \(error)")
        }
    }
    
    private func handleCourseDelete(_ data: [String: Any]) async {
        guard let idString = data["id"] as? String,
              let courseId = UUID(uuidString: idString) else { return }
        
        courses.removeAll { $0.id == courseId }
    }
    
    private func handleMeetingUpdate(_ data: [String: Any]) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let dbMeeting = try JSONDecoder().decode(DatabaseCourseMeeting.self, from: jsonData)
            let meeting = dbMeeting.toLocal()
            
            guard let courseIndex = courses.firstIndex(where: { $0.id == meeting.courseId }) else { return }
            
            if let existingMeetingIndex = courses[courseIndex].meetings.firstIndex(where: { $0.id == meeting.id }) {
                courses[courseIndex].meetings[existingMeetingIndex] = meeting
            } else {
                courses[courseIndex].meetings.append(meeting)
            }
        } catch {
            print("❌ Failed to handle meeting update: \(error)")
        }
    }
    
    private func handleMeetingDelete(_ data: [String: Any]) async {
        guard let idString = data["id"] as? String,
              let meetingId = UUID(uuidString: idString) else { return }
        
        for courseIndex in courses.indices {
            courses[courseIndex].meetings.removeAll { $0.id == meetingId }
        }
    }
    
    private func handleAssignmentUpdate(_ data: [String: Any]) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let dbAssignment = try JSONDecoder().decode(DatabaseAssignment.self, from: jsonData)
            let assignment = dbAssignment.toLocal()
            
            guard let courseIndex = courses.firstIndex(where: { $0.id == assignment.courseId }) else { return }
            
            if let existingAssignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == assignment.id }) {
                courses[courseIndex].assignments[existingAssignmentIndex] = assignment
            } else {
                courses[courseIndex].addAssignment(assignment)
            }
        } catch {
            print("❌ Failed to handle assignment update: \(error)")
        }
    }
    
    private func handleAssignmentDelete(_ data: [String: Any]) async {
        guard let idString = data["id"] as? String,
              let assignmentId = UUID(uuidString: idString) else { return }
        
        for courseIndex in courses.indices {
            courses[courseIndex].removeAssignment(withId: assignmentId)
        }
    }
}

// MARK: - Error Types
enum CourseError: LocalizedError {
    case notAuthenticated
    case noUserId
    case courseNotFound
    case meetingNotFound
    case assignmentNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .noUserId:
            return "No user ID available"
        case .courseNotFound:
            return "Course not found"
        case .meetingNotFound:
            return "Meeting not found"
        case .assignmentNotFound:
            return "Assignment not found"
        case .invalidData:
            return "Invalid data provided"
        }
    }
}