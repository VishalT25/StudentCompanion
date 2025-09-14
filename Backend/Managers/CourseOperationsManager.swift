import Foundation
import SwiftUI
import Combine

// MARK: - Course Operations Manager
@MainActor
class CourseOperationsManager: ObservableObject, RealtimeSyncDelegate {
    
    // MARK: - Published Properties
    @Published private(set) var courses: [Course] = []
    @Published private(set) var assignments: [Assignment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var operationStatistics = CourseStatistics()
    
    // MARK: - Dependencies
    private let courseRepository: CachedRepository<DatabaseCourse, Course>
    private let assignmentRepository: CachedRepository<DatabaseAssignment, Assignment>
    private let supabaseService = SupabaseService.shared
    private let realtimeSyncManager = RealtimeSyncManager.shared
    private let dataValidator = DataConsistencyValidator()
    private let authPromptHandler = AuthenticationPromptHandler.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let operationsQueue = DispatchQueue(label: "course.operations", qos: .userInitiated)
    
    init() {
        // Initialize repositories with caching
        let baseCourseRepo = BaseRepository<DatabaseCourse, Course>(tableName: "courses")
        let baseAssignmentRepo = BaseRepository<DatabaseAssignment, Assignment>(tableName: "assignments")
        
        courseRepository = CachedRepository(
            repository: baseCourseRepo,
            cache: CacheSystem.shared.courseCache,
            supabaseService: supabaseService
        )
        
        assignmentRepository = CachedRepository(
            repository: baseAssignmentRepo,
            cache: CacheSystem.shared.assignmentCache,
            supabaseService: supabaseService
        )
        
        setupRealtimeSync()
        setupAuthenticationObserver()
        
        Task {
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        guard supabaseService.isAuthenticated else { return }
        
        isLoading = true
        
        do {
            await loadCourses()
            await loadAssignments()
            lastSyncTime = Date()
        } catch {
        }
        
        isLoading = false
    }
    
    private func setupRealtimeSync() {
        realtimeSyncManager.courseDelegate = self
        realtimeSyncManager.assignmentDelegate = self
    }
    
    private func setupAuthenticationObserver() {
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task { 
                        // Add delay to ensure authentication is fully complete
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        await self?.initialize() 
                    }
                } else {
                    self?.clearData()
                }
            }
            .store(in: &cancellables)
        
        // Listen for post sign-in data refresh notification
        NotificationCenter.default.addObserver(
            forName: .init("UserSignedInDataRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshData() }
        }
        
        // Listen for data sync completed notification
        NotificationCenter.default.addObserver(
            forName: .init("DataSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.reloadFromCache() }
        }
    }
    
    // MARK: - Cache Reload
    
    private func reloadFromCache() async {
        
        // Load courses from cache
        let cachedCourses = await CacheSystem.shared.courseCache.retrieve()
        courses = cachedCourses
        
        // Load assignments from cache
        let cachedAssignments = await CacheSystem.shared.assignmentCache.retrieve()
        assignments = cachedAssignments
        
        // Update course assignments
        updateCourseAssignments()
        
        operationStatistics.updateCoursesLoaded(courses.count)
        operationStatistics.updateAssignmentsLoaded(assignments.count)
        lastSyncTime = Date()
        
    }
    
    // MARK: - Data Loading
    
    func loadCourses() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        do {
            let loadedCourses = try await courseRepository.readAll(userId: userId)
            courses = loadedCourses
            
            // Load assignments for each course
            for course in courses {
                course.assignments = assignments.filter { $0.courseId == course.id }
                course.refreshObservationsAndSignalChange()
            }
            
            operationStatistics.updateCoursesLoaded(loadedCourses.count)
        } catch {
        }
    }
    
    func loadAssignments() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        do {
            let loadedAssignments = try await assignmentRepository.readAll(userId: userId)
            assignments = loadedAssignments
            
            // Update course assignments
            updateCourseAssignments()
            
            operationStatistics.updateAssignmentsLoaded(loadedAssignments.count)
        } catch {
        }
    }
    
    private func updateCourseAssignments() {
        for course in courses {
            let courseAssignments = assignments.filter { $0.courseId == course.id }
            course.assignments = courseAssignments
            course.refreshObservationsAndSignalChange()
        }
    }
    
    // MARK: - Course Operations
    
    func addCourse(_ course: Course) {
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Add Course",
                description: "add your course"
            ) { [weak self] in
                self?.addCourse(course)
            }
            return
        }
        
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        // Validate course
        let validationResult = dataValidator.validateCourse(course)
        guard validationResult.isValid else {
            return
        }
        
        // Add locally for immediate UI update
        courses.append(course)
        operationStatistics.incrementCoursesCreated()
        
        // Sync to backend
        Task {
            do {
                let savedCourse = try await courseRepository.create(course, userId: userId)
                
                // Update local copy with server data
                if let index = courses.firstIndex(where: { $0.id == course.id }) {
                    courses[index] = savedCourse
                }
                
            } catch {
                // Remove from local array if sync failed
                courses.removeAll { $0.id == course.id }
                operationStatistics.incrementErrors()
            }
        }
    }
    
    func updateCourse(_ course: Course) {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else { return }
        
        // Validate course
        let validationResult = dataValidator.validateCourse(course)
        guard validationResult.isValid else {
            return
        }
        
        // Update locally for immediate UI update
        courses[index] = course
        operationStatistics.incrementCoursesUpdated()
        
        // Sync to backend
        Task {
            do {
                let updatedCourse = try await courseRepository.update(course, userId: userId)
                
                // Update local copy with server data
                if let currentIndex = courses.firstIndex(where: { $0.id == course.id }) {
                    courses[currentIndex] = updatedCourse
                }
                
            } catch {
                // Revert local changes if sync failed
                await loadCourses()
                operationStatistics.incrementErrors()
            }
        }
    }
    
    func deleteCourse(_ course: Course) {
        // Remove locally for immediate UI update
        courses.removeAll { $0.id == course.id }
        
        // Also remove associated assignments
        let courseAssignments = assignments.filter { $0.courseId == course.id }
        assignments.removeAll { $0.courseId == course.id }
        
        operationStatistics.incrementCoursesDeleted()
        
        // Sync to backend
        Task {
            do {
                // Delete assignments first
                for assignment in courseAssignments {
                    try await assignmentRepository.delete(id: assignment.id.uuidString)
                }
                
                // Then delete course
                try await courseRepository.delete(id: course.id.uuidString)
                
            } catch {
                // Restore data if sync failed
                courses.append(course)
                assignments.append(contentsOf: courseAssignments)
                updateCourseAssignments()
                operationStatistics.incrementErrors()
            }
        }
    }
    
    // MARK: - Assignment Operations
    
    func addAssignment(_ assignment: Assignment, to course: Course) {
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Add Assignment",
                description: "add your assignment"
            ) { [weak self] in
                self?.addAssignment(assignment, to: course)
            }
            return
        }
        
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        let validationResult = dataValidator.validateAssignment(assignment)
        guard validationResult.isValid else {
            return
        }
        
        assignments.append(assignment)
        course.addAssignment(assignment)
        operationStatistics.incrementAssignmentsCreated()
        
        Task {
            let courseId = course.id
            let exists = await verifyRemoteCourseExists(courseId: courseId, userId: userId)
            if !exists {
            }
            
            do {
                let savedAssignment = try await assignmentRepository.create(assignment, userId: userId)
                
                if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
                    assignments[index] = savedAssignment
                }
                
                updateCourseAssignments()
                
            } catch {
                
                do {
                    try await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                    let savedAssignment = try await assignmentRepository.create(assignment, userId: userId)
                    if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
                        assignments[index] = savedAssignment
                    }
                    updateCourseAssignments()
                } catch {
                    // Remove from local arrays if sync failed
                    assignments.removeAll { $0.id == assignment.id }
                    course.assignments.removeAll { $0.id == assignment.id }
                    operationStatistics.incrementErrors()
                }
            }
        }
    }
    
    func updateAssignment(_ assignment: Assignment) {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        guard let index = assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        
        let validationResult = dataValidator.validateAssignment(assignment)
        guard validationResult.isValid else {
            return
        }
        
        assignments[index] = assignment
        updateCourseAssignments()
        operationStatistics.incrementAssignmentsUpdated()
        
        Task {
            let exists = await verifyRemoteCourseExists(courseId: assignment.courseId, userId: userId)
            if !exists {
            }
            
            do {
                let updatedAssignment = try await assignmentRepository.update(assignment, userId: userId)
                
                if let currentIndex = assignments.firstIndex(where: { $0.id == assignment.id }) {
                    assignments[currentIndex] = updatedAssignment
                }
                
                updateCourseAssignments()
                
            } catch {
                await loadAssignments()
                operationStatistics.incrementErrors()
            }
        }
    }
    
    func deleteAssignment(_ assignment: Assignment) {
        // Remove locally for immediate UI update
        assignments.removeAll { $0.id == assignment.id }
        
        // Remove from course
        if let course = courses.first(where: { $0.id == assignment.courseId }) {
            course.assignments.removeAll { $0.id == assignment.id }
        }
        
        operationStatistics.incrementAssignmentsDeleted()
        
        // Sync to backend
        Task {
            do {
                try await assignmentRepository.delete(id: assignment.id.uuidString)
                
            } catch {
                // Restore data if sync failed
                assignments.append(assignment)
                updateCourseAssignments()
                operationStatistics.incrementErrors()
            }
        }
    }
    
    // MARK: - Bulk Operations
    
    func importCourses(_ coursesToImport: [Course]) async {
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Import Courses",
                description: "import your courses"
            ) { [weak self] in
                Task { await self?.importCourses(coursesToImport) }
            }
            return
        }
        
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        isLoading = true
        var successCount = 0
        
        for course in coursesToImport {
            do {
                let savedCourse = try await courseRepository.create(course, userId: userId)
                courses.append(savedCourse)
                successCount += 1
                operationStatistics.incrementCoursesCreated()
            } catch {
                operationStatistics.incrementErrors()
            }
        }
        
        isLoading = false
        
    }
    
    func exportCourses() -> [Course] {
        return courses
    }
    
    // MARK: - Query Operations
    
    func getCourse(by id: UUID) -> Course? {
        return courses.first { $0.id == id }
    }
    
    func getCourses(for scheduleId: UUID) -> [Course] {
        return courses.filter { $0.scheduleId == scheduleId }
    }
    
    func getCoursesWithGrades() -> [Course] {
        return courses.filter { course in
            course.assignments.contains { !$0.grade.isEmpty }
        }
    }
    
    func getAssignments(for courseId: UUID) -> [Assignment] {
        return assignments.filter { $0.courseId == courseId }
    }
    
    func getIncompleteAssignments() -> [Assignment] {
        return assignments.filter { assignment in
            assignment.grade.isEmpty || assignment.grade == "0"
        }
    }
    
    // MARK: - Analytics
    
    func calculateOverallGPA() -> Double? {
        let coursesWithGrades = getCoursesWithGrades()
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
    
    func getCourseGradeSummary() -> CourseGradeSummary {
        let coursesWithGrades = getCoursesWithGrades()
        let totalCourses = courses.count
        
        var gradeDistribution: [String: Int] = [:]
        
        for course in coursesWithGrades {
            let letterGrade = course.letterGrade
            gradeDistribution[letterGrade, default: 0] += 1
        }
        
        return CourseGradeSummary(
            totalCourses: totalCourses,
            coursesWithGrades: coursesWithGrades.count,
            overallGPA: calculateOverallGPA(),
            gradeDistribution: gradeDistribution,
            totalCreditHours: courses.reduce(0) { $0 + $1.creditHours }
        )
    }
    
    // MARK: - RealtimeSyncDelegate
    
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        Task { @MainActor in
            switch (table, action) {
            case ("courses", "INSERT"), ("courses", "UPDATE"):
                await handleCourseUpdate(data)
            case ("courses", "DELETE"):
                await handleCourseDelete(data)
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
                // Update existing course
                courses[existingIndex] = course
                courses[existingIndex].assignments = assignments.filter { $0.courseId == course.id }
            } else {
                // Add new course
                courses.append(course)
                course.assignments = assignments.filter { $0.courseId == course.id }
            }
            
        } catch {
        }
    }
    
    private func handleCourseDelete(_ data: [String: Any]) async {
        guard let idString = data["id"] as? String,
              let courseId = UUID(uuidString: idString) else { return }
        
        courses.removeAll { $0.id == courseId }
        assignments.removeAll { $0.courseId == courseId }
        
    }
    
    private func handleAssignmentUpdate(_ data: [String: Any]) async {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let dbAssignment = try JSONDecoder().decode(DatabaseAssignment.self, from: jsonData)
            let assignment = dbAssignment.toLocal()
            
            if let existingIndex = assignments.firstIndex(where: { $0.id == assignment.id }) {
                // Update existing assignment
                assignments[existingIndex] = assignment
            } else {
                // Add new assignment
                assignments.append(assignment)
            }
            
            // Update course assignments
            updateCourseAssignments()
            
        } catch {
        }
    }
    
    private func handleAssignmentDelete(_ data: [String: Any]) async {
        guard let idString = data["id"] as? String,
              let assignmentId = UUID(uuidString: idString) else { return }
        
        assignments.removeAll { $0.id == assignmentId }
        updateCourseAssignments()
        
    }
    
    // MARK: - Cleanup
    
    private func clearData() {
        courses.removeAll()
        assignments.removeAll()
        operationStatistics.reset()
        lastSyncTime = nil
    }
    
    func refreshData() async {
        await initialize()
    }
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        courses.isEmpty
    }
    
    var courseCount: Int {
        courses.count
    }
    
    var assignmentCount: Int {
        assignments.count
    }

    private func verifyRemoteCourseExists(courseId: UUID, userId: String) async -> Bool {
        do {
            let response = try await supabaseService.client
                .from("courses")
                .select("id,user_id")
                .eq("id", value: courseId.uuidString)
                .eq("user_id", value: userId)
                .single()
                .execute()
            if let json = String(data: response.data, encoding: .utf8) {
            }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Supporting Types

struct CourseGradeSummary {
    let totalCourses: Int
    let coursesWithGrades: Int
    let overallGPA: Double?
    let gradeDistribution: [String: Int]
    let totalCreditHours: Double
    
    var completionRate: Double {
        guard totalCourses > 0 else { return 0 }
        return Double(coursesWithGrades) / Double(totalCourses)
    }
    
    var formattedGPA: String {
        guard let gpa = overallGPA else { return "N/A" }
        return String(format: "%.2f", gpa)
    }
}

class CourseStatistics: ObservableObject {
    @Published private(set) var coursesLoaded = 0
    @Published private(set) var assignmentsLoaded = 0
    @Published private(set) var coursesCreated = 0
    @Published private(set) var coursesUpdated = 0
    @Published private(set) var coursesDeleted = 0
    @Published private(set) var assignmentsCreated = 0
    @Published private(set) var assignmentsUpdated = 0
    @Published private(set) var assignmentsDeleted = 0
    @Published private(set) var errors = 0
    @Published private(set) var lastReset = Date()
    
    func updateCoursesLoaded(_ count: Int) {
        coursesLoaded = count
    }
    
    func updateAssignmentsLoaded(_ count: Int) {
        assignmentsLoaded = count
    }
    
    func incrementCoursesCreated() {
        coursesCreated += 1
    }
    
    func incrementCoursesUpdated() {
        coursesUpdated += 1
    }
    
    func incrementCoursesDeleted() {
        coursesDeleted += 1
    }
    
    func incrementAssignmentsCreated() {
        assignmentsCreated += 1
    }
    
    func incrementAssignmentsUpdated() {
        assignmentsUpdated += 1
    }
    
    func incrementAssignmentsDeleted() {
        assignmentsDeleted += 1
    }
    
    func incrementErrors() {
        errors += 1
    }
    
    func reset() {
        coursesLoaded = 0
        assignmentsLoaded = 0
        coursesCreated = 0
        coursesUpdated = 0
        coursesDeleted = 0
        assignmentsCreated = 0
        assignmentsUpdated = 0
        assignmentsDeleted = 0
        errors = 0
        lastReset = Date()
    }
    
    var totalOperations: Int {
        coursesCreated + coursesUpdated + coursesDeleted + 
        assignmentsCreated + assignmentsUpdated + assignmentsDeleted
    }
    
    var successRate: Double {
        let total = totalOperations + errors
        guard total > 0 else { return 1.0 }
        return Double(totalOperations) / Double(total)
    }
}
