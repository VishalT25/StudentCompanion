import SwiftUI

struct EnhancedAddCourseWithMeetingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @Environment(\.colorScheme) private var colorScheme
    
    let existingCourse: Course?
    
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
    @State private var progressOffset: CGFloat = 0
    @State private var stepAnimationOffset: CGFloat = 0
    @State private var showContent = false
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    
    private let steps = ["Details", "Meetings", "Review"]
    private let maxStep = 2
    
    private let sfSymbolNames: [String] = [
        "book.closed.fill", "studentdesk", "laptopcomputer", "function",
        "atom", "testtube.2", "flame.fill", "brain.head.profile",
        "paintbrush.fill", "music.mic", "sportscourt.fill", "globe.americas.fill",
        "hammer.fill", "briefcase.fill", "camera.fill", "leaf.fill"
    ]
    
    private let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, 
        .indigo, .purple, .pink, .brown
    ]
    
    private let days = Array(1...7)
    
    init(existingCourse: Course? = nil) {
        self.existingCourse = existingCourse
        
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
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Spectacular animated background matching assignment view
                spectacularBackground
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        // Hero header section
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                        
                        // Progress section with elegant design
                        progressSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                        
                        // Content with smooth transitions
                        contentArea
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
                .refreshable { }
                .disabled(true)
                
                // Floating action button
                floatingActionButton
            }
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingAddMeeting) {
            ModernAddMeetingSheet(
                courseName: courseName,
                courseColor: selectedColor,
                scheduleType: scheduleManager.activeSchedule?.scheduleType ?? .traditional,
                onSave: { meeting in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        meetings.append(meeting)
                    }
                }
            )
        }
        .sheet(item: $editingMeeting) { meeting in
            ModernEditMeetingSheet(
                meeting: meeting,
                courseName: courseName,
                courseColor: selectedColor,
                onSave: { updatedMeeting in
                    if let index = meetings.firstIndex(where: { $0.id == updatedMeeting.id }) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            meetings[index] = updatedMeeting
                        }
                    }
                }
            )
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
                .font(.forma(.body))
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    selectedColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    selectedColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated floating shapes
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                selectedColor.opacity(0.1 - Double(index) * 0.015),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + CGFloat(index * 10)
                        )
                    )
                    .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                    .offset(
                        x: sin(animationOffset * 0.01 + Double(index)) * 50,
                        y: cos(animationOffset * 0.008 + Double(index)) * 30
                    )
                    .opacity(0.3)
                    .blur(radius: CGFloat(index * 2))
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text(existingCourse != nil ? "Edit Course" : "Create Course")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                selectedColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Build your perfect academic schedule with detailed course information and meeting times.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    selectedColor.opacity(0.3),
                                    selectedColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: selectedColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        HStack {
            // Progress circle on far left
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.secondary.opacity(0.2),
                                Color.secondary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: CGFloat(currentStep + 1) / CGFloat(maxStep + 1))
                    .stroke(
                        LinearGradient(
                            colors: [selectedColor, selectedColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: currentStep)
                
                Text("\(currentStep + 1)")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedColor, selectedColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer()
            
            // Step indicators centered in middle with slightly closer spacing
            HStack(spacing: 32) {
                ForEach(0...maxStep, id: \.self) { step in
                    VStack(spacing: 6) {
                        Text(steps[step])
                            .font(.forma(.subheadline, weight: step <= currentStep ? .semibold : .medium))
                            .foregroundColor(step <= currentStep ? selectedColor : .secondary)
                            .scaleEffect(step == currentStep ? 1.05 : 1.0)
                            .fixedSize(horizontal: true, vertical: false)
                            .lineLimit(1)
                        
                        Circle()
                            .fill(step <= currentStep ? selectedColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(step == currentStep ? 1.3 : 1.0)
                            .overlay(
                                Circle()
                                    .stroke(
                                        step <= currentStep ? selectedColor.opacity(0.3) : Color.clear,
                                        lineWidth: step == currentStep ? 2 : 0
                                    )
                                    .scaleEffect(step == currentStep ? 2.0 : 1.0)
                                    .opacity(step == currentStep ? 0.6 : 0)
                            )
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        VStack(spacing: 0) {
            currentStepView
                .opacity(1.0 - stepAnimationOffset)
                .scaleEffect(1.0 - (stepAnimationOffset * 0.05))
                .animation(.easeInOut(duration: 0.3), value: stepAnimationOffset)
        }
        .clipped()
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0: courseDetailsStep
        case 1: meetingsStep
        case 2: reviewStep
        default: courseDetailsStep
        }
    }
    
    // MARK: - Course Details Step
    private var courseDetailsStep: some View {
        VStack(spacing: 24) {
            Text("Course Details")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                coursePreviewSection
                
                courseNameSection
                courseCodeSection
                creditHoursSection
                iconSelectionSection
                colorSelectionSection
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var coursePreviewSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [selectedColor.opacity(0.8), selectedColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(selectedColor.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(
                        color: selectedColor.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                Image(systemName: selectedIconName)
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(1.1)
            }
            .scaleEffect(courseName.isEmpty ? 0.8 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: courseName)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedColor)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedIconName)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(courseName.isEmpty ? "Course Name" : courseName)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(courseName.isEmpty ? .secondary : .primary)
                
                Text(courseCode.isEmpty ? "Course Code" : courseCode)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(String(format: creditHours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", creditHours)) credits")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var courseNameSection: some View {
        StunningFormField(
            title: "Course Name",
            icon: "textformat",
            placeholder: "Introduction to Psychology",
            text: $courseName,
            courseColor: selectedColor,
            themeManager: themeManager,
            isValid: !courseName.isEmpty,
            errorMessage: "Please enter a course name",
            isFocused: false
        )
    }
    
    private var courseCodeSection: some View {
        HStack(spacing: 16) {
            StunningFormField(
                title: "Course Code",
                icon: "number",
                placeholder: "CS 101",
                text: $courseCode,
                courseColor: selectedColor,
                themeManager: themeManager,
                isValid: true,
                errorMessage: "",
                isFocused: false
            )
            
            StunningFormField(
                title: "Section",
                icon: "person.2",
                placeholder: "A",
                text: $section,
                courseColor: selectedColor,
                themeManager: themeManager,
                isValid: true,
                errorMessage: "",
                isFocused: false
            )
        }
    }
    
    private var creditHoursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap")
                    .font(.forma(.subheadline))
                    .foregroundColor(selectedColor)
                
                Text("Credit Hours")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            ModernCreditStepper(
                value: $creditHours,
                range: 0.5...6.0,
                step: 0.5,
                courseColor: selectedColor
            )
        }
    }
    
    private var iconSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.forma(.subheadline))
                    .foregroundColor(selectedColor)
                    .frame(width: 20)
                
                Text("Course Icon")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 8), spacing: 16) {
                ForEach(sfSymbolNames, id: \.self) { symbolName in
                    ModernIconButton(
                        symbolName: symbolName,
                        isSelected: selectedIconName == symbolName,
                        color: selectedColor
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedIconName = symbolName
                        }
                    }
                }
            }
        }
    }
    
    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.forma(.subheadline))
                    .foregroundColor(selectedColor)
                
                Text("Course Color")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(predefinedColors, id: \.self) { color in
                    ModernColorButton(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedColor = color
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Meetings Step
    private var meetingsStep: some View {
        VStack(spacing: 24) {
            Text("Course Meetings")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                Button(action: { showingAddMeeting = true }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(selectedColor.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "plus")
                                .font(.forma(.title3, weight: .bold))
                                .foregroundColor(selectedColor)
                        }

                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Meeting Time")
                                .font(.forma(.headline, weight: .semibold))
                            Text("Lecture, Lab, Tutorial, etc.")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedColor.opacity(0.3), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(SpringButtonStyle())
                
                if !meetings.isEmpty {
                    LazyVStack(spacing: 16) {
                        ForEach(meetings) { meeting in
                            ModernMeetingRow(
                                meeting: meeting,
                                courseColor: selectedColor,
                                onEdit: { editingMeeting = meeting },
                                onDelete: { 
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        meetings.removeAll { $0.id == meeting.id }
                                    }
                                }
                            )
                        }
                    }
                } else {
                    emptyMeetingsState
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var emptyMeetingsState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: "calendar.badge.plus")
                    .font(.forma(.largeTitle))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Text("No meetings yet")
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Add at least one meeting time to continue.\nThis helps organize your schedule perfectly.")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Review Step
    private var reviewStep: some View {
        VStack(spacing: 24) {
            Text("Review & Create")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                ModernCoursePreviewCard(
                    courseName: courseName,
                    courseCode: courseCode,
                    section: section,
                    creditHours: creditHours,
                    iconName: selectedIconName,
                    color: selectedColor,
                    meetings: meetings
                )
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.forma(.title3))
                            .foregroundColor(selectedColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ready to add to your schedule")
                                .font(.forma(.headline, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("This course will be added to your active schedule and synced across all your devices.")
                                .font(.forma(.body))
                                .foregroundColor(.secondary)
                        }

                        
                        Spacer()
                    }
                    
                    Divider()
                        .overlay(selectedColor.opacity(0.3))
                    
                    Text("You can edit course details, add more meetings, or adjust schedules anytime from the course details page.")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                if currentStep > 0 {
                    Button(action: previousStep) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.title3.bold())
                                .foregroundColor(.secondary)
                            Text("Back")
                                .font(.forma(.subheadline, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(.regularMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(
                                    color: .black.opacity(0.1),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                
                Spacer()
                
                Button(action: {
                    if currentStep == maxStep {
                        Task { await createCourse() }
                    } else {
                        if canProceed {
                            nextStep()
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else if currentStep == maxStep {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: canProceed ? "arrow.right" : "exclamationmark.triangle.fill")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !isCreating {
                            Text(currentStep == maxStep 
                                 ? (existingCourse != nil ? "Save Course" : "Create Course")
                                 : (canProceed ? "Next" : "Complete Required Fields"))
                                .font(.forma(.headline, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: (currentStep != maxStep && !canProceed) ? [.secondary.opacity(0.6), .secondary.opacity(0.4)] :
                                               [selectedColor, selectedColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if !isCreating && (currentStep == maxStep || canProceed) {
                                Capsule()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.5)
                                        )
                                    )
                            }
                        }
                        .shadow(
                            color: (currentStep != maxStep && !canProceed) ? .clear : selectedColor.opacity(0.4),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .buttonStyle(BounceButtonStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: canProceed)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helper Methods
    private func startAnimations() {
        withAnimation(.linear(duration: 22.5).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
        
        withAnimation(.easeInOut(duration: 2.25).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.1
        }
    }
    
    // MARK: - Navigation Functions
    private func nextStep() {
        withAnimation(.easeOut(duration: 0.3)) {
            stepAnimationOffset = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep += 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeIn(duration: 0.3)) {
                stepAnimationOffset = 0
            }
        }
    }
    
    private func previousStep() {
        withAnimation(.easeOut(duration: 0.3)) {
            stepAnimationOffset = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep -= 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeIn(duration: 0.3)) {
                stepAnimationOffset = 0
            }
        }
    }
    
    // MARK: - Create Course Action
    private func createCourse() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCreating = true
        }
        
        errorMessage = nil
        
        if let existingCourse = existingCourse {
            await updateExistingCourse(existingCourse)
        } else {
            await createNewCourse()
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCreating = false
        }
        
        dismiss()
    }
    
    private func updateExistingCourse(_ course: Course) async {
        course.name = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        course.courseCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        course.section = section.trimmingCharacters(in: .whitespacesAndNewlines)
        course.creditHours = creditHours
        course.iconName = selectedIconName
        course.colorHex = selectedColor.toHex() ?? "007AFF"
        
        course.meetings = meetings.map { meeting in
            var updatedMeeting = meeting
            updatedMeeting.courseId = course.id
            updatedMeeting.scheduleId = course.scheduleId
            return updatedMeeting
        }
        
        do {
            try await courseManager.updateCourse(course)
        } catch {
            errorMessage = "Failed to update course: \(error.localizedDescription)"
        }
    }
    
    private func createNewCourse() async {
        guard let activeScheduleId = scheduleManager.activeScheduleID else {
            errorMessage = "No active schedule found. Please create a schedule first."
            return
        }
        
        let course = Course(
            scheduleId: activeScheduleId,
            name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIconName,
            colorHex: selectedColor.toHex() ?? "007AFF",
            creditHours: creditHours,
            courseCode: courseCode.trimmingCharacters(in: .whitespacesAndNewlines),
            section: section.trimmingCharacters(in: .whitespacesAndNewlines),
            instructor: "",
            location: ""
        )
        
        let meetingsWithIds = meetings.map { meeting in
            var updatedMeeting = meeting
            updatedMeeting.courseId = course.id
            updatedMeeting.scheduleId = activeScheduleId
            return updatedMeeting
        }
        
        do {
            try await courseManager.createCourseWithMeetings(course, meetings: meetingsWithIds)
        } catch {
            errorMessage = "Failed to create course: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct ModernCreditStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let courseColor: Color
    
    var body: some View {
        HStack {
            Button(action: { 
                if value > range.lowerBound {
                    value -= step
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.forma(.title2))
                    .foregroundColor(value > range.lowerBound ? courseColor : .secondary)
            }
            .disabled(value <= range.lowerBound)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value))
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("credits")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                if value < range.upperBound {
                    value += step
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.forma(.title2))
                    .foregroundColor(value < range.upperBound ? courseColor : .secondary)
            }
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ModernIconButton: View {
    let symbolName: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.forma(.callout))
                .foregroundColor(isSelected ? .white : color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? color : color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(color.opacity(isSelected ? 0.3 : 0.3), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(
                            color: isSelected ? color.opacity(0.3) : .clear,
                            radius: isSelected ? 6 : 0,
                            x: 0,
                            y: isSelected ? 3 : 0
                        )
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(SpringButtonStyle())
    }
}

struct ModernColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .shadow(color: isSelected ? color.opacity(0.4) : color.opacity(0.2), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
        }
        .buttonStyle(SpringButtonStyle())
    }
}

struct ModernMeetingRow: View {
    let meeting: CourseMeeting
    let courseColor: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(meeting.meetingType.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(meeting.meetingType.color.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: meeting.meetingType.iconName)
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(meeting.meetingType.color)
            }
            .scaleEffect(1.1)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(meeting.displayName)
                    .font(.forma(.headline, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Label(meeting.timeRange, systemImage: "clock")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                    
                    if !meeting.daysString.isEmpty {
                        Label(meeting.daysString, systemImage: "calendar")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                    }
                }
                .labelStyle(CompactLabelStyle())
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(courseColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(courseColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(SpringButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(SpringButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ModernCoursePreviewCard: View {
    let courseName: String
    let courseCode: String
    let section: String
    let creditHours: Double
    let iconName: String
    let color: Color
    let meetings: [CourseMeeting]
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 2)
                        )
                    
                    Image(systemName: iconName)
                        .font(.forma(.title, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(courseName)
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if !courseCode.isEmpty {
                        Text("\(courseCode)\(!section.isEmpty ? " - Section \(section)" : "")")
                            .font(.forma(.headline, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(String(format: creditHours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", creditHours)) credit hours")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !meetings.isEmpty {
                VStack(spacing: 12) {
                    Divider()
                        .overlay(color.opacity(0.3))
                    
                    HStack {
                        VStack(spacing: 4) {
                            Text("\(meetings.count)")
                                .font(.forma(.title2, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Meetings")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", meetings.totalWeeklyHours))
                                .font(.forma(.title2, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Hours/Week")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("\(Set(meetings.flatMap { $0.daysOfWeek }).count)")
                                .font(.forma(.title2, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Days")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.2), lineWidth: 2)
                )
        )
        .shadow(color: color.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Modern Sheet Views

struct ModernAddMeetingSheet: View {
    let courseName: String
    let courseColor: Color
    let scheduleType: ScheduleType
    let onSave: (CourseMeeting) -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var meetingType: MeetingType = .lecture
    @State private var meetingLabel: String = ""
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var selectedDays: Set<Int> = []
    @State private var location: String = ""
    @State private var instructor: String = ""
    @State private var reminderTime: ReminderTime = .fifteenMinutes
    @State private var isLiveActivityEnabled = true
    
    @State private var animationOffset: CGFloat = 0
    @State private var showContent = false
    
    private let days = Array(1...7)
    
    private var canSave: Bool {
        return startTime < endTime && !selectedDays.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                spectacularBackground
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                        
                        VStack(spacing: 20) {
                            meetingTypeSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                            
                            timeSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                            
                            daysSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
                            
                            detailsSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.375), value: showContent)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                }
                
                floatingActionButton
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
    }
    
    private var spectacularBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    courseColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    courseColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                courseColor.opacity(0.1 - Double(index) * 0.015),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + CGFloat(index * 10)
                        )
                    )
                    .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                    .offset(
                        x: sin(animationOffset * 0.01 + Double(index)) * 50,
                        y: cos(animationOffset * 0.008 + Double(index)) * 30
                    )
                    .opacity(0.3)
                    .blur(radius: CGFloat(index * 2))
            }
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text("Add Meeting")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                courseColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                HStack(spacing: 8) {
                    Text("for")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                    
                    Text(courseName)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(courseColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(courseColor.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(courseColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                
                Text("Schedule when this course meets with all the important details.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    courseColor.opacity(0.3),
                                    courseColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: courseColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    private var meetingTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Type")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            meetingTypeGrid
            
            customLabelField
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var meetingTypeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(MeetingType.allCases, id: \.self) { type in
                meetingTypeButton(for: type)
            }
        }
    }
    
    private func meetingTypeButton(for type: MeetingType) -> some View {
        Button(action: { meetingType = type }) {
            HStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.forma(.title3))
                    .foregroundColor(meetingType == type ? .white : type.color)
                
                Text(type.displayName)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(meetingType == type ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(meetingTypeButtonBackground(for: type))
        }
        .buttonStyle(SpringButtonStyle())
    }
    
    private func meetingTypeButtonBackground(for type: MeetingType) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(meetingType == type
                  ? AnyShapeStyle(type.color)
                  : AnyShapeStyle(.ultraThinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        meetingType == type ? type.color.opacity(0.3) : Color.secondary.opacity(0.2),
                        lineWidth: meetingType == type ? 2 : 1
                    )
            )
            .shadow(
                color: meetingType == type ? type.color.opacity(0.3) : .clear,
                radius: meetingType == type ? 6 : 0,
                x: 0,
                y: meetingType == type ? 3 : 0
            )
    }
    
    private var customLabelField: some View {
        StunningFormField(
            title: "Custom Label",
            icon: "tag",
            placeholder: "Optional custom name",
            text: $meetingLabel,
            courseColor: courseColor,
            themeManager: themeManager,
            isValid: true,
            errorMessage: "",
            isFocused: false
        )
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("End")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Days of Week")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    DayButton(day: day, courseColor: courseColor, selectedDays: $selectedDays)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Additional Details")
                    .font(.forma(.title2, weight: .bold))
                
                Spacer()
                
                Text("Optional")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            VStack(spacing: 12) {
                StunningFormField(
                    title: "Location",
                    icon: "location",
                    placeholder: "Room 101, Science Building",
                    text: $location,
                    courseColor: courseColor,
                    themeManager: themeManager,
                    isValid: true,
                    errorMessage: "",
                    isFocused: false
                )
                
                StunningFormField(
                    title: "Instructor",
                    icon: "person",
                    placeholder: "Dr. Smith",
                    text: $instructor,
                    courseColor: courseColor,
                    themeManager: themeManager,
                    isValid: true,
                    errorMessage: "",
                    isFocused: false
                )
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: saveMeeting) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Save Meeting")
                            .font(.forma(.headline, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: canSave ? [courseColor, courseColor.opacity(0.8)] :
                                               [.secondary.opacity(0.6), .secondary.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if canSave {
                                Capsule()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.5)
                                        )
                                    )
                            }
                        }
                        .shadow(
                            color: canSave ? courseColor.opacity(0.4) : .clear,
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                    )
                }
                .disabled(!canSave)
                .buttonStyle(BounceButtonStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: canSave)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 32)
        }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 22.5).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private func saveMeeting() {
        let meeting = CourseMeeting(
            courseId: UUID(),
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
        
        onSave(meeting)
        dismiss()
    }
    
    struct DayButton: View {
        let day: Int
        let courseColor: Color
        @Binding var selectedDays: Set<Int>
        
        private var dayName: String {
            let symbols = Calendar.current.weekdaySymbols
            let index = (day + Calendar.current.firstWeekday - 2) % 7
            return String(symbols[index].prefix(3))
        }
        
        private var isSelected: Bool {
            selectedDays.contains(day)
        }
        
        var body: some View {
            Button(action: {
                if isSelected {
                    selectedDays.remove(day)
                } else {
                    selectedDays.insert(day)
                }
            }) {
                Text(dayName)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected
                                  ? AnyShapeStyle(courseColor)
                                  : AnyShapeStyle(.ultraThinMaterial))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isSelected ? courseColor.opacity(0.3) : Color.secondary.opacity(0.2),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: isSelected ? courseColor.opacity(0.3) : .clear,
                                radius: isSelected ? 6 : 0,
                                x: 0,
                                y: isSelected ? 3 : 0
                            )
                    )
            }
            .buttonStyle(SpringButtonStyle())
        }
    }
}

struct ModernEditMeetingSheet: View {
    let meeting: CourseMeeting
    let courseName: String
    let courseColor: Color
    let onSave: (CourseMeeting) -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var meetingType: MeetingType
    @State private var meetingLabel: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedDays: Set<Int>
    @State private var location: String
    @State private var instructor: String
    
    @State private var animationOffset: CGFloat = 0
    @State private var showContent = false
    
    private let days = Array(1...7)
    
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
    }
    
    private var canSave: Bool {
        return startTime < endTime && !selectedDays.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                spectacularBackground
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                        
                        VStack(spacing: 20) {
                            meetingTypeSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                            
                            timeSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                            
                            daysSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
                            
                            detailsSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.375), value: showContent)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                }
                
                floatingActionButton
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
    }
    
    private var spectacularBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    courseColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    courseColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                courseColor.opacity(0.1 - Double(index) * 0.015),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + CGFloat(index * 10)
                        )
                    )
                    .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                    .offset(
                        x: sin(animationOffset * 0.01 + Double(index)) * 50,
                        y: cos(animationOffset * 0.008 + Double(index)) * 30
                    )
                    .opacity(0.3)
                    .blur(radius: CGFloat(index * 2))
            }
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text("Edit Meeting")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                courseColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                HStack(spacing: 8) {
                    Text("for")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                    
                    Text(courseName)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(courseColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(courseColor.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(courseColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                
                Text("Update the meeting details and schedule.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    courseColor.opacity(0.3),
                                    courseColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: courseColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    private var meetingTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Type")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            meetingTypeGrid
            
            customLabelField
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var meetingTypeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(MeetingType.allCases, id: \.self) { type in
                meetingTypeButton(for: type)
            }
        }
    }
    
    private func meetingTypeButton(for type: MeetingType) -> some View {
        Button(action: { meetingType = type }) {
            HStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.forma(.title3))
                    .foregroundColor(meetingType == type ? .white : type.color)
                
                Text(type.displayName)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(meetingType == type ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(meetingTypeButtonBackground(for: type))
        }
        .buttonStyle(SpringButtonStyle())
    }
    
    private func meetingTypeButtonBackground(for type: MeetingType) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(meetingType == type
                  ? AnyShapeStyle(type.color)
                  : AnyShapeStyle(.ultraThinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        meetingType == type ? type.color.opacity(0.3) : Color.secondary.opacity(0.2),
                        lineWidth: meetingType == type ? 2 : 1
                    )
            )
            .shadow(
                color: meetingType == type ? type.color.opacity(0.3) : .clear,
                radius: meetingType == type ? 6 : 0,
                x: 0,
                y: meetingType == type ? 3 : 0
            )
    }
    
    private var customLabelField: some View {
        StunningFormField(
            title: "Custom Label",
            icon: "tag",
            placeholder: "Optional custom name",
            text: $meetingLabel,
            courseColor: courseColor,
            themeManager: themeManager,
            isValid: true,
            errorMessage: "",
            isFocused: false
        )
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("End")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Days of Week")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    DayButton(day: day, courseColor: courseColor, selectedDays: $selectedDays)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Additional Details")
                    .font(.forma(.title2, weight: .bold))
                
                Spacer()
                
                Text("Optional")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            VStack(spacing: 12) {
                StunningFormField(
                    title: "Location",
                    icon: "location",
                    placeholder: "Room 101, Science Building",
                    text: $location,
                    courseColor: courseColor,
                    themeManager: themeManager,
                    isValid: true,
                    errorMessage: "",
                    isFocused: false
                )
                
                StunningFormField(
                    title: "Instructor",
                    icon: "person",
                    placeholder: "Dr. Smith",
                    text: $instructor,
                    courseColor: courseColor,
                    themeManager: themeManager,
                    isValid: true,
                    errorMessage: "",
                    isFocused: false
                )
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: saveChanges) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Save Changes")
                            .font(.forma(.headline, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: canSave ? [courseColor, courseColor.opacity(0.8)] :
                                               [.secondary.opacity(0.6), .secondary.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if canSave {
                                Capsule()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.5)
                                        )
                                    )
                            }
                        }
                        .shadow(
                            color: canSave ? courseColor.opacity(0.4) : .clear,
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                    )
                }
                .disabled(!canSave)
                .buttonStyle(BounceButtonStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: canSave)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 32)
        }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 22.5).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private func saveChanges() {
        var updatedMeeting = meeting
        updatedMeeting.meetingType = meetingType
        updatedMeeting.meetingLabel = meetingLabel.isEmpty ? nil : meetingLabel
        updatedMeeting.startTime = startTime
        updatedMeeting.endTime = endTime
        updatedMeeting.daysOfWeek = Array(selectedDays)
        updatedMeeting.location = location
        updatedMeeting.instructor = instructor
        
        onSave(updatedMeeting)
        dismiss()
    }
    
    struct DayButton: View {
        let day: Int
        let courseColor: Color
        @Binding var selectedDays: Set<Int>
        
        private var dayName: String {
            let symbols = Calendar.current.weekdaySymbols
            let index = (day + Calendar.current.firstWeekday - 2) % 7
            return String(symbols[index].prefix(3))
        }
        
        private var isSelected: Bool {
            selectedDays.contains(day)
        }
        
        var body: some View {
            Button(action: {
                if isSelected {
                    selectedDays.remove(day)
                } else {
                    selectedDays.insert(day)
                }
            }) {
                Text(dayName)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected
                                  ? AnyShapeStyle(courseColor)
                                  : AnyShapeStyle(.ultraThinMaterial))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isSelected ? courseColor.opacity(0.3) : Color.secondary.opacity(0.2),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: isSelected ? courseColor.opacity(0.3) : .clear,
                                radius: isSelected ? 6 : 0,
                                x: 0,
                                y: isSelected ? 3 : 0
                            )
                    )
            }
            .buttonStyle(SpringButtonStyle())
        }
    }
}

// MARK: - Button Styles & Extensions

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

//struct BounceButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
//            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
//    }
//}

#Preview {
    EnhancedAddCourseWithMeetingsView()
        .environmentObject(ThemeManager())
        .environmentObject(ScheduleManager())
        .environmentObject(UnifiedCourseManager())
}