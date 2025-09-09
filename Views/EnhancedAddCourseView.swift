import SwiftUI

struct EnhancedAddCourseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @ObservedObject var courseManager: UnifiedCourseManager
    
    // Add optional existing course parameter for editing
    let existingCourse: Course?
    
    // Initialize with existing course if editing
    init(courseManager: UnifiedCourseManager, existingCourse: Course? = nil) {
        self.courseManager = courseManager
        self.existingCourse = existingCourse
        
        // Pre-populate fields if editing
        if let course = existingCourse {
            _courseName = State(initialValue: course.name)
            _courseCode = State(initialValue: course.courseCode)
            _section = State(initialValue: course.section)
            _instructor = State(initialValue: course.instructor)
            _location = State(initialValue: course.location)
            _creditHours = State(initialValue: course.creditHours)
            _selectedIconName = State(initialValue: course.iconName)
            _selectedColor = State(initialValue: course.color)
            _startTime = State(initialValue: course.startTime ?? Date())
            _endTime = State(initialValue: course.endTime ?? Date().addingTimeInterval(3600))
            _selectedDays = State(initialValue: Set(course.daysOfWeek))
            _reminderTime = State(initialValue: course.reminderTime)
            _isLiveActivityEnabled = State(initialValue: course.isLiveActivityEnabled)
        } else {
            _courseName = State(initialValue: "")
            _courseCode = State(initialValue: "")
            _section = State(initialValue: "")
            _instructor = State(initialValue: "")
            _location = State(initialValue: "")
            _creditHours = State(initialValue: 3.0)
            _selectedIconName = State(initialValue: "book.closed.fill")
            _selectedColor = State(initialValue: .blue)
            _startTime = State(initialValue: Date())
            _endTime = State(initialValue: Date().addingTimeInterval(3600))
            _selectedDays = State(initialValue: [])
            _reminderTime = State(initialValue: .fifteenMinutes)
            _isLiveActivityEnabled = State(initialValue: true)
        }
    }
    
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
    @State private var isSaving = false
    private let totalSteps = 3

    private var canProceed: Bool {
        switch currentStep {
        case 1: 
            let hasName = !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
             ("Step 1 - Course name: '\(courseName)', hasName: \(hasName)")
            return hasName
        case 2: 
            let hasDays = !selectedDays.isEmpty
             ("Step 2 - Selected days: \(selectedDays), hasDays: \(hasDays)")
            return hasDays
        case 3: 
             ("Step 3 - Always can proceed")
            return true
        default: 
            return false
        }
    }
    
    private var canSave: Bool {
        let result = canProceed && currentStep == totalSteps && !isSaving
         ("canSave: canProceed=\(canProceed), currentStep=\(currentStep), totalSteps=\(totalSteps), isSaving=\(isSaving), result=\(result)")
        return result
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
            .navigationTitle(existingCourse != nil ? "Edit Course" : "Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving {
                    savingOverlay
                }
            }
        }
    }
    
    // MARK: - Saving Overlay
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
                
                Text("Creating Course...")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(radius: 20)
            )
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
                .font(.forma(.subheadline, weight: .medium))
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
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(existingCourse != nil ? "Edit course information" : "Let's start with the basic course details")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    // Course Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Course Name *")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        TextField("e.g., Introduction to Computer Science", text: $courseName)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    HStack(spacing: 16) {
                        // Course Code
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Course Code")
                                .font(.forma(.subheadline, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            TextField("e.g., CS 101", text: $courseCode)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                        
                        // Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Section")
                                .font(.forma(.subheadline, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            TextField("e.g., A", text: $section)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                    }
                    
                    // Instructor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructor")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        TextField("e.g., Dr. Smith", text: $instructor)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    // Credit Hours
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credit Hours")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Stepper(
                                value: $creditHours,
                                in: 0.5...6.0,
                                step: 0.5
                            ) {
                                Text("\(String(format: creditHours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", creditHours)) credits")
                                    .font(.forma(.subheadline, weight: .medium))
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
                            .font(.forma(.subheadline, weight: .semibold))
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
                            .font(.forma(.subheadline, weight: .semibold))
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
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(existingCourse != nil ? "Update schedule details" : "When does this course meet?")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    // Days of Week
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days of the Week *")
                            .font(.forma(.subheadline, weight: .semibold))
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
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Start Time")
                                        .font(.forma(.caption, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    DatePicker(
                                        "",
                                        selection: $startTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                    .onChange(of: startTime) { _, newValue in
                                        // Auto-adjust end time to be 1 hour later
                                        endTime = newValue.addingTimeInterval(3600)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("End Time")
                                        .font(.forma(.caption, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    DatePicker(
                                        "",
                                        selection: $endTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }
                            }
                            
                            // Duration Display
                            let duration = endTime.timeIntervalSince(startTime)
                            if duration > 0 {
                                HStack {
                                    Text("Duration: \(formatDuration(duration))")
                                        .font(.forma(.subheadline, weight: .medium))
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
                            .font(.forma(.subheadline, weight: .semibold))
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
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(existingCourse != nil ? "Update settings and preferences" : "Configure reminders and notifications")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    // Reminder Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reminders")
                            .font(.forma(.subheadline, weight: .semibold))
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
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Toggle(isOn: $isLiveActivityEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show on Lock Screen")
                                    .font(.forma(.subheadline))
                                
                                Text("Display class progress on your lock screen during class time")
                                    .font(.forma(.caption))
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
                            .font(.forma(.subheadline, weight: .semibold))
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
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.currentTheme.primaryColor, lineWidth: 1.5)
                )
                .disabled(isSaving)
            }
            
            Button(currentStep < totalSteps ? "Next" : (existingCourse != nil ? "Save Changes" : "Create Course")) {
                 ("Button tapped - currentStep: \(currentStep), totalSteps: \(totalSteps)")
                if currentStep < totalSteps {
                     ("Moving to next step")
                    withAnimation(.easeInOut) {
                        currentStep += 1
                    }
                } else {
                     ("Saving course")
                    Task {
                        await saveCourse()
                    }
                }
            }
            .font(.forma(.subheadline, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        (currentStep < totalSteps ? canProceed : canSave) 
                            ? themeManager.currentTheme.primaryColor 
                            : Color(.systemGray3)
                    )
            )
            .disabled(currentStep < totalSteps ? !canProceed : !canSave)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    // MARK: - Helper Methods
    private func saveCourse() async {
        guard !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let activeScheduleId = scheduleManager.activeScheduleID else { return }
        
        isSaving = true
        
        if let existingCourse = existingCourse {
            // Edit existing course
            existingCourse.name = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
            existingCourse.courseCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
            existingCourse.section = section.trimmingCharacters(in: .whitespacesAndNewlines)
            existingCourse.instructor = instructor.trimmingCharacters(in: .whitespacesAndNewlines)
            existingCourse.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
            existingCourse.creditHours = creditHours
            existingCourse.iconName = selectedIconName
            existingCourse.colorHex = selectedColor.toHex() ?? Color.blue.toHex()!
            existingCourse.startTime = startTime
            existingCourse.endTime = endTime
            existingCourse.daysOfWeek = Array(selectedDays)
            existingCourse.reminderTime = reminderTime
            existingCourse.isLiveActivityEnabled = isLiveActivityEnabled
            
            // Update the course through the manager
            courseManager.updateCourse(existingCourse)
        } else {
            // Create new course
            let newCourse = Course(
                scheduleId: activeScheduleId,
                name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
                iconName: selectedIconName,
                colorHex: selectedColor.toHex() ?? Color.blue.toHex()!,
                startTime: startTime,
                endTime: endTime,
                daysOfWeek: Array(selectedDays),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                creditHours: creditHours,
                courseCode: courseCode.trimmingCharacters(in: .whitespacesAndNewlines),
                section: section.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            newCourse.reminderTime = reminderTime
            newCourse.isLiveActivityEnabled = isLiveActivityEnabled
            
            // Use the CourseOperationsManager to properly save the course
            courseManager.addCourse(newCourse)
        }
        
        // Small delay to show the saving state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isSaving = false
        dismiss()
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

#Preview {
    EnhancedAddCourseView(courseManager: UnifiedCourseManager())
        .environmentObject(ThemeManager())
        .environmentObject(ScheduleManager())
}