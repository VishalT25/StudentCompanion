import SwiftUI
import Combine

// MARK: - Main Wizard View (Simplified - Traditional Only)
struct ScheduleCreationWizardView: View {
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var academicCalendarManager: AcademicCalendarManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var currentStep: WizardStep = .name
    @State private var scheduleName = ""
    @State private var semesterStartDate = Date()
    @State private var semesterLength = 16
    @State private var linkedAcademicCalendar: AcademicCalendar?
    @State private var isCreating = false
    @State private var showingAcademicCalendarCreation = false
    @State private var showingAcademicCalendarSelection = false
    @State private var pulseAnimation: Double = 1.0
    
    @State private var academicYear: String = ""
    @State private var preCalendarIDs: Set<UUID> = []
    @State private var showCancelConfirm = false
    @State private var didCreateSchedule = false
    @State private var scheduleType: ScheduleType = .traditional
    @State private var isCalendarStepSkipped = false

    private let totalSteps = 4 // Reduced from 6
    private let maxContentWidth: CGFloat = 360

    private var semesterEndDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: semesterLength, to: semesterStartDate) ?? semesterStartDate
    }
    
    private var currentStepIndex: Int {
        WizardStep.allCases.firstIndex(of: currentStep) ?? 0
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .name:
            let trimmedName = scheduleName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let trimmedYear = academicYear.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return !trimmedName.isEmpty && !trimmedYear.isEmpty
        case .semesterDetails:
            return semesterLength >= 8 && semesterLength <= 24
        case .academicCalendar:
            return true
        case .review:
            return !isCreating
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        progressIndicator
                        stepContent
                    }
                    .frame(maxWidth: maxContentWidth)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    navigationButtons
                }
            }
            .navigationTitle("Create Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showCancelConfirm = true
                    }
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            })

        }
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showingAcademicCalendarCreation, onDismiss: {
            let currentIDs = Set(academicCalendarManager.academicCalendars.map { $0.id })
            let newIDs = currentIDs.subtracting(preCalendarIDs)
            if let newID = newIDs.first,
               let created = academicCalendarManager.calendar(withID: newID) {
                linkedAcademicCalendar = created
            }
        }) {
            CreateAcademicCalendarView()
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAcademicCalendarSelection) {
            AcademicCalendarSelectionStep(
                selectedCalendar: $linkedAcademicCalendar,
                isSkipped: $isCalendarStepSkipped,
                onCreateNew: {
                    preCalendarIDs = Set(academicCalendarManager.academicCalendars.map { $0.id })
                    showingAcademicCalendarSelection = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingAcademicCalendarCreation = true
                    }
                }
            )
            .environmentObject(academicCalendarManager)
            .environmentObject(themeManager)
        }
        .onAppear {
            setupDefaults()
            startAnimations()
        }
        .alert("Discard schedule?", isPresented: $showCancelConfirm) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("If you leave now, your schedule will not be created and your progress will be lost.")
        }
        .onChange(of: isCalendarStepSkipped) { oldValue, newValue in
            if newValue {
                showingAcademicCalendarSelection = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentStep = .review
                }
            }
        }
        .onChange(of: linkedAcademicCalendar?.id) { oldValue, newValue in
            if newValue != nil {
                isCalendarStepSkipped = false
                showingAcademicCalendarSelection = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentStep = .review
                }
            }
        }
        .onChange(of: currentStep) { oldValue, newValue in
            if newValue == .academicCalendar {
                isCalendarStepSkipped = false
            }
        }

    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.02),
                    themeManager.currentTheme.secondaryColor.opacity(0.01),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.currentTheme.tertiaryColor.opacity(0.08 - Double(index) * 0.02),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.8 - Double(index) * 0.2, y: 0.2 + Double(index) * 0.3),
                            startRadius: 0,
                            endRadius: 200 + CGFloat(index * 50)
                        )
                    )
                    .frame(width: 300 + CGFloat(index * 100), height: 300 + CGFloat(index * 100))
                    .scaleEffect(pulseAnimation + Double(index) * 0.1)
                    .offset(
                        x: CGFloat(50 - index * 30),
                        y: CGFloat(-100 + index * 50)
                    )
                    .opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.6 : 0.3)
            }
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.2
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(
                                index <= currentStepIndex
                                    ? LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.primaryColor,
                                            themeManager.currentTheme.secondaryColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color(.systemGray5), Color(.systemGray4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: index == currentStepIndex ? 16 : 12, height: index == currentStepIndex ? 16 : 12)
                            .overlay(
                                Circle()
                                    .stroke(
                                        index <= currentStepIndex
                                            ? Color.white.opacity(0.3)
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .shadow(
                                color: index <= currentStepIndex
                                    ? themeManager.currentTheme.primaryColor.opacity(0.4)
                                    : Color.clear,
                                radius: 6, x: 0, y: 3
                            )
                        
                        if index < currentStepIndex {
                            Image(systemName: "checkmark")
                                .font(.forma(.caption2, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStepIndex)
                    
                    if index < totalSteps - 1 {
                        Rectangle()
                            .fill(
                                index < currentStepIndex
                                    ? themeManager.currentTheme.primaryColor.opacity(0.6)
                                    : Color(.systemGray4)
                            )
                            .frame(width: 24, height: 2)
                            .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
                    }
                }
            }
            
            Text(currentStep.title)
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(.primary)
                .animation(.easeInOut(duration: 0.2), value: currentStep)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
    
    // MARK: - Step Content
    
    private var stepContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                switch currentStep {
                case .name:
                    ScheduleNameStep(
                        scheduleName: $scheduleName,
                        academicYear: $academicYear,
                        scheduleType: $scheduleType
                    )
                    .environmentObject(themeManager)
                case .semesterDetails:
                    SemesterDetailsStep(
                        semesterStartDate: $semesterStartDate,
                        semesterLength: $semesterLength
                    )
                    .environmentObject(themeManager)
                case .academicCalendar:
                    AcademicCalendarSelectionStep(
                        selectedCalendar: $linkedAcademicCalendar,
                        isSkipped: $isCalendarStepSkipped,
                        onCreateNew: {
                            preCalendarIDs = Set(academicCalendarManager.academicCalendars.map { $0.id })
                            showingAcademicCalendarSelection = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingAcademicCalendarCreation = true
                            }
                        }
                    )
                    .environmentObject(academicCalendarManager)
                    .environmentObject(themeManager)
                case .review:
                    VStack(alignment: .leading, spacing: 20) {
                        ThemedSection(title: "Schedule Details") {
                            ThemedInfoRow(icon: "textformat.abc", label: "Name", value: scheduleName)
                            ThemedInfoRow(icon: scheduleType == .rotating ? "repeat" : "calendar", label: "Type", value: (scheduleType == .rotating ? "Day 1 / Day 2" : "Weekly Schedule"))
                            ThemedInfoRow(icon: "calendar", label: "Semester", value: academicYear)
                        }
                        .environmentObject(themeManager)

                        ThemedSection(title: "Semester Timeline") {
                            ThemedInfoRow(icon: "clock", label: "Duration", value: "\(semesterLength) weeks")
                            ThemedInfoRow(icon: "calendar.badge.plus", label: "Start Date", value: semesterStartDate.formatted(date: .abbreviated, time: .omitted))
                            ThemedInfoRow(icon: "calendar.badge.checkmark", label: "End Date", value: semesterEndDate.formatted(date: .abbreviated, time: .omitted))
                        }
                        .environmentObject(themeManager)

                        ThemedSection(title: "Academic Calendar") {
                            if let calendar = linkedAcademicCalendar {
                                ThemedInfoRow(icon: "calendar", label: "Calendar", value: calendar.name)
                                ThemedInfoRow(icon: "graduationcap", label: "Academic Year", value: calendar.academicYear)
                                ThemedInfoRow(icon: "minus.circle", label: "Breaks", value: "\(calendar.breaks.count) configured")
                            } else {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.forma(.body, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("No calendar linked")
                                            .font(.forma(.subheadline, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text("Optional — you can add one later")
                                            .font(.forma(.caption))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    ThemedTag(text: "Optional")
                                        .environmentObject(themeManager)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6).opacity(0.35))
                                )
                            }
                        }
                        .environmentObject(themeManager)
                    }

                }
                Spacer(minLength: 120)
            }
            .frame(maxWidth: maxContentWidth)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Navigation
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStepIndex > 0 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = WizardStep.allCases[currentStepIndex - 1]
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.forma(.body, weight: .semibold))
                        Text("Previous")
                            .font(.forma(.headline, weight: .medium))
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(WizardEnhancedButtonStyle())
            }
            
            Button {
                if currentStep == .review {
                    createSchedule()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = WizardStep.allCases[currentStepIndex + 1]
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(currentStep == .review ? "Create Schedule" : "Continue")
                            .font(.forma(.headline, weight: .medium))
                        
                        if currentStep != .review {
                            Image(systemName: "chevron.right")
                                .font(.forma(.body, weight: .semibold))
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: canProceed && !isCreating ? [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ] : [
                                        Color.gray,
                                        Color.gray.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(
                        color: canProceed && !isCreating
                            ? themeManager.currentTheme.primaryColor.opacity(0.35)
                            : Color.clear,
                        radius: 10, x: 0, y: 5
                    )
                )
            }
            .disabled(!canProceed || isCreating)
            .buttonStyle(WizardEnhancedButtonStyle())
        }
        .frame(maxWidth: maxContentWidth)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Logic
    
    private func setupDefaults() {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        if month >= 8 || month <= 1 {
            semesterStartDate = calendar.date(from: DateComponents(year: month <= 1 ? year : year, month: 8, day: 26)) ?? now
        } else if month >= 2 && month <= 5 {
            semesterStartDate = calendar.date(from: DateComponents(year: year, month: 1, day: 15)) ?? now
        } else {
            semesterStartDate = calendar.date(from: DateComponents(year: year, month: 6, day: 1)) ?? now
        }
        
        academicYear = getCurrentSemesterName()
        scheduleName = ""
    }
    
    private func getCurrentSemesterName() -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        
        if month >= 8 || month <= 1 {
            return "Fall \(year)"
        } else if month >= 2 && month <= 5 {
            return "Spring \(year)"
        } else {
            return "Summer \(year)"
        }
    }
    
    private func createSchedule() {
        guard !isCreating else { return }
        isCreating = true
        didCreateSchedule = true

        let trimmedName = scheduleName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let trimmedYear = academicYear.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        var newSchedule = ScheduleCollection(
            name: trimmedName,
            semester: trimmedYear,
            color: themeManager.currentTheme.primaryColor,
            scheduleType: scheduleType
        )
        newSchedule.semesterStartDate = semesterStartDate
        newSchedule.semesterEndDate = semesterEndDate

        var finalSchedule = newSchedule

        if let calendar = linkedAcademicCalendar {
            finalSchedule.academicCalendarID = calendar.id
        }

        scheduleManager.addSchedule(finalSchedule)
        scheduleManager.setActiveSchedule(finalSchedule.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Wizard Steps Enum (Simplified)

enum WizardStep: String, CaseIterable {
    case name = "name"
    case semesterDetails = "semesterDetails"
    case academicCalendar = "academicCalendar"
    case review = "review"
    
    var title: String {
        switch self {
        case .name: return "Schedule Name"
        case .semesterDetails: return "Semester Details"
        case .academicCalendar: return "Academic Calendar"
        case .review: return "Review & Create"
        }
    }
}

// MARK: - Individual Step Views

struct ScheduleNameStep: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var scheduleName: String
    @Binding var academicYear: String
    @Binding var scheduleType: ScheduleType
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "textformat.abc")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text(scheduleName.isEmpty ? "Name Your Schedule" : scheduleName)
                        .font(.forma(.title, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text("Enter a name first, then the semester")
                        .font(.forma(.body))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Schedule Name")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                TextField("e.g., My Freshman Fall", text: $scheduleName)
                    .font(.forma(.body, weight: .medium))
                    .textInputAutocapitalization(.words)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isTextFieldFocused
                                            ? themeManager.currentTheme.primaryColor
                                            : Color(.systemGray4),
                                        lineWidth: isTextFieldFocused ? 2 : 1
                                    )
                            )
                    )
                    .shadow(
                        color: isTextFieldFocused
                            ? themeManager.currentTheme.primaryColor.opacity(0.1)
                            : Color.clear,
                        radius: 8, x: 0, y: 4
                    )

                Text("Semester")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                TextField("e.g., Fall 2025", text: $academicYear)
                    .font(.forma(.body, weight: .medium))
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Schedule Pattern")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        patternCard(
                            icon: "calendar",
                            title: "Traditional",
                            subtitle: "Weekly (Mon–Fri)",
                            selected: scheduleType == .traditional
                        ) { scheduleType = .traditional }
                        
                        patternCard(
                            icon: "repeat",
                            title: "Rotating",
                            subtitle: "Day 1 / Day 2",
                            selected: scheduleType == .rotating
                        ) { scheduleType = .rotating }
                    }
                }

                if !scheduleName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.forma(.caption))
                            .foregroundColor(.green)
                        Text("Looks good!")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: 340)
        .padding(.horizontal, 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTextFieldFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scheduleName.isEmpty)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func patternCard(icon: String, title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.forma(.title2, weight: .semibold))
                    .foregroundColor(selected ? .white : themeManager.currentTheme.primaryColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(selected ? themeManager.currentTheme.primaryColor.opacity(0.4) : themeManager.currentTheme.primaryColor.opacity(0.12))
                    )
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.forma(.subheadline, weight: .bold))
                        .foregroundColor(selected ? .white : .primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.forma(.caption2))
                        .foregroundColor(selected ? .white.opacity(0.9) : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? .white : Color(.systemGray3))
                    .font(.system(size: 14))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? themeManager.currentTheme.primaryColor : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selected ? themeManager.currentTheme.primaryColor.opacity(0.5) : Color(.systemGray5),
                                lineWidth: selected ? 2 : 1
                            )
                    )
            )
            .shadow(color: selected ? themeManager.currentTheme.primaryColor.opacity(0.15) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(selected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
    }
}

struct SemesterDetailsStep: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var semesterStartDate: Date
    @Binding var semesterLength: Int
    
    private var semesterEndDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: semesterLength, to: semesterStartDate) ?? semesterStartDate
    }
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("Semester Duration")
                        .font(.forma(.title, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Set your semester timeline to enable smart scheduling features")
                        .font(.forma(.body))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Semester Start Date")
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    DatePicker(
                        "Start Date",
                        selection: $semesterStartDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .accentColor(themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        themeManager.currentTheme.primaryColor.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Semester Length")
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(semesterLength) weeks")
                                .font(.forma(.title2, weight: .bold))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                            
                            Text("Typical: 16 weeks")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Stepper(
                            "",
                            value: $semesterLength,
                            in: 8...24,
                            step: 1
                        )
                        .labelsHidden()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        themeManager.currentTheme.primaryColor.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("End Date")
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.forma(.body, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.secondaryColor)
                        
                        Text(semesterEndDate.formatted(date: .complete, time: .omitted))
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        themeManager.currentTheme.secondaryColor.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: semesterLength)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: semesterStartDate)
    }
}

// MARK: - Academic Calendar SelectionStep

struct AcademicCalendarSelectionStep: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var academicCalendarManager: AcademicCalendarManager
    
    @Binding var selectedCalendar: AcademicCalendar?
    @Binding var isSkipped: Bool
    let onCreateNew: () -> Void
    
    @State private var showingAllCalendars = false
    
    private var availableCalendars: [AcademicCalendar] {
        academicCalendarManager.academicCalendars
    }
    
    var body: some View {
        VStack(spacing: 32) {
            headerSection
            
            if availableCalendars.isEmpty {
                emptyStateContent
            } else {
                calendarSelectionContent
            }
            
            Spacer()
        }
        .frame(maxWidth: 340)
        .padding(.horizontal, 0)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor,
                            themeManager.currentTheme.secondaryColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("Academic Calendar")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Link an academic calendar to respect breaks, holidays, and exam periods")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }
    
    private var calendarSelectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Choose Calendar")
                    .font(.forma(.headline, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Create New") {
                    onCreateNew()
                }
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                )
            }
            
            VStack(spacing: 12) {
                let calendarsToShow = showingAllCalendars ? availableCalendars : Array(availableCalendars.prefix(3))
                
                ForEach(calendarsToShow) { calendar in
                    EnhancedCalendarRow(
                        calendar: calendar,
                        isSelected: selectedCalendar?.id == calendar.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCalendar = calendar
                            isSkipped = false
                        }
                    }
                    .environmentObject(themeManager)
                }
                
                if availableCalendars.count > 3 && !showingAllCalendars {
                    Button("+ \(availableCalendars.count - 3) more calendars") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingAllCalendars = true
                        }
                    }
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(.top, 8)
                } else if showingAllCalendars && availableCalendars.count > 3 {
                    Button("Show less") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingAllCalendars = false
                        }
                    }
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: 300)
            
            Button("Skip for now") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedCalendar = nil
                    isSkipped = true
                }
            }
            .font(.forma(.subheadline))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .frame(maxWidth: 300)
    }
    
    private var emptyStateContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("No Academic Calendars")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Create your first academic calendar to get started with smart scheduling features")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button("Create Calendar") {
                    onCreateNew()
                }
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor,
                            themeManager.currentTheme.secondaryColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.3),
                    radius: 12, x: 0, y: 6
                )
                
                Button("Skip for now") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedCalendar = nil
                        isSkipped = true
                    }
                }
                .font(.forma(.subheadline))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct EnhancedCalendarRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let calendar: AcademicCalendar
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 8, height: 8)
                        .opacity(isSelected ? 1.0 : 0.3)
                    
                    Rectangle()
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.2))
                        .frame(width: 2, height: 16)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(calendar.name)
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.forma(.caption2))
                                .foregroundColor(.secondary)
                            
                            Text(calendar.academicYear)
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "minus.circle")
                                .font(.forma(.caption2))
                                .foregroundColor(.secondary)
                            
                            Text("\(calendar.breaks.count) breaks")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? themeManager.currentTheme.primaryColor
                            : Color(.systemGray3)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected
                                    ? themeManager.currentTheme.primaryColor.opacity(0.4)
                                    : Color(.systemGray5),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: isSelected
                    ? themeManager.currentTheme.primaryColor.opacity(0.1)
                    : Color.clear,
                radius: 6, x: 0, y: 3
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

struct ThemedSection<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 6, height: 22)
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 4, x: 0, y: 2)

                Text(title)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
            }

            VStack(spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor.opacity(0.25),
                                        themeManager.currentTheme.secondaryColor.opacity(0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.15), radius: 10, x: 0, y: 6)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
            )
        }
        .animation(.easeInOut(duration: 0.25), value: title)
    }
}

struct ThemedInfoRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.primaryColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.35))
        )
    }
}

struct ThemedTag: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let text: String

    var body: some View {
        Text(text)
            .font(.forma(.caption, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Button Styles

struct WizardEnhancedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ScheduleCreationWizardView()
        .environmentObject(ScheduleManager())
        .environmentObject(ThemeManager())
        .environmentObject(AcademicCalendarManager())
}