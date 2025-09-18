import SwiftUI
import Combine
import Supabase

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
        
        // Load course meetings from cache
        let cachedMeetings = await CacheSystem.shared.courseMeetingCache.retrieve()
        
        // If cache is empty, do not wipe locally stored courses
        guard !cachedCourses.isEmpty else {
            print("🔄 UnifiedCourseManager: Cache empty, preserving existing local courses")
            return
        }
        
        var updatedCourses: [Course] = []
        for course in cachedCourses {
            var updatedCourse = course
            updatedCourse.assignments = cachedAssignments.filter { $0.courseId == course.id }
            updatedCourse.meetings = cachedMeetings.filter { $0.courseId == course.id }
            updatedCourses.append(updatedCourse)
        }
        
        await MainActor.run {
            self.courses = updatedCourses
        }
        
        saveCoursesLocally()
        
        print("🔄 UnifiedCourseManager: Reloaded \(cachedCourses.count) courses with \(cachedAssignments.count) total assignments and \(cachedMeetings.count) total meetings from cache")
    }
    
    // NEW: Set schedule manager for synchronization
    func setScheduleManager(_ scheduleManager: ScheduleManager) {
        self.scheduleManager = scheduleManager
        print("🔄 UnifiedCourseManager: Schedule manager reference set")
        
        // The course manager will be the single source of truth for course data
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
            
        case ("course_meetings", "SYNC"):
            if let meetingsData = data["course_meetings"] as? [DatabaseCourseMeeting] {
                syncCourseMeetingsFromDatabase(meetingsData)
            }
        case ("course_meetings", "INSERT"):
            if let meetingData = try? JSONSerialization.data(withJSONObject: data),
               let dbMeeting = try? JSONDecoder().decode(DatabaseCourseMeeting.self, from: meetingData) {
                handleCourseMeetingInsert(dbMeeting)
            }
        case ("course_meetings", "UPDATE"):
            if let meetingData = try? JSONSerialization.data(withJSONObject: data),
               let dbMeeting = try? JSONDecoder().decode(DatabaseCourseMeeting.self, from: meetingData) {
                handleCourseMeetingUpdate(dbMeeting)
            }
        case ("course_meetings", "DELETE"):
            if let meetingId = data["id"] as? String {
                handleCourseMeetingDelete(meetingId)
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
    
    // MARK: - Course Meeting Sync Handlers
    
    private func syncCourseMeetingsFromDatabase(_ meetings: [DatabaseCourseMeeting]) {
        print("🔄 UnifiedCourseManager: Syncing \(meetings.count) course meetings from database")
        
        let localMeetings = meetings.map { $0.toLocal() }
        let groupedMeetings = Dictionary(grouping: localMeetings) { $0.courseId }
        
        var coursesUpdated = false
        
        for (courseId, meetingsForCourse) in groupedMeetings {
            if let courseIndex = courses.firstIndex(where: { $0.id == courseId }) {
                // Replace meetings for this course
                courses[courseIndex].meetings = meetingsForCourse
                coursesUpdated = true
                print("🔄 UnifiedCourseManager: Updated \(meetingsForCourse.count) meetings for course: \(courses[courseIndex].name)")
            }
        }
        
        // Save to local storage after sync
        if coursesUpdated {
            saveCoursesLocally()
            print("🔄 UnifiedCourseManager: Saved courses with meetings to local storage")
        }
        
        print("🔄 UnifiedCourseManager: Course meeting sync complete")
    }
    
    private func handleCourseMeetingInsert(_ dbMeeting: DatabaseCourseMeeting) {
        let localMeeting = dbMeeting.toLocal()
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == localMeeting.courseId }) else {
            print("🔄 UnifiedCourseManager: Course not found for meeting: \(localMeeting.displayName)")
            return
        }
        
        if !courses[courseIndex].meetings.contains(where: { $0.id == localMeeting.id }) {
            courses[courseIndex].meetings.append(localMeeting)
            // Force UI update by reassigning the courses array
            courses = courses
            saveCoursesLocally() // Save to UserDefaults for UI consistency
            print("🔄 UnifiedCourseManager: Added meeting \(localMeeting.displayName) to course \(courses[courseIndex].name)")
        }
    }
    
    private func handleCourseMeetingUpdate(_ dbMeeting: DatabaseCourseMeeting) {
        let localMeeting = dbMeeting.toLocal()
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == localMeeting.courseId }),
              let meetingIndex = courses[courseIndex].meetings.firstIndex(where: { $0.id == localMeeting.id }) else {
            print("🔄 UnifiedCourseManager: Meeting or course not found for update: \(localMeeting.displayName)")
            return
        }
        
        courses[courseIndex].meetings[meetingIndex] = localMeeting
        // Force UI update by reassigning the courses array  
        courses = courses
        saveCoursesLocally() // Save to UserDefaults for UI consistency
        print("🔄 UnifiedCourseManager: Updated meeting \(localMeeting.displayName) in course \(courses[courseIndex].name)")
    }
    
    private func handleCourseMeetingDelete(_ meetingId: String) {
        guard let uuid = UUID(uuidString: meetingId) else { return }
        
        for courseIndex in courses.indices {
            if let meetingIndex = courses[courseIndex].meetings.firstIndex(where: { $0.id == uuid }) {
                let removedMeeting = courses[courseIndex].meetings.remove(at: meetingIndex)
                // Force UI update by reassigning the courses array
                courses = courses
                saveCoursesLocally() // Save to UserDefaults for UI consistency
                print("🔄 UnifiedCourseManager: Deleted meeting \(removedMeeting.displayName) from course \(courses[courseIndex].name)")
                break
            }
        }
    }
    
    // MARK: - Real-time Course Handlers
    
    private func syncCoursesFromDatabase(_ dbCourses: [DatabaseCourse]) {
        print("🔄 UnifiedCourseManager: Syncing \(dbCourses.count) courses from database")
        
        let remoteCourses = dbCourses.map { $0.toLocal() }
        
        // Preserve existing locally stored courses (including unsynced ones)
        let existingCourses = CourseStorage.load()
        let remoteIDs = Set(remoteCourses.map { $0.id })
        
        // Start with remote courses, preserving assignments and meetings for matches
        var updatedCourses: [Course] = remoteCourses.map { remote in
            if let existing = existingCourses.first(where: { $0.id == remote.id }) {
                var merged = remote
                merged.assignments = existing.assignments
                merged.meetings = existing.meetings // Always preserve existing meetings
                print("🔄 UnifiedCourseManager: Preserved \(existing.meetings.count) meetings for course '\(remote.name)'")
                return merged
            } else {
                return remote
            }
        }
        
        // Add any local-only courses that don't exist remotely yet (unsynced)
        let localOnly = existingCourses.filter { !remoteIDs.contains($0.id) }
        updatedCourses.append(contentsOf: localOnly)
        
        // Update courses immediately - don't wait for async meeting loading
        self.courses = updatedCourses
        saveCoursesLocally()
        
        print("🔄 UnifiedCourseManager: Synced courses (remote=\(remoteCourses.count), preserved local-only=\(localOnly.count), total=\(updatedCourses.count))")
        
        // Load meetings from database for courses that don't have them - but don't block
        Task {
            await loadMeetingsForCoursesIfNeeded()
        }
    }
    
    // MARK: - Load meetings for courses that don't have them (simplified)
    private func loadMeetingsForCoursesIfNeeded() async {
        guard SupabaseService.shared.isAuthenticated,
              let userId = SupabaseService.shared.currentUser?.id.uuidString else { 
            print("🔄 UnifiedCourseManager: Cannot load meetings - no auth or user ID")
            return 
        }
        
        print("🔄 UnifiedCourseManager: Loading meetings for courses that need them...")
        print("🔄 UnifiedCourseManager: User ID: \(userId)")
        
        let meetingRepo = CourseMeetingRepository()
        var coursesNeedingUpdate: [(Int, Course)] = []
        
        // Check which courses need meetings loaded
        for (index, course) in courses.enumerated() {
            if course.meetings.isEmpty {
                print("🔄 UnifiedCourseManager: Course '\(course.name)' has no meetings, loading from database...")
                do {
                    let meetings = try await meetingRepo.findByCourse(course.id.uuidString, userId: userId)
                    print("🔄 UnifiedCourseManager: Found \(meetings.count) meetings for course '\(course.name)' in database")
                    
                    if !meetings.isEmpty {
                        var updatedCourse = course
                        updatedCourse.meetings = meetings
                        coursesNeedingUpdate.append((index, updatedCourse))
                        
                        // Debug each meeting
                        for meeting in meetings {
                            print("  - Meeting: \(meeting.displayName) on days \(meeting.daysOfWeek) at \(meeting.timeRange)")
                        }
                    } else {
                        print("🔄 UnifiedCourseManager: No meetings found for course '\(course.name)' in database")
                    }
                } catch {
                    print("❌ UnifiedCourseManager: Failed to load meetings for course '\(course.name)': \(error)")
                    print("❌ Error type: \(type(of: error))")
                    print("❌ Error details: \(error.localizedDescription)")
                }
            } else {
                print("🔄 UnifiedCourseManager: Course '\(course.name)' already has \(course.meetings.count) meetings")
            }
        }
        
        // Update courses with loaded meetings
        if !coursesNeedingUpdate.isEmpty {
            await MainActor.run {
                for (index, updatedCourse) in coursesNeedingUpdate {
                    if index < self.courses.count && self.courses[index].id == updatedCourse.id {
                        print("🔄 UnifiedCourseManager: Updating course '\(updatedCourse.name)' with \(updatedCourse.meetings.count) meetings")
                        self.courses[index] = updatedCourse
                    }
                }
                // Force UI update
                self.courses = self.courses
                self.saveCoursesLocally()
                print("✅ UnifiedCourseManager: Updated \(coursesNeedingUpdate.count) courses with meetings from database")
            }
        } else {
            print("🔄 UnifiedCourseManager: No courses needed meeting updates")
        }
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
            print("🔒 UnifiedCourseManager: Added course locally (offline). Will sync when signed in.")
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
            print("🔒 UnifiedCourseManager: Add assignment blocked - user not authenticated")
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
        
        // Load current courses from storage first - this preserves meetings
        loadCourses()
        print("🔄 DEBUG: Loaded \(courses.count) courses from local storage")
        
        // If authenticated, load fresh course and meeting data from database
        if SupabaseService.shared.isAuthenticated {
            await loadCoursesWithMeetingsFromDatabase()
        }
        
        // Refresh real-time sync data (this might override some data, but we've already loaded meetings)
        await realtimeSyncManager.refreshAllData()
        
        await backfillUnsyncedCourses()
        
        isInitialLoad = false
        lastSyncTime = Date()
        isSyncing = false
        print("🔄 UnifiedCourseManager: Course data refresh completed. Loaded \(courses.count) courses.")
    }
    
    // MARK: - New method to load courses with meetings from database
    private func loadCoursesWithMeetingsFromDatabase() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { 
            print("🔄 UnifiedCourseManager: Cannot load from database - no user ID")
            return 
        }
        
        do {
            print("🔄 UnifiedCourseManager: Loading courses with meetings from database...")
            print("🔄 UnifiedCourseManager: User ID: \(userId)")
            
            // Load courses from database
            let courseRepo = CourseRepository()
            let dbCourses = try await courseRepo.readAll(userId: userId)
            print("🔄 UnifiedCourseManager: Loaded \(dbCourses.count) courses from database")
            
            // Load all course meetings from database in one go
            let meetingRepo = CourseMeetingRepository()
            let allMeetings = try await meetingRepo.readAll(userId: userId)
            let meetingsByCode = Dictionary(grouping: allMeetings) { $0.courseId }
            print("🔄 UnifiedCourseManager: Loaded \(allMeetings.count) total meetings from database")
            
            // Debug: Print all meetings
            for meeting in allMeetings {
                print("  - Meeting ID: \(meeting.id), Course: \(meeting.courseId), Type: \(meeting.meetingType.displayName), Days: \(meeting.daysOfWeek)")
            }
            
            var coursesWithMeetings: [Course] = []
            
            for course in dbCourses {
                var enrichedCourse = course
                
                // Assign meetings for this course
                let courseMeetings = meetingsByCode[course.id] ?? []
                enrichedCourse.meetings = courseMeetings
                print("🔄 UnifiedCourseManager: Course '\(course.name)' (ID: \(course.id)) has \(enrichedCourse.meetings.count) meetings from database")
                
                // Preserve any local assignments
                if let existingCourse = courses.first(where: { $0.id == course.id }) {
                    enrichedCourse.assignments = existingCourse.assignments
                }
                
                coursesWithMeetings.append(enrichedCourse)
            }
            
            // Update courses with database data - this should make meetings appear immediately
            self.courses = coursesWithMeetings
            
            // Save to local storage so meetings persist across app restarts
            saveCoursesLocally()
            
            print("✅ UnifiedCourseManager: Successfully loaded \(coursesWithMeetings.count) courses with meetings from database")
            
        } catch {
            print("❌ UnifiedCourseManager: Failed to load courses with meetings from database: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error details: \(error.localizedDescription)")
        }
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
        let storedCourses = CourseStorage.load()
        
        // CRITICAL FIX: Don't overwrite courses if they already have meetings and we're loading from storage
        // This prevents the sync process from wiping out meetings that were just loaded
        if courses.isEmpty {
            // Only load from storage if we have no courses yet
            self.courses = storedCourses
            print("🔄 UnifiedCourseManager: Loaded \(storedCourses.count) courses from storage (initial load)")
        } else if !storedCourses.isEmpty {
            // Merge stored courses with existing courses, preserving meetings
            print("🔄 UnifiedCourseManager: Merging \(storedCourses.count) stored courses with \(courses.count) existing courses")
            
            var mergedCourses = courses
            
            for storedCourse in storedCourses {
                if let existingIndex = mergedCourses.firstIndex(where: { $0.id == storedCourse.id }) {
                    // Preserve meetings from existing course if stored course doesn't have them
                    if !mergedCourses[existingIndex].meetings.isEmpty && storedCourse.meetings.isEmpty {
                        print("🔄 UnifiedCourseManager: Preserving \(mergedCourses[existingIndex].meetings.count) meetings for course '\(storedCourse.name)'")
                        var updatedCourse = storedCourse
                        updatedCourse.meetings = mergedCourses[existingIndex].meetings
                        mergedCourses[existingIndex] = updatedCourse
                    } else {
                        // Use stored version (it has more recent data or meetings)
                        mergedCourses[existingIndex] = storedCourse
                    }
                } else {
                    // Add new course from storage
                    mergedCourses.append(storedCourse)
                }
            }
            
            self.courses = mergedCourses
            print("🔄 UnifiedCourseManager: Merged courses - total: \(mergedCourses.count)")
        } else {
            print("🔄 UnifiedCourseManager: No stored courses to load, keeping existing \(courses.count) courses")
        }
        
        // Debug: Print course and meeting counts
        for course in courses {
            if !course.meetings.isEmpty {
                print("🔄 Course: \(course.name) has \(course.meetings.count) meetings")
            }
        }
    }

    func createCourseWithMeetings(_ course: Course, meetings: [CourseMeeting]) async throws {
        print("🔍 DEBUG: createCourseWithMeetings called")
        print("🔍 DEBUG: Course: '\(course.name)' with \(meetings.count) meetings")
        print("🔍 DEBUG: Authentication status: \(SupabaseService.shared.isAuthenticated)")
        print("🔍 DEBUG: User authenticated: \(SupabaseService.shared.currentUser != nil)")
        
        // Check authentication first
        guard SupabaseService.shared.isAuthenticated else {
            print("❌ DEBUG: User not authenticated")
            throw NSError(domain: "CourseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("❌ DEBUG: No user ID available")
            throw NSError(domain: "CourseManager", code: 402, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }
        
        // Validate course data
        guard !course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ DEBUG: Course name is empty")
            throw NSError(domain: "CourseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Course name cannot be empty"])
        }
        
        print("🔍 DEBUG: User ID: \(userId)")
        print("🔍 DEBUG: Schedule ID: \(course.scheduleId)")

        do {
            let courseRepo = CourseRepository()
            let meetingRepo = CourseMeetingRepository()

            print("🔍 DEBUG: Creating course '\(course.name)' in database...")

            // 1) Create the course in DB first
            let createdCourse = try await courseRepo.create(course, userId: userId)
            print("🔍 DEBUG: ✅ Course created in database with ID: \(createdCourse.id)")

            // 2) Create ALL meetings in database
            var savedMeetings: [CourseMeeting] = []
            print("🔍 DEBUG: Creating \(meetings.count) meetings in database...")
            
            for (idx, var meeting) in meetings.enumerated() {
                print("🔍 DEBUG: Creating meeting \(idx + 1)/\(meetings.count): \(meeting.meetingType.displayName)")
                
                // Ensure proper IDs are set - FIXED: userId is already a string, don't convert to UUID
                meeting.userId = UUID(uuidString: userId) // This should work if userId is valid UUID string
                meeting.courseId = createdCourse.id
                meeting.scheduleId = meeting.scheduleId ?? createdCourse.scheduleId
                
                // Validate that all required fields are set
                guard let meetingUserId = meeting.userId else {
                    print("❌ DEBUG: Failed to set userId for meeting")
                    throw NSError(domain: "CourseManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"])
                }
                
                print("🔍 DEBUG: Meeting details before save:")
                print("  - ID: \(meeting.id)")
                print("  - CourseId: \(meeting.courseId)")
                print("  - ScheduleId: \(String(describing: meeting.scheduleId))")
                print("  - UserId: \(String(describing: meeting.userId))")
                print("  - Days: \(meeting.daysOfWeek)")
                print("  - Start: \(meeting.startTime)")
                print("  - End: \(meeting.endTime)")
                
                // Actually save to database
                let savedMeeting = try await meetingRepo.create(meeting, userId: userId)
                savedMeetings.append(savedMeeting)
                
                print("🔍 DEBUG: ✅ Meeting '\(savedMeeting.displayName)' saved to database with ID: \(savedMeeting.id)")
            }

            // 3) Update local store with database-saved data
            var courseWithMeetings = createdCourse
            courseWithMeetings.meetings = savedMeetings
            
            // Add to local courses array
            self.courses.append(courseWithMeetings)
            
            // Force UI update
            await MainActor.run {
                self.courses = self.courses
            }
            
            // Save to local storage
            self.saveCoursesLocally()
            
            // IMPORTANT: Store meetings in cache for realtime sync
            for meeting in savedMeetings {
                await CacheSystem.shared.courseMeetingCache.store(meeting)
            }
            
            print("🔍 DEBUG: ✅ Successfully created course with \(savedMeetings.count) meetings")
            print("🔍 DEBUG: Local courses count: \(self.courses.count)")
            print("🔍 DEBUG: Course '\(courseWithMeetings.name)' has \(courseWithMeetings.meetings.count) meetings")
            
            // Debug: Print each meeting
            for meeting in courseWithMeetings.meetings {
                print("🔍 DEBUG: Meeting '\(meeting.displayName)' on days \(meeting.daysOfWeek) at \(meeting.timeRange)")
            }
        } catch {
            print("🛑 createCourseWithMeetings FAILED: \(error)")
            print("🛑 Error type: \(type(of: error))")
            print("🛑 Error details: \(error.localizedDescription)")
            
            // Check specific error types
            if let urlError = error as? URLError {
                print("🛑 URLError: \(urlError)")
                print("🛑 URLError code: \(urlError.code)")
            }
            
            // Check if it's a Supabase-related error
            if error.localizedDescription.contains("PGRST") {
                print("🛑 Database error detected: \(error.localizedDescription)")
            }
            
            // Re-throw the error so caller knows it failed
            throw error
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