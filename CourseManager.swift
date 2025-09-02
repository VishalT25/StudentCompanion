import SwiftUI
import Combine

// MARK: - Bulk Course Selection Manager
class BulkCourseSelectionManager: ObservableObject {
    @Published var isSelecting = false
    @Published var selectionContext: CourseSelectionContext = .none
    @Published var selectedCourseIDs: Set<UUID> = []
    @Published var selectedAssignmentIDs: Set<UUID> = []
    
    enum CourseSelectionContext: Equatable {
        case none
        case courses
        case assignments(courseID: UUID)
    }
    
    func startSelection(_ context: CourseSelectionContext, initialID: UUID? = nil) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectionContext = context
            isSelecting = true
            
            clearAllSelections()
            
            if let id = initialID {
                switch context {
                case .courses:
                    selectedCourseIDs.insert(id)
                case .assignments:
                    selectedAssignmentIDs.insert(id)
                case .none:
                    break
                }
            }
        }
    }
    
    func endSelection() {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectionContext = .none
            isSelecting = false
            clearAllSelections()
        }
    }
    
    func toggleSelection(_ id: UUID) {
        switch selectionContext {
        case .courses:
            if selectedCourseIDs.contains(id) {
                selectedCourseIDs.remove(id)
            } else {
                selectedCourseIDs.insert(id)
            }
        case .assignments:
            if selectedAssignmentIDs.contains(id) {
                selectedAssignmentIDs.remove(id)
            } else {
                selectedAssignmentIDs.insert(id)
            }
        case .none:
            break
        }
    }
    
    func selectAll<T: Identifiable>(items: [T]) where T.ID == UUID {
        let allIDs = Set(items.map { $0.id })
        switch selectionContext {
        case .courses:
            selectedCourseIDs = allIDs
        case .assignments:
            selectedAssignmentIDs = allIDs
        case .none:
            break
        }
    }
    
    func deselectAll() {
        switch selectionContext {
        case .courses:
            selectedCourseIDs.removeAll()
        case .assignments:
            selectedAssignmentIDs.removeAll()
        case .none:
            break
        }
    }
    
    private func clearAllSelections() {
        selectedCourseIDs.removeAll()
        selectedAssignmentIDs.removeAll()
    }
    
    func selectedCount() -> Int {
        switch selectionContext {
        case .courses:
            return selectedCourseIDs.count
        case .assignments:
            return selectedAssignmentIDs.count
        case .none:
            return 0
        }
    }
    
    func isSelected(_ id: UUID) -> Bool {
        switch selectionContext {
        case .courses:
            return selectedCourseIDs.contains(id)
        case .assignments:
            return selectedAssignmentIDs.contains(id)
        case .none:
            return false
        }
    }
}

// MARK: - Enhanced Course Operations Manager with Real-time Sync
@MainActor
class CourseOperationsManager: ObservableObject, RealtimeSyncDelegate {
    @Published var courses: [Course] = []
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = "Ready"
    @Published var lastSyncTime: Date?
    
    private let realtimeSyncManager = RealtimeSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true
    
    init() {
        // Set up real-time sync delegate
        realtimeSyncManager.coursesDelegate = self
        
        // Load local data first for offline support
        loadCourses()
        
        // Setup sync status observation
        setupSyncStatusObservation()
    }
    
    // MARK: - RealtimeSyncDelegate
    
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        print("🔄 CourseOperationsManager: Received real-time update for table: \(table), action: \(action)")
        
        switch (table, action) {
        case ("courses", "SYNC"):
            if let coursesData = data["courses"] as? [DatabaseCourse] {
                syncCoursesFromDatabase(coursesData)
            }
        case ("courses", "INSERT"):
            if let courseData = try? JSONSerialization.data(withJSONObject: data),
               let dbCourse = try? JSONDecoder().decode(DatabaseCourse.self, from: courseData) {
                handleCourseInsert(dbCourse)
            }
        case ("courses", "UPDATE"):
            if let courseData = try? JSONSerialization.data(withJSONObject: data),
               let dbCourse = try? JSONDecoder().decode(DatabaseCourse.self, from: courseData) {
                handleCourseUpdate(dbCourse)
            }
        case ("courses", "DELETE"):
            if let courseId = data["id"] as? String {
                handleCourseDelete(courseId)
            }
            
        case ("assignments", "SYNC"):
            if let assignmentsData = data["assignments"] as? [DatabaseAssignment] {
                syncAssignmentsFromDatabase(assignmentsData)
            }
        case ("assignments", "INSERT"):
            if let assignmentData = try? JSONSerialization.data(withJSONObject: data),
               let dbAssignment = try? JSONDecoder().decode(DatabaseAssignment.self, from: assignmentData) {
                handleAssignmentInsert(dbAssignment)
            }
        case ("assignments", "UPDATE"):
            if let assignmentData = try? JSONSerialization.data(withJSONObject: data),
               let dbAssignment = try? JSONDecoder().decode(DatabaseAssignment.self, from: assignmentData) {
                handleAssignmentUpdate(dbAssignment)
            }
        case ("assignments", "DELETE"):
            if let assignmentId = data["id"] as? String {
                handleAssignmentDelete(assignmentId)
            }
            
        default:
            print("🔄 CourseOperationsManager: Unhandled real-time update: \(table) - \(action)")
        }
    }
    
    // MARK: - Real-time Course Handlers
    
    private func syncCoursesFromDatabase(_ courses: [DatabaseCourse]) {
        print("🔄 CourseOperationsManager: Syncing \(courses.count) courses from database")
        let localCourses = courses.map { $0.toLocal() }
        
        // Preserve existing assignments for courses that already exist
        for (index, localCourse) in localCourses.enumerated() {
            if let existingCourseIndex = self.courses.firstIndex(where: { $0.id == localCourse.id }) {
                // Preserve existing assignments
                var updatedCourse = localCourse
                updatedCourse.assignments = self.courses[existingCourseIndex].assignments
                self.courses[existingCourseIndex] = updatedCourse
            } else {
                // New course
                self.courses.append(localCourse)
            }
        }
        
        // Remove courses that no longer exist on server
        let serverCourseIds = Set(localCourses.map { $0.id })
        self.courses.removeAll { !serverCourseIds.contains($0.id) }
        
        if !isInitialLoad {
            saveCoursesLocally() // Cache for offline use
        }
        
        print("🔄 CourseOperationsManager: Courses sync complete - \(self.courses.count) total courses")
    }
    
    private func syncAssignmentsFromDatabase(_ assignments: [DatabaseAssignment]) {
        print("🔄 CourseOperationsManager: Syncing \(assignments.count) assignments from database")
        
        // Group assignments by course_id
        let groupedAssignments = Dictionary(grouping: assignments) { $0.course_id }
        
        for (courseIdString, dbAssignments) in groupedAssignments {
            guard let courseId = UUID(uuidString: courseIdString),
                  let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
                print("🔄 CourseOperationsManager: Course not found for assignments: \(courseIdString)")
                continue
            }
            
            let localAssignments = dbAssignments.map { $0.toLocal() }
            courses[courseIndex].assignments = localAssignments
        }
        
        if !isInitialLoad {
            saveCoursesLocally() // Cache for offline use
        }
        
        print("🔄 CourseOperationsManager: Assignments sync complete")
    }
    
    private func handleCourseInsert(_ dbCourse: DatabaseCourse) {
        let localCourse = dbCourse.toLocal()
        
        // Check if course already exists locally
        if !courses.contains(where: { $0.id == localCourse.id }) {
            courses.append(localCourse)
            saveCoursesLocally()
            print("🔄 CourseOperationsManager: Added new course from real-time: \(localCourse.name)")
        }
    }
    
    private func handleCourseUpdate(_ dbCourse: DatabaseCourse) {
        let localCourse = dbCourse.toLocal()
        
        if let index = courses.firstIndex(where: { $0.id == localCourse.id }) {
            // Preserve existing assignments
            var updatedCourse = localCourse
            updatedCourse.assignments = courses[index].assignments
            courses[index] = updatedCourse
            saveCoursesLocally()
            print("🔄 CourseOperationsManager: Updated course from real-time: \(localCourse.name)")
        }
    }
    
    private func handleCourseDelete(_ courseId: String) {
        if let uuid = UUID(uuidString: courseId),
           let index = courses.firstIndex(where: { $0.id == uuid }) {
            let removedCourse = courses.remove(at: index)
            saveCoursesLocally()
            print("🔄 CourseOperationsManager: Deleted course from real-time: \(removedCourse.name)")
        }
    }
    
    private func handleAssignmentInsert(_ dbAssignment: DatabaseAssignment) {
        let localAssignment = dbAssignment.toLocal()
        
        guard let courseId = UUID(uuidString: dbAssignment.course_id),
              let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
            print("🔄 CourseOperationsManager: Course not found for new assignment: \(dbAssignment.course_id)")
            return
        }
        
        // Check if assignment already exists locally
        if !courses[courseIndex].assignments.contains(where: { $0.id == localAssignment.id }) {
            courses[courseIndex].addAssignment(localAssignment)
            saveCoursesLocally()
            print("🔄 CourseOperationsManager: Added new assignment from real-time: \(localAssignment.name)")
        }
    }
    
    private func handleAssignmentUpdate(_ dbAssignment: DatabaseAssignment) {
        let localAssignment = dbAssignment.toLocal()
        
        guard let courseId = UUID(uuidString: dbAssignment.course_id),
              let courseIndex = courses.firstIndex(where: { $0.id == courseId }),
              let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == localAssignment.id }) else {
            print("🔄 CourseOperationsManager: Course or assignment not found for update: \(dbAssignment.id)")
            return
        }
        
        courses[courseIndex].assignments[assignmentIndex] = localAssignment
        saveCoursesLocally()
        print("🔄 CourseOperationsManager: Updated assignment from real-time: \(localAssignment.name)")
    }
    
    private func handleAssignmentDelete(_ assignmentId: String) {
        guard let uuid = UUID(uuidString: assignmentId) else { return }
        
        for courseIndex in courses.indices {
            if let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == uuid }) {
                let removedAssignment = courses[courseIndex].assignments.remove(at: assignmentIndex)
                saveCoursesLocally()
                print("🔄 CourseOperationsManager: Deleted assignment from real-time: \(removedAssignment.name)")
                break
            }
        }
    }
    
    // MARK: - Enhanced Course Operations with Sync
    
    func addCourse(_ course: Course) {
        // Add locally for immediate UI update
        courses.append(course)
        saveCoursesLocally()
        
        // Sync to database
        syncCourseToDatabase(course, action: .create)
        
        print("📚 CourseOperationsManager: Added course: \(course.name)")
    }
    
    func updateCourse(_ course: Course) {
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else { return }
        
        // Update locally for immediate UI update
        courses[index] = course
        saveCoursesLocally()
        
        // Sync to database
        syncCourseToDatabase(course, action: .update)
        
        print("📚 CourseOperationsManager: Updated course: \(course.name)")
    }
    
    func deleteCourse(_ courseID: UUID) {
        guard let course = courses.first(where: { $0.id == courseID }) else { return }
        
        // Remove locally for immediate UI update
        courses.removeAll { $0.id == courseID }
        saveCoursesLocally()
        
        // Sync to database
        syncCourseToDatabase(course, action: .delete)
        
        print("📚 CourseOperationsManager: Deleted course: \(course.name)")
    }
    
    func addAssignment(_ assignment: Assignment, to courseId: UUID) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else { return }
        
        // Add locally for immediate UI update
        courses[courseIndex].addAssignment(assignment)
        saveCoursesLocally()
        
        // Sync to database
        syncAssignmentToDatabase(assignment, courseId: courseId, action: .create)
        
        print("📚 CourseOperationsManager: Added assignment: \(assignment.name) to course: \(courseId)")
    }
    
    func updateAssignment(_ assignment: Assignment, in courseId: UUID) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }),
              let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        
        // Update locally for immediate UI update
        courses[courseIndex].assignments[assignmentIndex] = assignment
        saveCoursesLocally()
        
        // Sync to database
        syncAssignmentToDatabase(assignment, courseId: courseId, action: .update)
        
        print("📚 CourseOperationsManager: Updated assignment: \(assignment.name)")
    }
    
    func deleteAssignment(_ assignmentId: UUID, from courseId: UUID) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }),
              let assignment = courses[courseIndex].assignments.first(where: { $0.id == assignmentId }) else { return }
        
        // Remove locally for immediate UI update
        courses[courseIndex].assignments.removeAll { $0.id == assignmentId }
        saveCoursesLocally()
        
        // Sync to database
        syncAssignmentToDatabase(assignment, courseId: courseId, action: .delete)
        
        print("📚 CourseOperationsManager: Deleted assignment: \(assignment.name)")
    }
    
    // MARK: - Database Sync Operations
    
    private func syncCourseToDatabase(_ course: Course, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("🔄 CourseOperationsManager: Cannot sync - user not authenticated")
            return
        }
        
        let dbCourse = DatabaseCourse(from: course, userId: userId)
        
        do {
            let data = try JSONEncoder().encode(dbCourse)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            let operation = SyncOperation(
                type: .courses,
                action: action,
                data: dict
            )
            
            realtimeSyncManager.queueSyncOperation(operation)
        } catch {
            print("🔄 CourseOperationsManager: Failed to prepare course sync: \(error)")
        }
    }
    
    private func syncAssignmentToDatabase(_ assignment: Assignment, courseId: UUID, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("🔄 CourseOperationsManager: Cannot sync - user not authenticated")
            return
        }
        
        let dbAssignment = DatabaseAssignment(
            from: assignment, 
            userId: userId, 
            courseId: courseId.uuidString
        )
        
        do {
            let data = try JSONEncoder().encode(dbAssignment)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            let operation = SyncOperation(
                type: .assignments,
                action: action,
                data: dict
            )
            
            realtimeSyncManager.queueSyncOperation(operation)
        } catch {
            print("🔄 CourseOperationsManager: Failed to prepare assignment sync: \(error)")
        }
    }
    
    // MARK: - Enhanced Refresh with Sync
    
    func refreshCourseData() async {
        isSyncing = true
        
        // Refresh real-time sync data
        await realtimeSyncManager.refreshAllData()
        
        // Mark as no longer initial load after first refresh
        isInitialLoad = false
        
        lastSyncTime = Date()
        isSyncing = false
    }
    
    // MARK: - Sync Status Observation
    
    private func setupSyncStatusObservation() {
        realtimeSyncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status.displayName
                self?.isSyncing = status.isActive
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Save locally for offline support
    
    private func saveCoursesLocally() {
        CourseStorage.save(courses)
    }
    
    func loadCourses() {
        self.courses = CourseStorage.load()
    }
}