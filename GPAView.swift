import SwiftUI

struct GPAView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @StateObject private var bulkSelectionManager = BulkCourseSelectionManager()
    @State private var showingAddCourseSheet = false
    @State private var showConflictResolution = false
    @State private var orphanedData: (courses: [Course], scheduleItems: [ScheduleItem]) = ([], [])
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("lastGradeUpdate") private var lastGradeUpdate: Double = 0
    @State private var showBulkDeleteAlert = false
    @State private var showDeleteCourseAlert = false
    @State private var courseToDelete: Course?
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @Environment(\.colorScheme) var colorScheme
    
    // New state for average detail sheets
    @State private var showingSemesterDetail = false
    @State private var showingYearDetail = false
    @State private var selectedYearScheduleIDs: Set<UUID> = []
    @AppStorage("YearDetail_SelectedScheduleIDs") private var selectedYearScheduleIDsStorage: String = ""

    // Analytics computed properties
    private var activeScheduleCourses: [Course] {
        guard let activeSchedule = scheduleManager.activeSchedule else { return [] }
        return courseManager.courses.filter { $0.scheduleId == activeSchedule.id }
    }
    
    private var semesterAverage: Double? {
        let coursesWithGrades = activeScheduleCourses.compactMap { course -> (grade: Double, creditHours: Double)? in
            guard let grade = course.calculateCurrentGrade() else { return nil }
            return (grade: grade, creditHours: course.creditHours)
        }
        
        guard !coursesWithGrades.isEmpty else { return nil }
        
        let totalWeightedGrade = coursesWithGrades.reduce(0) { $0 + ($1.grade * $1.creditHours) }
        let totalCredits = coursesWithGrades.reduce(0) { $0 + $1.creditHours }
        
        return totalCredits > 0 ? totalWeightedGrade / totalCredits : nil
    }
    
    private var semesterGPA: Double? {
        let coursesWithGPA = activeScheduleCourses.compactMap { course -> (gpaPoints: Double, creditHours: Double)? in
            guard let gpaPoints = course.gpaPoints else { return nil }
            return (gpaPoints: gpaPoints, creditHours: course.creditHours)
        }
        
        guard !coursesWithGPA.isEmpty else { return nil }
        
        let totalQualityPoints = coursesWithGPA.reduce(0) { $0 + ($1.gpaPoints * $1.creditHours) }
        let totalCredits = coursesWithGPA.reduce(0) { $0 + $1.creditHours }
        
        return totalCredits > 0 ? totalQualityPoints / totalCredits : nil
    }
    
    private var yearAverage: Double? {
        let selectedCourses = courseManager.courses.filter { selectedYearScheduleIDs.contains($0.scheduleId) }
        let allCoursesWithGrades = selectedCourses.compactMap { course -> (grade: Double, creditHours: Double)? in
            guard let grade = course.calculateCurrentGrade() else { return nil }
            return (grade: grade, creditHours: course.creditHours)
        }
        
        guard !allCoursesWithGrades.isEmpty else { return nil }
        
        let totalWeightedGrade = allCoursesWithGrades.reduce(0) { $0 + ($1.grade * $1.creditHours) }
        let totalCredits = allCoursesWithGrades.reduce(0) { $0 + $1.creditHours }
        
        return totalCredits > 0 ? totalWeightedGrade / totalCredits : nil
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Stunning header section with analytics
                spectacularHeaderSection
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Beautiful courses grid
                        coursesGridSection
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Magical floating add button
            if !bulkSelectionManager.isSelecting {
                magicalFloatingAddButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddCourseSheet) {
            EnhancedAddCourseView(courseManager: courseManager)
                .environmentObject(themeManager)
                .environmentObject(scheduleManager)
        }
        .sheet(isPresented: $showConflictResolution) {
            DataConflictResolutionView(
                orphanedData: OrphanedDataResult(
                    orphanedCourses: orphanedData.courses,
                    orphanedScheduleItems: orphanedData.scheduleItems.map { scheduleItem in
                        ScheduleItemWithScheduleID(
                            scheduleItem: scheduleItem,
                            scheduleId: UUID(),
                            scheduleName: "Unknown Schedule"
                        )
                    }
                ),
                onResolution: handleConflictResolution
            )
            .environmentObject(themeManager)
            .environmentObject(courseManager)
            .environmentObject(scheduleManager)
        }
        .sheet(isPresented: $showingSemesterDetail) {
            SemesterDetailView(
                semesterAverage: semesterAverage,
                semesterGPA: semesterGPA,
                courses: activeScheduleCourses,
                usePercentageGrades: usePercentageGrades,
                themeManager: themeManager,
                activeSchedule: scheduleManager.activeSchedule
            )
        }
        .sheet(isPresented: $showingYearDetail) {
            YearDetailView(
                allSchedules: Array(scheduleManager.scheduleCollections),
                allCourses: courseManager.courses,
                selectedScheduleIDs: $selectedYearScheduleIDs,
                usePercentageGrades: usePercentageGrades,
                themeManager: themeManager
            )
        }
        .onAppear {
            courseManager.loadCourses()
            startAnimations()
            loadYearSelectionFromStorage()
            
            // NEW: Set up cross-references between managers
            courseManager.setScheduleManager(scheduleManager)
            scheduleManager.setCourseManager(courseManager)
        }
        .refreshable {
            await refreshData()
        }
        .onChange(of: selectedYearScheduleIDs) { oldValue, newValue in
            saveYearSelectionToStorage()
        }
        .onChange(of: scheduleManager.scheduleCollections.map { $0.id }) {
            syncSelectionWithAvailableSchedules()
        }
        .toolbar {
            toolbarContent
        }
        .alert("Delete Course?", isPresented: $showDeleteCourseAlert) {
            deleteAlert
        } message: {
            Text("This will remove the course and its assignments.")
        }
        .alert("Delete Selected Courses?", isPresented: $showBulkDeleteAlert) {
            bulkDeleteAlert
        } message: {
            Text("This will permanently delete \(bulkSelectionManager.selectedCount()) course(s) and all their assignments.")
        }
    }
    
    // MARK: - Spectacular Header Section
    private var spectacularHeaderSection: some View {
        VStack(spacing: 28) {
            // Schedule title with beautiful styling and compact averages
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("My Courses")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    if let activeSchedule = scheduleManager.activeSchedule {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.forma(.caption))
                                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.8))
                            
                            Text(activeSchedule.displayName)
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.forma(.caption))
                                .foregroundColor(.orange)
                            
                            Text("No Active Schedule")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                
                Spacer()
                
                // Ultra-compact averages horizontally
                HStack(spacing: 6) {
                    Button(action: { showingSemesterDetail = true }) {
                        MiniAveragePill(
                            title: "SEM",
                            value: semesterAverage,
                            gpa: semesterGPA,
                            usePercentage: usePercentageGrades,
                            color: themeManager.currentTheme.primaryColor,
                            themeManager: themeManager
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showingYearDetail = true }) {
                        MiniAveragePill(
                            title: "YR",
                            value: yearAverage,
                            gpa: nil,
                            usePercentage: usePercentageGrades,
                            color: themeManager.currentTheme.secondaryColor,
                            themeManager: themeManager
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Courses Grid Section
    private var coursesGridSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            if activeScheduleCourses.isEmpty {
                spectacularEmptyState
            } else {
                LazyVStack(spacing: 20) {
                    ForEach(Array(activeScheduleCourses.enumerated()), id: \.element.id) { index, course in
                        NavigationLink(
                            destination: CourseDetailView(course: course, courseManager: courseManager)
                        ) {
                            GorgeousCourseCard(
                                course: course,
                                courseManager: courseManager,
                                bulkSelectionManager: bulkSelectionManager,
                                themeManager: themeManager,
                                usePercentageGrades: usePercentageGrades,
                                animationDelay: Double(index) * 0.1,
                                onDelete: { deleteCourse(course) },
                                onLongPress: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    bulkSelectionManager.startSelection(.courses, initialID: course.id)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Spectacular Empty State
    private var spectacularEmptyState: some View {
        VStack(spacing: 32) {
            // Animated illustration
            ZStack {
                // Background circles with animation
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(pulseAnimation + Double(index) * 0.1)
                        .animation(
                            .easeInOut(duration: 3.0 + Double(index) * 0.5)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                // Main icon
                Image(systemName: "graduationcap")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulseAnimation * 0.95 + 0.05)
            }
            
            VStack(spacing: 16) {
                Text("Ready to excel?")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add your first course to start tracking grades, schedules, and assignments with beautiful analytics")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Gorgeous call-to-action button
            Button("Add Your First Course") {
                showingAddCourseSheet = true
            }
            .font(.forma(.headline, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.4),
                    radius: 16, x: 0, y: 8
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.2),
                    radius: 8, x: 0, y: 4
                )
            )
            .buttonStyle(EnhancedButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.1),
                    radius: 24, x: 0, y: 12
                )
        )
    }
    
    // MARK: - Magical Floating Add Button
    private var magicalFloatingAddButton: some View {
        Button(action: { showingAddCourseSheet = true }) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(
                    ZStack {
                        // Main gradient background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Animated glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeManager.currentTheme.darkModeAccentHue.opacity(0.6),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .scaleEffect(pulseAnimation * 0.3 + 0.7)
                            .opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity : 0.3)
                        
                        // Shimmer effect
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.4),
                                        Color.clear,
                                        Color.clear
                                    ],
                                    center: .center,
                                    angle: .degrees(animationOffset * 0.5)
                                )
                            )
                    }
                    .shadow(
                        color: themeManager.currentTheme.primaryColor.opacity(0.4),
                        radius: 20, x: 0, y: 10
                    )
                    .shadow(
                        color: themeManager.currentTheme.darkModeAccentHue.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.6 : 0.2),
                        radius: 12, x: 0, y: 6
                    )
                )
        }
        .buttonStyle(MagicalButtonStyle())
        .padding(.trailing, 24)
        .padding(.bottom, 32)
    }
    
    // MARK: - Enhanced Selection Toolbar
    private var enhancedSelectionToolbar: some View {
        HStack {
            Text("\(bulkSelectionManager.selectedCount()) selected")
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Select All") {
                toggleSelectAll()
            }
            .font(.forma(.subheadline, weight: .semibold))
            .foregroundColor(themeManager.currentTheme.primaryColor)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor.opacity(0.3),
                            themeManager.currentTheme.secondaryColor.opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2),
            alignment: .bottom
        )
    }
    
    // MARK: - Helper Methods
    private func startAnimations() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
        
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.15
        }
    }
    
    private func deleteCourse(_ course: Course) {
        courseToDelete = course
        showDeleteCourseAlert = true
    }
    
    private func longPressGesture(for course: Course) -> some Gesture {
        LongPressGesture(minimumDuration: 0.6)
            .onEnded { _ in
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                bulkSelectionManager.startSelection(.courses, initialID: course.id)
            }
    }
    
    private func handleConflictResolution(_ resolution: OrphanResolutionAction) {
        switch resolution {
        case .assignCourseToActiveSchedule(let course):
             ("Assigning course \(course.name) to active schedule")
        case .createScheduleForCourse(let course):
             ("Creating new schedule for course \(course.name)")
        case .createCourseFromScheduleItem(let scheduleItemWrapper):
             ("Creating course from schedule item \(scheduleItemWrapper.scheduleItem.title)")
        case .mergeScheduleItemWithCourse(let scheduleItemWrapper, let course):
             ("Merging schedule item \(scheduleItemWrapper.scheduleItem.title) with course \(course.name)")
        case .deleteOrphanedCourse(let course):
            courseManager.deleteCourse(course.id)
             ("Deleted orphaned course \(course.name)")
        case .deleteOrphanedScheduleItem(let scheduleItemWrapper):
             ("Deleted orphaned schedule item \(scheduleItemWrapper.scheduleItem.title)")
        }
    }
    
    private func refreshData() async {
        courseManager.loadCourses()
        await courseManager.refreshCourseData()
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if bulkSelectionManager.isSelecting && bulkSelectionManager.selectionContext == .courses {
                Button(selectionAllButtonTitle()) {
                    toggleSelectAll()
                }
                .foregroundColor(themeManager.currentTheme.primaryColor)
                
                Button(role: .destructive) {
                    showBulkDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(bulkSelectionManager.selectedCount() == 0)
                .foregroundColor(bulkSelectionManager.selectedCount() == 0 ? .secondary : .red)
            }
        }
        
        ToolbarItemGroup(placement: .navigationBarLeading) {
            if bulkSelectionManager.isSelecting {
                Button("Cancel") {
                    bulkSelectionManager.endSelection()
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var deleteAlert: some View {
        Button("Cancel", role: .cancel) { courseToDelete = nil }
        Button("Delete", role: .destructive) {
            if let course = courseToDelete {
                courseManager.deleteCourse(course.id)
            }
            courseToDelete = nil
        }
    }
    
    @ViewBuilder
    private var bulkDeleteAlert: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) {
            for courseID in bulkSelectionManager.selectedCourseIDs {
                courseManager.deleteCourse(courseID)
            }
            bulkSelectionManager.endSelection()
        }
    }
    
    private func selectionAllButtonTitle() -> String {
        let total = activeScheduleCourses.count
        let selected = bulkSelectionManager.selectedCount()
        return selected == total && total > 0 ? "Deselect All" : "Select All"
    }
    
    private func toggleSelectAll() {
        let total = activeScheduleCourses.count
        let selected = bulkSelectionManager.selectedCount()
        
        if selected == total && total > 0 {
            bulkSelectionManager.deselectAll()
        } else {
            bulkSelectionManager.selectAll(items: activeScheduleCourses)
        }
    }

    private func loadYearSelectionFromStorage() {
        let availableIDs = Set(scheduleManager.scheduleCollections.map { $0.id })
        if selectedYearScheduleIDsStorage.isEmpty {
            selectedYearScheduleIDs = availableIDs
            saveYearSelectionToStorage()
            return
        }
        let stored = selectedYearScheduleIDsStorage
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
        let parsed = Set(stored).intersection(availableIDs)
        selectedYearScheduleIDs = parsed.isEmpty ? availableIDs : parsed
    }
    
    private func saveYearSelectionToStorage() {
        selectedYearScheduleIDsStorage = selectedYearScheduleIDs.map { $0.uuidString }.joined(separator: ",")
    }
    
    private func syncSelectionWithAvailableSchedules() {
        let availableIDs = Set(scheduleManager.scheduleCollections.map { $0.id })
        selectedYearScheduleIDs = selectedYearScheduleIDs.intersection(availableIDs)
        if selectedYearScheduleIDs.isEmpty {
            selectedYearScheduleIDs = availableIDs
        }
        saveYearSelectionToStorage()
    }

}

// MARK: - Mini Average Pill Component
struct MiniAveragePill: View {
    let title: String
    let value: Double?
    let gpa: Double?
    let usePercentage: Bool
    let color: Color
    let themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.forma(.caption2, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.8))
                .tracking(0.2)
            
            if let value = value {
                Text(displayValue)
                    .font(.forma(.caption, weight: .bold)) // Shrunk from .subheadline to .caption
                    .foregroundColor(.primary)
            } else {
                Text("--")
                    .font(.forma(.caption, weight: .bold)) // Shrunk from .subheadline to .caption
                    .foregroundColor(.secondary.opacity(0.6))
            }
            
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 60)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(
                    color: color.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.2 : 0.05),
                    radius: 3 + (colorScheme == .dark ? themeManager.darkModeHueIntensity * 2 : 0),
                    x: 0,
                    y: 1 + (colorScheme == .dark ? themeManager.darkModeHueIntensity * 1 : 0)
                )
        )
    }
    
    private var displayValue: String {
        guard let value = value else { return "--" }
        
        if usePercentage {
            return String(format: "%.0f%%", value)
        } else if let gpaValue = gpa {
            return String(format: "%.1f", gpaValue)
        } else {
            return String(format: "%.0f%%", value)
        }
    }
    
    private var gradeColor: Color {
        guard let value = value else { return .secondary.opacity(0.3) }
        
        let percentage = usePercentage ? value : (gpa ?? 0) * 25
        
        switch percentage {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }
}

#Preview {
    NavigationView {
        GPAView()
            .environmentObject(ThemeManager())
    }
}