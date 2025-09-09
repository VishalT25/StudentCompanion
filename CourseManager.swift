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

// MARK: - Enhanced Course Operations Manager with Real-time Sync and Schedule Integration
@MainActor
class UnifiedCourseManager: ObservableObject, RealtimeSyncDelegate {
    @Published var courses: [Course] = []
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = "Ready"
    @Published var lastSyncTime: Date?
    
    // NEW: Schedule integration
    private var scheduleManager: ScheduleManager?
    
    private let realtimeSyncManager = RealtimeSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true
    
    init() {
        // Set up real-time sync delegate
        realtimeSyncManager.courseDelegate = self
        realtimeSyncManager.assignmentDelegate = self
        
        // Load local data first for offline support
        loadCourses()
        
        // Setup sync status observation
        setupSyncStatusObservation()
        
        // Setup authentication observer
        setupAuthenticationObserver()
        
        Task {
            await realtimeSyncManager.ensureStarted()
            await self.refreshCourseData()
        }
    }
    
    // MARK: - Authentication Observer
    
    private func setupAuthenticationObserver() {
        // Listen for post sign-in data refresh notification
        NotificationCenter.default.addObserver(
            forName: .init("UserSignedInDataRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 UnifiedCourseManager: Received post sign-in data refresh notification")
            Task { await self?.refreshCourseData() }
        }
        
        // Listen for data sync completed notification
        NotificationCenter.default.addObserver(
            forName: .init("DataSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 UnifiedCourseManager: Received data sync completed notification")
            Task { await self?.reloadFromCache() }
        }
    }
    
    // MARK: - Cache Reload
    
    private func reloadFromCache() async {
        print("🔄 UnifiedCourseManager: Reloading data from cache")
        
        // Load courses from cache
        let cachedCourses = await CacheSystem.shared.courseCache.retrieve()
        
        // Load assignments from cache
        let cachedAssignments = await CacheSystem.shared.assignmentCache.retrieve()
        
        // Update courses with their assignments in a single update to prevent UI conflicts
        var updatedCourses: [Course] = []
        for course in cachedCourses {
            var updatedCourse = course
            updatedCourse.assignments = cachedAssignments.filter { $0.courseId == course.id }
            updatedCourses.append(updatedCourse)
        }
        
        // Perform a single UI update to prevent layering issues
        await MainActor.run {
            self.courses = updatedCourses
        }
        
        // Save to local storage
        saveCoursesLocally()
        
        print("🔄 UnifiedCourseManager: Reloaded \(cachedCourses.count) courses with \(cachedAssignments.count) total assignments from cache")
    }
    
    // NEW: Set schedule manager for synchronization
    func setScheduleManager(_ scheduleManager: ScheduleManager) {
        self.scheduleManager = scheduleManager
    }
    
    // MARK: - RealtimeSyncDelegate
    
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
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
            break
        }
    }
    
    // MARK: - Real-time Course Handlers
    
    private func syncCoursesFromDatabase(_ dbCourses: [DatabaseCourse]) {
        let localCourses = dbCourses.map { $0.toLocal() }
        
        // Load existing courses from storage to preserve assignments
        let existingCourses = CourseStorage.load()
        var updatedCourses: [Course] = []
        
        // Preserve existing assignments for courses that already exist
        for localCourse in localCourses {
            if let existingCourse = existingCourses.first(where: { $0.id == localCourse.id }) {
                // Create updated course with preserved assignments
                var updatedCourse = localCourse
                updatedCourse.assignments = existingCourse.assignments
                updatedCourses.append(updatedCourse)
            } else {
                // New course with empty assignments (will be populated separately)
                updatedCourses.append(localCourse)
            }
        }
        
        // Update manager's courses array
        self.courses = updatedCourses
        
        saveCoursesLocally() // Always save after sync
        
        print("🔄 UnifiedCourseManager: Synced \(updatedCourses.count) courses from database")
    }
    
    private func syncAssignmentsFromDatabase(_ assignments: [DatabaseAssignment]) {
        print("🔄 UnifiedCourseManager: Syncing \(assignments.count) assignments from database")
        
        let localAssignments = assignments.map { $0.toLocal() }
        let groupedAssignments = Dictionary(grouping: localAssignments.filter { assignment in
            // Ensure we only include assignments with valid course IDs
            return self.courses.contains { $0.id == assignment.courseId }
        }, by: { $0.courseId })
        
        var coursesUpdated = false
        
        for (courseId, dbAssignments) in groupedAssignments {
            if let courseIndex = courses.firstIndex(where: { $0.id == courseId }) {
                // Replace assignments for this course
                courses[courseIndex].assignments = dbAssignments
                coursesUpdated = true
                print("🔄 UnifiedCourseManager: Updated \(dbAssignments.count) assignments for course: \(courses[courseIndex].name)")
            }
        }
        
        // Save to local storage after sync
        if coursesUpdated {
            saveCoursesLocally()
            print("🔄 UnifiedCourseManager: Saved courses with assignments to local storage")
        }
        
        print("🔄 UnifiedCourseManager: Assignment sync complete")
    }
    
    private func handleCourseInsert(_ dbCourse: DatabaseCourse) {
        let localCourse = dbCourse.toLocal()
        
        // Check if course already exists locally
        if !courses.contains(where: { $0.id == localCourse.id }) {
            courses.append(localCourse)
            saveCoursesLocally()
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
        }
    }
    
    private func handleCourseDelete(_ courseId: String) {
        if let uuid = UUID(uuidString: courseId),
           let index = courses.firstIndex(where: { $0.id == uuid }) {
            let removedCourse = courses.remove(at: index)
            saveCoursesLocally()
        }
    }
    
    private func handleAssignmentInsert(_ dbAssignment: DatabaseAssignment) {
        let localAssignment = dbAssignment.toLocal()
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == localAssignment.courseId }) else {
            print("🔄 UnifiedCourseManager: Course not found for assignment: \(localAssignment.name)")
            return
        }
        
        if !courses[courseIndex].assignments.contains(where: { $0.id == localAssignment.id }) {
            courses[courseIndex].addAssignment(localAssignment)
            saveCoursesLocally() // Save to UserDefaults for UI consistency
            print("🔄 UnifiedCourseManager: Added assignment \(localAssignment.name) to course \(courses[courseIndex].name)")
        }
    }
    
    private func handleAssignmentUpdate(_ dbAssignment: DatabaseAssignment) {
        let localAssignment = dbAssignment.toLocal()
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == localAssignment.courseId }),
              let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == localAssignment.id }) else {
            print("🔄 UnifiedCourseManager: Assignment or course not found for update: \(localAssignment.name)")
            return
        }
        
        courses[courseIndex].assignments[assignmentIndex] = localAssignment
        saveCoursesLocally() // Save to UserDefaults for UI consistency
        print("🔄 UnifiedCourseManager: Updated assignment \(localAssignment.name) in course \(courses[courseIndex].name)")
    }
    
    private func handleAssignmentDelete(_ assignmentId: String) {
        guard let uuid = UUID(uuidString: assignmentId) else { return }
        
        for courseIndex in courses.indices {
            if let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == uuid }) {
                let removedAssignment = courses[courseIndex].assignments.remove(at: assignmentIndex)
                saveCoursesLocally() // Save to UserDefaults for UI consistency
                print("🔄 UnifiedCourseManager: Deleted assignment \(removedAssignment.name) from course \(courses[courseIndex].name)")
                break
            }
        }
    }
    
    // MARK: - Enhanced Course Operations with Sync
    
    func addCourse(_ course: Course) {
        guard SupabaseService.shared.isAuthenticated else {
             ("🔒 UnifiedCourseManager: Add course blocked - user not authenticated")
            return
        }
        courses.append(course)
        saveCoursesLocally()
        
        syncCourseToDatabase(course, action: .create)
    }
    
    func updateCourse(_ course: Course) {
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else { return }
        
        courses[index] = course
        saveCoursesLocally()
        
        syncCourseToDatabase(course, action: .update)
    }
    
    func deleteCourse(_ courseID: UUID) {
        guard let course = courses.first(where: { $0.id == courseID }) else { return }
        
        courses.removeAll { $0.id == courseID }
        saveCoursesLocally()
        
        syncCourseToDatabase(course, action: .delete)
    }
    
    func addAssignment(_ assignment: Assignment, to courseId: UUID) {
        guard SupabaseService.shared.isAuthenticated else {
             ("🔒 UnifiedCourseManager: Add assignment blocked - user not authenticated")
            return
        }
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else { return }
        
        courses[courseIndex].addAssignment(assignment)
        saveCoursesLocally()
        
        syncAssignmentToDatabase(assignment, courseId: courseId, action: .create)
    }
    
    func updateAssignment(_ assignment: Assignment, in courseId: UUID) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }),
              let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        
        courses[courseIndex].assignments[assignmentIndex] = assignment
        saveCoursesLocally()
        
        syncAssignmentToDatabase(assignment, courseId: courseId, action: .update)
    }
    
    func deleteAssignment(_ assignmentId: UUID, from courseId: UUID) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }),
              let assignment = courses[courseIndex].assignments.first(where: { $0.id == assignmentId }) else { return }
        
        courses[courseIndex].assignments.removeAll { $0.id == assignmentId }
        saveCoursesLocally()
        
        syncAssignmentToDatabase(assignment, courseId: courseId, action: .delete)
    }
    
    // MARK: - Database Sync Operations
    
    private func syncCourseToDatabase(_ course: Course, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
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
        }
    }
    
    private func syncAssignmentToDatabase(_ assignment: Assignment, courseId: UUID, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let dbAssignment = DatabaseAssignment(
            from: assignment,
            userId: userId
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
        }
    }
    
    // MARK: - Enhanced Refresh with Sync
    
    func refreshCourseData() async {
        isSyncing = true
        
        // Load current courses from storage first
        loadCourses()
        
        // Refresh real-time sync data
        await realtimeSyncManager.refreshAllData()
        
        // Mark as no longer initial load after first refresh
        isInitialLoad = false
        
        lastSyncTime = Date()
        isSyncing = false
        
        print("🔄 UnifiedCourseManager: Course data refresh completed. Loaded \(courses.count) courses.")
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
        print("🔄 UnifiedCourseManager: Loaded \(courses.count) courses from storage")
        
        // Debug: Print course and assignment counts
        for course in courses {
            print("🔄 Course: \(course.name) has \(course.assignments.count) assignments")
        }
    }
}