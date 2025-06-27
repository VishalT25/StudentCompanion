import SwiftUI

struct NaturalLanguageInputView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventViewModel: EventViewModel

    @State private var inputText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    private let nlpEngine = NLPEngine()
    @State private var existingCourses: [Course] = []
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var selectedSuggestionIndex = 0
    
    @State private var isInFollowUpMode = false
    @State private var followUpContext: ParseContext? = nil
    @State private var conversationHistory: [String] = []
    
    private let suggestions = [
        "Lunch on Friday at 12:30",
        "Math class every Monday 9am to 10am",
        "Got 95% on CS101 midterm",
        "Team meeting tomorrow at 2pm",
        "Study session every Tuesday 6pm for 2 hours",
        "Received B+ on History essay"
    ]
    
    private let quickActions = [
        ("📅", "Event", "Add a one-time event"),
        ("🗓️", "Schedule", "Add recurring schedule"),
        ("📊", "Grade", "Record a grade")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.1),
                        Color.white,
                        themeManager.currentTheme.secondaryColor.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header section with icon and description
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: isInFollowUpMode ? "bubble.left.and.bubble.right" : "brain.head.profile")
                                    .font(.system(size: 40))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .animation(.easeInOut, value: isInFollowUpMode)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isInFollowUpMode ? "Follow-up Question" : "Smart Input")
                                        .font(.title2.bold())
                                        .foregroundColor(.primary)
                                        .animation(.easeInOut, value: isInFollowUpMode)
                                    
                                    Text(isInFollowUpMode ? "Please provide the additional information" : "Tell me what you want to add")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .animation(.easeInOut, value: isInFollowUpMode)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        }
                        
                        if isInFollowUpMode && !conversationHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.orange)
                                        .font(.headline)
                                    
                                    Text("Conversation")
                                        .font(.headline.weight(.medium))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 20)
                                
                                VStack(spacing: 8) {
                                    ForEach(Array(conversationHistory.enumerated()), id: \.offset) { index, message in
                                        HStack {
                                            Text(message)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                                                )
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Main input section
                        VStack(spacing: 20) {
                            // Text input with beautiful styling
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "pencil.line")
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                        .font(.headline)
                                    
                                    Text("What would you like to add?")
                                        .font(.headline.weight(.medium))
                                        .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    TextField("", text: $inputText, prompt: Text(isInFollowUpMode ? "Enter your response..." : suggestions[selectedSuggestionIndex]).foregroundColor(.secondary))
                                        .focused($isTextFieldFocused)
                                        .font(.body)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(UIColor.secondarySystemBackground))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(
                                                            isTextFieldFocused ?
                                                            themeManager.currentTheme.primaryColor :
                                                            Color.gray.opacity(0.3),
                                                            lineWidth: isTextFieldFocused ? 2 : 1
                                                        )
                                                )
                                        )
                                        .submitLabel(.done)
                                        .onSubmit {
                                            processInput()
                                        }
                                    
                                    if !inputText.isEmpty {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                inputText = ""
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                                .font(.title3)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if isInFollowUpMode {
                                Button {
                                    withAnimation(.easeInOut) {
                                        resetConversation()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Start Over")
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                                    )
                                }
                                .transition(.opacity.combined(with: .scale))
                            }
                            
                            // Quick action buttons (only show when not in follow-up mode)
                            if !isInFollowUpMode {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(themeManager.currentTheme.secondaryColor)
                                            .font(.headline)
                                        
                                        Text("Quick Actions")
                                            .font(.headline.weight(.medium))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                        ForEach(Array(quickActions.enumerated()), id: \.offset) { index, action in
                                            QuickActionButton(
                                                emoji: action.0,
                                                title: action.1,
                                                subtitle: action.2,
                                                color: index == 0 ? themeManager.currentTheme.primaryColor :
                                                       index == 1 ? themeManager.currentTheme.secondaryColor :
                                                       themeManager.currentTheme.tertiaryColor
                                            ) {
                                                fillQuickAction(for: index)
                                            }
                                            .scaleEffect(inputText.isEmpty ? 1.0 : 0.95)
                                            .opacity(inputText.isEmpty ? 1.0 : 0.7)
                                            .animation(.spring(response: 0.3), value: inputText.isEmpty)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            
                            // Example suggestions (only show when not in follow-up mode and input is empty)
                            if inputText.isEmpty && !isInFollowUpMode {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.orange)
                                            .font(.headline)
                                        
                                        Text("Try these examples")
                                            .font(.headline.weight(.medium))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    VStack(spacing: 8) {
                                        ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                                            Button {
                                                withAnimation(.easeInOut) {
                                                    inputText = suggestion
                                                    isTextFieldFocused = true
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: getIconForSuggestion(suggestion))
                                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                                        .frame(width: 20)
                                                    
                                                    Text(suggestion)
                                                        .font(.subheadline)
                                                        .foregroundColor(.primary)
                                                        .multilineTextAlignment(.leading)
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "arrow.up.left")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color(UIColor.tertiarySystemBackground))
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle(isInFollowUpMode ? "Follow-up" : "Add Something New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isInFollowUpMode ? "Continue" : "Add") {
                        processInput()
                    }
                    .foregroundColor(inputText.isEmpty ? .gray : themeManager.currentTheme.primaryColor)
                    .disabled(inputText.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    // Check if this is a grade success alert and dismiss the view
                    if alertTitle == "Grade Added" {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                isTextFieldFocused = true
                loadCourses()
                if !isInFollowUpMode {
                    startSuggestionRotation()
                }
            }
        }
    }
    
    private func resetConversation() {
        isInFollowUpMode = false
        followUpContext = nil
        conversationHistory.removeAll()
        inputText = ""
        isTextFieldFocused = true
    }
    
    private func startSuggestionRotation() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            if !isInFollowUpMode {
                withAnimation(.easeInOut(duration: 0.5)) {
                    selectedSuggestionIndex = (selectedSuggestionIndex + 1) % suggestions.count
                }
            }
        }
    }
    
    private func getIconForSuggestion(_ suggestion: String) -> String {
        if suggestion.contains("class") || suggestion.contains("every") {
            return "calendar.badge.clock"
        } else if suggestion.contains("%") || suggestion.contains("grade") || suggestion.contains("got") {
            return "chart.bar.fill"
        } else {
            return "calendar.badge.plus"
        }
    }
    
    private func fillQuickAction(for index: Int) {
        withAnimation(.spring()) {
            switch index {
            case 0: // Event
                inputText = "Meeting tomorrow at 2pm"
            case 1: // Schedule
                inputText = "Study session every Tuesday 6pm for 2 hours"
            case 2: // Grade
                inputText = "Got 95% on CS101 midterm"
            default:
                break
            }
            isTextFieldFocused = true
        }
    }

    private func loadCourses() {
        self.existingCourses = CourseStorage.load()
        print("🔍 NLP Debug - Loaded \(existingCourses.count) courses from CourseStorage")
        for course in existingCourses {
            print("🔍 NLP Debug - Course: '\(course.name)' with \(course.assignments.count) assignments")
        }
    }

    private func processInput() {
        let result: NLPResult
        
        if isInFollowUpMode, let context = followUpContext {
            result = nlpEngine.parseFollowUp(inputText: inputText, context: context, conversationId: nil, availableCategories: eventViewModel.categories, existingCourses: existingCourses)
        } else {
            result = nlpEngine.parse(inputText: inputText,
                                     availableCategories: eventViewModel.categories,
                                     existingCourses: existingCourses)
        }
        
        switch result {
        case .parsedEvent(let title, let date, let categoryName, let reminderTime):
            handleAddEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminderTime)
        case .parsedScheduleItem(let title, let days, let startTimeComponents, let endTimeComponents, let duration, let reminderTime, let colorHex):
            handleAddScheduleItem(title: title, days: days, startTimeComponents: startTimeComponents, endTimeComponents: endTimeComponents, duration: duration, reminderTime: reminderTime, colorHex: colorHex)
        case .parsedGrade(let courseName, let assignmentName, let grade, let weight):
            handleAddGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
        case .needsMoreInfo(let prompt, _, let context, let conversationId):
            handleFollowUpQuestion(prompt: prompt, context: context, conversationId: conversationId)
        case .unrecognized(_):
            showSimpleAlert(title: "Input Not Understood", message: "Sorry, I couldn't understand that. Please try rephrasing. Examples:\n'Meeting tomorrow at 2pm about project'\n'Math class every Monday 9am'\n'Got 95% on CS101 midterm'")
        case .notAttempted:
            dismiss()
        }
    }
    
    private func handleFollowUpQuestion(prompt: String, context: ParseContext?, conversationId: UUID?) {
        withAnimation(.easeInOut) {
            conversationHistory.append("You: \(inputText)")
            conversationHistory.append("Assistant: \(prompt)")
            isInFollowUpMode = true
            followUpContext = context
            inputText = ""
            isTextFieldFocused = true
        }
    }

    private func showSimpleAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }

    private func handleAddEvent(title: String, date: Date?, categoryName: String?, reminderTime: ReminderTime?) {
        guard !title.isEmpty else {
            showSimpleAlert(title: "Event Error", message: "Event title cannot be empty.")
            return
        }

        let eventDate = date ?? Date()

        var finalCategoryId: UUID? = nil
        
        // FIXED: Only auto-assign category if one was explicitly provided by NLP engine
        if let catName = categoryName, let foundCategory = eventViewModel.categories.first(where: { $0.name.lowercased() == catName.lowercased() }) {
            finalCategoryId = foundCategory.id
        } else if categoryName != nil {
            // If NLP engine provided a category name but we can't find it, show error
            showSimpleAlert(title: "Category Not Found", message: "The category '\(categoryName!)' was not found. Please add this category first or choose from existing categories.")
            return
        }
        // FIXED: Don't auto-assign first category - this should have been handled by NLP engine asking for category

        guard let categoryId = finalCategoryId else {
            showSimpleAlert(title: "Event Error", message: "No category was specified. The NLP engine should have asked for this information.")
            return
        }

        let newEvent = Event(date: eventDate, title: title, categoryId: categoryId, reminderTime: reminderTime ?? .none)
        Task {
            await eventViewModel.addEvent(newEvent)
            dismiss()
        }
    }

    private func handleAddScheduleItem(title: String, days: Set<DayOfWeek>, startTimeComponents: DateComponents?, endTimeComponents: DateComponents?, duration: TimeInterval?, reminderTime: ReminderTime?, colorHex: String?) {
        guard !title.isEmpty else {
            showSimpleAlert(title: "Schedule Item Error", message: "Please provide a title for the schedule item (e.g., 'Math class').")
            return
        }

        guard !days.isEmpty else {
            showSimpleAlert(title: "Schedule Item Error", message: "Please specify the days for '\(title)' (e.g., 'every Monday', 'MWF').")
            return
        }

        guard let startComps = startTimeComponents, let startHour = startComps.hour, let startMinute = startComps.minute else {
            showSimpleAlert(title: "Schedule Item Error", message: "Please specify a start time for '\(title)' (e.g., 'at 9am', 'from 10:30').")
            return
        }

        var finalEndTimeComponents: DateComponents? = endTimeComponents
        if finalEndTimeComponents == nil, let dur = duration, dur > 0 {
            let calendar = Calendar.current
            var startDateForCalc = Date()
            startDateForCalc = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: startDateForCalc) ?? startDateForCalc
            if let endDateFromDuration = calendar.date(byAdding: .second, value: Int(dur), to: startDateForCalc) {
                finalEndTimeComponents = calendar.dateComponents([.hour, .minute], from: endDateFromDuration)
            }
        }

        guard let endComps = finalEndTimeComponents, let endHour = endComps.hour, let endMinute = endComps.minute else {
            showSimpleAlert(title: "Schedule Item Error", message: "Please specify an end time or duration for '\(title)' (e.g., 'to 11am', 'for 1 hour').")
            return
        }
        
        let startTotalMinutes = startHour * 60 + startMinute
        let endTotalMinutes = endHour * 60 + endMinute
        
        if endTotalMinutes <= startTotalMinutes {
            showSimpleAlert(title: "Schedule Item Error", message: "The end time for '\(title)' must be after the start time.")
            return
        }

        let calendar = Calendar.current
        let startTimeDate = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: Date()) ?? Date()
        let endTimeDate = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: Date()) ?? Date()
        
        // Use provided color or default to theme color
        let itemColor: Color
        if let hexColor = colorHex {
            itemColor = Color(hex: hexColor) ?? themeManager.currentTheme.secondaryColor
        } else {
            itemColor = themeManager.currentTheme.secondaryColor
        }

        let newScheduleItem = ScheduleItem(
            title: title,
            startTime: startTimeDate,
            endTime: endTimeDate,
            daysOfWeek: days,
            color: itemColor,
            reminderTime: reminderTime ?? .none,
            isLiveActivityEnabled: true
        )

        eventViewModel.addScheduleItem(newScheduleItem, themeManager: themeManager)
        dismiss()
    }

    private func handleAddGrade(courseName: String, assignmentName: String, grade: String, weight: String?) {
        print("🔍 =================================")
        print("🔍 SAVE Debug - Course: '\(courseName)'")
        print("🔍 SAVE Debug - Assignment: '\(assignmentName)'")
        print("🔍 SAVE Debug - Grade: '\(grade)'")
        print("🔍 SAVE Debug - Weight: '\(weight ?? "nil")'")
        print("🔍 =================================")
        
        guard let courseIndex = existingCourses.firstIndex(where: { $0.name.lowercased() == courseName.lowercased() }) else {
            showSimpleAlert(title: "Grade Error", message: "Course '\(courseName)' not found.")
            return
        }
        
        var courseToUpdate = existingCourses[courseIndex]
        let normalizedGrade = normalizeGradeForStorage(grade)
        let normalizedWeight = weight != nil ? normalizeWeightForStorage(weight!) : ""
        
        print("🔍 SAVE Debug - Normalized grade: '\(normalizedGrade)'")
        print("🔍 SAVE Debug - Normalized weight: '\(normalizedWeight)'")

        let existingAssignment = courseToUpdate.assignments.first(where: { $0.name.lowercased() == assignmentName.lowercased() })
        
        var finalAssignmentName = assignmentName
        if existingAssignment != nil {
            // Find a unique name by adding a number
            var counter = 2
            while courseToUpdate.assignments.contains(where: { $0.name.lowercased() == "\(assignmentName) \(counter)".lowercased() }) {
                counter += 1
            }
            finalAssignmentName = "\(assignmentName) \(counter)"
            print("🔍 SAVE Debug - Duplicate name detected, using: '\(finalAssignmentName)'")
        }
        
        print("🔍 SAVE Debug - Creating new assignment")
        let newAssignment = Assignment(name: finalAssignmentName, grade: normalizedGrade, weight: normalizedWeight)
        print("🔍 SAVE Debug - New assignment created: name='\(newAssignment.name)', grade='\(newAssignment.grade)', weight='\(newAssignment.weight)'")
        courseToUpdate.assignments.append(newAssignment)
        
        var totalWeight = 0.0
        for assignment in courseToUpdate.assignments {
            if let weight = assignment.weightValue, weight > 0 {
                totalWeight += weight
            }
        }
        
        existingCourses[courseIndex] = courseToUpdate
        
        print("🔍 SAVE Debug - About to save using CourseStorage...")
        CourseStorage.save(existingCourses)
        print("🔍 SAVE Debug - Successfully saved using CourseStorage")
        
        let displayGrade = grade.hasSuffix("%") ? grade : "\(grade)%"
        var successMessage = "Added \(displayGrade) for \(finalAssignmentName) in \(courseName)"
        
        // Add duplicate name notification
        if existingAssignment != nil {
            successMessage += "\n\n📝 Note: '\(assignmentName)' already exists, so this was saved as '\(finalAssignmentName)'"
        }
        
        if totalWeight > 100.0 {
            let excess = totalWeight - 100.0
            successMessage += "\n\n⚠️ Warning: Assignment weights now exceed 100% by \(String(format: "%.1f", excess))%. You may want to adjust the weights."
        }
        
        showSimpleAlert(title: "Grade Added", message: successMessage)
        
    }
    
    private func normalizeGradeForStorage(_ grade: String) -> String {
        var normalized = grade.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 NORMALIZE Grade - Input: '\(grade)' -> After trim: '\(normalized)'")
        
        // For percentage grades, remove the % sign for storage so calculations work
        if normalized.hasSuffix("%") {
            normalized = String(normalized.dropLast())
            print("🔍 NORMALIZE Grade - Removed % sign: '\(normalized)'")
        }
        
        print("🔍 NORMALIZE Grade - Final result: '\(normalized)'")
        return normalized
    }
    
    private func normalizeWeightForStorage(_ weight: String) -> String {
        var normalized = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 NORMALIZE Weight - Input: '\(weight)' -> After trim: '\(normalized)'")
        
        // Remove % sign from weight for storage
        if normalized.hasSuffix("%") {
            normalized = String(normalized.dropLast())
            print("🔍 NORMALIZE Weight - Removed % sign: '\(normalized)'")
        }
        
        print("🔍 NORMALIZE Weight - Final result: '\(normalized)'")
        return normalized
    }

    func processUserInput(_ text: String) {
        let result = nlpEngine.parse(inputText: text,
                                    availableCategories: eventViewModel.categories,
                                    existingCourses: existingCourses)
        
        switch result {
        case .parsedGrade(let courseName, let assignmentName, let grade, let weight):
            handleAddGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
        case .parsedEvent(let title, let date, let categoryName, let reminderTime):
            handleAddEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminderTime)
        case .parsedScheduleItem(let title, let days, let startTimeComponents, let endTimeComponents, let duration, let reminderTime, let colorHex):
            handleAddScheduleItem(title: title, days: days, startTimeComponents: startTimeComponents, endTimeComponents: endTimeComponents, duration: duration, reminderTime: reminderTime, colorHex: colorHex)
        case .needsMoreInfo(let prompt, _, let context, let conversationId):
            handleFollowUpQuestion(prompt: prompt, context: context, conversationId: conversationId)
        case .unrecognized(_):
            showSimpleAlert(title: "Input Not Understood", message: "Sorry, I couldn't understand that. Please try rephrasing. Examples:\n'Meeting tomorrow at 2pm about project'\n'Math class every Monday 9am'\n'Got 95% on CS101 midterm'")
        case .notAttempted:
            handleGenericResult(result)
        }
    }

    private func handleGradeUpdate(_ courseName: String, _ assignmentName: String, _ grade: String, _ weight: String?) {
        handleAddGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
    }
    
    private func showAlert(title: String, message: String) {
        showSimpleAlert(title: title, message: message)
    }
    
    private func fallbackToLegacyProcessing(_ text: String) {
        let result = nlpEngine.parse(inputText: text,
                                    availableCategories: eventViewModel.categories,
                                    existingCourses: existingCourses)
        
        switch result {
        case .parsedEvent(let title, let date, let categoryName, let reminderTime):
            handleAddEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminderTime)
        case .parsedScheduleItem(let title, let days, let startTimeComponents, let endTimeComponents, let duration, let reminderTime, let colorHex):
            handleAddScheduleItem(title: title, days: days, startTimeComponents: startTimeComponents, endTimeComponents: endTimeComponents, duration: duration, reminderTime: reminderTime, colorHex: colorHex)
        case .needsMoreInfo(let prompt, _, let context, let conversationId):
            handleFollowUpQuestion(prompt: prompt, context: context, conversationId: conversationId)
        case .unrecognized(_):
            showSimpleAlert(title: "Input Not Understood", message: "Sorry, I couldn't understand that. Please try rephrasing. Examples:\n'Meeting tomorrow at 2pm about project'\n'Math class every Monday 9am'\n'Got 95% on CS101 midterm'")
        case .notAttempted:
            handleGenericResult(result)
        case .parsedGrade(let courseName, let assignmentName, let grade, let weight):
            handleAddGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
        }
    }

    private func handleGenericResult(_ result: NLPResult) {
        switch result {
        case .notAttempted:
            dismiss()
        default:
            showSimpleAlert(title: "Unexpected Result", message: "An unexpected result was received.")
        }
    }

    struct QuickActionButton: View {
        let emoji: String
        let title: String
        let subtitle: String
        let color: Color
        let action: () -> Void
        
        @State private var isPressed = false
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Text(emoji)
                        .font(.title2)
                    
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                )
                .shadow(color: color.opacity(0.3), radius: isPressed ? 2 : 8, x: 0, y: isPressed ? 1 : 4)
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                    action()
                }
            }
        }
    }

}

#if DEBUG
class PreviewThemeManager: ObservableObject {
    struct Theme {
        var primaryColor: Color = .blue
        var secondaryColor: Color = .green
        var tertiaryColor: Color = .orange
    }
    @Published var currentTheme: Theme = Theme()
}

struct NaturalLanguageInputView_Previews: PreviewProvider {
    static var previews: some View {
        NaturalLanguageInputView()
            .environmentObject(PreviewThemeManager())
            .environmentObject(EventViewModel())
    }
}
#endif
