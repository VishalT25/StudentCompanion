import SwiftUI

struct GPAView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var courseManager = CourseOperationsManager()
    @StateObject private var bulkSelectionManager = BulkCourseSelectionManager()
    @State private var showingAddCourseSheet = false
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("lastGradeUpdate") private var lastGradeUpdate: Double = 0
    @State private var showBulkDeleteAlert = false
    @State private var showDeleteCourseAlert = false
    @State private var courseToDelete: Course?

    var body: some View {
        ZStack {
            mainContentView
            
            if !bulkSelectionManager.isSelecting {
                addButton
            }
        }
        .sheet(isPresented: $showingAddCourseSheet) {
            AddCourseView(courses: $courseManager.courses)
                .environmentObject(themeManager)
        }
        .onAppear {
            courseManager.loadCourses()
        }
        .refreshable {
            courseManager.loadCourses()
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
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if bulkSelectionManager.isSelecting {
                selectionToolbar
            }
            
            coursesList
        }
    }
    
    private var coursesList: some View {
        List {
            ForEach(courseManager.courses) { course in
                courseRow(for: course)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, bulkSelectionManager.isSelecting ? .constant(.active) : .constant(.inactive))
    }
    
    @ViewBuilder
    private func courseRow(for course: Course) -> some View {
        if bulkSelectionManager.selectionContext == .courses {
            selectionModeRow(for: course)
        } else {
            normalModeRow(for: course)
        }
    }
    
    private func selectionModeRow(for course: Course) -> some View {
        HStack {
            CourseWidgetView(
                course: course,
                showGrade: showCurrentGPA,
                usePercentage: usePercentageGrades
            )
            Spacer()
            selectionIndicator(isSelected: bulkSelectionManager.isSelected(course.id))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            bulkSelectionManager.toggleSelection(course.id)
        }
    }
    
    private func normalModeRow(for course: Course) -> some View {
        NavigationLink(destination: CourseDetailView(course: course, courseManager: courseManager)) {
            CourseWidgetView(
                course: course,
                showGrade: showCurrentGPA,
                usePercentage: usePercentageGrades
            )
        }
        .contextMenu {
            courseContextMenu(for: course)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(longPressGesture(for: course))
    }
    
    @ViewBuilder
    private func courseContextMenu(for course: Course) -> some View {
        Button("Select Multiple", systemImage: "checkmark.circle") {
            bulkSelectionManager.startSelection(.courses, initialID: course.id)
        }
        Button("Delete Course", systemImage: "trash", role: .destructive) {
            courseToDelete = course
            showDeleteCourseAlert = true
        }
    }
    
    private func longPressGesture(for course: Course) -> some Gesture {
        LongPressGesture(minimumDuration: 0.6)
            .onEnded { _ in
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                bulkSelectionManager.startSelection(.courses, initialID: course.id)
            }
    }
    
    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showingAddCourseSheet = true }) {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(20)
                        .background(Circle().fill(themeManager.currentTheme.primaryColor))
                        .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(SpringButtonStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
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
            // Bulk delete selected courses
            for courseID in bulkSelectionManager.selectedCourseIDs {
                courseManager.deleteCourse(courseID)
            }
            bulkSelectionManager.endSelection()
        }
    }
    
    private var selectionToolbar: some View {
        HStack {
            Text("\(bulkSelectionManager.selectedCount()) selected")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if bulkSelectionManager.selectedCount() > 0 {
                Text("Tap to delete selected items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(isSelected ? themeManager.currentTheme.primaryColor : .secondary)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func selectionAllButtonTitle() -> String {
        let total = courseManager.courses.count
        let selected = bulkSelectionManager.selectedCount()
        return selected == total && total > 0 ? "Deselect All" : "Select All"
    }
    
    private func toggleSelectAll() {
        let total = courseManager.courses.count
        let selected = bulkSelectionManager.selectedCount()
        
        if selected == total && total > 0 {
            bulkSelectionManager.deselectAll()
        } else {
            bulkSelectionManager.selectAll(items: courseManager.courses)
        }
    }
}

struct CourseWidgetView: View {
    @ObservedObject var course: Course
    let showGrade: Bool
    let usePercentage: Bool
    
    private var foregroundColor: Color {
        course.color.isDark ? .white : .black
    }
    
    private var currentGrade: String {
        if !showGrade {
            return ""
        }
        
        let grade = calculateCurrentGrade()
        if grade == "N/A" {
            return "N/A"
        }
        
        if usePercentage {
            return "\(grade)%"
        } else {
            if let gradeValue = Double(grade) {
                let gpa = (gradeValue / 100.0) * 4.0
                return String(format: "%.2f", gpa)
            }
            return "N/A"
        }
    }
    
    private func calculateCurrentGrade() -> String {
        var totalWeightedGrade = 0.0
        var totalWeight = 0.0
        
        for assignment in course.assignments {
            if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                totalWeightedGrade += grade * weight
                totalWeight += weight
            }
        }
        
        if totalWeight == 0 {
            return "N/A"
        }
        
        let currentGradeVal = totalWeightedGrade / totalWeight
        return String(format: "%.1f", currentGradeVal)
    }

    var body: some View {
        HStack(spacing: 12) {
            courseInfo
            
            Spacer()

            if showGrade && !currentGrade.isEmpty {
                gradeDisplay
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 80)
        .background(courseBackground)
        .cornerRadius(12)
    }
    
    private var courseInfo: some View {
        HStack(spacing: 10) {
            Image(systemName: course.iconName)
                .font(.title2)
                .foregroundColor(foregroundColor)
                .frame(width: 30, alignment: .center)

            Text(course.name)
                .font(.headline)
                .foregroundColor(foregroundColor)
                .lineLimit(2)
        }
    }
    
    private var gradeDisplay: some View {
        Text(currentGrade)
            .font(.headline.bold())
            .foregroundColor(foregroundColor)
    }
    
    private var courseBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [course.color.lighter(by: 0.2), course.color]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Button Style
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension Color {
    var isDark: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.5
    }

    func lighter(by percentage: CGFloat = 0.2) -> Color {
        return self.adjust(by: abs(percentage))
    }

    private func adjust(by percentage: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) {
            return Color(UIColor(red: min(r + percentage, 1.0),
                               green: min(g + percentage, 1.0),
                               blue: min(b + percentage, 1.0),
                               alpha: a))
        } else {
            return self
        }
    }
}

#Preview {
    GPAView()
        .environmentObject(ThemeManager())
}