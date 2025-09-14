import SwiftUI

struct ProgressiveEnhancementView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @Environment(\.dismiss) private var dismiss
    
    let scheduleID: UUID
    let onEnhancementCompleted: (() -> Void)?
    
    @State private var currentStep = 0
    @State private var scheduleType: ScheduleType = .traditional
    @State private var semesterLength: Int = 16
    @State private var semesterStartDate = Date()
    @State private var semesterEndDate = Date()
    @State private var academicCalendar: AcademicCalendar?
    @State private var showingAcademicCalendarImport = false
    @State private var isCompleting = false
    @State private var showingAIClassImport = false
    
    private let totalSteps = 5 // Reduced since we removed schedule type step
    
    init(scheduleID: UUID, importedItems: [ScheduleItem], onEnhancementCompleted: (() -> Void)? = nil) {
        self.scheduleID = scheduleID
        // We are removing the direct import from this view
        self.onEnhancementCompleted = onEnhancementCompleted
    }
    
    var body: some View {
        NavigationView {
            mainContent
        }
        .sheet(isPresented: $showingAcademicCalendarImport) {
            AcademicCalendarImportView { imported in
                academicCalendar = imported
                if let idx = scheduleManager.scheduleCollections.firstIndex(where: { $0.id == scheduleID }) {
                    var s = scheduleManager.scheduleCollections[idx]
                    s.academicCalendarID = imported.id
                    s.academicCalendar = nil
                    scheduleManager.updateSchedule(s)
                }
            }
            .environmentObject(academicCalendarManager)
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAIClassImport) {
            AIScheduleImportView(scheduleID: scheduleID) {
                onEnhancementCompleted?()
                dismiss()
            }
            .environmentObject(scheduleManager)
            .environmentObject(themeManager)
        }
        .onAppear {
            setupDefaultValues()
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            progressIndicator
            stepContent
            navigationButtons
        }
        .navigationTitle("Enhance Your Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Skip") {
                    dismiss()
                }
            }
        }
    }
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? themeManager.currentTheme.primaryColor : Color(.systemGray4))
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var stepContent: some View {
        TabView(selection: $currentStep) {
            EnhancementWelcomeStep(importedItemsCount: 0)
                .environmentObject(themeManager)
                .tag(0)
            
            EnhancementSemesterLengthStep(
                semesterLength: $semesterLength,
                semesterStartDate: $semesterStartDate,
                semesterEndDate: $semesterEndDate
            )
            .environmentObject(themeManager)
            .tag(1)
            
            EnhancementAcademicCalendarStep(
                academicCalendar: $academicCalendar,
                showingImport: $showingAcademicCalendarImport
            )
            .environmentObject(themeManager)
            .tag(2)
            
            EnhancementReviewStep(
                scheduleType: scheduleType,
                semesterLength: semesterLength,
                semesterStartDate: semesterStartDate,
                semesterEndDate: semesterEndDate,
                academicCalendar: academicCalendar,
                importedItemsCount: 0
            )
            .environmentObject(themeManager)
            .tag(3)

            EnhancementAddClassesStep(onImportWithAI: {
                showingAIClassImport = true
            })
            .environmentObject(themeManager)
            .tag(4)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            previousButton
            nextButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    @ViewBuilder
    private var previousButton: some View {
        if currentStep > 0 {
            Button("Previous") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep -= 1
                }
            }
            .font(.headline)
            .foregroundColor(themeManager.currentTheme.primaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(themeManager.currentTheme.primaryColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var nextButton: some View {
        Button(currentStep == totalSteps - 2 ? "Finish Setup" : "Next") {
            if currentStep == totalSteps - 2 { // Review step
                completeEnhancement()
                // Move to the final "add classes" step
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep += 1
                }
            } else if currentStep < totalSteps - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep += 1
                }
            }
        }
        .font(.headline.weight(.semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(nextButtonBackground)
        .cornerRadius(12)
        .disabled(!canProceedFromCurrentStep || isCompleting)
        .opacity(currentStep == totalSteps - 1 ? 0 : 1) // Hide on the last step
    }
    
    private var nextButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(canProceedFromCurrentStep ? themeManager.currentTheme.primaryColor : Color.gray)
    }
    
    private var canProceedFromCurrentStep: Bool {
        switch currentStep {
        case 0...3: return !isCompleting
        default: return true
        }
    }
    
    private func setupDefaultValues() {
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
        semesterEndDate = calendar.date(byAdding: .weekOfYear, value: semesterLength, to: semesterStartDate) ?? now
    }
    
    private func completeEnhancement() {
        isCompleting = true
        
        Task {
            await MainActor.run {
                guard let scheduleIndex = scheduleManager.scheduleCollections.firstIndex(where: { $0.id == scheduleID }) else {
                    isCompleting = false
                    return
                }
                
                var schedule = scheduleManager.scheduleCollections[scheduleIndex]
                
                // Apply enhancements
                schedule.scheduleType = scheduleType
                if let cal = academicCalendar {
                    schedule.academicCalendarID = cal.id
                    schedule.academicCalendar = nil
                }
                
                // We are not handling imported items here anymore
                schedule.enhancedScheduleItems = []
                schedule.scheduleItems = []
                
                // Update the schedule
                scheduleManager.updateSchedule(schedule)
                
                isCompleting = false
            }
        }
    }
}

// MARK: - New Final Step for Adding Classes
struct EnhancementAddClassesStep: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let onImportWithAI: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 80))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                Text("Your smart schedule is ready!")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Now, let's add your classes. You can use our AI importer or add them manually from the schedule screen.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: onImportWithAI) {
                    Label("Import Classes with AI", systemImage: "wand.and.stars")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.currentTheme.primaryColor)
                        .cornerRadius(12)
                }
                
                Button("Finish and Add Manually Later") {
                    // Properly dismiss the wizard and return to schedule home
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
}

struct EnhancementSemesterLengthStep: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var semesterLength: Int
    @Binding var semesterStartDate: Date
    @Binding var semesterEndDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Semester duration")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                HStack {
                    Text("Weeks")
                    Spacer()
                    Stepper(value: $semesterLength, in: 8...24) {
                        Text("\(semesterLength) weeks")
                            .fontWeight(.medium)
                    }
                }

                DatePicker("Semester Start", selection: $semesterStartDate, displayedComponents: .date)
                DatePicker("Semester End", selection: $semesterEndDate, displayedComponents: .date)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .onChange(of: semesterStartDate) { _, _ in
            updateEndDate()
        }
        .onChange(of: semesterLength) { _, _ in
            updateEndDate()
        }
    }

    private func updateEndDate() {
        let calendar = Calendar.current
        semesterEndDate = calendar.date(byAdding: .weekOfYear, value: semesterLength, to: semesterStartDate) ?? semesterStartDate
    }
}

struct EnhancementAcademicCalendarStep: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var academicCalendar: AcademicCalendar?
    @Binding var showingImport: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Academic calendar")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                Button {
                    showingImport = true
                } label: {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text(academicCalendar == nil ? "Import with AI" : "Re-import with AI")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.currentTheme.primaryColor)
                    .cornerRadius(12)
                }

                if let calendar = academicCalendar {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Imported: \(calendar.name)")
                            .font(.subheadline).fontWeight(.medium)
                        Text("Year: \(calendar.academicYear)")
                            .font(.caption).foregroundColor(.secondary)
                        Text("Breaks: \(calendar.breaks.count)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                } else {
                    Text("No academic calendar yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct EnhancementReviewStep: View {
    @EnvironmentObject var themeManager: ThemeManager
    let scheduleType: ScheduleType
    let semesterLength: Int
    let semesterStartDate: Date
    let semesterEndDate: Date
    let academicCalendar: AcademicCalendar?
    let importedItemsCount: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review")
                    .font(.title2)
                    .fontWeight(.bold)

                reviewRow(title: "Schedule Type", value: scheduleType.displayName)
                reviewRow(title: "Semester Length", value: "\(semesterLength) weeks")
                reviewRow(title: "Start", value: semesterStartDate.formatted(date: .abbreviated, time: .omitted))
                reviewRow(title: "End", value: semesterEndDate.formatted(date: .abbreviated, time: .omitted))
                reviewRow(title: "Academic Calendar", value: academicCalendar != nil ? "Configured" : "Not set")
                reviewRow(title: "Imported Classes", value: "\(importedItemsCount)")

                if let calendar = academicCalendar {
                    Divider().padding(.vertical, 8)
                    Text("Calendar details")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Year: \(calendar.academicYear)")
                            .font(.subheadline)
                        Text("Breaks: \(calendar.breaks.count)")
                            .font(.subheadline)
                    }
                }
            }
            .padding(20)
        }
    }

    private func reviewRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct EnhancementFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct EnhancementWelcomeStep: View {
    @EnvironmentObject var themeManager: ThemeManager
    let importedItemsCount: Int // This will now be 0
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                Text("Let's create a smart schedule")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Answer a few questions to set up advanced features and make your schedule work for you.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    EnhancementFeatureRow(icon: "calendar", title: "Traditional Schedule", description: "Weekly repeating schedule structure")
                    EnhancementFeatureRow(icon: "calendar.badge.minus", title: "Academic Calendar", description: "Respect breaks, holidays, and exam periods")
                    EnhancementFeatureRow(icon: "clock", title: "Smart Scheduling", description: "Understand your semester timeline")
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}