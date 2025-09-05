import SwiftUI
import Combine

struct CourseDetailView: View {
    @ObservedObject var course: Course
    var courseManager: CourseOperationsManager?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var bulkSelectionManager = BulkCourseSelectionManager()
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @State private var showBulkDeleteAlert = false
    
    @State private var currentGradeInput: String = ""
    @State private var desiredGradeInput: String = ""
    @State private var finalWorthInput: String = ""
    @State private var neededOnFinalOutput: String = ""
    
    private var weightValidation: (total: Double, isValid: Bool, message: String) {
        var totalWeight = 0.0
        var assignmentsWithWeights = 0
        
        for assignment in course.assignments {
            if let weight = assignment.weightValue, weight > 0 {
                totalWeight += weight
                assignmentsWithWeights += 1
            }
        }
        
        let isValid = totalWeight <= 100.0
        var message = ""
        
        if assignmentsWithWeights == 0 {
            message = "No assignment weights set"
        } else if totalWeight > 100.0 {
            let excess = totalWeight - 100.0
            message = String(format: "Exceeds 100%% by %.1f%%", excess)
        } else {
            message = ""
        }
        
        return (total: totalWeight, isValid: isValid, message: message)
    }
    
    private func requestSave() {
        // Load all courses, update this course, and save back
        var allCourses = CourseStorage.load()
        if let index = allCourses.firstIndex(where: { $0.id == course.id }) {
            allCourses[index] = course
            CourseStorage.save(allCourses)
        }
    }
    
    private var textColor: Color {
        course.color.isDark ? .white : .black
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                assignmentsSection
                finalGradeCalculatorSection
                Spacer(minLength: 50)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if bulkSelectionManager.isSelecting {
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
        .onAppear {
            autoFillCalculatorValues()
        }
        .onChange(of: course.assignments) { oldValue, newValue in
            autoFillCalculatorValues()
            requestSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            reloadCourseData()
        }
        .alert("Delete Selected Assignments?", isPresented: $showBulkDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                bulkDeleteAssignments()
            }
        } message: {
            Text("This will permanently delete \(bulkSelectionManager.selectedCount()) assignment(s).")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: course.iconName)
                .font(.system(size: 40))
                .foregroundColor(textColor)
                .frame(height: 50)
            Text(course.name)
                .font(.forma(.title2, weight: .bold))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
            VStack(spacing: 4) {
                Text("Current Grade")
                    .font(.forma(.subheadline))
                    .foregroundColor(textColor.opacity(0.8))
                let grade = calculateCurrentGrade()
                if grade != "N/A" {
                    Text("\(grade)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                } else {
                    Text("Enter grades to calculate")
                        .font(.forma(.subheadline))
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            course.color.opacity(0.9),
                            course.color,
                            course.color.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: course.color.opacity(0.3), radius: 12, x: 0, y: 6)
        )
    }
    
    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Assignments & Exams")
                    .font(.forma(.title3, weight: .bold))
                Spacer()
                if bulkSelectionManager.isSelecting {
                    Text("\(bulkSelectionManager.selectedCount()) selected")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Button(action: {
                        course.assignments.append(Assignment(courseId: course.id))
                        requestSave()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(course.color)
                    }
                }
            }
            
            if !course.assignments.isEmpty {
                let validation = weightValidation
                
                if !validation.isValid && !validation.message.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.forma(.subheadline))
                        
                        Text(validation.message)
                            .font(.forma(.subheadline))
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Text("Total: \(String(format: "%.1f", validation.total))%")
                            .font(.forma(.caption))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .animation(.easeInOut(duration: 0.3), value: validation.isValid)
                }
            }
            
            if course.assignments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No assignments added yet")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                    Button("Add your first assignment") {
                        course.assignments.append(Assignment(courseId: course.id))
                        requestSave()
                    }
                    .font(.forma(.caption))
                    .foregroundColor(course.color)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(course.assignments) { assignment in
                        if bulkSelectionManager.selectionContext == .assignments(courseID: course.id) {
                            HStack {
                                AssignmentRow(
                                    assignment: assignment,
                                    courseColor: course.color,
                                    onEdit: { requestSave() },
                                    onDelete: { deleteAssignment(assignment) },
                                    isSelectionMode: true
                                )
                                selectionIndicator(isSelected: bulkSelectionManager.isSelected(assignment.id))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                bulkSelectionManager.toggleSelection(assignment.id)
                            }
                        } else {
                            AssignmentRow(
                                assignment: assignment,
                                courseColor: course.color,
                                onEdit: { requestSave() },
                                onDelete: { deleteAssignment(assignment) },
                                isSelectionMode: false
                            )
                            .contextMenu {
                                Button("Select Multiple", systemImage: "checkmark.circle") {
                                    bulkSelectionManager.startSelection(.assignments(courseID: course.id), initialID: assignment.id)
                                }
                                Button("Delete Assignment", systemImage: "trash", role: .destructive) {
                                    deleteAssignment(assignment)
                                }
                            }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.6)
                                    .onEnded { _ in
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                        bulkSelectionManager.startSelection(.assignments(courseID: course.id), initialID: assignment.id)
                                    }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(course.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(isSelected ? themeManager.currentTheme.primaryColor : .secondary)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func selectionAllButtonTitle() -> String {
        let total = course.assignments.count
        let selected = bulkSelectionManager.selectedCount()
        return selected == total && total > 0 ? "Deselect All" : "Select All"
    }
    
    private func toggleSelectAll() {
        let total = course.assignments.count
        let selected = bulkSelectionManager.selectedCount()
        
        if selected == total && total > 0 {
            bulkSelectionManager.deselectAll()
        } else {
            bulkSelectionManager.selectAll(items: course.assignments)
        }
    }
    
    private func bulkDeleteAssignments() {
        let assignmentIDsToDelete = bulkSelectionManager.selectedAssignmentIDs
        course.assignments.removeAll { assignmentIDsToDelete.contains($0.id) }
        requestSave()
        bulkSelectionManager.endSelection()
    }
    
    private var finalGradeCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Final Grade Calculator")
                .font(.forma(.title3, weight: .bold))
            
            VStack(spacing: 12) {
                CalculatorInputRow(
                    title: "Your current grade:",
                    value: $currentGradeInput,
                    suffix: "%",
                    placeholder: "e.g. 88",
                    courseColor: course.color,
                    themeManager: themeManager
                )
                
                CalculatorInputRow(
                    title: "Grade you want:",
                    value: $desiredGradeInput,
                    suffix: "%",
                    placeholder: "85",
                    courseColor: course.color,
                    themeManager: themeManager
                )
                
                CalculatorInputRow(
                    title: "Final exam weight:",
                    value: $finalWorthInput,
                    suffix: "%",
                    placeholder: "100",
                    courseColor: course.color,
                    themeManager: themeManager
                )
            }
            
            HStack(spacing: 12) {
                Button("Clear") {
                    currentGradeInput = ""
                    desiredGradeInput = ""
                    finalWorthInput = ""
                    neededOnFinalOutput = ""
                    autoFillCalculatorValues()
                }
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(course.color)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(course.color.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button("Calculate") {
                    calculateNeededOnFinal()
                }
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(course.color)
                        .shadow(color: course.color.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            
            if !neededOnFinalOutput.isEmpty {
                finalGradeResultView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(course.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var finalGradeResultView: some View {
        VStack(spacing: 12) {
            if let neededGrade = Double(neededOnFinalOutput) {
                VStack(spacing: 8) {
                    Text(getMotivationalMessage(for: neededGrade))
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("\(neededOnFinalOutput)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(getGradeColor(for: neededGrade))
                    
                    Text("needed on your final exam")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(neededOnFinalOutput)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(course.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    func calculateCurrentGrade() -> String {
        var totalWeightedGrade = 0.0
        var totalWeight = 0.0
        for assignment in course.assignments {
            if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                totalWeightedGrade += grade * weight
                totalWeight += weight
            }
        }
        if totalWeight == 0 { return "N/A" }
        let currentGradeVal = totalWeightedGrade / totalWeight
        return String(format: "%.1f", currentGradeVal)
    }

    func calculateNeededOnFinal() {
        guard let current = Double(currentGradeInput),
              let desired = Double(desiredGradeInput),
              let finalWeight = Double(finalWorthInput), finalWeight > 0, finalWeight <= 100 else {
            neededOnFinalOutput = "Please fill in all fields with valid numbers"
            return
        }
        let currentWeightPercentage = (100.0 - finalWeight) / 100.0
        let finalWeightPercentage = finalWeight / 100.0
        let needed = (desired - (current * currentWeightPercentage)) / finalWeightPercentage
        neededOnFinalOutput = String(format: "%.1f", needed)
    }

    private func autoFillCalculatorValues() {
        let calculatedGrade = calculateCurrentGrade()
        if calculatedGrade != "N/A" {
            currentGradeInput = calculatedGrade
        } else if currentGradeInput.isEmpty {
             currentGradeInput = ""
        }
        
        var totalAssignmentWeight = 0.0
        for assignment in course.assignments {
            if let weight = assignment.weightValue {
                totalAssignmentWeight += weight
            }
        }
        let remainingWeight = max(0, 100 - totalAssignmentWeight)
        finalWorthInput = String(format: "%.0f", remainingWeight)
        
        if desiredGradeInput.isEmpty {
            if let currentGradeVal = Double(calculatedGrade), calculatedGrade != "N/A" {
                let suggestedGrade = max(85.0, currentGradeVal + 5.0)
                desiredGradeInput = String(format: "%.0f", min(suggestedGrade, 100.0))
            } else {
                desiredGradeInput = "85"
            }
        }
    }
    
    private func getMotivationalMessage(for grade: Double) -> String {
        switch grade {
        case ..<0:
            return "🎉 You've already got this! You could skip the final and still pass!"
        case 0..<50:
            return "✨ Very achievable! You're in great shape!"
        case 50..<70:
            return "📚 Totally doable with some solid studying!"
        case 70..<85:
            return "💪 Time to buckle down, but you've got this!"
        case 85..<95:
            return "🔥 Challenge accepted! Time to show what you're made of!"
        case 95..<100:
            return "😅 Yikes! You'll need to channel your inner genius!"
        case 100..<110:
            return "🚀 Technically possible, but you'll need to be absolutely perfect!"
        default:
            return "😬 Hate to break it to you, but this might require a miracle... or extra credit!"
        }
    }
    
    private func getGradeColor(for grade: Double) -> Color {
        switch grade {
        case ..<50:
            return .green
        case 50..<70:
            return .blue
        case 70..<85:
            return course.color
        case 85..<95:
            return .orange
        default:
            return .red
        }
    }
    
    private func deleteAssignment(_ assignment: Assignment) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let index = course.assignments.firstIndex(where: { $0.id == assignment.id }) {
                course.assignments.remove(at: index)
                requestSave()
            }
        }
    }
    
    private func reloadCourseData() {
        let allCourses = CourseStorage.load()
        
        if let updatedCourse = allCourses.first(where: { $0.id == course.id }) {
            DispatchQueue.main.async {
                course.assignments = updatedCourse.assignments
                autoFillCalculatorValues()
            }
        }
    }
}

struct AssignmentRow: View {
    @ObservedObject var assignment: Assignment
    let courseColor: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    let isSelectionMode: Bool
    
    @FocusState private var isNameFocused: Bool
    @FocusState private var isGradeFocused: Bool
    @FocusState private var isWeightFocused: Bool
    @State private var showDeleteConfirmation = false
    
    private var displayGrade: String {
        get {
            if assignment.grade.isEmpty {
                return ""
            }
            if assignment.grade.hasSuffix("%") {
                return assignment.grade
            } else {
                return "\(assignment.grade)%"
            }
        }
        set {
            assignment.grade = newValue.replacingOccurrences(of: "%", with: "")
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Assignment name", text: $assignment.name)
                    .font(.subheadline.weight(.medium))
                    .focused($isNameFocused)
                    .textFieldStyle(.plain)
                    .onChange(of: assignment.name) { _, _ in onEdit() }
                    .disabled(isSelectionMode)
                
                Spacer()
                
                if !isSelectionMode {
                    HStack(spacing: 4) {
                        TextField("Grade", text: Binding(
                            get: { displayGrade },
                            set: { newValue in
                                assignment.grade = newValue.replacingOccurrences(of: "%", with: "")
                                onEdit()
                            }
                        ))
                            .font(.subheadline.weight(.medium))
                            .focused($isGradeFocused)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Weight", text: $assignment.weight)
                            .font(.subheadline.weight(.medium))
                            .focused($isWeightFocused)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: assignment.weight) { _, _ in onEdit() }
                        
                        Text("%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Grade: \(displayGrade.isEmpty ? "—" : displayGrade)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Weight: \(assignment.weight.isEmpty ? "—" : assignment.weight)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if !isSelectionMode {
                Divider()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(isSelectionMode ? 0.3 : 0.5))
        .cornerRadius(8)
        .opacity(isSelectionMode ? 0.8 : 1.0)
        .contextMenu {
            if !isSelectionMode {
                Button("Delete Assignment", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .alert("Delete Assignment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(assignment.name.isEmpty ? "this assignment" : assignment.name)'?")
        }
    }
}

struct CalculatorInputRow: View {
    let title: String
    @Binding var value: String
    let suffix: String
    let placeholder: String
    let courseColor: Color
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Text(title)
                .font(.forma(.subheadline))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                TextField(placeholder, text: $value)
                    .font(.forma(.subheadline, weight: .medium))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(courseColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                
                Text(suffix)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(courseColor)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var sampleCourse = Course(
            scheduleId: UUID(),
            name: "Sample Course",
            assignments: [
                Assignment(courseId: UUID(), name: "Homework 1", grade: "95", weight: "15"),
                Assignment(courseId: UUID(), name: "Midterm Exam", grade: "87", weight: "25"),
                Assignment(courseId: UUID(), name: "Final Project", grade: "92", weight: "20")
            ]
        )
        
        var body: some View {
            NavigationView {
                CourseDetailView(course: sampleCourse)
                    .environmentObject(ThemeManager())
            }
        }
    }
    return PreviewWrapper()
}