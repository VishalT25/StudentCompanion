import SwiftUI

struct NaturalLanguageInputView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventViewModel: EventViewModel
    
    @State private var inputText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    private let smartEngine = SmartInputEngine()
    @State private var existingCourses: [Course] = []
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var selectedSuggestionIndex = 0
    @State private var isProcessing = false
    @State private var isInFollowUpMode = false
    @State private var followUpContext: ParseContext? = nil
    @State private var conversationHistory: [String] = []
    @State private var currentIntent = ""
    @State private var processingAttempts = 0 
    @State private var conversationContext: [String: String] = [:]
    @State private var pendingIntent: String = ""
    @State private var isAwaitingFollowUp: Bool = false
    
    @StateObject private var courseSelectionManager = CourseSelectionManager()
    @State private var pendingCourseSelectionInput = ""
    @State private var pendingCourseSelectionContext: [String: String] = [:]
    
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
                        
                        VStack(spacing: 20) {
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
                
                if courseSelectionManager.showPopup {
                    CourseSelectionPopup(
                        originalInput: courseSelectionManager.originalInput,
                        suggestedAlias: courseSelectionManager.suggestedAlias,
                        availableCourses: courseSelectionManager.availableCourses,
                        onCourseSelected: { course in
                            courseSelectionManager.selectCourse(course)
                            handleCourseSelection(course: course)
                        },
                        onDismiss: {
                            courseSelectionManager.dismissPopup()
                            resetCourseSelectionState()
                        }
                    )
                    .environmentObject(themeManager)
                    .transition(.opacity)
                    .zIndex(1000)
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
                        resetConversation()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                let courseNames = eventViewModel.courses.map { $0.name }
                smartEngine.updateUserCourses(courseNames)
                
                smartEngine.updateUserCoursesWithObjects(eventViewModel.courses)
                
                smartEngine.setCourseSelectionCallback { [self] originalInput, suggestedAlias, availableCourses in
                    DispatchQueue.main.async {
                        self.pendingCourseSelectionInput = originalInput
                        self.pendingCourseSelectionContext = self.conversationContext
                        
                        courseSelectionManager.requestCourseSelection(
                            originalInput: originalInput,
                            suggestedAlias: suggestedAlias,
                            availableCourses: availableCourses,
                            onSelection: { course in
                                handleCourseSelection(course: course)
                            },
                            onDismiss: {
                                resetCourseSelectionState()
                            }
                        )
                    }
                }
                
                print("SmartInputEngine initialized with \(courseNames.count) user courses")
                
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
        processingAttempts = 0
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
            case 0:
                inputText = "Meeting tomorrow at 2pm"
            case 1:
                inputText = "Study session every Tuesday 6pm for 2 hours"
            case 2:
                inputText = "Got 95% on CS101 midterm"
            default:
                break
            }
            isTextFieldFocused = true
        }
    }
    
    private func loadCourses() {
        self.existingCourses = CourseStorage.load()
        print("NLP Debug - Loaded \(existingCourses.count) courses from CourseStorage")
        for course in existingCourses {
            print("NLP Debug - Course: '\(course.name)' with \(course.assignments.count) assignments")
        }
    }
    
    private func processInput() {
        // SAFEGUARD: Prevent infinite processing loops
        guard processingAttempts < 3 else {
            print("❌ SAFEGUARD: Too many processing attempts, resetting state")
            showSimpleAlert(title: "Processing Error", message: "Unable to process input. Please try again.")
            resetConversation()
            processingAttempts = 0
            isProcessing = false
            return
        }
        
        processingAttempts += 1
        
        Task {
            isProcessing = true
            var entities = [String: String]()
            
            if isInFollowUpMode, let context = followUpContext {
                // FOLLOW-UP MODE: Combine new input with previous context
                print("📝 FOLLOW-UP MODE: Processing answer with context")
                print("📝 Previous context: \(conversationContext)")
                print("📝 Current input: '\(inputText)'")
                
                // Process the follow-up answer
                let result = await smartEngine.process(inputText)
                print("📝 Follow-up result: \(result)")
                
                // Merge new entities with previous context
                entities = conversationContext
                for (key, value) in result.entities {
                    entities[key] = value
                    print("📝 Added/Updated entity: \(key) = \(value)")
                }
                
                // Check if we have all required fields now
                let missingFields = smartEngine.getMissingFields(for: pendingIntent, from: entities)
                
                if missingFields.isEmpty {
                    // All fields complete - create the item
                    print("📝 All fields complete! Creating item...")
                    switch pendingIntent {
                    case "grade_tracking":
                        handleCompleteGrade(entities: entities)
                    case "scheduled_event", "event_reminder":
                        handleCompleteEvent(entities: entities)
                    default:
                        showSimpleAlert(title: "Error", message: "Unknown intent: \(pendingIntent)")
                    }
                    
                    // Reset conversation state
                    resetConversationState()
                    
                } else {
                    // Still missing fields - ask for next one
                    if let nextMissingField = missingFields.first {
                        let question = smartEngine.generateFollowUpQuestion(for: nextMissingField, intent: pendingIntent)
                        let context: ParseContext = pendingIntent == "grade_tracking" ? .grade : .event
                        handleFollowUpQuestion(prompt: question, context: context, conversationId: nil)
                    }
                }
                
            } else {
                // INITIAL MODE: First time processing
                print("📝 INITIAL MODE: Processing initial input")
                let result = await smartEngine.process(inputText)
                currentIntent = result.intent
                entities = result.entities
                
                print("📝 INITIAL MODE: Intent=\(currentIntent), Entities=\(entities)")
                
                // CRITICAL: Only proceed if intent is valid
                guard currentIntent != "unknown" else {
                    showSimpleAlert(title: "Input Not Understood",
                                    message: "Try phrases like:\n'Got 95% on CS101 midterm'\n'Math class every Monday 9am'")
                    inputText = ""
                    isProcessing = false
                    return
                }
                
                // Check for missing fields
                let missingFields = smartEngine.getMissingFields(for: currentIntent, from: entities)
                print("📝 Missing fields: \(missingFields)")
                
                if missingFields.isEmpty {
                    // CRITICAL: Double-check we actually have all required data before creating
                    print("📝 No missing fields reported, validating data...")
                    
                    switch currentIntent {
                    case "grade_tracking":
                        // STRICT validation for grade data
                        let hasCourse = entities["COURSE_NAME"] != nil
                        let hasAssignment = entities["ASSIGNMENT"] != nil
                        let hasScore = entities["SCORE_VALUE"] != nil
                        
                        print("📝 Grade validation: course=\(hasCourse), assignment=\(hasAssignment), score=\(hasScore)")
                        print("📝 Entities: \(entities)")
                        
                        if hasCourse && hasAssignment && hasScore {
                            print("📝 ✅ All grade data validated, creating grade...")
                            handleCompleteGrade(entities: entities)
                        } else {
                            print("📝 ❌ Grade validation failed despite missing fields check")
                            showSimpleAlert(title: "Input Error", message: "Could not extract all required grade information")
                        }
                        
                    case "scheduled_event", "event_reminder":
                        handleCompleteEvent(entities: entities)
                    default:
                        showSimpleAlert(title: "Input Not Understood",
                                        message: "Try phrases like:\n'Got 95% on CS101 midterm'\n'Math class every Monday 9am'")
                    }
                } else {
                    // Missing fields - start follow-up conversation
                    if let missingField = missingFields.first {
                        print("📝 Starting follow-up for missing field: \(missingField)")
                        conversationContext = entities
                        pendingIntent = currentIntent
                        isAwaitingFollowUp = true
                        
                        let question = smartEngine.generateFollowUpQuestion(for: missingField, intent: currentIntent)
                        let context: ParseContext = currentIntent == "grade_tracking" ? .grade : .event
                        
                        handleFollowUpQuestion(prompt: question, context: context, conversationId: nil)
                    }
                }
            }
            
            print("📝 Final entities: \(entities)")
            inputText = ""
            isProcessing = false
            processingAttempts = 0 // RESET: Processing completed successfully
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
        
        if let catName = categoryName, let foundCategory = eventViewModel.categories.first(where: { $0.name.lowercased() == catName.lowercased() }) {
            finalCategoryId = foundCategory.id
        } else if categoryName != nil {
            showSimpleAlert(title: "Category Not Found", message: "The category '\(categoryName!)' was not found. Please add this category first or choose from existing categories.")
            return
        }
        
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
        print("==================================")
        print("SAVE Debug - Course: '\(courseName)'")
        print("SAVE Debug - Assignment: '\(assignmentName)'")
        print("SAVE Debug - Grade: '\(grade)'")
        print("SAVE Debug - Weight: '\(weight ?? "nil")'")
        print("==================================")
        
        guard let courseIndex = existingCourses.firstIndex(where: { $0.name.lowercased() == courseName.lowercased() }) else {
            print("Course '\(courseName)' not found in existing courses, but popup should have handled this")
            return
        }
        
        var courseToUpdate = existingCourses[courseIndex]
        let normalizedGrade = normalizeGradeForStorage(grade)
        let normalizedWeight = weight != nil ? normalizeWeightForStorage(weight!) : ""
        
        print("SAVE Debug - Normalized grade: '\(normalizedGrade)'")
        print("SAVE Debug - Normalized weight: '\(normalizedWeight)'")
        
        let existingAssignment = courseToUpdate.assignments.first(where: { $0.name.lowercased() == assignmentName.lowercased() })
        
        var finalAssignmentName = assignmentName
        if existingAssignment != nil {
            var counter = 2
            while courseToUpdate.assignments.contains(where: { $0.name.lowercased() == "\(assignmentName) \(counter)".lowercased() }) {
                counter += 1
            }
            finalAssignmentName = "\(assignmentName) \(counter)"
            print("Duplicate name detected, using: '\(finalAssignmentName)'")
        }
        
        print("Creating new assignment")
        let newAssignment = Assignment(name: finalAssignmentName, grade: normalizedGrade, weight: normalizedWeight)
        print("New assignment created: name='\(newAssignment.name)', grade='\(newAssignment.grade)', weight='\(newAssignment.weight)'")
        courseToUpdate.assignments.append(newAssignment)
        
        var totalWeight = 0.0
        for assignment in courseToUpdate.assignments {
            if let weight = assignment.weightValue, weight > 0 {
                totalWeight += weight
            }
        }
        
        existingCourses[courseIndex] = courseToUpdate
        
        print("About to save using CourseStorage...")
        CourseStorage.save(existingCourses)
        print("Successfully saved using CourseStorage")
        
        let displayGrade = grade.hasSuffix("%") ? grade : "\(grade)%"
        var successMessage = "Added \(displayGrade) for \(finalAssignmentName) in \(courseName)"
        
        if existingAssignment != nil {
            successMessage += "\n\n Note: '\(assignmentName)' already exists, so this was saved as '\(finalAssignmentName)'"
        }
        
        if totalWeight > 100.0 {
            let excess = totalWeight - 100.0
            successMessage += "\n\n Warning: Assignment weights now exceed 100% by \(String(format: "%.1f", excess))%. You may want to adjust the weights."
        }
        
        showSimpleAlert(title: "Grade Added", message: successMessage)
        
    }
    
    private func normalizeGradeForStorage(_ grade: String) -> String {
        var normalized = grade.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("NORMALIZE Grade - Input: '\(grade)' -> After trim: '\(normalized)'")
        
        if normalized.hasSuffix("%") {
            normalized = String(normalized.dropLast())
            print("NORMALIZE Grade - Removed % sign: '\(normalized)'")
        }
        
        print("NORMALIZE Grade - Final result: '\(normalized)'")
        return normalized
    }
    
    private func normalizeWeightForStorage(_ weight: String) -> String {
        var normalized = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("NORMALIZE Weight - Input: '\(weight)' -> After trim: '\(normalized)'")
        
        if normalized.hasSuffix("%") {
            normalized = String(normalized.dropLast())
            print("NORMALIZE Weight - Removed % sign: '\(normalized)'")
        }
        
        print("NORMALIZE Weight - Final result: '\(normalized)'")
        return normalized
    }
    
    private func handleGradeIntent(entities: [String: String]) {
        print("Grade entities: \(entities)")
        
        guard let course = entities["COURSE_NAME"] ?? entities["COURSE_CODE"] ?? entities["COURSE_ALIAS"],
              let assignment = entities["ASSIGNMENT"],
              let score = entities["SCORE_VALUE"] ?? entities["LETTER_GRADE"] else {
            
            let missing = [
                entities["COURSE_NAME"] == nil && entities["COURSE_CODE"] == nil && entities["COURSE_ALIAS"] == nil ? "course" : nil,
                entities["ASSIGNMENT"] == nil ? "assignment" : nil,
                entities["SCORE_VALUE"] == nil && entities["LETTER_GRADE"] == nil ? "score" : nil
            ].compactMap { $0 }
            
            if let missingField = missing.first {
                handleFollowUpQuestion(prompt: "What's the \(missingField)?", context: .grade, conversationId: nil)
            } else {
                showSimpleAlert(title: "Input Error", message: "Missing required grade information")
            }
            return
        }
        let weight = entities["WEIGHT_PERCENT"] ?? entities["WEIGHT"]
        handleAddGrade(courseName: course, assignmentName: assignment, grade: score, weight: weight)
    }
    
    private func handleEventIntent(entities: [String: String]) {
        print("Event entities: \(entities)")
        guard let event = entities["EVENT"], let time = entities["TIME"] else {
            let missing = [
                entities["EVENT"] == nil ? "event name" : nil,
                entities["TIME"] == nil ? "time" : nil
            ].compactMap { $0 }
            if let missingField = missing.first {
                handleFollowUpQuestion(prompt: "What's the \(missingField)?", context: .event, conversationId: nil)
            } else {
                showSimpleAlert(title: "Input Error", message: "Missing required event information")
            }
            return
        }
        let date = entities["DATE_ABS"] ?? entities["DATE_REL"] ?? "today"
        let category = entities["CATEGORY"]
        if currentIntent == "scheduled_event" {
            handleScheduledEvent(event: event, time: time, date: date, entities: entities)
        } else {
            handleSingleEvent(event: event, time: time, date: date, category: category)
        }
    }
    private func handleScheduledEvent(event: String, time: String, date: String, entities: [String: String]) {
        let days = entities["DAY_OF_WEEK"] ?? "Monday"
        let recurrence = entities["REC_FREQ"] ?? "weekly"
        print("Creating recurring schedule: \(event) on \(days) at \(time)")
    }
    private func handleSingleEvent(event: String, time: String, date: String, category: String?) {
        handleAddEvent(title: event, date: parseDateFromEntities(date: date, time: time), categoryName: category, reminderTime: .thirtyMinutes)
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
    private func parseDateFromEntities(date: String, time: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        guard let timeDate = dateFormatter.date(from: time) else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: timeDate)
        if date == "today" {
            return calendar.date(bySettingHour: components.hour!, minute: components.minute!, second: 0, of: Date())
        } else {
            return Date()
        }
    }
    private func resetConversationState() {
        conversationContext = [:]
        pendingIntent = ""
        isAwaitingFollowUp = false
        isInFollowUpMode = false
        followUpContext = nil
    }
    private func handleCompleteGrade(entities: [String: String]) {
        print("COMPLETE GRADE: Starting with entities: \(entities)")
        guard let course = entities["COURSE_NAME"], let assignment = entities["ASSIGNMENT"], let score = entities["SCORE_VALUE"], !course.isEmpty, !assignment.isEmpty, !score.isEmpty else {
            print("CRITICAL: Missing or empty required grade information")
            print("Course: '\(entities["COURSE_NAME"] ?? "MISSING")'")
            print("Assignment: '\(entities["ASSIGNMENT"] ?? "MISSING")'")
            print("Score: '\(entities["SCORE_VALUE"] ?? "MISSING")'")
            showSimpleAlert(title: "Error", message: "Missing required grade information")
            return
        }
        print("Grade validation passed")
        print("Creating grade with: Course='\(course)', Assignment='\(assignment)', Score='\(score)'")
        let weight = entities["WEIGHT_PERCENT"] ?? entities["WEIGHT"]
        if isInFollowUpMode {
            conversationHistory.append("Grade added: \(score) in \(course) \(assignment)")
        }
        handleAddGrade(courseName: course, assignmentName: assignment, grade: score, weight: weight)
    }
    private func handleCompleteEvent(entities: [String: String]) {
        guard let event = entities["EVENT"] else {
            showSimpleAlert(title: "Error", message: "Missing event name")
            return
        }
        let date = entities["DATE_ABS"] ?? entities["DATE_REL"] ?? "today"
        let time = entities["TIME"] ?? "9:00 AM"
        let category = entities["CATEGORY"]
        handleAddEvent(title: event, date: parseDateFromEntities(date: date, time: time), categoryName: category, reminderTime: .thirtyMinutes)
        conversationHistory.append("Event added: \(event)")
    }
    private func handleCourseSelection(course: Course) {
        print("Course selected: \(course.name)")
        var updatedContext = pendingCourseSelectionContext
        updatedContext["COURSE_NAME"] = course.name
        if isInFollowUpMode {
            conversationContext = updatedContext
            let missingFields = smartEngine.getMissingFields(for: pendingIntent, from: updatedContext)
            if missingFields.isEmpty {
                print("All fields complete after course selection! Creating item...")
                switch pendingIntent {
                case "grade_tracking":
                    handleCompleteGrade(entities: updatedContext)
                case "scheduled_event", "event_reminder":
                    handleCompleteEvent(entities: updatedContext)
                default:
                    showSimpleAlert(title: "Error", message: "Unknown intent: \(pendingIntent)")
                }
                resetConversationState()
                resetCourseSelectionState()
            } else {
                let question = smartEngine.generateFollowUpQuestion(for: missingFields.first!, intent: pendingIntent)
                let context: ParseContext = pendingIntent == "grade_tracking" ? .grade : .event
                resetCourseSelectionState()
                handleFollowUpQuestion(prompt: question, context: context, conversationId: nil)
            }
        } else {
            conversationContext = updatedContext
            pendingIntent = currentIntent
            let missingFields = smartEngine.getMissingFields(for: currentIntent, from: updatedContext)
            if missingFields.isEmpty {
                switch currentIntent {
                case "grade_tracking":
                    handleCompleteGrade(entities: updatedContext)
                case "scheduled_event", "event_reminder":
                    handleCompleteEvent(entities: updatedContext)
                default:
                    showSimpleAlert(title: "Error", message: "Unknown intent: \(currentIntent)")
                }
                resetCourseSelectionState()
            } else {
                if let missingField = missingFields.first {
                    print("Starting follow-up for missing field after course selection: \(missingField)")
                    conversationContext = updatedContext
                    isAwaitingFollowUp = true
                    let question = smartEngine.generateFollowUpQuestion(for: missingField, intent: currentIntent)
                    let context: ParseContext = currentIntent == "grade_tracking" ? .grade : .event
                    resetCourseSelectionState()
                    handleFollowUpQuestion(prompt: question, context: context, conversationId: nil)
                }
            }
        }
    }
    private func resetCourseSelectionState() {
        pendingCourseSelectionInput = ""
        pendingCourseSelectionContext = [:]
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
}
