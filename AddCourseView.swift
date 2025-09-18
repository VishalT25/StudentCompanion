import SwiftUI

struct AddCourseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @Binding var courses: [Course]

    @State private var courseName: String = ""
    @State private var courseCode: String = ""
    @State private var section: String = ""
    @State private var instructor: String = ""
    @State private var location: String = ""
    @State private var creditHours: Double = 3.0
    @State private var selectedIconName: String = "book.closed.fill"
    @State private var selectedColor: Color = .blue
    
    // Schedule Information
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // 1 hour later
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var reminderTime: ReminderTime = .fifteenMinutes
    @State private var isLiveActivityEnabled = true
    
    @State private var currentStep = 1
    private let totalSteps = 3

    private var canProceed: Bool {
        switch currentStep {
        case 1: return !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: return !selectedDays.isEmpty && startTime < endTime
        case 3: return true
        default: return false
        }
    }
    
    private var canSave: Bool {
        return canProceed && currentStep == totalSteps
    }
    
    let sfSymbolNames: [String] = [
        "book.closed.fill", "studentdesk", "laptopcomputer", "function",
        "atom", "testtube.2", "flame.fill", "brain.head.profile",
        "paintbrush.fill", "music.mic", "sportscourt.fill", "globe.americas.fill",
        "hammer.fill", "briefcase.fill", "creditcard.fill", "figure.walk",
        "graduationcap.fill", "pencil", "calculator", "microscope"
    ]
    
    let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Bar
                progressBar
                
                // Content
                TabView(selection: $currentStep) {
                    // Step 1: Course Details
                    courseDetailsStep
                        .tag(1)
                    
                    // Step 2: Schedule Information  
                    scheduleDetailsStep
                        .tag(2)
                    
                    // Step 3: Additional Settings
                    additionalSettingsStep
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation Buttons
                navigationButtons
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? themeManager.currentTheme.primaryColor : Color(.systemGray4))
                        .frame(width: 12, height: 12)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                    
                    if step < totalSteps {
                        Rectangle()
                            .fill(step < currentStep ? themeManager.currentTheme.primaryColor : Color(.systemGray4))
                            .frame(height: 2)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                    }
                }
            }
            
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - Course Details Step
    private var courseDetailsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Course Information")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("Let's start with the basic course details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    // Course Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Course Name *")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        TextField("e.g., Introduction to Computer Science", text: $courseName)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    HStack(spacing: 16) {
                        // Course Code
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Course Code")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            TextField("e.g., CS 101", text: $courseCode)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                        
                        // Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Section")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            TextField("e.g., A", text: $section)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                    }
                    
                    // Instructor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructor")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        TextField("e.g., Dr. Smith", text: $instructor)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    // Credit Hours
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credit Hours")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Stepper(
                                value: $creditHours,
                                in: 0.5...6.0,
                                step: 0.5
                            ) {
                                Text("\(String(format: creditHours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", creditHours)) credits")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Icon Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Icon")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(sfSymbolNames, id: \.self) { symbolName in
                                Button(action: {
                                    selectedIconName = symbolName
                                }) {
                                    Image(systemName: symbolName)
                                        .font(.title3)
                                        .foregroundColor(selectedIconName == symbolName ? .white : selectedColor)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(selectedIconName == symbolName ? selectedColor : selectedColor.opacity(0.15))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Color Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Color")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(predefinedColors, id: \.self) { color in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 120)
            }
        }
    }
    
    // MARK: - Schedule Details Step
    private var scheduleDetailsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Schedule Details")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("When does this course meet?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    // Days of Week
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days of the Week *")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach([DayOfWeek.monday, .tuesday, .wednesday, .thursday, .friday], id: \.self) { day in
                                CourseCreationDayToggle(
                                    day: day,
                                    isSelected: selectedDays.contains(day),
                                    color: selectedColor
                                ) {
                                    if selectedDays.contains(day) {
                                        selectedDays.remove(day)
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Time Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Class Time")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Start Time")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                    
                                    DatePicker(
                                        "",
                                        selection: $startTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                    .onChange(of: startTime) { _, newValue in
                                        endTime = newValue.addingTimeInterval(3600)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("End Time")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                    
                                    DatePicker(
                                        "",
                                        selection: $endTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }
                            }
                            
                            let duration = endTime.timeIntervalSince(startTime)
                            if duration > 0 {
                                HStack {
                                    Text("Duration: \(formatDuration(duration))")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(selectedColor)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        TextField("e.g., Room 101, Science Building", text: $location)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 120)
            }
        }
    }
    
    // MARK: - Additional Settings Step
    private var additionalSettingsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Final Settings")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("Configure reminders and notifications")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    // Reminder Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reminders")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Picker("Reminder Time", selection: $reminderTime) {
                            ForEach(ReminderTime.allCases, id: \.self) { reminder in
                                Text(reminder.displayName).tag(reminder)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                    
                    // Live Activity Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Live Activities")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Toggle(isOn: $isLiveActivityEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show on Lock Screen")
                                    .font(.subheadline)
                                
                                Text("Display class progress on your lock screen during class time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: selectedColor))
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Course Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Course Summary")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            SummaryRow(title: "Course", value: courseName.isEmpty ? "Untitled Course" : courseName)
                            if !courseCode.isEmpty {
                                SummaryRow(title: "Code", value: courseCode)
                            }
                            if !instructor.isEmpty {
                                SummaryRow(title: "Instructor", value: instructor)
                            }
                            SummaryRow(title: "Days", value: selectedDays.isEmpty ? "No days selected" : selectedDays.sorted { $0.rawValue < $1.rawValue }.map { $0.short }.joined(separator: ", "))
                            SummaryRow(title: "Time", value: "\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))")
                            if !location.isEmpty {
                                SummaryRow(title: "Location", value: location)
                            }
                            SummaryRow(title: "Credits", value: String(format: "%.1f", creditHours))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedColor.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 120)
            }
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 1 {
                Button("Previous") {
                    withAnimation(.easeInOut) {
                        currentStep -= 1
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.currentTheme.primaryColor, lineWidth: 1.5)
                )
            }
            
            Button(currentStep < totalSteps ? "Next" : "Create Course") {
                if currentStep < totalSteps {
                    withAnimation(.easeInOut) {
                        currentStep += 1
                    }
                } else {
                    saveCourse()
                    dismiss()
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canProceed ? themeManager.currentTheme.primaryColor : Color(.systemGray3))
            )
            .disabled(!canProceed)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    // MARK: - Helper Methods
    private func saveCourse() {
        guard !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Ensure there's an active schedule - create one if needed
        var activeScheduleId: UUID
        if let existingScheduleId = scheduleManager.activeScheduleID {
            activeScheduleId = existingScheduleId
        } else {
            let defaultSchedule = ScheduleCollection(
                name: "My Schedule", 
                semester: "Fall 2025"
            )
            
            scheduleManager.addSchedule(defaultSchedule)
            scheduleManager.setActiveSchedule(defaultSchedule.id)
            activeScheduleId = defaultSchedule.id
            print("🔧 Created default schedule for course sync: \(defaultSchedule.id)")
        }
        
        // Create the course with basic information (no time data)
        let newCourse = Course(
            scheduleId: activeScheduleId,
            name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIconName,
            colorHex: selectedColor.toHex() ?? Color.blue.toHex()!,
            creditHours: creditHours,
            courseCode: courseCode.trimmingCharacters(in: .whitespacesAndNewlines),
            section: section.trimmingCharacters(in: .whitespacesAndNewlines),
            instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Create a meeting with the schedule information
        if !selectedDays.isEmpty && startTime < endTime {
            let meeting = CourseMeeting(
                courseId: newCourse.id,
                scheduleId: activeScheduleId,
                meetingType: .lecture, // Default to lecture
                startTime: startTime,
                endTime: endTime,
                daysOfWeek: selectedDays.map { $0.rawValue },
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                reminderTime: reminderTime,
                isLiveActivityEnabled: isLiveActivityEnabled
            )
            
            // Add the meeting to the course
            newCourse.addMeeting(meeting)
        }
        
        courses.append(newCourse)
        
        print("✅ Course created successfully for scheduleId: \(activeScheduleId)")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
    }
}

struct CourseCreationDayToggle: View {
    let day: DayOfWeek
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(day.short.prefix(1).uppercased())
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isSelected ? .white : color)
                
                Text(day.short)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : color.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    AddCourseView(courses: .constant([]))
        .environmentObject(ThemeManager())
        .environmentObject(ScheduleManager())
}