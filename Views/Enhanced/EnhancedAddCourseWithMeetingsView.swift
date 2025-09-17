import SwiftUI

struct EnhancedAddCourseWithMeetingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager // Use shared manager instead of separate one
    
    let existingCourse: Course? // Add support for editing existing courses
    
    // Course details
    @State private var courseName: String = ""
    @State private var courseCode: String = ""
    @State private var section: String = ""
    @State private var creditHours: Double = 3.0
    @State private var selectedIconName: String = "book.closed.fill"
    @State private var selectedColor: Color = .blue
    
    // Meetings
    @State private var meetings: [CourseMeeting] = []
    @State private var showingAddMeeting = false
    @State private var editingMeeting: CourseMeeting?
    
    // UI State
    @State private var currentStep = 0
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    private let steps = ["Course Details", "Meetings", "Review"]
    private let maxStep = 2
    
    private let sfSymbolNames: [String] = [
        "book.closed.fill", "studentdesk", "laptopcomputer", "function",
        "atom", "testtube.2", "flame.fill", "brain.head.profile",
        "paintbrush.fill", "music.mic", "sportscourt.fill", "globe.americas.fill",
        "hammer.fill", "briefcase.fill", "microscope.fill", "leaf.fill"
    ]
    
    private let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, 
        .indigo, .purple, .pink, .brown
    ]
    
    // MARK: - Initializers
    
    init(existingCourse: Course? = nil) {
        self.existingCourse = existingCourse
        
        // Pre-populate fields if editing
        if let course = existingCourse {
            _courseName = State(initialValue: course.name)
            _courseCode = State(initialValue: course.courseCode)
            _section = State(initialValue: course.section)
            _creditHours = State(initialValue: course.creditHours)
            _selectedIconName = State(initialValue: course.iconName)
            _selectedColor = State(initialValue: course.color)
            _meetings = State(initialValue: course.meetings)
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: return !meetings.isEmpty
        case 2: return true
        default: return false
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                progressHeader
                
                ScrollView {
                    VStack(spacing: 32) {
                        currentStepView
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddMeeting) {
                AddMeetingSheetView(
                    courseName: courseName,
                    courseColor: selectedColor,
                    scheduleType: scheduleManager.activeSchedule?.scheduleType ?? .traditional,
                    onSave: { meeting in
                        meetings.append(meeting)
                    }
                )
            }
            .sheet(item: $editingMeeting) { meeting in
                EditMeetingSheetView(
                    meeting: meeting,
                    courseName: courseName,
                    courseColor: selectedColor,
                    onSave: { updatedMeeting in
                        if let index = meetings.firstIndex(where: { $0.id == updatedMeeting.id }) {
                            meetings[index] = updatedMeeting
                        }
                    }
                )
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Progress Header
    
    private var progressHeader: some View {
        VStack(spacing: 20) {
            // Top controls
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.body.weight(.medium))
                .foregroundColor(.secondary)
                .disabled(isCreating)
                
                Spacer()
                
                Text(existingCourse != nil ? "Edit Course" : "Add Course")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                if currentStep == maxStep {
                    Button(existingCourse != nil ? "Save" : "Create") {
                        Task { await createCourse() }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(canProceed && !isCreating ? themeManager.currentTheme.primaryColor : .secondary)
                    .disabled(!canProceed || isCreating)
                } else {
                    Button("Next") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentStep += 1
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(canProceed ? themeManager.currentTheme.primaryColor : .secondary)
                    .disabled(!canProceed)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0...maxStep, id: \.self) { step in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(step <= currentStep ? themeManager.currentTheme.primaryColor : Color(.systemGray4))
                            .frame(width: 8, height: 8)
                        
                        Text(steps[step])
                            .font(.caption.weight(.medium))
                            .foregroundColor(step <= currentStep ? themeManager.currentTheme.primaryColor : .secondary)
                    }
                    
                    if step < maxStep {
                        Rectangle()
                            .fill(step < currentStep ? themeManager.currentTheme.primaryColor : Color(.systemGray4))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            if currentStep > 0 {
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentStep -= 1
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.caption.bold())
                            Text("Back")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Step Views
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0: courseDetailsStep
        case 1: meetingsStep
        case 2: reviewStep
        default: courseDetailsStep
        }
    }
    
    private var courseDetailsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Course Details")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Let's start with the basic information about your course.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 20) {
                // Course name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Course Name *")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    TextField("e.g., Introduction to Psychology", text: $courseName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                }
                
                // Course details
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Course Code")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("e.g., CS 101", text: $courseCode)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Section")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("e.g., A", text: $section)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                // Credit Hours
                VStack(alignment: .leading, spacing: 8) {
                    Text("Credit Hours")
                        .font(.subheadline.weight(.semibold))
                    
                    HStack {
                        Stepper(
                            value: $creditHours,
                            in: 0.5...6.0,
                            step: 0.5
                        ) {
                            Text("\(String(format: creditHours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", creditHours)) credits")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                }
                
                // Icon Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Course Icon")
                        .font(.subheadline.weight(.semibold))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(sfSymbolNames, id: \.self) { symbolName in
                            Button(action: { selectedIconName = symbolName }) {
                                Image(systemName: symbolName)
                                    .font(.title2)
                                    .foregroundColor(selectedIconName == symbolName ? .white : selectedColor)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedIconName == symbolName ? selectedColor : selectedColor.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
                
                // Color Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Course Color")
                        .font(.subheadline.weight(.semibold))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(predefinedColors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    private var meetingsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Course Meetings")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Add when this course meets. You can have different types of meetings like lectures, labs, tutorials, etc.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                // Add Meeting Button
                Button(action: { showingAddMeeting = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        
                        Text("Add Meeting")
                            .font(.headline.weight(.semibold))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedColor)
                    )
                }
                .buttonStyle(.plain)
                
                // Existing Meetings
                if !meetings.isEmpty {
                    LazyVStack(spacing: 12) {
                        ForEach(meetings) { meeting in
                            MeetingRowView(
                                meeting: meeting,
                                courseColor: selectedColor,
                                onEdit: { editingMeeting = meeting },
                                onDelete: { 
                                    meetings.removeAll { $0.id == meeting.id }
                                }
                            )
                        }
                    }
                }
                
                if meetings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No meetings added yet")
                            .font(.headline.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Text("Add at least one meeting to continue")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review & Create")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Review your course details before creating.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 20) {
                // Course Preview
                CoursePreviewCard(
                    courseName: courseName,
                    courseCode: courseCode,
                    section: section,
                    creditHours: creditHours,
                    iconName: selectedIconName,
                    color: selectedColor,
                    meetings: meetings
                )
                
                // Creation Note
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        Text("This course will be added to your active schedule")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    Text("You can edit course details and meetings later from the course details page.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Create Course Action
    
    private func createCourse() async {
        isCreating = true
        errorMessage = nil
        
        if let existingCourse = existingCourse {
            // Update existing course
            await updateExistingCourse(existingCourse)
        } else {
            // Create new course
            await createNewCourse()
        }
        
        isCreating = false
        dismiss()
    }
    
    private func updateExistingCourse(_ course: Course) async {
        print("🔍 COURSE UPDATE: Starting updateExistingCourse")
        print("🔍 COURSE UPDATE: Course ID: \(course.id)")
        print("🔍 COURSE UPDATE: Course name: '\(courseName.trimmingCharacters(in: .whitespacesAndNewlines))'")
        
        // Update course metadata
        course.name = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        course.courseCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        course.section = section.trimmingCharacters(in: .whitespacesAndNewlines)
        course.creditHours = creditHours
        course.iconName = selectedIconName
        course.colorHex = selectedColor.toHex() ?? "007AFF"
        
        // Update meetings
        course.meetings = meetings.map { meeting in
            var updatedMeeting = meeting
            updatedMeeting.courseId = course.id
            updatedMeeting.scheduleId = course.scheduleId
            return updatedMeeting
        }
        
        do {
            courseManager.updateCourse(course)
            print("✅ COURSE UPDATE: Course updated: \(course.name)")
        } catch {
            print("❌ COURSE UPDATE: Failed to update course: \(error)")
            errorMessage = "Failed to update course: \(error.localizedDescription)"
        }
    }
    
    private func createNewCourse() async {
        print("🔍 COURSE CREATION: Starting createNewCourse()")
        
        guard let activeScheduleId = scheduleManager.activeScheduleID else {
            print("❌ COURSE CREATION: No active schedule found")
            errorMessage = "No active schedule found. Please create a schedule first."
            return
        }
        
        print("🔍 COURSE CREATION: Active schedule ID: \(activeScheduleId)")
        print("🔍 COURSE CREATION: Course name: '\(courseName.trimmingCharacters(in: .whitespacesAndNewlines))'")
        print("🔍 COURSE CREATION: Number of meetings: \(meetings.count)")
        
        let course = Course(
            scheduleId: activeScheduleId,
            name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIconName,
            colorHex: selectedColor.toHex() ?? "007AFF",
            creditHours: creditHours,
            courseCode: courseCode.trimmingCharacters(in: .whitespacesAndNewlines),
            section: section.trimmingCharacters(in: .whitespacesAndNewlines),
            instructor: "", // No longer set at course level
            location: ""   // No longer set at course level
        )
        
        // Set course and schedule IDs for meetings
        let meetingsWithIds = meetings.map { meeting in
            var updatedMeeting = meeting
            updatedMeeting.courseId = course.id
            updatedMeeting.scheduleId = activeScheduleId
            print("🔍 COURSE CREATION: Meeting '\(updatedMeeting.displayName)' with courseId: \(updatedMeeting.courseId)")
            return updatedMeeting
        }
        
        do {
            print("🔍 COURSE CREATION: Calling courseManager.createCourseWithMeetings...")
            try await courseManager.createCourseWithMeetings(course, meetings: meetingsWithIds)
            print("✅ COURSE CREATION: Successfully created course with meetings")
        } catch {
            print("❌ COURSE CREATION: Failed with error: \(error)")
            print("❌ COURSE CREATION: Error details: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("❌ COURSE CREATION: URLError code: \(urlError.code)")
                print("❌ COURSE CREATION: URLError description: \(urlError.localizedDescription)")
            }
            errorMessage = "Failed to create course: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct MeetingRowView: View {
    let meeting: CourseMeeting
    let courseColor: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Meeting type icon
            Image(systemName: meeting.meetingType.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(meeting.meetingType.color))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(meeting.timeRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !meeting.daysString.isEmpty {
                    Text(meeting.daysString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(courseColor)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
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

struct CoursePreviewCard: View {
    let courseName: String
    let courseCode: String
    let section: String
    let creditHours: Double
    let iconName: String
    let color: Color
    let meetings: [CourseMeeting]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 16).fill(color))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(courseName)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    if !courseCode.isEmpty {
                        Text("\(courseCode)\(!section.isEmpty ? " - \(section)" : "")")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(String(format: "%.1f", creditHours)) credits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Details
            VStack(spacing: 12) {
                DetailRow(icon: "clock.fill", title: "Meetings", value: "\(meetings.count) meeting\(meetings.count == 1 ? "" : "s")")
                
                if !meetings.isEmpty {
                    DetailRow(icon: "calendar.fill", title: "Weekly Hours", value: String(format: "%.1f hours", meetings.totalWeeklyHours))
                }
                
                if meetings.count > 0 {
                    let meetingTypes = Set(meetings.map { $0.meetingType.displayName })
                    DetailRow(icon: "list.bullet", title: "Types", value: meetingTypes.joined(separator: ", "))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Sheet Views (Placeholder implementations)

struct AddMeetingSheetView: View {
    let courseName: String
    let courseColor: Color
    let scheduleType: ScheduleType
    let onSave: (CourseMeeting) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var meetingType: MeetingType = .lecture
    @State private var meetingLabel: String = ""
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var selectedDays: Set<Int> = []
    @State private var location: String = ""
    @State private var instructor: String = ""
    @State private var reminderTime: ReminderTime = .fifteenMinutes
    @State private var isLiveActivityEnabled = true
    
    // Rotation properties for Day 1/Day 2 schedules
    @State private var rotationLabel: String = ""
    @State private var rotationIndex: Int = 1
    
    // Day 1/Day 2 times for rotating schedules
    @State private var day1StartTime = Date()
    @State private var day1EndTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var day2StartTime = Date()
    @State private var day2EndTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var hasDay1 = true
    @State private var hasDay2 = true
    
    private var isRotatingSchedule: Bool {
        scheduleType == .rotating
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isRotatingSchedule {
                    // Simple Day 1/Day 2 interface for rotating schedules
                    rotatingScheduleForm
                } else {
                    // Complex meeting details for traditional schedules
                    traditionalScheduleForm
                }
            }
            .navigationTitle(isRotatingSchedule ? "Add Class Times" : "Add Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if isRotatingSchedule {
                            saveRotatingMeeting()
                        } else {
                            saveTraditionalMeeting()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        if isRotatingSchedule {
            return (hasDay1 && day1StartTime < day1EndTime) || (hasDay2 && day2StartTime < day2EndTime)
        } else {
            return startTime < endTime && !selectedDays.isEmpty
        }
    }
    
    @ViewBuilder
    private var rotatingScheduleForm: some View {
        Section("Course Information") {
            TextField("Course Title", text: $meetingLabel, prompt: Text("e.g., 'Advanced Section', 'Honors'"))
                .textInputAutocapitalization(.words)
        }
        
        Section("Day 1 Schedule") {
            Toggle("Has Day 1 Classes", isOn: $hasDay1)
            
            if hasDay1 {
                DatePicker("Start Time", selection: $day1StartTime, displayedComponents: .hourAndMinute)
                    .onChange(of: day1StartTime) { _, newValue in
                        if day1EndTime <= newValue {
                            day1EndTime = newValue.addingTimeInterval(3600)
                        }
                    }
                
                DatePicker("End Time", selection: $day1EndTime, displayedComponents: .hourAndMinute)
                
                if day1EndTime > day1StartTime {
                    LabeledContent("Duration") {
                        Text(formatDuration(day1EndTime.timeIntervalSince(day1StartTime)))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        
        Section("Day 2 Schedule") {
            Toggle("Has Day 2 Classes", isOn: $hasDay2)
            
            if hasDay2 {
                DatePicker("Start Time", selection: $day2StartTime, displayedComponents: .hourAndMinute)
                    .onChange(of: day2StartTime) { _, newValue in
                        if day2EndTime <= newValue {
                            day2EndTime = newValue.addingTimeInterval(3600)
                        }
                    }
                
                DatePicker("End Time", selection: $day2EndTime, displayedComponents: .hourAndMinute)
                
                if day2EndTime > day2StartTime {
                    LabeledContent("Duration") {
                        Text(formatDuration(day2EndTime.timeIntervalSince(day2StartTime)))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        
        Section("Location & Instructor") {
            TextField("Location", text: $location, prompt: Text("e.g., Room 101"))
                .textInputAutocapitalization(.words)
            
            TextField("Instructor", text: $instructor, prompt: Text("e.g., Dr. Smith"))
                .textInputAutocapitalization(.words)
        }
        
        Section("Settings") {
            Picker("Reminder", selection: $reminderTime) {
                ForEach(ReminderTime.allCases, id: \.self) { time in
                    Text(time.displayName).tag(time)
                }
            }
            
            Toggle("Live Activities", isOn: $isLiveActivityEnabled)
        }
    }
    
    @ViewBuilder
    private var traditionalScheduleForm: some View {
        Section("Meeting Details") {
            Picker("Meeting Type", selection: $meetingType) {
                ForEach(MeetingType.allCases, id: \.self) { type in
                    Label {
                        VStack(alignment: .leading) {
                            Text(type.displayName)
                                .font(.subheadline.weight(.medium))
                            Text(getMeetingTypeDescription(type))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: type.iconName)
                            .foregroundColor(type.color)
                    }
                    .tag(type)
                }
            }
            
            TextField("Custom Label (optional)", text: $meetingLabel, prompt: Text("e.g., 'Advanced Section', 'Lab A'"))
                .textInputAutocapitalization(.words)
        }
        
        Section("Time") {
            DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                .onChange(of: startTime) { _, newValue in
                    if endTime <= newValue {
                        endTime = newValue.addingTimeInterval(3600)
                    }
                }
            
            DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
            
            if endTime > startTime {
                LabeledContent("Duration") {
                    Text(formatDuration(endTime.timeIntervalSince(startTime)))
                        .foregroundColor(.secondary)
                }
            }
        }
        
        Section("Days of Week") {
            ForEach(1...7, id: \.self) { day in
                let dayName = Calendar.current.weekdaySymbols[day - 1]
                HStack {
                    Text(dayName)
                    Spacer()
                    if selectedDays.contains(day) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(courseColor)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }
            }
        }
        
        if !selectedDays.isEmpty {
            Section {
                Text("Selected days: \(selectedDays.sorted().map { Calendar.current.weekdaySymbols[$0 - 1] }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        Section("Location & Instructor") {
            TextField("Location", text: $location, prompt: Text("e.g., Room 101"))
                .textInputAutocapitalization(.words)
            
            TextField("Instructor", text: $instructor, prompt: Text("e.g., Dr. Smith"))
                .textInputAutocapitalization(.words)
        }
        
        Section("Settings") {
            Picker("Reminder", selection: $reminderTime) {
                ForEach(ReminderTime.allCases, id: \.self) { time in
                    Text(time.displayName).tag(time)
                }
            }
            
            Toggle("Live Activities", isOn: $isLiveActivityEnabled)
        }
    }
    
    private func saveRotatingMeeting() {
        // For rotating schedules, we create separate meetings for Day 1 and Day 2
        if hasDay1 && day1StartTime < day1EndTime {
            let day1Meeting = CourseMeeting(
                courseId: UUID(), // Temporary courseId - will be updated when course is created
                meetingType: meetingType,
                meetingLabel: meetingLabel.isEmpty ? nil : meetingLabel,
                isRotating: true,
                rotationLabel: "Day 1",
                rotationIndex: 1,
                startTime: day1StartTime,
                endTime: day1EndTime,
                daysOfWeek: [], // No specific days for rotation meetings
                location: location,
                instructor: instructor,
                reminderTime: reminderTime,
                isLiveActivityEnabled: isLiveActivityEnabled
            )
            onSave(day1Meeting)
        }
        
        if hasDay2 && day2StartTime < day2EndTime {
            let day2Meeting = CourseMeeting(
                courseId: UUID(), // Temporary courseId - will be updated when course is created
                meetingType: meetingType,
                meetingLabel: meetingLabel.isEmpty ? nil : meetingLabel,
                isRotating: true,
                rotationLabel: "Day 2",
                rotationIndex: 2,
                startTime: day2StartTime,
                endTime: day2EndTime,
                daysOfWeek: [], // No specific days for rotation meetings
                location: location,
                instructor: instructor,
                reminderTime: reminderTime,
                isLiveActivityEnabled: isLiveActivityEnabled
            )
            onSave(day2Meeting)
        }
        
        dismiss()
    }
    
    private func saveTraditionalMeeting() {
        let meeting = CourseMeeting(
            courseId: UUID(), // Temporary courseId - will be updated when course is created
            meetingType: meetingType,
            meetingLabel: meetingLabel.isEmpty ? nil : meetingLabel,
            isRotating: false,
            rotationLabel: nil,
            rotationIndex: nil,
            startTime: startTime,
            endTime: endTime,
            daysOfWeek: Array(selectedDays),
            location: location,
            instructor: instructor,
            reminderTime: reminderTime,
            isLiveActivityEnabled: isLiveActivityEnabled
        )
        
        print("🔍 DEBUG: Creating meeting with days: \(meeting.daysOfWeek)")
        print("🔍 DEBUG: Selected days were: \(selectedDays)")
        
        onSave(meeting)
        dismiss()
    }
    
    private func getMeetingTypeDescription(_ type: MeetingType) -> String {
        switch type {
        case .lecture: return "Traditional classroom lecture"
        case .lab: return "Hands-on laboratory session"
        case .tutorial: return "Small group tutorial"
        case .seminar: return "Discussion-based seminar"
        case .workshop: return "Interactive workshop"
        case .practicum: return "Practical application session"
        case .recitation: return "Review and problem-solving"
        case .studio: return "Creative studio work"
        case .fieldwork: return "Field-based learning"
        case .clinic: return "Clinical practice session"
        case .other: return "Other meeting type"
        }
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

struct EditMeetingSheetView: View {
    let meeting: CourseMeeting
    let courseName: String
    let courseColor: Color
    let onSave: (CourseMeeting) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var meetingType: MeetingType
    @State private var meetingLabel: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedDays: Set<Int>
    @State private var location: String
    @State private var instructor: String
    @State private var reminderTime: ReminderTime
    @State private var isLiveActivityEnabled: Bool
    @State private var rotationLabel: String
    @State private var rotationIndex: Int
    
    init(meeting: CourseMeeting, courseName: String, courseColor: Color, onSave: @escaping (CourseMeeting) -> Void) {
        self.meeting = meeting
        self.courseName = courseName
        self.courseColor = courseColor
        self.onSave = onSave
        
        _meetingType = State(initialValue: meeting.meetingType)
        _meetingLabel = State(initialValue: meeting.meetingLabel ?? "")
        _startTime = State(initialValue: meeting.startTime)
        _endTime = State(initialValue: meeting.endTime)
        _selectedDays = State(initialValue: Set(meeting.daysOfWeek))
        _location = State(initialValue: meeting.location)
        _instructor = State(initialValue: meeting.instructor)
        _reminderTime = State(initialValue: meeting.reminderTime)
        _isLiveActivityEnabled = State(initialValue: meeting.isLiveActivityEnabled)
        _rotationLabel = State(initialValue: meeting.rotationLabel ?? "")
        _rotationIndex = State(initialValue: meeting.rotationIndex ?? 1)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Meeting Details") {
                    Picker("Meeting Type", selection: $meetingType) {
                        ForEach(MeetingType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    
                    TextField("Custom Label (optional)", text: $meetingLabel)
                }
                
                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                if meeting.isRotating {
                    Section("Rotation") {
                        TextField("Rotation Label", text: $rotationLabel)
                        
                        Picker("Rotation Index", selection: $rotationIndex) {
                            ForEach(1...4, id: \.self) { index in
                                Text("Day \(index)").tag(index)
                            }
                        }
                    }
                } else {
                    Section("Days of Week") {
                        ForEach(1...7, id: \.self) { day in
                            let dayName = Calendar.current.weekdaySymbols[day - 1]
                            HStack {
                                Text(dayName)
                                Spacer()
                                if selectedDays.contains(day) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }
                        }
                    }
                }
                
                Section("Location & Instructor") {
                    TextField("Location", text: $location)
                    TextField("Instructor", text: $instructor)
                }
                
                Section("Settings") {
                    Picker("Reminder", selection: $reminderTime) {
                        ForEach(ReminderTime.allCases, id: \.self) { time in
                            Text(time.displayName).tag(time)
                        }
                    }
                    
                    Toggle("Live Activities", isOn: $isLiveActivityEnabled)
                }
            }
            .navigationTitle("Edit Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedMeeting = meeting
                        updatedMeeting.meetingType = meetingType
                        updatedMeeting.meetingLabel = meetingLabel.isEmpty ? nil : meetingLabel
                        updatedMeeting.startTime = startTime
                        updatedMeeting.endTime = endTime
                        updatedMeeting.daysOfWeek = Array(selectedDays)
                        updatedMeeting.location = location
                        updatedMeeting.instructor = instructor
                        updatedMeeting.reminderTime = reminderTime
                        updatedMeeting.isLiveActivityEnabled = isLiveActivityEnabled
                        updatedMeeting.rotationLabel = rotationLabel.isEmpty ? nil : rotationLabel
                        updatedMeeting.rotationIndex = rotationIndex
                        
                        onSave(updatedMeeting)
                        dismiss()
                    }
                    .disabled(startTime >= endTime || (!meeting.isRotating && selectedDays.isEmpty))
                }
            }
        }
    }
}

#Preview {
    EnhancedAddCourseWithMeetingsView()
        .environmentObject(ThemeManager())
        .environmentObject(ScheduleManager())
}