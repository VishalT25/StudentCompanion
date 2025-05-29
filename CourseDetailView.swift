import SwiftUI

struct CourseDetailView: View {
    @State var course: Course
    @Environment(\.dismiss) var dismiss
    
    // State for the "Final Grade Calculator" section
    @State private var currentGradeInput: String = ""
    @State private var desiredGradeInput: String = ""
    @State private var finalWorthInput: String = ""
    @State private var neededOnFinalOutput: String = ""
    @State private var showingFinalCalculator = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with current grade
                headerView
                
                // Assignments section
                assignmentsSection
                
                // Final grade calculator section
                finalGradeCalculatorSection
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Course icon and name
            Image(systemName: course.iconName)
                .font(.system(size: 40))
                .foregroundColor(course.color)
                .frame(height: 50)
            
            Text(course.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            // Current grade display
            VStack(spacing: 4) {
                Text("Current Grade")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(calculateCurrentGrade())%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(course.color)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [course.color.opacity(0.1), course.color.opacity(0.05)]),
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
                Button(action: { course.assignments.append(Assignment()) }) {
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
                    ForEach($course.assignments) { $assignment in
                        AssignmentRowView(assignment: $assignment, courseColor: course.color)
                    }
                    .onDelete(perform: deleteAssignment)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
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
                    placeholder: "88"
                )
                
                CalculatorInputRow(
                    title: "Grade you want:",
                    value: $desiredGradeInput,
                    suffix: "%",
                    placeholder: "85"
                )
                
                CalculatorInputRow(
                    title: "Final exam weight:",
                    value: $finalWorthInput,
                    suffix: "%",
                    placeholder: "40"
                )
            }
            
            HStack(spacing: 12) {
                Button("Clear") {
                    currentGradeInput = ""
                    desiredGradeInput = ""
                    finalWorthInput = ""
                    neededOnFinalOutput = ""
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                
                Button("Calculate") {
                    calculateNeededOnFinal()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
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
    
    private func deleteAssignment(offsets: IndexSet) {
        course.assignments.remove(atOffsets: offsets)
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
        
        if totalWeight == 0 {
            return "N/A"
        }
        
        let currentGrade = totalWeightedGrade / totalWeight
        return String(format: "%.1f", currentGrade)
    }

    func calculateNeededOnFinal() {
        autoFillMissingValues()
        
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
    
    private func autoFillMissingValues() {
        // If current grade is empty but we have course data, use calculated grade
        if currentGradeInput.isEmpty {
            let calculatedGrade = calculateCurrentGrade()
            if calculatedGrade != "N/A", let grade = Double(calculatedGrade) {
                currentGradeInput = String(format: "%.1f", grade)
            }
        }
        
        // If final weight is empty, suggest a common value
        if finalWorthInput.isEmpty {
            finalWorthInput = "40" // Common final exam weight
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
    @Binding var assignment: Assignment
    let courseColor: Color
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
                
                Spacer()
                
                HStack(spacing: 4) {
                    TextField("Grade", text: $assignment.grade)
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
    NavigationView {
        CourseDetailView(course: Course(name: "Sample Course", assignments: [
            Assignment(name: "Homework 1", grade: "95", weight: "15"),
            Assignment(name: "Midterm Exam", grade: "87", weight: "25"),
            Assignment(name: "Final Project", grade: "92", weight: "20")
        ]))
    }
}
