import SwiftUI

struct ScheduleSetupWizard: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    
    @State private var currentStep = 0
    @State private var newSchedule = ScheduleCollection(name: "", semester: "", scheduleType: .traditional)
    @State private var showingPreview = false
    
    private let totalSteps = 7
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
                    .padding()
                
                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        BasicInfoStep(schedule: $newSchedule)
                    case 1:
                        ScheduleTypeStep(schedule: $newSchedule)
                    case 2:
                        RotationPatternStep(schedule: $newSchedule)
                    case 3:
                        SemesterDurationStep(schedule: $newSchedule)
                    case 4:
                        AcademicCalendarStep(schedule: $newSchedule)
                    case 5:
                        ClassImportStep(schedule: $newSchedule, scheduleManager: scheduleManager)
                    case 6:
                        ReviewStep(schedule: $newSchedule)
                    default:
                        BasicInfoStep(schedule: $newSchedule)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    if currentStep < totalSteps - 1 {
                        Button("Next") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.primaryColor)
                        .cornerRadius(8)
                        .disabled(!canProceedFromCurrentStep)
                    } else {
                        Button("Create Schedule") {
                            createSchedule()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.primaryColor)
                        .cornerRadius(8)
                        .disabled(!isScheduleValid)
                    }
                }
                .padding()
            }
            .navigationTitle("New Schedule")
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
    
    private var canProceedFromCurrentStep: Bool {
        switch currentStep {
        case 0:
            return !newSchedule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !newSchedule.semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return true // Schedule type is always selected
        case 2:
            // For rotating schedule, ensure rotation pattern is set
            if newSchedule.scheduleType == .rotatingDays {
                return newSchedule.rotationPattern != nil
            }
            return true
        case 3:
            // Semester duration is always valid with defaults
            return true
        case 4:
            // Academic calendar is optional but if set, it should be valid
            return true
        case 5:
            // Class import is optional
            return true
        case 6:
            // Review step - always proceed
            return true
        default:
            return true
        }
    }
    
    private var isScheduleValid: Bool {
        return !newSchedule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !newSchedule.semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createSchedule() {
        var finalSchedule = newSchedule
        finalSchedule.lastModified = Date()
        finalSchedule.color = themeManager.currentTheme.primaryColor
        scheduleManager.addSchedule(finalSchedule)
        scheduleManager.setActiveSchedule(finalSchedule.id)
        dismiss()
    }
}

// MARK: - Step 1: Basic Information
struct BasicInfoStep: View {
    @Binding var schedule: ScheduleCollection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's set up your schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Start by giving your schedule a name and selecting the academic period.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule Name")
                        .font(.headline)
                    
                    TextField("My School Schedule", text: $schedule.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Academic Period")
                        .font(.headline)
                    
                    TextField("Fall 2024", text: $schedule.semester)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Step 2: Schedule Type Selection
struct ScheduleTypeStep: View {
    @Binding var schedule: ScheduleCollection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What type of schedule do you have?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Choose the pattern that best matches your school's schedule system.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach([ScheduleType.traditional, ScheduleType.rotatingDays], id: \.self) { type in
                    ScheduleTypeCard(
                        type: type,
                        isSelected: schedule.scheduleType == type
                    ) {
                        schedule.scheduleType = type
                        
                        // Reset rotation pattern when type changes
                        if type == .traditional {
                            schedule.rotationPattern = nil
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
}

struct ScheduleTypeCard: View {
    let type: ScheduleType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Step 3: Rotation Pattern Setup (for rotating schedules)
struct RotationPatternStep: View {
    @Binding var schedule: ScheduleCollection
    @State private var cycleLength = 2
    @State private var dayLabels: [String] = ["Day 1", "Day 2"]
    @State private var startDate = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configure rotation pattern")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if schedule.scheduleType == .rotatingDays {
                    Text("Set up how your rotating schedule works.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Your traditional schedule doesn't need a rotation pattern.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if schedule.scheduleType == .rotatingDays {
                rotationPatternEditor()
            } else {
                nonRotatingScheduleInfo()
            }
            
            Spacer()
        }
        .onAppear {
            setupDefaultPattern()
        }
    }
    
    @ViewBuilder
    private func rotationPatternEditor() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cycle Length")
                    .font(.headline)
                
                HStack {
                    Text("Number of days in rotation:")
                    
                    Spacer()
                    
                    Stepper(value: $cycleLength, in: 2...10) {
                        Text("\(cycleLength) days")
                            .fontWeight(.medium)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Day Labels")
                    .font(.headline)
                
                ForEach(0..<cycleLength, id: \.self) { index in
                    HStack {
                        Text("Day \(index + 1):")
                        TextField("Label", text: Binding(
                            get: { index < dayLabels.count ? dayLabels[index] : "" },
                            set: { newValue in
                                while dayLabels.count <= index {
                                    dayLabels.append("")
                                }
                                dayLabels[index] = newValue
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Start Date")
                    .font(.headline)
                
                DatePicker("First day of rotation", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
            }
            
            Button("Save Rotation Pattern") {
                updateRotationPattern()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: cycleLength) { _, newValue in
            updateDayLabels(for: newValue)
        }
    }
    
    @ViewBuilder
    private func nonRotatingScheduleInfo() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("No rotation needed!")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Your traditional weekly schedule will repeat Monday through Friday.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func setupDefaultPattern() {
        if schedule.scheduleType == .rotatingDays {
            dayLabels = (1...cycleLength).map { "Day \($0)" }
            updateRotationPattern()
        }
    }
    
    private func updateDayLabels(for length: Int) {
        let oldLength = dayLabels.count
        
        if length > oldLength {
            // Add new labels
            for i in oldLength..<length {
                dayLabels.append("Day \(i + 1)")
            }
        } else if length < oldLength {
            // Remove excess labels
            dayLabels = Array(dayLabels.prefix(length))
        }
        
        updateRotationPattern()
    }
    
    private func updateRotationPattern() {
        guard schedule.scheduleType == .rotatingDays else {
            schedule.rotationPattern = nil
            return
        }
        
        schedule.rotationPattern = RotationPattern(
            type: schedule.scheduleType,
            cycleLength: cycleLength,
            dayLabels: dayLabels,
            startDate: startDate
        )
    }
}

// MARK: - Step 4: Semester Duration
struct SemesterDurationStep: View {
    @Binding var schedule: ScheduleCollection
    @State private var semesterWeeks = 16
    @State private var semesterStartDate = Date()
    @State private var semesterEndDate = Date()
    
    private let commonLengths = [
        (weeks: 14, name: "14 weeks (Quarter)"),
        (weeks: 15, name: "15 weeks (Standard)"),
        (weeks: 16, name: "16 weeks (Standard)"),
        (weeks: 17, name: "17 weeks (Extended)"),
        (weeks: 18, name: "18 weeks (Extended)")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                headerSection
                commonLengthsSection
                customLengthSection
                Spacer(minLength: 20)
            }
        }
        .onAppear {
            setupDefaultDates()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How long is your semester?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This helps us understand your academic timeline.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var commonLengthsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Common Lengths")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                ForEach(commonLengths, id: \.weeks) { length in
                    SemesterLengthCard(
                        weeks: length.weeks,
                        name: length.name,
                        isSelected: semesterWeeks == length.weeks
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            semesterWeeks = length.weeks
                            updateEndDate()
                        }
                    }
                }
            }
        }
    }
    
    private var customLengthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Length")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Weeks:")
                    Spacer()
                    Stepper(value: $semesterWeeks, in: 8...24) {
                        Text("\(semesterWeeks) weeks")
                            .fontWeight(.medium)
                    }
                    .onChange(of: semesterWeeks) { _, _ in
                        updateEndDate()
                    }
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    DatePicker("Semester Start", selection: $semesterStartDate, displayedComponents: .date)
                        .onChange(of: semesterStartDate) { _, _ in
                            updateEndDate()
                        }
                    
                    DatePicker("Semester End", selection: $semesterEndDate, displayedComponents: .date)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private func setupDefaultDates() {
        // Set default semester dates based on current date
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        
        if month >= 8 || month <= 1 {
            // Fall semester
            semesterStartDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 8, day: 26)) ?? now
        } else if month >= 2 && month <= 5 {
            // Spring semester
            semesterStartDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 15)) ?? now
        } else {
            // Summer semester
            semesterStartDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 6, day: 1)) ?? now
        }
        
        updateEndDate()
    }
    
    private func updateEndDate() {
        let calendar = Calendar.current
        semesterEndDate = calendar.date(byAdding: .weekOfYear, value: semesterWeeks, to: semesterStartDate) ?? semesterStartDate
    }
}

struct SemesterLengthCard: View {
    let weeks: Int
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text("Approximately \(weeks * 7) days total")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Step 5: Academic Calendar Setup
struct AcademicCalendarStep: View {
    @Binding var schedule: ScheduleCollection
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @State private var showingBreakEditor = false
    @State private var showingAIImport = false
    @State private var editingBreak: AcademicBreak?
    @State private var setupChoice: CalendarSetupChoice = .none
    @State private var selectedCalendarID: UUID?
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    
    enum CalendarSetupChoice {
        case none, ai, manual, existing
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up your academic calendar")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add important dates like breaks, holidays, and exam periods.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if schedule.academicCalendarID == nil && setupChoice == .none {
                setupChoiceOptions()
            } else if setupChoice == .ai {
                aiImportSection()
            } else if setupChoice == .existing {
                existingCalendarSelector()
            } else if setupChoice == .manual || schedule.academicCalendarID != nil {
                academicCalendarEditor()
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingBreakEditor) {
            if let calendarID = schedule.academicCalendarID,
               let calendar = academicCalendarManager.calendar(withID: calendarID) {
                BreakEditorView(
                    break: $editingBreak,
                    academicCalendar: Binding(
                        get: { calendar },
                        set: { updatedCalendar in
                            academicCalendarManager.updateCalendar(updatedCalendar)
                        }
                    )
                )
            }
        }
        .sheet(isPresented: $showingAIImport) {
            AcademicCalendarImportView()
                .environmentObject(academicCalendarManager)
                .onDisappear {
                    // Check if a new calendar was added and link it to our schedule
                    if let latestCalendar = academicCalendarManager.academicCalendars.last {
                        schedule.academicCalendarID = latestCalendar.id
                        setupChoice = .manual
                    }
                }
        }
    }
    
    @ViewBuilder
    private func setupChoiceOptions() -> some View {
        VStack(spacing: 16) {
            // Use existing calendar option (if any exist)
            if !academicCalendarManager.academicCalendars.isEmpty {
                Button("Use existing calendar") {
                    setupChoice = .existing
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(8)
            }
            
            // AI Import Option
            Button("Import with AI") {
                setupChoice = .ai
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
            
            // Manual Setup Option
            Button("Set up manually") {
                setupChoice = .manual
                createNewCalendar()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
            
            // Skip Option
            Button("Skip for now") {
                // Don't set up any calendar
                setupChoice = .manual
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    @ViewBuilder
    private func existingCalendarSelector() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose an existing calendar")
                .font(.headline)
            
            ForEach(academicCalendarManager.academicCalendars) { calendar in
                Button(action: {
                    schedule.academicCalendarID = calendar.id
                    setupChoice = .manual
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(calendar.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Text(calendar.academicYear)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if schedule.academicCalendarID == calendar.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(schedule.academicCalendarID == calendar.id ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Button("Create new calendar instead") {
                setupChoice = .manual
                createNewCalendar()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
    }
    
    private func createNewCalendar() {
        let startDate = Calendar.current.date(from: DateComponents(year: currentYear, month: 8, day: 15)) ?? Date()
        let endDate = Calendar.current.date(from: DateComponents(year: currentYear + 1, month: 6, day: 15)) ?? Date()
        
        let newCalendar = AcademicCalendar(
            name: "\(schedule.name) Calendar",
            academicYear: "\(currentYear)-\(currentYear + 1)",
            termType: .semester,
            startDate: startDate,
            endDate: endDate
        )
        
        // Add common breaks
        var calendarWithBreaks = newCalendar
        addCommonBreaks(to: &calendarWithBreaks)
        
        academicCalendarManager.addCalendar(calendarWithBreaks)
        schedule.academicCalendarID = calendarWithBreaks.id
    }
    
    private func addCommonBreaks(to calendar: inout AcademicCalendar) {
        // Add common academic breaks
        let year = Calendar.current.component(.year, from: Date())
        
        // Fall Break
        if let fallBreakStart = Calendar.current.date(from: DateComponents(year: year, month: 10, day: 9)),
           let fallBreakEnd = Calendar.current.date(from: DateComponents(year: year, month: 10, day: 12)) {
            calendar.breaks.append(AcademicBreak(
                name: "Fall Break",
                type: .custom,
                startDate: fallBreakStart,
                endDate: fallBreakEnd,
                affectsRotation: true
            ))
        }
        
        // Thanksgiving Break
        if let thanksgivingStart = Calendar.current.date(from: DateComponents(year: year, month: 11, day: 25)),
           let thanksgivingEnd = Calendar.current.date(from: DateComponents(year: year, month: 11, day: 29)) {
            calendar.breaks.append(AcademicBreak(
                name: "Thanksgiving Break",
                type: .holiday,
                startDate: thanksgivingStart,
                endDate: thanksgivingEnd,
                affectsRotation: true
            ))
        }
        
        // Winter Break
        if let winterBreakStart = Calendar.current.date(from: DateComponents(year: year, month: 12, day: 19)),
           let winterBreakEnd = Calendar.current.date(from: DateComponents(year: year + 1, month: 1, day: 15)) {
            calendar.breaks.append(AcademicBreak(
                name: "Winter Break",
                type: .winterBreak,
                startDate: winterBreakStart,
                endDate: winterBreakEnd,
                affectsRotation: true
            ))
        }
        
        // Spring Break
        if let springBreakStart = Calendar.current.date(from: DateComponents(year: year + 1, month: 3, day: 11)),
           let springBreakEnd = Calendar.current.date(from: DateComponents(year: year + 1, month: 3, day: 18)) {
            calendar.breaks.append(AcademicBreak(
                name: "Spring Break",
                type: .springBreak,
                startDate: springBreakStart,
                endDate: springBreakEnd,
                affectsRotation: true
            ))
        }
    }
    
    @ViewBuilder
    private func aiImportSection() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("AI Calendar Import")
                .font(.title3.weight(.semibold))
            
            Text("Take a screenshot of your academic calendar and let AI extract all the important dates.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Start AI Import") {
                showingAIImport = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
            
            Button("Use manual setup instead") {
                setupChoice = .manual
                createNewCalendar()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func academicCalendarEditor() -> some View {
        if let calendarID = schedule.academicCalendarID,
           let calendar = academicCalendarManager.calendar(withID: calendarID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Calendar info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calendar: \(calendar.name)")
                            .font(.headline)
                        Text("Academic Year: \(calendar.academicYear)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Breaks section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Breaks & Holidays")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Add Break") {
                                editingBreak = nil
                                showingBreakEditor = true
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(6)
                        }
                        
                        if !calendar.breaks.isEmpty {
                            ForEach(calendar.breaks) { academicBreak in
                                BreakRow(break: academicBreak) {
                                    editingBreak = academicBreak
                                    showingBreakEditor = true
                                }
                            }
                        } else {
                            Text("No breaks added yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 16) {
                Text("No academic calendar selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Set up calendar") {
                    setupChoice = .none
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
}

struct BreakRow: View {
    let `break`: AcademicBreak
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: `break`.type.icon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(`break`.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(`break`.startDate.formatted(date: .abbreviated, time: .omitted)) - \(`break`.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Edit") {
                onEdit()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Step 6: Class Import
struct ClassImportStep: View {
    @Binding var schedule: ScheduleCollection
    @ObservedObject var scheduleManager: ScheduleManager
    @State private var showingAIImport = false
    @State private var tempScheduleID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Import your classes")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add your classes to your schedule using AI or manual entry.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                Button("Import with AI") {
                    // First create a temporary schedule to import classes into
                    var tempSchedule = schedule
                    tempSchedule.lastModified = Date()
                    scheduleManager.addSchedule(tempSchedule)
                    tempScheduleID = tempSchedule.id
                    showingAIImport = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
                
                Button("Add classes manually") {
                    // For now, we'll just note that manual entry will be available
                    // In a real implementation, this would navigate to a class entry screen
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                Text("You can always add or edit classes later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingAIImport) {
            if let scheduleID = tempScheduleID {
                AIScheduleImportView(scheduleID: scheduleID)
                    .environmentObject(scheduleManager)
            }
        }
    }
}

// MARK: - Step 7: Review
struct ReviewStep: View {
    @Binding var schedule: ScheduleCollection
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review your schedule")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Check that everything looks correct before creating your schedule.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    ReviewRow(title: "Schedule Name", value: schedule.name)
                    ReviewRow(title: "Academic Period", value: schedule.semester)
                    ReviewRow(title: "Schedule Type", value: schedule.scheduleType.displayName)
                    
                    if schedule.scheduleType == .rotatingDays, let pattern = schedule.rotationPattern {
                        ReviewRow(title: "Rotation Pattern", value: "\(pattern.cycleLength)-day cycle")
                        ReviewRow(title: "Day Labels", value: pattern.dayLabels.joined(separator: ", "))
                    }
                    
                    if let calendar = schedule.academicCalendar {
                        ReviewRow(title: "Academic Year", value: calendar.academicYear)
                        ReviewRow(title: "Breaks & Holidays", value: "\(calendar.breaks.count) breaks added")
                    }
                }
                
                if schedule.scheduleType == .rotatingDays, let pattern = schedule.rotationPattern {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sample Rotation Preview")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(pattern.dayLabels.count, 3)), spacing: 8) {
                            ForEach(pattern.dayLabels.indices, id: \.self) { index in
                                Text(pattern.dayLabels[index])
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ReviewRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Break Editor View
struct BreakEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var `break`: AcademicBreak?
    @Binding var academicCalendar: AcademicCalendar
    
    @State private var name = ""
    @State private var type = BreakType.custom
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var affectsRotation = true
    @State private var description = ""
    
    private var isEditing: Bool {
        `break` != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Break Information") {
                    TextField("Break Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(BreakType.allCases, id: \.self) { breakType in
                            Label(breakType.displayName, systemImage: breakType.icon)
                                .tag(breakType)
                        }
                    }
                }
                
                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
                
                Section("Options") {
                    Toggle("Affects Rotation Cycle", isOn: $affectsRotation)
                        .help("Whether this break pauses the rotation cycle")
                }
                
                Section("Description") {
                    TextField("Optional description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Break" : "Add Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBreak()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            loadBreakData()
        }
    }
    
    private func loadBreakData() {
        if let existingBreak = `break` {
            name = existingBreak.name
            type = existingBreak.type
            startDate = existingBreak.startDate
            endDate = existingBreak.endDate
            affectsRotation = existingBreak.affectsRotation
            description = existingBreak.description
        }
    }
    
    private func saveBreak() {
        let newBreak = AcademicBreak(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            startDate: startDate,
            endDate: endDate,
            affectsRotation: affectsRotation
        )
        
        var updatedCalendar = academicCalendar
        
        if let existingBreak = `break` {
            // Update existing break
            if let index = updatedCalendar.breaks.firstIndex(where: { $0.id == existingBreak.id }) {
                updatedCalendar.breaks[index] = newBreak
            }
        } else {
            // Add new break
            updatedCalendar.breaks.append(newBreak)
        }
        
        academicCalendar = updatedCalendar
        dismiss()
    }
}

#Preview {
    ScheduleSetupWizard(scheduleManager: ScheduleManager())
        .environmentObject(ThemeManager())
}