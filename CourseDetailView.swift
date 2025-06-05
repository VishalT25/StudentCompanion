import SwiftUI

struct CourseDetailView: View {
    @ObservedObject var course: Course
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    
    @State private var currentGradeInput: String = ""
    @State private var desiredGradeInput: String = ""
    @State private var finalWorthInput: String = ""
    @State private var neededOnFinalOutput: String = ""
    
    private func requestSave() {
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
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
        .onAppear {
            autoFillCalculatorValues()
        }
        .onChange(of: course.assignments) { oldValue, newValue in 
            autoFillCalculatorValues()
            requestSave()
        }
        // Add onChange for individual assignment properties if deeper reactivity is needed,
        // but the current setup should cover most cases via the assignments array changing
        // or the onEdit callback in AssignmentRowView.
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: course.iconName)
                .font(.system(size: 40))
                .foregroundColor(textColor)
                .frame(height: 50)
            Text(course.name)
                .font(.title2.bold())
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
            VStack(spacing: 4) {
                Text("Current Grade")
                    .font(.subheadline)
                    .foregroundColor(textColor.opacity(0.8))
                let grade = calculateCurrentGrade()
                if grade != "N/A" {
                    Text("\(grade)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                } else {
                    Text("Enter grades to calculate")
                        .font(.subheadline)
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [course.color.opacity(0.9), course.color]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
    }
    
    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Assignments & Exams")
                    .font(.title3.bold())
                Spacer()
                Button(action: { 
                    course.assignments.append(Assignment())
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(course.color)
                }
            }
            
            if course.assignments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No assignments added yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Add your first assignment") {
                        course.assignments.append(Assignment())
                    }
                    .font(.caption)
                    .foregroundColor(course.color) 
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(course.assignments.indices, id: \.self) { index in
                        AssignmentRowView(assignment: course.assignments[index], courseColor: course.color) {
                            autoFillCalculatorValues()
                            requestSave()
                        }
                    }
                    .onDelete(perform: deleteAssignment)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func deleteAssignment(offsets: IndexSet) {
        course.assignments.remove(atOffsets: offsets)
    }

    private var finalGradeCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Final Grade Calculator")
                .font(.title3.bold())
            
            VStack(spacing: 12) {
                CalculatorInputRow(
                    title: "Your current grade:",
                    value: $currentGradeInput,
                    suffix: "%",
                    placeholder: "e.g. 88" 
                )
                
                CalculatorInputRow(
                    title: "Grade you want:",
                    value: $desiredGradeInput,
                    suffix: "%",
                    placeholder: "e.g. 85" 
                )
                
                CalculatorInputRow(
                    title: "Final exam weight:",
                    value: $finalWorthInput,
                    suffix: "%",
                    placeholder: "e.g. 40" 
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
                .font(.subheadline.weight(.medium))
                .foregroundColor(course.color)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(course.color.opacity(0.15)) 
                .cornerRadius(8)
                
                Button("Calculate") {
                    calculateNeededOnFinal()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(course.color.isDark ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(course.color)
                .cornerRadius(8)
            }
            
            if !neededOnFinalOutput.isEmpty {
                finalGradeResultView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var finalGradeResultView: some View {
        VStack(spacing: 12) {
            if let neededGrade = Double(neededOnFinalOutput) {
                VStack(spacing: 8) {
                    Text(getMotivationalMessage(for: neededGrade))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("\(neededOnFinalOutput)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(getGradeColor(for: neededGrade)) 
                    
                    Text("needed on your final exam")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(neededOnFinalOutput) 
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.red) 
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    course.color.opacity(0.1),
                    course.color.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(12)
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
}

struct AssignmentRowView: View {
    @ObservedObject var assignment: Assignment
    let courseColor: Color
    let onEdit: () -> Void
    
    @FocusState private var isNameFocused: Bool
    @FocusState private var isGradeFocused: Bool
    @FocusState private var isWeightFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Assignment name", text: $assignment.name)
                    .font(.subheadline.weight(.medium))
                    .focused($isNameFocused)
                    .textFieldStyle(.plain)
                    .onChange(of: assignment.name) { _, _ in onEdit() }
                
                Spacer()
                
                HStack(spacing: 4) {
                    TextField("Grade", text: $assignment.grade)
                        .font(.subheadline.weight(.medium))
                        .focused($isGradeFocused)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: assignment.grade) { _, _ in onEdit() }
                    
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
            }
            Divider()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

struct CalculatorInputRow: View {
    let title: String
    @Binding var value: String
    let suffix: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                TextField(placeholder, text: $value)
                    .font(.subheadline.weight(.medium))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                
                Text(suffix)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var sampleCourse = Course(name: "Sample Course", assignments: [
            Assignment(name: "Homework 1", grade: "95", weight: "15"),
            Assignment(name: "Midterm Exam", grade: "87", weight: "25"),
            Assignment(name: "Final Project", grade: "92", weight: "20")
        ])
        
        var body: some View {
            NavigationView {
                CourseDetailView(course: sampleCourse)
                    .environmentObject(ThemeManager())
            }
        }
    }
    return PreviewWrapper()
}

extension Notification.Name {
    static let courseDataDidChange = Notification.Name("courseDataDidChange")
}
