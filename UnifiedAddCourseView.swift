import SwiftUI

struct UnifiedAddCourseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    
    // Course details
    @State private var courseName: String = ""
    @State private var selectedIconName: String = "book.closed.fill"
    @State private var selectedColor: Color = .blue
    
    // Schedule details
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var location: String = ""
    @State private var instructor: String = ""
    @State private var reminderTime: ReminderTime = .fifteenMinutes
    @State private var isLiveActivityEnabled: Bool = true
    
    // UI State
    @State private var currentStep = 0
    @State private var showingScheduleStep = false
    
    private let steps = ["Course Info", "Schedule", "Review"]
    private let maxStep = 2
    
    private let sfSymbolNames: [String] = [
        "book.closed.fill", "studentdesk", "laptopcomputer", "function",
        "atom", "testtube.2", "flame.fill", "brain.head.profile",
        "paintbrush.fill", "music.mic", "sportscourt.fill", "globe.americas.fill",
        "hammer.fill", "briefcase.fill", "microscope.fill", "leaf.fill",
        "heart.fill", "star.fill", "camera.fill", "gamecontroller.fill"
    ]
    
    private let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, 
        .indigo, .purple, .pink, .brown
    ]
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: return !selectedDays.isEmpty && startTime < endTime
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
                
                Spacer()
                
                Text("Add Course")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                if currentStep == maxStep {
                    Button("Create") {
                        createCourse()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(canProceed ? themeManager.currentTheme.primaryColor : .secondary)
                    .disabled(!canProceed)
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
        case 0: courseInfoStep
        case 1: scheduleInfoStep
        case 2: reviewStep
        default: courseInfoStep
        }
    }
    
    private var courseInfoStep: some View {
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
                    Text("Course Name")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    TextField("e.g., Introduction to Psychology", text: $courseName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                }
                
                // Icon selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Course Icon")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
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
                
                // Color selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Course Color")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
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
                    
                    ColorPicker("Custom Color", selection: $selectedColor, supportsOpacity: false)
                        .font(.subheadline.weight(.medium))
                        .padding(.top, 8)
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
    
    private var scheduleInfoStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            scheduleStepHeader
            scheduleStepContent
        }
    }
    
    private var scheduleStepHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Class Schedule")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("When does this course meet? This will help you stay organized.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var scheduleStepContent: some View {
        VStack(spacing: 20) {
            timeSelectionSection
            daysSelectionSection
            additionalInfoSection
            reminderSettingsSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var timeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Class Time")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starts")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ends")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
            }
            
            if startTime >= endTime {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("End time must be after start time")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var daysSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Days of Week")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    dayToggleButton(for: day)
                }
            }
            
            if selectedDays.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Select at least one day")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func dayToggleButton(for day: DayOfWeek) -> some View {
        Button(action: {
            if selectedDays.contains(day) {
                selectedDays.remove(day)
            } else {
                selectedDays.insert(day)
            }
        }) {
            VStack(spacing: 4) {
                Text(String(day.short.prefix(1)))
                    .font(.caption.bold())
                
                Text(day.short)
                    .font(.caption2)
            }
            .foregroundColor(selectedDays.contains(day) ? .white : selectedColor)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedDays.contains(day) ? selectedColor : selectedColor.opacity(0.1))
            )
        }
    }
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Info")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                TextField("Location (optional)", text: $location)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                
                TextField("Instructor (optional)", text: $instructor)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
            }
        }
    }
    
    private var reminderSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminders")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                Picker("Reminder Time", selection: $reminderTime) {
                    ForEach(ReminderTime.allCases, id: \.self) { time in
                        Text(time.displayName).tag(time)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle("Live Activities", isOn: $isLiveActivityEnabled)
                    .font(.subheadline.weight(.medium))
            }
        }
    }
    
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            reviewStepHeader
            coursePreviewCard
            creationNoteCard
        }
    }
    
    private var reviewStepHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review & Create")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("Double-check everything looks good before creating your course.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var coursePreviewCard: some View {
        VStack(spacing: 20) {
            coursePreviewHeader
            Divider()
            coursePreviewDetails
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var coursePreviewHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: selectedIconName)
                .font(.system(size: 40))
                .foregroundColor(selectedColor.isDark ? .white : .black)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(courseName.isEmpty ? "Course Name" : courseName)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                if !selectedDays.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(selectedDays).sorted(by: { 
                            $0.rawValue < $1.rawValue 
                        }), id: \.self) { day in
                            Text(String(day.short.prefix(1)))
                                .font(.caption2.bold())
                                .foregroundColor(selectedColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(selectedColor.opacity(0.15))
                                )
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var coursePreviewDetails: some View {
        VStack(spacing: 12) {
            InfoRow(
                icon: "clock.fill",
                label: "Time",
                value: "\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))"
            )
            
            if !location.isEmpty {
                InfoRow(
                    icon: "location.fill",
                    label: "Location",
                    value: location
                )
            }
            
            if !instructor.isEmpty {
                InfoRow(
                    icon: "person.fill",
                    label: "Instructor",
                    value: instructor
                )
            }
            
            InfoRow(
                icon: "bell.fill",
                label: "Reminders",
                value: reminderTime.displayName
            )
        }
    }
    
    private var creationNoteCard: some View {
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
            
            Text("You can edit any of these details later from the course details page.")
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
    
    // MARK: - Helper Methods
    
    private func createCourse() {
        guard let activeScheduleId = scheduleManager.activeScheduleID else {
             ("No active schedule found")
            return
        }
        
        // Create traditional course only
        let newCourse = Course(
            scheduleId: activeScheduleId,
            name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIconName,
            colorHex: selectedColor.toHex() ?? Color.blue.toHex()!,
            startTime: startTime,
            endTime: endTime,
            daysOfWeek: Array(selectedDays),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        newCourse.reminderTime = reminderTime
        newCourse.isLiveActivityEnabled = isLiveActivityEnabled
        
        courseManager.addCourse(newCourse)
        
        if newCourse.hasScheduleInfo {
            let scheduleItem = newCourse.toScheduleItem()
            scheduleManager.addScheduleItem(scheduleItem, to: activeScheduleId)
        }
        
         ("Created traditional course")
        dismiss()
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    UnifiedAddCourseView()
        .environmentObject(ThemeManager())
        .environmentObject(UnifiedCourseManager())
        .environmentObject(ScheduleManager())
}