import SwiftUI

// MARK: - Enhanced Course Creation with Meetings Support
struct EnhancedAddCourseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var courseManager: UnifiedCourseManager // Use the shared course manager
    
    let existingCourse: Course?
    
    // Course details
    @State private var courseName: String = ""
    @State private var courseCode: String = ""
    @State private var section: String = ""
    @State private var instructor: String = ""
    @State private var location: String = ""
    @State private var creditHours: Double = 3.0
    @State private var selectedIconName: String = "book.closed.fill"
    @State private var selectedColor: Color = .blue
    
    // Traditional schedule only (for backward compatibility)
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedDays: Set<DayOfWeek> = []
    
    @State private var day1Enabled = true
    @State private var day2Enabled = false
    @State private var day1Start = Date()
    @State private var day1End = Date().addingTimeInterval(3600)
    @State private var day2Start = Date()
    @State private var day2End = Date().addingTimeInterval(3600)
    
    // Settings
    @State private var reminderTime: ReminderTime = .fifteenMinutes
    @State private var isLiveActivityEnabled = true
    
    // UI state
    @State private var currentStep = 1
    @State private var isSaving = false
    private let totalSteps = 3
    private let maxContentWidth: CGFloat = 520
    
    // Computed properties
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            if isActiveScheduleRotating {
                let d1OK = day1Enabled ? (day1Start < day1End) : false
                let d2OK = day2Enabled ? (day2Start < day2End) : false
                return d1OK || d2OK
            } else {
                return !selectedDays.isEmpty && startTime < endTime
            }
        case 3:
            return true
        default:
            return false
        }
    }
    
    private var canSave: Bool {
        return canProceed && currentStep == totalSteps && !isSaving
    }
    
    // Initialize with existing course if editing
    init(existingCourse: Course? = nil) {
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
            
            // Handle legacy data if available
            if let firstMeeting = course.meetings.first {
                _reminderTime = State(initialValue: firstMeeting.reminderTime)
                _isLiveActivityEnabled = State(initialValue: firstMeeting.isLiveActivityEnabled)
                _startTime = State(initialValue: firstMeeting.startTime)
                _endTime = State(initialValue: firstMeeting.endTime)
                _selectedDays = State(initialValue: Set(firstMeeting.daysOfWeek.compactMap { DayOfWeek(rawValue: $0) }))
            }
            
            // Handle rotating schedule data
            if let meeting1 = course.meetings.first(where: { $0.rotationIndex == 1 }) {
                _day1Enabled = State(initialValue: true)
                _day1Start = State(initialValue: meeting1.startTime)
                _day1End = State(initialValue: meeting1.endTime)
            }
            
            if let meeting2 = course.meetings.first(where: { $0.rotationIndex == 2 }) {
                _day2Enabled = State(initialValue: true)
                _day2Start = State(initialValue: meeting2.startTime)
                _day2End = State(initialValue: meeting2.endTime)
            }
        }
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
                VStack(spacing: 0) {
                    // Progress Bar
                    progressBar
                    
                    // Content
                    TabView(selection: $currentStep) {
                        courseDetailsStep.tag(1)
                        scheduleDetailsStep.tag(2)
                        additionalSettingsStep.tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)
                    
                    // Navigation Buttons
                    navigationButtons
                }
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal, 16)
            }
            .navigationTitle(existingCourse != nil ? "Edit Course" : "Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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
    
    // MARK: - Views
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
    
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
                
                Text("Creating Course...")
                    .font(.subheadline.weight(.semibold))
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
    
    private var courseDetailsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Course Information")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text(existingCourse != nil ? "Edit course information" : "Let's start with the basic course details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    courseInfoFields
                    iconSelection
                    colorSelection
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 120)
            }
        }
    }
    
    private var courseInfoFields: some View {
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
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                TextField("e.g., Room 101, Science Building", text: $location)
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
        }
    }
    
    private var iconSelection: some View {
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
    }
    
    private var colorSelection: some View {
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
    
    private var scheduleDetailsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Schedule Details")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text(isActiveScheduleRotating ? "Configure Day 1 / Day 2 times" : "When does this course meet?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    if isActiveScheduleRotating {
                        rotatingScheduleView
                    } else {
                        traditionalScheduleView
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 120)
            }
        }
    }
    
    private var traditionalScheduleView: some View {
        VStack(spacing: 20) {
            // Days of Week
            VStack(alignment: .leading, spacing: 12) {
                Text("Days of the Week *")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
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
                            
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .onChange(of: startTime) { _, newValue in
                                    if endTime <= newValue {
                                        endTime = newValue.addingTimeInterval(3600)
                                    }
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("End Time")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
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
        }
    }
    
    private var rotatingScheduleView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Days")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                // Day 1
                VStack(spacing: 12) {
                    Toggle(isOn: $day1Enabled) {
                        HStack {
                            Text("Day 1")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Odd dates")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedColor))
                    
                    if day1Enabled {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Start")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $day1Start, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .onChange(of: day1Start) { _, newValue in
                                        if day1End <= newValue {
                                            day1End = newValue.addingTimeInterval(3600)
                                        }
                                    }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("End")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $day1End, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                // Day 2
                VStack(spacing: 12) {
                    Toggle(isOn: $day2Enabled) {
                        HStack {
                            Text("Day 2")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Even dates")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedColor))
                    
                    if day2Enabled {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Start")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $day2Start, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .onChange(of: day2Start) { _, newValue in
                                        if day2End <= newValue {
                                            day2End = newValue.addingTimeInterval(3600)
                                        }
                                    }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("End")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $day2End, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
    
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
                    reminderSettings
                    liveActivityToggle
                    courseSummary
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 120)
            }
        }
    }
    
    private var reminderSettings: some View {
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
    }
    
    private var liveActivityToggle: some View {
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
    }
    
    private var courseSummary: some View {
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
                if !location.isEmpty {
                    SummaryRow(title: "Location", value: location)
                }
                SummaryRow(title: "Credits", value: String(format: "%.1f", creditHours))
                
                if isActiveScheduleRotating {
                    let pattern: String = {
                        switch (day1Enabled, day2Enabled) {
                        case (true, true): return "Day 1 / Day 2"
                        case (true, false): return "Day 1 only"
                        case (false, true): return "Day 2 only"
                        default: return "No days configured"
                        }
                    }()
                    SummaryRow(title: "Pattern", value: pattern)
                    
                    if day1Enabled {
                        SummaryRow(
                            title: "Day 1 Time",
                            value: "\(day1Start.formatted(date: .omitted, time: .shortened)) - \(day1End.formatted(date: .omitted, time: .shortened))"
                        )
                    }
                    if day2Enabled {
                        SummaryRow(
                            title: "Day 2 Time",
                            value: "\(day2Start.formatted(date: .omitted, time: .shortened)) - \(day2End.formatted(date: .omitted, time: .shortened))"
                        )
                    }
                } else {
                    SummaryRow(title: "Days", value: selectedDays.isEmpty ? "No days selected" : selectedDays.sorted { $0.rawValue < $1.rawValue }.map { $0.short }.joined(separator: ", "))
                    SummaryRow(title: "Time", value: "\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedColor.opacity(0.1))
            )
        }
    }
    
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
                .disabled(isSaving)
            }
            
            Button(currentStep < totalSteps ? "Next" : (existingCourse != nil ? "Save Changes" : "Create Course")) {
                if currentStep < totalSteps {
                    withAnimation(.easeInOut) {
                        currentStep += 1
                    }
                } else {
                    Task {
                        await saveCourse()
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
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
    
    // MARK: - Course Saving with New Architecture
    private func saveCourse() async {
        guard !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let activeScheduleId = scheduleManager.activeScheduleID else {
            print("🛑 COURSE CREATION: Missing required data")
            return
        }
        
        print("🔍 COURSE CREATION: Starting course creation/update")
        
        isSaving = true
        
        if let existingCourse = existingCourse {
            await updateExistingCourse(existingCourse)
        } else {
            await createNewCourse(activeScheduleId: activeScheduleId)
        }
        
        isSaving = false
        dismiss()
    }
    
    private func updateExistingCourse(_ course: Course) async {
        // Update course metadata
        course.name = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        course.courseCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        course.section = section.trimmingCharacters(in: .whitespacesAndNewlines)
        course.instructor = instructor.trimmingCharacters(in: .whitespacesAndNewlines)
        course.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        course.creditHours = creditHours
        course.iconName = selectedIconName
        course.colorHex = selectedColor.toHex() ?? Color.blue.toHex()!
        
        // Clear existing meetings and create new ones
        course.meetings.removeAll()
        
        if isActiveScheduleRotating {
            // Create rotation meetings
            if day1Enabled {
                let meeting1 = CourseMeeting(
                    courseId: course.id,
                    scheduleId: course.scheduleId,
                    meetingType: .lecture,
                    isRotating: true,
                    rotationLabel: "Day 1",
                    rotationIndex: 1,
                    startTime: day1Start,
                    endTime: day1End,
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                    reminderTime: reminderTime,
                    isLiveActivityEnabled: isLiveActivityEnabled
                )
                course.addMeeting(meeting1)
            }
            
            if day2Enabled {
                let meeting2 = CourseMeeting(
                    courseId: course.id,
                    scheduleId: course.scheduleId,
                    meetingType: .lecture,
                    isRotating: true,
                    rotationLabel: "Day 2",
                    rotationIndex: 2,
                    startTime: day2Start,
                    endTime: day2End,
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                    reminderTime: reminderTime,
                    isLiveActivityEnabled: isLiveActivityEnabled
                )
                course.addMeeting(meeting2)
            }
        } else {
            // Create traditional meeting
            if !selectedDays.isEmpty && startTime < endTime {
                let meeting = CourseMeeting(
                    courseId: course.id,
                    scheduleId: course.scheduleId,
                    meetingType: .lecture,
                    startTime: startTime,
                    endTime: endTime,
                    daysOfWeek: selectedDays.map { $0.rawValue },
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                    reminderTime: reminderTime,
                    isLiveActivityEnabled: isLiveActivityEnabled
                )
                course.addMeeting(meeting)
            }
        }
        
        // Use the shared course manager
        courseManager.updateCourse(course)
        print("✅ COURSE UPDATE: Successfully updated course '\(course.name)'")
    }
    
    private func createNewCourse(activeScheduleId: UUID) async {
        print("🔍 COURSE CREATION: Creating new course")
        
        // Create course metadata
        let course = Course(
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
        
        // Create meetings
        var meetings: [CourseMeeting] = []
        
        if isActiveScheduleRotating {
            if day1Enabled {
                let meeting1 = CourseMeeting(
                    courseId: course.id,
                    scheduleId: activeScheduleId,
                    meetingType: .lecture,
                    isRotating: true,
                    rotationLabel: "Day 1",
                    rotationIndex: 1,
                    startTime: day1Start,
                    endTime: day1End,
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                    reminderTime: reminderTime,
                    isLiveActivityEnabled: isLiveActivityEnabled
                )
                meetings.append(meeting1)
            }
            
            if day2Enabled {
                let meeting2 = CourseMeeting(
                    courseId: course.id,
                    scheduleId: activeScheduleId,
                    meetingType: .lecture,
                    isRotating: true,
                    rotationLabel: "Day 2",
                    rotationIndex: 2,
                    startTime: day2Start,
                    endTime: day2End,
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                    reminderTime: reminderTime,
                    isLiveActivityEnabled: isLiveActivityEnabled
                )
                meetings.append(meeting2)
            }
        } else {
            if !selectedDays.isEmpty && startTime < endTime {
                let meeting = CourseMeeting(
                    courseId: course.id,
                    scheduleId: activeScheduleId,
                    meetingType: .lecture,
                    startTime: startTime,
                    endTime: endTime,
                    daysOfWeek: selectedDays.map { $0.rawValue },
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                    reminderTime: reminderTime,
                    isLiveActivityEnabled: isLiveActivityEnabled
                )
                meetings.append(meeting)
            }
        }
        
        // Use the shared course manager's createCourseWithMeetings method
        do {
            try await courseManager.createCourseWithMeetings(course, meetings: meetings)
            print("✅ COURSE CREATION: Created course '\(course.name)' with \(meetings.count) meetings")
        } catch {
            print("❌ COURSE CREATION: Failed to create course: \(error)")
            // You might want to show an alert to the user here
        }
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var isActiveScheduleRotating: Bool {
        guard let activeSchedule = scheduleManager.activeSchedule else { return false }
        return activeSchedule.scheduleType == .rotating
    }
}

#Preview {
    EnhancedAddCourseView()
        .environmentObject(ThemeManager())
        .environmentObject(ScheduleManager())
}