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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
        // CRITICAL: Listen for data clearing when user signs out
        NotificationCenter.default.addObserver(
            forName: .init("UserDataCleared"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🧹 UnifiedCourseManager: Received UserDataCleared notification")
            self?.clearAllData()
        }
        
        // Listen for post sign-in data refresh notification
        NotificationCenter.default.addObserver(
            forName: .init("UserSignedInDataRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 UnifiedCourseManager: Received post sign-in data refresh notification")
            Task { 
                await self?.refreshCourseData()
                await self?.backfillUnsyncedCourses()
            }
        }
        
        // Listen for data sync completed notification
        NotificationCenter.default.addObserver(
            forName: .init("DataSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 UnifiedCourseManager: Received data sync completed notification")
            Task { 
                await self?.reloadFromCache()
                await self?.backfillUnsyncedCourses()
            }
        }
    }
    
    // MARK: - Data Clearing
    
    private func clearAllData() {
        print("🧹 UnifiedCourseManager: Clearing all local data")
        courses.removeAll()
        
        // Force save empty state
        saveCoursesLocally()
        
        print("🧹 UnifiedCourseManager: All data cleared")
    }
    
    // MARK: - Cache Reload
    
    private func reloadFromCache() async {
        print("🔄 UnifiedCourseManager: Reloading data from cache")
        
        // Load courses from cache
        let cachedCourses = await CacheSystem.shared.courseCache.retrieve()
        
        // Load assignments from cache
        let cachedAssignments = await CacheSystem.shared.assignmentCache.retrieve()
        
        // If cache is empty, do not wipe locally stored courses
        guard !cachedCourses.isEmpty else {
            print("🔄 UnifiedCourseManager: Cache empty, preserving existing local courses")
            return
        }
        
        var updatedCourses: [Course] = []
        for course in cachedCourses {
            var updatedCourse = course
            updatedCourse.assignments = cachedAssignments.filter { $0.courseId == course.id }
            updatedCourses.append(updatedCourse)
        }
        
        await MainActor.run {
            self.courses = updatedCourses
        }
        
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
        let remoteCourses = dbCourses.map { $0.toLocal() }
        
        // Preserve existing locally stored courses (including unsynced ones)
        let existingCourses = CourseStorage.load()
        let remoteIDs = Set(remoteCourses.map { $0.id })
        
        // Start with remote courses, preserving assignments for matches
        var updatedCourses: [Course] = remoteCourses.map { remote in
            if let existing = existingCourses.first(where: { $0.id == remote.id }) {
                var merged = remote
                merged.assignments = existing.assignments
                return merged
            } else {
                return remote
            }
        }
        
        // Add any local-only courses that don't exist remotely yet (unsynced)
        let localOnly = existingCourses.filter { !remoteIDs.contains($0.id) }
        updatedCourses.append(contentsOf: localOnly)
        
        self.courses = updatedCourses
        saveCoursesLocally()
        
        print("🔄 UnifiedCourseManager: Synced courses (remote=\(remoteCourses.count), preserved local-only=\(localOnly.count), total=\(updatedCourses.count))")
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
        courses.append(course)
        saveCoursesLocally()
        
        // If authenticated, queue sync to backend; otherwise, it will remain local until sign-in.
        if SupabaseService.shared.isAuthenticated {
            syncCourseToDatabase(course, action: .create)
        } else {
             ("🔒 UnifiedCourseManager: Added course locally (offline). Will sync when signed in.")
        }
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
    
    func addMeeting(_ meeting: CourseMeeting) {
        // Append locally first for instant UI
        if let idx = self.courses.firstIndex(where: { $0.id == meeting.courseId }) {
            self.courses[idx].meetings.append(meeting)
            self.courses = self.courses
            self.saveCoursesLocally()
        }

        // Sync to backend if authenticated
        guard SupabaseService.shared.isAuthenticated else { return }
        Task {
            do {
                let repo = CourseMeetingRepository()
                let userId = SupabaseService.shared.currentUser?.id.uuidString ?? ""
                let saved = try await repo.create(meeting, userId: userId)

                if let cidx = self.courses.firstIndex(where: { $0.id == saved.courseId }),
                   let midx = self.courses[cidx].meetings.firstIndex(where: { $0.id == meeting.id }) {
                    self.courses[cidx].meetings[midx] = saved
                } else if let cidx = self.courses.firstIndex(where: { $0.id == saved.courseId }) {
                    self.courses[cidx].meetings.append(saved)
                }

                await MainActor.run {
                    self.courses = self.courses
                }

                self.saveCoursesLocally()
                await CacheSystem.shared.courseMeetingCache.store(saved)
            } catch {
                print("🔄 UnifiedCourseManager: Failed to add meeting: \(error)")
            }
        }
    }

    func updateMeeting(_ meeting: CourseMeeting) {
        Task {
            do {
                let repo = CourseMeetingRepository()
                let userId = SupabaseService.shared.currentUser?.id.uuidString ?? ""
                let saved = try await repo.update(meeting, userId: userId)
                if let cidx = self.courses.firstIndex(where: { $0.id == saved.courseId }),
                   let midx = self.courses[cidx].meetings.firstIndex(where: { $0.id == saved.id }) {
                    self.courses[cidx].meetings[midx] = saved
                    await MainActor.run {
                        self.courses = self.courses
                    }
                    self.saveCoursesLocally()
                    await CacheSystem.shared.courseMeetingCache.update(saved)
                }
            } catch {
                print("🔄 UnifiedCourseManager: Failed to update meeting: \(error)")
            }
        }
    }

    func deleteMeeting(_ meetingId: UUID, courseId: UUID) {
        Task {
            do {
                let repo = CourseMeetingRepository()
                try await repo.delete(id: meetingId.uuidString)
                if let cidx = self.courses.firstIndex(where: { $0.id == courseId }) {
                    self.courses[cidx].meetings.removeAll { $0.id == meetingId }
                    await MainActor.run {
                        self.courses = self.courses
                    }
                    self.saveCoursesLocally()
                    await CacheSystem.shared.courseMeetingCache.delete(id: meetingId.uuidString)
                }
            } catch {
                print("🔄 UnifiedCourseManager: Failed to delete meeting: \(error)")
            }
        }
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
        print("🔄 DEBUG: refreshCourseData started")
        isSyncing = true
        
        // Load current courses from storage first
        loadCourses()
        print("🔄 DEBUG: Loaded \(courses.count) courses from local storage")
        
        // Refresh real-time sync data
        await realtimeSyncManager.refreshAllData()
        
        await backfillUnsyncedCourses()
        
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

    func createCourseWithMeetings(_ course: Course, meetings: [CourseMeeting]) async {
        print("🔍 DEBUG: createCourseWithMeetings called")
        print("🔍 DEBUG: Course: '\(course.name)' with \(meetings.count) meetings")
        print("🔍 DEBUG: Authentication status: \(SupabaseService.shared.isAuthenticated)")
        
        // If not authenticated or offline, save locally for immediate UI
        guard SupabaseService.shared.isAuthenticated else {
            var localCourse = course
            localCourse.meetings = meetings
            self.courses.append(localCourse)
            self.saveCoursesLocally()
            print("🔍 DEBUG: Saved course locally (offline) with \(meetings.count) meetings")
            print("🔍 DEBUG: Course now has \(localCourse.meetings.count) meetings in memory")
            return
        }

        do {
            let userId = SupabaseService.shared.currentUser?.id.uuidString ?? ""
            let courseRepo = CourseRepository()
            let meetingRepo = CourseMeetingRepository()

            print("🔍 DEBUG: Creating course '\(course.name)' in database...")
            print("🔍 DEBUG: User ID: \(userId)")
            print("🔍 DEBUG: Schedule ID: \(course.scheduleId)")

            // 1) Create the course in DB first so FK constraints pass
            let createdCourse = try await courseRepo.create(course, userId: userId)
            print("🔍 DEBUG: ✅ Course created in database with ID: \(createdCourse.id)")

            // 2) Create meetings referencing the created course
            var savedMeetings: [CourseMeeting] = []
            print("🔍 DEBUG: Creating \(meetings.count) meetings...")
            
            for (idx, var m) in meetings.enumerated() {
                print("🔍 DEBUG: Creating meeting \(idx + 1)/\(meetings.count):")
                print("🔍 DEBUG: - Label: '\(m.rotationLabel ?? "nil")'")
                print("🔍 DEBUG: - Rotation index: \(m.rotationIndex ?? -1)")
                print("🔍 DEBUG: - Time: \(m.startTime.formatted(date: .omitted, time: .shortened)) - \(m.endTime.formatted(date: .omitted, time: .shortened))")
                
                m.userId = UUID(uuidString: userId)
                m.courseId = createdCourse.id
                m.scheduleId = m.scheduleId ?? createdCourse.scheduleId
                
                let saved = try await meetingRepo.create(m, userId: userId)
                savedMeetings.append(saved)
                await CacheSystem.shared.courseMeetingCache.store(saved)
                
                print("🔍 DEBUG: ✅ Meeting created with ID: \(saved.id)")
                print("🔍 DEBUG: - DB rotation index: \(saved.rotationIndex ?? -1)")
            }

            // 3) Update local store and caches
            createdCourse.meetings = savedMeetings
            self.courses.append(createdCourse)
            self.saveCoursesLocally()
            await CacheSystem.shared.courseCache.store(createdCourse)
            
            print("🔍 DEBUG: ✅ Successfully created course with \(savedMeetings.count) meetings")
            print("🔍 DEBUG: Course in memory now has \(createdCourse.meetings.count) meetings")
            print("🔍 DEBUG: Total courses in manager: \(self.courses.count)")
        } catch {
            print("🛑 createCourseWithMeetings failed: \(error)")
            print("🛑 Error details: \(String(describing: error))")
            
            // Fallback: store locally so UI still shows data
            var fallbackCourse = course
            fallbackCourse.meetings = meetings
            self.courses.append(fallbackCourse)
            self.saveCoursesLocally()
            print("🔍 DEBUG: Stored course locally as fallback with \(meetings.count) meetings")
        }
    }
}

extension UnifiedCourseManager {
    private func backfillUnsyncedCourses() async {
        guard SupabaseService.shared.isAuthenticated,
              let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            return
        }
        
        let courseRepo = CourseRepository()
        
        for (index, course) in courses.enumerated() {
            do {
                let remote = try await courseRepo.read(id: course.id.uuidString)
                if remote == nil {
                    print("☁️ Backfill: Creating course remotely: \(course.name)")
                    let createdCourse = try await courseRepo.create(course, userId: userId)
                    
                    var updated = createdCourse
                    updated.assignments = course.assignments
                    
                    if index < courses.count, courses[index].id == course.id {
                        courses[index] = updated
                    } else if let idx = courses.firstIndex(where: { $0.id == course.id }) {
                        courses[idx] = updated
                    }
                    
                    await CacheSystem.shared.courseCache.update(updated)
                    print("☁️ Backfill: ✅ Created course '\(updated.name)'")
                }
            } catch {
                print("⚠️ Backfill: Failed to backfill course \(course.name): \(error.localizedDescription)")
            }
        }
    }
}