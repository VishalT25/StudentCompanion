import Foundation

// MARK: - Simple Parse Results & Context
enum NLPResult {
    case parsedEvent(title: String, date: Date?, categoryName: String?, reminderTime: ReminderTime?)
    case parsedScheduleItem(title: String, days: Set<DayOfWeek>, startTimeComponents: DateComponents?, endTimeComponents: DateComponents?, duration: TimeInterval?, reminderTime: ReminderTime?, colorHex: String?)
    case parsedGrade(courseName: String, assignmentName: String, grade: String, weight: String?)
    case needsMoreInfo(prompt: String, originalInput: String, context: ParseContext?, conversationId: UUID?)
    case unrecognized(originalInput: String)
    case notAttempted
}

enum ParseContext {
    case gradeNeedsWeight(courseName: String, assignmentName: String, grade: String)
    case gradeNeedsAssignmentName(courseName: String, grade: String)
    case gradeNeedsCourse(assignmentName: String?, grade: String)
    case eventNeedsReminder(title: String, date: Date?, categoryName: String?)
    case eventNeedsDate(title: String, categoryName: String?)
    case eventNeedsCategory(title: String, date: Date?)
    case eventNeedsTime(title: String, baseDate: Date, categoryName: String?)
    case eventNeedsTimeNoReminder(title: String, baseDate: Date, categoryName: String?)
    case eventNeedsCategoryNoReminder(title: String, date: Date)
    case scheduleNeedsReminder(title: String, days: Set<DayOfWeek>, startTime: DateComponents?, endTime: DateComponents?, duration: TimeInterval?)
    case scheduleNeedsMoreTime(title: String, days: Set<DayOfWeek>, startTime: DateComponents?)
    case scheduleNeedsColor(title: String, days: Set<DayOfWeek>, startTime: DateComponents?, endTime: DateComponents?, duration: TimeInterval?, reminderTime: ReminderTime?)
    case scheduleNeedsReminderAndColor(title: String, days: Set<DayOfWeek>, startTime: DateComponents?, endTime: DateComponents?, duration: TimeInterval?)
}

// MARK: - Simplified NLP Engine
class NLPEngine {
    private let conversationTimeoutInterval: TimeInterval = 300
    private var activeConversations: [UUID: Date] = [:]
    
    func parse(inputText: String, availableCategories: [Category] = [], existingCourses: [Course] = []) -> NLPResult {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .notAttempted }
        
        let lowercased = trimmed.lowercased()
        
        // Try parsing as grade first
        if let gradeResult = tryParseAsGrade(text: trimmed, lowercased: lowercased, courses: existingCourses) {
            return gradeResult
        }
        
        // Try parsing as schedule BEFORE event (schedule has priority)
        if let scheduleResult = tryParseAsScheduleItem(text: trimmed, lowercased: lowercased) {
            return scheduleResult
        }
        
        // Try parsing as event
        if let eventResult = tryParseAsEvent(text: trimmed, lowercased: lowercased, categories: availableCategories) {
            return eventResult
        }
        
        return .unrecognized(originalInput: inputText)
    }
    
    func parseFollowUp(inputText: String, context: ParseContext, conversationId: UUID?, availableCategories: [Category] = [], existingCourses: [Course] = []) -> NLPResult {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.lowercased().contains("cancel") {
            return .unrecognized(originalInput: "Cancelled.")
        }
        
        switch context {
        case .gradeNeedsWeight(let courseName, let assignmentName, let grade):
            if let weight = extractWeight(from: trimmed) {
                return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
            } else if trimmed.lowercased().contains("skip") || trimmed.lowercased().contains("no") {
                return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: nil)
            } else {
                return .needsMoreInfo(prompt: "Please enter the weight as a percentage (e.g., '20%') or say 'skip'.", originalInput: trimmed, context: context, conversationId: conversationId)
            }
            
        case .gradeNeedsAssignmentName(let courseName, let grade):
            let assignmentName = trimmed.isEmpty ? "Assignment" : trimmed
            return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%')", originalInput: "", context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignmentName, grade: grade), conversationId: conversationId)
            
        case .gradeNeedsCourse(let assignmentName, let grade):
            if let course = existingCourses.first(where: { $0.name.lowercased().contains(trimmed.lowercased()) }) {
                let finalAssignmentName = assignmentName ?? "Assignment"
                return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%')", originalInput: "", context: .gradeNeedsWeight(courseName: course.name, assignmentName: finalAssignmentName, grade: grade), conversationId: conversationId)
            } else {
                return .needsMoreInfo(prompt: "Course not found. Please enter an existing course name.", originalInput: trimmed, context: context, conversationId: conversationId)
            }
            
        case .eventNeedsReminder(let title, let date, let categoryName):
            let reminderTime = parseReminderTime(from: trimmed)
            return .parsedEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminderTime)
            
        case .eventNeedsDate(let title, let categoryName):
            if let date = parseDate(from: trimmed) {
                if categoryName != nil {
                    let reminderPrompt = "When would you like to be reminded about '\(title)'? (e.g., '15 minutes before', 'at the start', or 'no reminder')"
                    return .needsMoreInfo(
                        prompt: reminderPrompt,
                        originalInput: trimmed,
                        context: .eventNeedsReminder(title: title, date: date, categoryName: categoryName),
                        conversationId: conversationId
                    )
                } else {
                    let categoryPrompt = buildCategoryPrompt(for: title, availableCategories: availableCategories)
                    return .needsMoreInfo(
                        prompt: categoryPrompt,
                        originalInput: trimmed,
                        context: .eventNeedsCategory(title: title, date: date),
                        conversationId: conversationId
                    )
                }
            } else {
                return .needsMoreInfo(
                    prompt: "I couldn't understand that date. Please try again with formats like 'tomorrow at 3pm', 'next Monday', or 'December 15'.",
                    originalInput: trimmed,
                    context: context,
                    conversationId: conversationId
                )
            }
            
        case .eventNeedsCategory(let title, let date):
            let selectedCategory = findCategoryFromUserInput(trimmed, availableCategories: availableCategories)
            
            if let categoryName = selectedCategory {
                return .needsMoreInfo(
                    prompt: "When would you like to be reminded about '\(title)'? (e.g., '15 minutes before', 'at the start', or 'no reminder')",
                    originalInput: trimmed,
                    context: .eventNeedsReminder(title: title, date: date, categoryName: categoryName),
                    conversationId: conversationId
                )
            } else {
                let categoryPrompt = buildCategoryPrompt(for: title, availableCategories: availableCategories, isRetry: true)
                return .needsMoreInfo(
                    prompt: categoryPrompt,
                    originalInput: trimmed,
                    context: context,
                    conversationId: conversationId
                )
            }
            
        case .eventNeedsTimeNoReminder(let title, let baseDate, let categoryName):
            if let specificTime = parseSpecificTime(from: trimmed) {
                let calendar = Calendar.current
                let finalDate = calendar.date(bySettingHour: specificTime.hour ?? 12, minute: specificTime.minute ?? 0, second: 0, of: baseDate) ?? baseDate
                
                if categoryName != nil {
                    // No reminder needed - create event directly
                    return .parsedEvent(title: title, date: finalDate, categoryName: categoryName, reminderTime: .none)
                } else {
                    let categoryPrompt = buildCategoryPrompt(for: title, availableCategories: availableCategories)
                    return .needsMoreInfo(
                        prompt: categoryPrompt,
                        originalInput: trimmed,
                        context: .eventNeedsCategoryNoReminder(title: title, date: finalDate),
                        conversationId: conversationId
                    )
                }
            } else {
                return .needsMoreInfo(
                    prompt: "What time is '\(title)'? (e.g., '3:30 PM', '9am', '14:00')",
                    originalInput: trimmed,
                    context: context,
                    conversationId: conversationId
                )
            }
            
        case .eventNeedsCategoryNoReminder(let title, let date):
            let selectedCategory = findCategoryFromUserInput(trimmed, availableCategories: availableCategories)
            
            if let categoryName = selectedCategory {
                // No reminder needed - create event directly
                return .parsedEvent(title: title, date: date, categoryName: categoryName, reminderTime: .none)
            } else {
                let categoryPrompt = buildCategoryPrompt(for: title, availableCategories: availableCategories, isRetry: true)
                return .needsMoreInfo(
                    prompt: categoryPrompt,
                    originalInput: trimmed,
                    context: context,
                    conversationId: conversationId
                )
            }
            
        case .eventNeedsTime(let title, let baseDate, let categoryName):
            if let specificTime = parseSpecificTime(from: trimmed) {
                let calendar = Calendar.current
                let finalDate = calendar.date(bySettingHour: specificTime.hour ?? 12, minute: specificTime.minute ?? 0, second: 0, of: baseDate) ?? baseDate
                
                if categoryName != nil {
                    let reminderPrompt = "When would you like to be reminded about '\(title)'? (e.g., '15 minutes before', 'at the start', or 'no reminder')"
                    return .needsMoreInfo(
                        prompt: reminderPrompt,
                        originalInput: trimmed,
                        context: .eventNeedsReminder(title: title, date: finalDate, categoryName: categoryName),
                        conversationId: conversationId
                    )
                } else {
                    let categoryPrompt = buildCategoryPrompt(for: title, availableCategories: availableCategories)
                    return .needsMoreInfo(
                        prompt: categoryPrompt,
                        originalInput: trimmed,
                        context: .eventNeedsCategory(title: title, date: finalDate),
                        conversationId: conversationId
                    )
                }
            } else {
                return .needsMoreInfo(
                    prompt: "What time is '\(title)'? (e.g., '3:30 PM', '9am', '14:00')",
                    originalInput: trimmed,
                    context: context,
                    conversationId: conversationId
                )
            }
            
        case .scheduleNeedsReminder(let title, let days, let startTime, let endTime, let duration):
            let reminderTime = parseReminderTime(from: trimmed)
            return .parsedScheduleItem(title: title, days: days, startTimeComponents: startTime, endTimeComponents: endTime, duration: duration, reminderTime: reminderTime, colorHex: nil)
        
        case .scheduleNeedsColor(let title, let days, let startTime, let endTime, let duration, let reminderTime):
            let extractedColor = extractColorFromText(from: trimmed.lowercased())
            let finalColor = extractedColor ?? "007AFF" // Default blue
            return .parsedScheduleItem(title: title, days: days, startTimeComponents: startTime, endTimeComponents: endTime, duration: duration, reminderTime: reminderTime, colorHex: finalColor)
            
        case .scheduleNeedsReminderAndColor(let title, let days, let startTime, let endTime, let duration):
            let reminderTime = parseReminderTime(from: trimmed)
            return .needsMoreInfo(
                prompt: "What color would you like for '\(title)'? (e.g., 'blue', 'red', 'green', or 'default')",
                originalInput: trimmed,
                context: .scheduleNeedsColor(title: title, days: days, startTime: startTime, endTime: endTime, duration: duration, reminderTime: reminderTime),
                conversationId: conversationId
            )
            
        case .scheduleNeedsMoreTime(let title, let days, let startTime):
            let updatedDays = days.isEmpty ? extractDaysOfWeek(from: trimmed) : days
            let updatedTimes = extractScheduleTimes(from: trimmed)
            let updatedStartTime = startTime ?? updatedTimes.start
            
            var updatedEndTime = updatedTimes.end
            if startTime != nil && updatedEndTime == nil && updatedTimes.start != nil {
                updatedEndTime = updatedTimes.start
            }
            
            if updatedDays.isEmpty {
                return .needsMoreInfo(prompt: "Please specify the days for '\(title)' (e.g., 'every Monday', 'MWF').", originalInput: trimmed, context: .scheduleNeedsMoreTime(title: title, days: Set<DayOfWeek>(), startTime: updatedStartTime), conversationId: conversationId)
            }
            
            if updatedStartTime == nil {
                return .needsMoreInfo(prompt: "What time does '\(title)' start? (e.g., 'at 9am', 'from 10:30')", originalInput: trimmed, context: .scheduleNeedsMoreTime(title: title, days: updatedDays, startTime: nil), conversationId: conversationId)
            }
            
            if updatedEndTime == nil && updatedTimes.duration == nil {
                return .needsMoreInfo(prompt: "When does '\(title)' end? (e.g., 'to 11am', 'for 1 hour')", originalInput: trimmed, context: .scheduleNeedsMoreTime(title: title, days: updatedDays, startTime: updatedStartTime), conversationId: conversationId)
            }
            
            // Now ask for reminder
            return .needsMoreInfo(
                prompt: "Would you like to set a reminder for '\(title)'? (e.g., '15 minutes before', 'at start time', or 'no')",
                originalInput: trimmed,
                context: .scheduleNeedsReminderAndColor(title: title, days: updatedDays, startTime: updatedStartTime, endTime: updatedEndTime, duration: updatedTimes.duration),
                conversationId: conversationId
            )
        }
    }
    
    // MARK: - Grade Parsing
    private func tryParseAsGrade(text: String, lowercased: String, courses: [Course]) -> NLPResult? {
        let specificGradeKeywords = ["grade", "score", "received", "earned", "scored", "percent", "%"]
        let contextualGradeWords = ["got"]
        
        let hasSpecificGradeKeyword = specificGradeKeywords.contains { lowercased.contains($0) }
        let hasContextualGradeWord = contextualGradeWords.contains { lowercased.contains($0) }
        
        let isLikelyGrade = hasSpecificGradeKeyword || 
                           (hasContextualGradeWord && containsGradePattern(lowercased))
        
        guard isLikelyGrade || containsGradePattern(lowercased) else { return nil }
        
        if isEventNotGrade(text: lowercased) {
            return nil
        }
        
        guard let gradeString = extractGrade(from: text), !gradeString.isEmpty else {
            if hasSpecificGradeKeyword {
                let conversationId = startNewConversation()
                return .needsMoreInfo(prompt: "Please include the grade (e.g., '95%', 'A+', '87', '45/67').", originalInput: text, context: nil, conversationId: conversationId)
            }
            return nil
        }
        
        let identifiedCourseName = findBestCourseMatch(from: lowercased, courses: courses)
        let assignmentName = extractAssignmentName(from: lowercased)
        let weight = extractWeight(from: text)
        
        let conversationId = startNewConversation()
        
        if let courseName = identifiedCourseName, let assignment = assignmentName {
            if weight == nil {
                return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%')", originalInput: text, context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignment, grade: gradeString), conversationId: conversationId)
            } else {
                return .parsedGrade(courseName: courseName, assignmentName: assignment, grade: gradeString, weight: weight)
            }
        } else if let courseName = identifiedCourseName {
            return .needsMoreInfo(prompt: "What's the name of this assignment in \(courseName)?", originalInput: text, context: .gradeNeedsAssignmentName(courseName: courseName, grade: gradeString), conversationId: conversationId)
        } else {
            if courses.isEmpty {
                return .needsMoreInfo(prompt: "No courses found. Please add some courses first.", originalInput: text, context: nil, conversationId: conversationId)
            } else {
                let courseNames = courses.prefix(5).map { $0.name }.joined(separator: ", ")
                return .needsMoreInfo(prompt: "Which course is this grade for? Available: \(courseNames)", originalInput: text, context: .gradeNeedsCourse(assignmentName: assignmentName, grade: gradeString), conversationId: conversationId)
            }
        }
    }
    
    // MARK: - Schedule Parsing
    private func tryParseAsScheduleItem(text: String, lowercased: String) -> NLPResult? {
        let strongScheduleKeywords = ["every", "weekly", "recurring", "weekday", "weekdays", "daily"]
        let scheduleKeywords = ["schedule", "class", "course", "lecture", "tutorial", "lab", "seminar"]
        
        let hasStrongScheduleKeyword = strongScheduleKeywords.contains { lowercased.contains($0) }
        let hasScheduleKeyword = scheduleKeywords.contains { lowercased.contains($0) }
        
        let dayPatterns = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "mwf", "tth", "tr"]
        let hasDayPattern = dayPatterns.contains { lowercased.contains($0) }
        
        let hasTimeRange = lowercased.contains("from") && (lowercased.contains("to") || lowercased.contains("-"))
        let hasCourseCode = lowercased.range(of: "[a-z]{2,4}\\d{3,4}", options: .regularExpression) != nil
        
        let isLikelySchedule = hasStrongScheduleKeyword || 
                             (hasCourseCode && hasTimeRange) ||
                             (hasScheduleKeyword && hasDayPattern) ||
                             (hasScheduleKeyword && hasTimeRange)
        
        guard isLikelySchedule else { return nil }
        
        let extractedDays = extractDaysOfWeek(from: text)
        let extractedTimes = extractScheduleTimes(from: text)
        let extractedTitle = extractScheduleTitle(from: text)
        
        let extractedReminderTime = extractReminderFromScheduleText(from: lowercased)
        let extractedColor = extractColorFromText(from: lowercased)
        
        let explicitlyDeclinedReminder = lowercased.contains("don't need to be reminded") || 
                                       lowercased.contains("no reminder needed") ||
                                       lowercased.contains("don't remind me") ||
                                       lowercased.contains("no reminder") ||
                                       lowercased.contains("don't need reminder") ||
                                       lowercased.contains("no need to remind")
        
        let conversationId = startNewConversation()
        
        if extractedDays.isEmpty {
            return .needsMoreInfo(prompt: "Please specify the days for '\(extractedTitle)' (e.g., 'every Monday', 'MWF').", originalInput: text, context: .scheduleNeedsMoreTime(title: extractedTitle, days: Set<DayOfWeek>(), startTime: extractedTimes.start), conversationId: conversationId)
        }
        
        if extractedTimes.start == nil {
            return .needsMoreInfo(prompt: "What time does '\(extractedTitle)' start? (e.g., 'at 9am', 'from 10:30')", originalInput: text, context: .scheduleNeedsMoreTime(title: extractedTitle, days: extractedDays, startTime: nil), conversationId: conversationId)
        }
        
        if extractedTimes.end == nil && extractedTimes.duration == nil {
            return .needsMoreInfo(prompt: "When does '\(extractedTitle)' end? (e.g., 'to 11am', 'for 1 hour')", originalInput: text, context: .scheduleNeedsMoreTime(title: extractedTitle, days: extractedDays, startTime: extractedTimes.start), conversationId: conversationId)
        }
        
        let needsReminder = extractedReminderTime == nil && !explicitlyDeclinedReminder
        let needsColor = extractedColor == nil
        
        if needsReminder && needsColor {
            return .needsMoreInfo(
                prompt: "Would you like to set a reminder for '\(extractedTitle)'? (e.g., '15 minutes before', 'at start time', or 'no')",
                originalInput: text,
                context: .scheduleNeedsReminderAndColor(title: extractedTitle, days: extractedDays, startTime: extractedTimes.start, endTime: extractedTimes.end, duration: extractedTimes.duration),
                conversationId: conversationId
            )
        } else if needsReminder {
            return .needsMoreInfo(
                prompt: "Would you like to set a reminder for '\(extractedTitle)'? (e.g., '15 minutes before', 'at start time', or 'no')",
                originalInput: text,
                context: .scheduleNeedsReminder(title: extractedTitle, days: extractedDays, startTime: extractedTimes.start, endTime: extractedTimes.end, duration: extractedTimes.duration),
                conversationId: conversationId
            )
        } else if needsColor {
            return .needsMoreInfo(
                prompt: "What color would you like for '\(extractedTitle)'? (e.g., 'blue', 'red', 'green', or 'default')",
                originalInput: text,
                context: .scheduleNeedsColor(title: extractedTitle, days: extractedDays, startTime: extractedTimes.start, endTime: extractedTimes.end, duration: extractedTimes.duration, reminderTime: extractedReminderTime ?? .none),
                conversationId: conversationId
            )
        }
        
        return .parsedScheduleItem(
            title: extractedTitle, 
            days: extractedDays, 
            startTimeComponents: extractedTimes.start, 
            endTimeComponents: extractedTimes.end, 
            duration: extractedTimes.duration, 
            reminderTime: extractedReminderTime ?? .none,
            colorHex: extractedColor
        )
    }
    
    // MARK: - Event Parsing
    private func tryParseAsEvent(text: String, lowercased: String, categories: [Category]) -> NLPResult? {
        let strongEventKeywords = ["remind me", "reminder", "set reminder", "alert me", "notify me"]
        let eventKeywords = ["meeting", "appointment", "deadline", "exam", "test", "quiz", "homework", "due", "assignment", "project", "presentation", "interview", "dentist", "doctor", "class", "lecture", "seminar", "workshop", "conference", "party", "event", "birthday", "anniversary", "vacation", "trip", "flight", "complete", "finish", "submit", "turn in", "hand in", "work on"]
        
        let hasStrongIndicator = strongEventKeywords.contains { lowercased.contains($0) }
        let isLikelyEvent = hasStrongIndicator || eventKeywords.contains { lowercased.contains($0) } || lowercased.contains("on ") || lowercased.contains("at ") || lowercased.contains("have") || lowercased.contains("need to")
        
        guard isLikelyEvent else { return nil }
        
        let extractedTitle = extractEventTitle(from: text)
        let detectedDate = parseDate(from: text)
        let categoryName = findBestCategoryMatch(from: text, categories: categories)
        let specificTime = parseSpecificTime(from: text)
        
        let explicitlyDeclinedReminder = lowercased.contains("don't need to be reminded") || 
                                       lowercased.contains("no reminder needed") ||
                                       lowercased.contains("don't remind me") ||
                                       lowercased.contains("no reminder") ||
                                       lowercased.contains("don't need reminder") ||
                                       lowercased.contains("no need to remind")
        
        let conversationId = startNewConversation()
        
        if hasStrongIndicator {
            if let date = detectedDate {
                if specificTime != nil {
                    let calendar = Calendar.current
                    let finalDate = calendar.date(bySettingHour: specificTime?.hour ?? 12, minute: specificTime?.minute ?? 0, second: 0, of: date) ?? date
                    
                    if categoryName != nil {
                        if explicitlyDeclinedReminder {
                            return .parsedEvent(title: extractedTitle, date: finalDate, categoryName: categoryName, reminderTime: .none)
                        } else {
                            return .needsMoreInfo(
                                prompt: "When would you like to be reminded about '\(extractedTitle)'? (e.g., '15 minutes before', 'at the start', or 'no reminder')",
                                originalInput: text,
                                context: .eventNeedsReminder(title: extractedTitle, date: finalDate, categoryName: categoryName),
                                conversationId: conversationId
                            )
                        }
                    } else {
                        let categoryPrompt = buildCategoryPrompt(for: extractedTitle, availableCategories: categories)
                        let categoryContext: ParseContext = explicitlyDeclinedReminder ?
                            .eventNeedsCategoryNoReminder(title: extractedTitle, date: finalDate) :
                            .eventNeedsCategory(title: extractedTitle, date: finalDate)
                        
                        return .needsMoreInfo(
                            prompt: categoryPrompt,
                            originalInput: text,
                            context: categoryContext,
                            conversationId: conversationId
                        )
                    }
                } else {
                    let timeContext: ParseContext = explicitlyDeclinedReminder ? 
                        .eventNeedsTimeNoReminder(title: extractedTitle, baseDate: date, categoryName: categoryName) :
                        .eventNeedsTime(title: extractedTitle, baseDate: date, categoryName: categoryName)
                    
                    return .needsMoreInfo(
                        prompt: "What time is '\(extractedTitle)'? (e.g., '3:30 PM', '9am', '14:00')",
                        originalInput: text,
                        context: timeContext,
                        conversationId: conversationId
                    )
                }
            } else {
                return .needsMoreInfo(
                    prompt: "When is '\(extractedTitle)'? (e.g., 'tomorrow at 3pm', 'next Monday', 'December 15 at 2:30')",
                    originalInput: text,
                    context: .eventNeedsDate(title: extractedTitle, categoryName: categoryName),
                    conversationId: conversationId
                )
            }
        } else {
            if let date = detectedDate {
                if specificTime != nil {
                    let calendar = Calendar.current
                    let finalDate = calendar.date(bySettingHour: specificTime?.hour ?? 12, minute: specificTime?.minute ?? 0, second: 0, of: date) ?? date
                    
                    if categoryName != nil {
                        if explicitlyDeclinedReminder {
                            return .parsedEvent(title: extractedTitle, date: finalDate, categoryName: categoryName, reminderTime: .none)
                        } else {
                            return .needsMoreInfo(
                                prompt: "Would you like to set a reminder for '\(extractedTitle)'? (e.g., '15 minutes before' or 'no')",
                                originalInput: text,
                                context: .eventNeedsReminder(title: extractedTitle, date: finalDate, categoryName: categoryName),
                                conversationId: conversationId
                            )
                        }
                    } else {
                        let categoryPrompt = buildCategoryPrompt(for: extractedTitle, availableCategories: categories)
                        let categoryContext: ParseContext = explicitlyDeclinedReminder ?
                            .eventNeedsCategoryNoReminder(title: extractedTitle, date: finalDate) :
                            .eventNeedsCategory(title: extractedTitle, date: finalDate)
                        
                        return .needsMoreInfo(
                            prompt: categoryPrompt,
                            originalInput: text,
                            context: categoryContext,
                            conversationId: conversationId
                        )
                    }
                } else {
                    let timeContext: ParseContext = explicitlyDeclinedReminder ? 
                        .eventNeedsTimeNoReminder(title: extractedTitle, baseDate: date, categoryName: categoryName) :
                        .eventNeedsTime(title: extractedTitle, baseDate: date, categoryName: categoryName)
                    
                    return .needsMoreInfo(
                        prompt: "What time is '\(extractedTitle)'? (e.g., '3:30 PM', '9am', '14:00')",
                        originalInput: text,
                        context: timeContext,
                        conversationId: conversationId
                    )
                }
            } else {
                return .needsMoreInfo(
                    prompt: "When is '\(extractedTitle)'? (e.g., 'tomorrow at 3pm', 'next Monday', 'December 15 at 2:30')",
                    originalInput: text,
                    context: .eventNeedsDate(title: extractedTitle, categoryName: categoryName),
                    conversationId: conversationId
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    private func startNewConversation() -> UUID {
        let conversationId = UUID()
        activeConversations[conversationId] = Date()
        return conversationId
    }
    
    private func containsGradePattern(_ text: String) -> Bool {
        return text.contains("%") || 
               text.range(of: "\\b[A-F][+-]?\\b", options: .regularExpression) != nil ||
               text.range(of: "\\b\\d+/\\d+\\b", options: .regularExpression) != nil
    }
    
    private func extractGrade(from text: String) -> String? {
        if let range = text.range(of: "\\b(\\d+(?:\\.\\d+)?)\\s*%", options: .regularExpression) {
            return String(text[range])
        }
        
        if let range = text.range(of: "\\b[A-F][+-]?\\b", options: .regularExpression) {
            return String(text[range]).uppercased()
        }
        
        if let range = text.range(of: "\\b(\\d+(?:\\.\\d+)?/\\d+(?:\\.\\d+)?)\\b", options: .regularExpression) {
            return String(text[range])
        }
        
        if let range = text.range(of: "\\b(\\d+(?:\\.\\d+)?)\\b", options: .regularExpression) {
            let numberString = String(text[range])
            if let number = Double(numberString), number <= 100 {
                return numberString
            }
        }
        
        return nil
    }
    
    private func extractWeight(from text: String) -> String? {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let range = lowercased.range(of: "worth\\s+(\\d{1,2})\\s*%?", options: .regularExpression) {
            let match = String(lowercased[range])
            if let numberRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                let number = String(match[numberRange])
                return number
            }
        }
        
        if let range = lowercased.range(of: "weighted\\s+(\\d{1,2})\\s*%?", options: .regularExpression) {
            let match = String(lowercased[range])
            if let numberRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                let number = String(match[numberRange])
                return number
            }
        }
        
        if let range = lowercased.range(of: "counts\\s+for\\s+(\\d{1,2})\\s*%?", options: .regularExpression) {
            let match = String(lowercased[range])
            if let numberRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                let number = String(match[numberRange])
                return number
            }
        }
        
        let isLikelyFollowUpResponse = lowercased.count < 20 && 
                                     !lowercased.contains("got") && 
                                     !lowercased.contains("received") && 
                                     !lowercased.contains("scored") && 
                                     !lowercased.contains("earned") &&
                                     !lowercased.contains("exam") &&
                                     !lowercased.contains("test") &&
                                     !lowercased.contains("quiz") &&
                                     !lowercased.contains("assignment")
        
        if isLikelyFollowUpResponse {
            if let range = lowercased.range(of: "^\\s*(\\d{1,2})\\s*%?\\s*$", options: .regularExpression) {
                let match = String(lowercased[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let numberRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                    let number = String(match[numberRange])
                    return number
                }
            }
            
            if let range = lowercased.range(of: "(\\d{1,2})\\s*percent", options: .regularExpression) {
                let match = String(lowercased[range])
                if let numberRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                    let number = String(match[numberRange])
                    return number
                }
            }
            
            if lowercased.contains("percent") {
                if let range = lowercased.range(of: "^\\s*(\\d{1,2})\\s*percent\\s*$", options: .regularExpression) {
                    let match = String(lowercased[range])
                    if let numberRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                        let number = String(match[numberRange])
                        return number
                    }
                }
            }
            
            if let range = lowercased.range(of: "^\\s*(\\d{1,2})\\s*$", options: .regularExpression) {
                let numberString = String(lowercased[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let number = Int(numberString), number >= 1 && number <= 100 {
                    return numberString
                }
            }
        }
        
        return nil
    }
    
    private func extractReminderFromScheduleText(from text: String) -> ReminderTime? {
        if text.contains("remind me") || text.contains("reminder") || text.contains("alert") {
            return parseReminderTime(from: text)
        }
        return nil
    }
    
    private func extractColorFromText(from text: String) -> String? {
        let colorMappings: [String: String] = [
            "red": "FF0000",
            "blue": "0000FF", 
            "green": "00FF00",
            "yellow": "FFFF00",
            "orange": "FFA500",
            "purple": "800080",
            "pink": "FFC0CB",
            "cyan": "00FFFF",
            "magenta": "FF00FF",
            "lime": "00FF00",
            "indigo": "4B0082",
            "violet": "8A2BE2",
            "brown": "A52A2A",
            "gray": "808080",
            "grey": "808080",
            "black": "000000",
            "white": "FFFFFF"
        ]
        
        for (colorName, colorHex) in colorMappings {
            if text.contains(colorName) {
                return colorHex
            }
        }
        
        return nil
    }
    
    private func parseDate(from text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        if lowercased.contains("today") {
            return now
        }
        
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        
        if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }
        
        if let relativeDate = parseRelativeTime(from: lowercased, baseDate: now) {
            return relativeDate
        }
        
        let dayMappings: [String: Int] = [
            "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7, "sunday": 1
        ]
        
        for (dayName, weekday) in dayMappings {
            if lowercased.contains("next \(dayName)") || lowercased.contains("on \(dayName)") || lowercased.contains("this \(dayName)") {
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = weekday - currentWeekday
                if daysToAdd <= 0 {
                    daysToAdd += 7
                }
                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
            }
        }
        
        return nil
    }
    
    private func parseRelativeTime(from text: String, baseDate: Date) -> Date? {
        let calendar = Calendar.current
        
        if text.contains("in ") {
            if let range = text.range(of: "in\\s+(\\d+(?:\\.\\d+)?(?:\\s+and\\s+a\\s+half)?)\\s+(hour|hr|minute|min|day)s?", options: .regularExpression) {
                let match = String(text[range])
                
                var timeValue: Double = 0
                var timeUnit: Calendar.Component = .hour
                
                if match.contains("minute") || match.contains("min") {
                    timeUnit = .minute
                } else if match.contains("hour") || match.contains("hr") {
                    timeUnit = .hour
                } else if match.contains("day") {
                    timeUnit = .day
                }
                
                if match.contains("and a half") {
                    if let numberRange = match.range(of: "\\d+", options: .regularExpression) {
                        let numberString = String(match[numberRange])
                        if let baseNumber = Double(numberString) {
                            timeValue = baseNumber + 0.5
                        }
                    }
                } else {
                    if let numberRange = match.range(of: "\\d+(?:\\.\\d+)?", options: .regularExpression) {
                        let numberString = String(match[numberRange])
                        timeValue = Double(numberString) ?? 0
                    }
                }
                
                let timeInterval: TimeInterval
                switch timeUnit {
                case .minute:
                    timeInterval = timeValue * 60
                case .hour:
                    timeInterval = timeValue * 3600
                case .day:
                    timeInterval = timeValue * 86400
                default:
                    timeInterval = timeValue * 3600
                }
                
                return baseDate.addingTimeInterval(timeInterval)
            }
            
            if let range = text.range(of: "in\\s+(\\d+)\\s+(hour|hr|minute|min|day)s?", options: .regularExpression) {
                let match = String(text[range])
                
                if let numberRange = match.range(of: "\\d+", options: .regularExpression) {
                    let numberString = String(match[numberRange])
                    if let number = Int(numberString) {
                        if match.contains("minute") || match.contains("min") {
                            return calendar.date(byAdding: .minute, value: number, to: baseDate)
                        } else if match.contains("hour") || match.contains("hr") {
                            return calendar.date(byAdding: .hour, value: number, to: baseDate)
                        } else if match.contains("day") {
                            return calendar.date(byAdding: .day, value: number, to: baseDate)
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func parseReminderTime(from text: String) -> ReminderTime {
        let lowercased = text.lowercased()
        
        if lowercased.contains("no") || lowercased.contains("none") || lowercased.contains("skip") {
            return .none
        }
        
        if lowercased.contains("at the start") || lowercased.contains("when it starts") || lowercased.contains("at start time") || lowercased.contains("exactly at") {
            return .minutes(0)
        }
        
        if lowercased.contains("5") && lowercased.contains("min") {
            return .minutes(5)
        } else if lowercased.contains("15") && lowercased.contains("min") {
            return .minutes(15)
        } else if lowercased.contains("30") && lowercased.contains("min") {
            return .minutes(30)
        } else if lowercased.contains("1") && lowercased.contains("hour") {
            return .hours(1)
        } else if lowercased.contains("2") && lowercased.contains("hour") {
            return .hours(2)
        } else if lowercased.contains("1") && lowercased.contains("day") {
            return .days(1)
        } else if lowercased.contains("2") && lowercased.contains("day") {
            return .days(2)
        } else if lowercased.contains("1") && lowercased.contains("week") {
            return .weeks(1)
        }
        
        return .minutes(15)
    }
    
    private func findBestCourseMatch(from text: String, courses: [Course]) -> String? {
        let lowercaseText = text.lowercased()
        
        for course in courses {
            let courseName = course.name.lowercased()
            if lowercaseText.contains(courseName) {
                return course.name
            }
        }
        
        let courseKeywords = extractCourseKeywords(from: lowercaseText)
        
        for keyword in courseKeywords {
            for course in courses {
                let courseName = course.name.lowercased()
                if courseName.contains(keyword) {
                    return course.name
                }
            }
        }
        
        let courseAbbreviations = extractCourseAbbreviations(from: lowercaseText)
        
        for abbreviation in courseAbbreviations {
            for course in courses {
                if courseMatchesAbbreviation(courseName: course.name, abbreviation: abbreviation) {
                    return course.name
                }
            }
        }
        
        let courseNumbers = extractCourseNumbers(from: lowercaseText)
        
        for number in courseNumbers {
            for course in courses {
                if courseContainsNumber(courseName: course.name, number: number) {
                    return course.name
                }
            }
        }
        
        let textWords = lowercaseText.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        
        for course in courses {
            let courseWords = course.name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            
            for textWord in textWords {
                if textWord.count >= 3 {
                    for courseWord in courseWords {
                        if courseWord.contains(textWord) || textWord.contains(courseWord) {
                            return course.name
                        }
                        
                        if areWordsSimilar(textWord, courseWord) {
                            return course.name
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractCourseNumbers(from text: String) -> [String] {
        var numbers: [String] = []
        
        let numberPattern = "\\b\\d{3,4}\\b"
        guard let regex = try? NSRegularExpression(pattern: numberPattern) else { return numbers }
        
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        for result in results {
            let numberString = nsString.substring(with: result.range)
            numbers.append(numberString)
        }
        
        return numbers
    }
    
    private func courseContainsNumber(courseName: String, number: String) -> Bool {
        if courseName.contains(number) {
            return true
        }
        
        let courseNumberPattern = "\\b\\d{3,4}\\b"
        guard let regex = try? NSRegularExpression(pattern: courseNumberPattern) else { return false }
        
        let nsString = courseName as NSString
        let results = regex.matches(in: courseName, range: NSRange(location: 0, length: nsString.length))
        
        for result in results {
            let courseNumber = nsString.substring(with: result.range)
            if courseNumber == number {
                return true
            }
        }
        
        return false
    }
    
    private func extractCourseKeywords(from text: String) -> [String] {
        let commonSubjects = [
            "math", "mathematics", "calculus", "calc", "algebra", "geometry", "statistics", "stats", "trig", "trigonometry",
            "physics", "chemistry", "chem", "biology", "bio", "science", "anatomy", "physiology",
            "english", "literature", "writing", "composition", "rhetoric",
            "history", "geography", "social", "studies", "government", "civics", "politics",
            "computer", "programming", "coding", "software", "cs", "java", "python", "web",
            "economics", "business", "accounting", "finance", "marketing", "management",
            "psychology", "psych", "sociology", "philosophy", "anthropology",
            "spanish", "french", "german", "chinese", "japanese", "italian", "latin",
            "art", "music", "drama", "theater", "theatre", "dance", "film",
            "engineering", "mechanical", "electrical", "civil", "chemical", "structural",
            "organic", "inorganic", "analytical", "physical", "biochemistry", "microbiology",
            "intro", "introduction", "advanced", "honors", "ap", "basic", "fundamentals",
            "discrete", "linear", "differential", "integral", "abstract"
        ]
        
        var keywords: [String] = []
        
        for subject in commonSubjects {
            if text.contains(subject) {
                keywords.append(subject)
            }
        }
        
        let courseCodePattern = "[a-z]{2,4}\\d{3}"
        if let range = text.range(of: courseCodePattern, options: .regularExpression) {
            let courseCode = String(text[range])
            keywords.append(courseCode)
        }
        
        return keywords
    }
    
    private func extractCourseAbbreviations(from text: String) -> [String] {
        var abbreviations: [String] = []
        
        let commonAbbreviations = [
            "ochem", "orgo", "gen chem", "genchem", "phys", "calc", "pre calc", "precalc",
            "bio", "micro", "macro", "econ", "psych", "soc", "anthro", "poli sci", "polisci",
            "comp sci", "compsci", "lit", "hist", "geo", "stats", "trig", "alg", "eng",
            "chem", "math", "cs", "ap", "honors"
        ]
        
        for abbrev in commonAbbreviations {
            if text.contains(abbrev) {
                abbreviations.append(abbrev)
            }
        }
        
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        for word in words {
            if word.count >= 2 && word.count <= 6 && word.allSatisfy({ $0.isLetter }) {
                abbreviations.append(word)
            }
        }
        
        return abbreviations
    }
    
    private func courseMatchesAbbreviation(courseName: String, abbreviation: String) -> Bool {
        let lowercaseCourseName = courseName.lowercased()
        let lowercaseAbbrev = abbreviation.lowercased()
        
        let abbreviationMappings: [String: [String]] = [
            "ochem": ["organic chemistry", "organic chem", "org chem"],
            "orgo": ["organic chemistry", "organic chem", "org chem"],
            "gen chem": ["general chemistry", "general chem"],
            "genchem": ["general chemistry", "general chem"],
            "phys": ["physics", "physical"],
            "calc": ["calculus", "calc"],
            "precalc": ["precalculus", "pre-calculus", "pre calculus"],
            "bio": ["biology", "biological"],
            "micro": ["microbiology", "microeconomics"],
            "macro": ["macroeconomics", "macrobiology"],
            "econ": ["economics", "economic"],
            "psych": ["psychology", "psychological"],
            "soc": ["sociology", "social"],
            "anthro": ["anthropology"],
            "poli sci": ["political science", "politics"],
            "polisci": ["political science", "politics"],
            "comp sci": ["computer science", "computing"],
            "compsci": ["computer science", "computing"],
            "lit": ["literature", "literary"],
            "hist": ["history", "historical"],
            "geo": ["geography", "geological"],
            "stats": ["statistics", "statistical"],
            "trig": ["trigonometry"],
            "alg": ["algebra", "algebraic"],
            "eng": ["english", "engineering"],
            "chem": ["chemistry", "chemical"],
            "math": ["mathematics", "mathematical"]
        ]
        
        if let mappings = abbreviationMappings[lowercaseAbbrev] {
            for mapping in mappings {
                if lowercaseCourseName.contains(mapping) {
                    return true
                }
            }
        }
        
        if isAcronymMatch(courseName: lowercaseCourseName, abbreviation: lowercaseAbbrev) {
            return true
        }
        
        let courseWords = lowercaseCourseName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        for word in courseWords {
            if word.hasPrefix(lowercaseAbbrev) && lowercaseAbbrev.count >= 3 {
                return true
            }
        }
        
        return false
    }
    
    private func isAcronymMatch(courseName: String, abbreviation: String) -> Bool {
        let courseWords = courseName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty && $0.count > 2 }
        
        if courseWords.count < 2 || abbreviation.count < 2 {
            return false
        }
        
        let firstLetters = courseWords.map { String($0.first!) }.joined()
        return firstLetters.hasPrefix(abbreviation) || abbreviation.hasPrefix(firstLetters)
    }
    
    private func areWordsSimilar(_ word1: String, _ word2: String) -> Bool {
        if word1.count != word2.count {
            return false
        }
        
        if word1.count < 4 {
            return false
        }
        
        var differences = 0
        for (char1, char2) in zip(word1, word2) {
            if char1 != char2 {
                differences += 1
                if differences > 1 {
                    return false
                }
            }
        }
        
        return differences <= 1
    }
    
    private func extractAssignmentName(from text: String) -> String? {
        let assignmentKeywords = ["midterm", "final", "exam", "test", "quiz", "homework", "assignment", "project", "paper", "essay", "lab", "report", "presentation", "interview", "dentist", "doctor", "class", "lecture", "seminar", "workshop", "conference", "party", "event", "birthday", "anniversary", "vacation", "trip", "flight", "complete", "finish", "submit", "turn in", "hand in", "work on"]
        
        for keyword in assignmentKeywords {
            if text.contains(keyword) {
                if let range = text.range(of: "\(keyword)\\s+(\\d+)", options: .regularExpression) {
                    let match = String(text[range])
                    if let numberRange = match.range(of: "\\d+", options: .regularExpression) {
                        let number = String(match[numberRange])
                        return "\(keyword.capitalized) \(number)"
                    }
                }
                return keyword.capitalized
            }
        }
        return nil
    }
    
    private func extractEventTitle(from text: String) -> String {
        var title = text
        
        let startPhrases = ["remind me to ", "remind me ", "i have a ", "i have ", "need to ", "have to "]
        for phrase in startPhrases {
            if title.lowercased().hasPrefix(phrase) {
                title = String(title.dropFirst(phrase.count))
                break
            }
        }
        
        let timePatterns = [
            "\\s+(tomorrow|today).*$",
            "\\s+in\\s+\\d+(?:\\.\\d+)?(?:\\s+and\\s+a\\s+half)?\\s+(hour|hr|minute|min|day)s?.*$",
            "\\s+after\\s+\\d+(?:\\.\\d+)?\\s+(hour|hr|minute|min)s?.*$",
            "\\s+next\\s+\\w+.*$",
            "\\s+on\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday).*$",
            "\\s+this\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday).*$",
            "\\s+at\\s+\\d+.*$",
            "\\s+at\\s+\\d{1,2}:\\d{2}.*$",
            "\\s+at\\s+\\d{1,2}(am|pm).*$",
            "\\s+at\\s+\\d{1,2}:\\d{2}\\s*(am|pm).*$"
        ]
        
        for pattern in timePatterns {
            if let range = title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                title = String(title[..<range.lowerBound])
                break
            }
        }
        
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if title.isEmpty || title.count < 2 {
            if text.lowercased().contains("test") || text.lowercased().contains("exam") {
                title = "Test"
            } else if text.lowercased().contains("meeting") {
                title = "Meeting"
            } else if text.lowercased().contains("homework") {
                title = "Homework"
            } else {
                title = "Event"
            }
        }
        
        return title.prefix(1).uppercased() + title.dropFirst()
    }
    
    private func extractScheduleTitle(from text: String) -> String {
        var title = text
        
        let startPhrases = ["i have ", "i have a ", "i've got ", "i got ", "my ", "there's ", "there is "]
        for phrase in startPhrases {
            if title.lowercased().hasPrefix(phrase) {
                title = String(title.dropFirst(phrase.count))
                break
            }
        }
        
        let removePatterns = ["every ", "weekly ", "recurring ", "schedule ", "class ", "course ", "lecture ", "tutorial ", "lab ", "seminar "]
        for pattern in removePatterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        let timeAndDayPatterns = [
            "\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|weekday|weekdays|weekend|weekends|mwf|tth|tr).*$",
            "\\s+from\\s+\\d+.*$",
            "\\s+at\\s+\\d+.*$",
            "\\s+\\d{1,2}:\\d{2}.*$",
            "\\s+\\d{1,2}\\s*(am|pm).*$"
        ]
        
        for pattern in timeAndDayPatterns {
            if let range = title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                title = String(title[..<range.lowerBound])
                break
            }
        }
        
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let courseCodeRange = title.range(of: "\\b[A-Z]{2,4}\\d{3,4}\\b", options: .regularExpression) {
            return String(title[courseCodeRange])
        }
        
        let words = title.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .filter { word in
                let lowercaseWord = word.lowercased()
                return !["a", "an", "the", "is", "are", "of", "for", "in", "on", "at", "to", "from", "with", "by"].contains(lowercaseWord) &&
                       word.count >= 2
            }
        
        if !words.isEmpty {
            let firstWord = words[0]
            if firstWord.count >= 3 {
                title = firstWord.prefix(1).uppercased() + firstWord.dropFirst()
            } else {
                title = firstWord.uppercased()
            }
        }
        
        if title.isEmpty || title.count < 2 {
            title = "Class"
        }
        
        return title
    }
    
    private func extractDaysOfWeek(from text: String) -> Set<DayOfWeek> {
        let lowercased = text.lowercased()
        var days: Set<DayOfWeek> = []
        
        if lowercased.contains("weekday") || lowercased.contains("weekdays") {
            days.formUnion([.monday, .tuesday, .wednesday, .thursday, .friday])
            return days
        }
        
        if lowercased.contains("weekend") || lowercased.contains("weekends") {
            days.formUnion([.saturday, .sunday])
            return days
        }
        
        let dayMappings: [String: DayOfWeek] = [
            "monday": .monday, "tuesday": .tuesday, "wednesday": .wednesday,
            "thursday": .thursday, "friday": .friday, "saturday": .saturday, "sunday": .sunday
        ]
        
        for (dayName, dayEnum) in dayMappings {
            if lowercased.contains(dayName) {
                days.insert(dayEnum)
            }
        }
        
        if lowercased.contains("mwf") {
            days.formUnion([.monday, .wednesday, .friday])
        } else if lowercased.contains("tth") || lowercased.contains("tr") {
            days.formUnion([.tuesday, .thursday])
        }
        
        return days
    }
    
    private func extractScheduleTimes(from text: String) -> (start: DateComponents?, end: DateComponents?, duration: TimeInterval?) {
        var startTime: DateComponents? = nil
        var endTime: DateComponents? = nil
        var duration: TimeInterval? = nil
        
        if let fromToRange = text.range(of: "from\\s+(\\d{1,2}:\\d{2}(?:am|pm)?|\\d{1,2}(?:am|pm))\\s+to\\s+(\\d{1,2}:\\d{2}(?:am|pm)?|\\d{1,2}(?:am|pm))", options: .regularExpression) {
            let match = String(text[fromToRange])
            
            if let startRange = match.range(of: "from\\s+(\\d{1,2}:?\\d{0,2}(?:am|pm)?)", options: .regularExpression) {
                let startMatch = String(match[startRange])
                if let timeRange = startMatch.range(of: "\\d{1,2}:?\\d{0,2}(?:am|pm)?", options: .regularExpression) {
                    let timeString = String(startMatch[timeRange])
                    startTime = parseTimeString(timeString)
                }
            }
            
            if let endRange = match.range(of: "to\\s+(\\d{1,2}:?\\d{0,2}(?:am|pm)?)", options: .regularExpression) {
                let endMatch = String(match[endRange])
                if let timeRange = endMatch.range(of: "\\d{1,2}:?\\d{0,2}(?:am|pm)?", options: .regularExpression) {
                    let timeString = String(endMatch[timeRange])
                    endTime = parseTimeString(timeString)
                }
            }
        }
        else if let range = text.range(of: "(\\d{1,2})\\s*(am|pm)", options: .regularExpression) {
            let match = String(text[range])
            if let hourRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                let hourString = String(match[hourRange])
                if let hour = Int(hourString) {
                    var finalHour = hour
                    if match.lowercased().contains("pm") && hour != 12 {
                        finalHour = hour + 12
                    } else if match.lowercased().contains("am") && hour == 12 {
                        finalHour = 0
                    }
                    
                    startTime = DateComponents(hour: finalHour, minute: 0)
                }
            }
        }
        
        if let range = text.range(of: "(\\d+)\\s+(hour|hr)", options: .regularExpression) {
            let match = String(text[range])
            if let numberRange = match.range(of: "\\d+", options: .regularExpression) {
                let numberString = String(match[numberRange])
                if let hours = Int(numberString) {
                    duration = TimeInterval(hours * 3600)
                }
            }
        }
        
        return (start: startTime, end: endTime, duration: duration)
    }
    
    private func parseTimeString(_ timeString: String) -> DateComponents? {
        let cleaned = timeString.lowercased()
        
        if let range = cleaned.range(of: "(\\d{1,2}):(\\d{2})(am|pm)", options: .regularExpression) {
            let match = String(cleaned[range])
            let components = match.replacingOccurrences(of: "am", with: "").replacingOccurrences(of: "pm", with: "").components(separatedBy: ":")
            
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]) {
                
                var finalHour = hour
                if match.contains("pm") && hour != 12 {
                    finalHour = hour + 12
                } else if match.contains("am") && hour == 12 {
                    finalHour = 0
                }
                
                return DateComponents(hour: finalHour, minute: minute)
            }
        }
        
        if let range = cleaned.range(of: "(\\d{1,2})(am|pm)", options: .regularExpression) {
            let match = String(cleaned[range])
            if let hourRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                let hourString = String(match[hourRange])
                if let hour = Int(hourString) {
                    var finalHour = hour
                    if match.contains("pm") && hour != 12 {
                        finalHour = hour + 12
                    } else if match.contains("am") && hour == 12 {
                        finalHour = 0
                    }
                    
                    return DateComponents(hour: finalHour, minute: 0)
                }
            }
        }
        
        return nil
    }
    
    private func findBestCategoryMatch(from text: String, categories: [Category]) -> String? {
        let lowercased = text.lowercased()
        
        for category in categories {
            if lowercased.contains(category.name.lowercased()) {
                return category.name
            }
        }
        
        return nil
    }
    
    private func buildCategoryPrompt(for title: String, availableCategories: [Category], isRetry: Bool = false) -> String {
        let basePrompt = isRetry ? "I couldn't find that category. " : ""
        
        if availableCategories.isEmpty {
            return "\(basePrompt)What category should '\(title)' be in? (e.g., 'assignment', 'exam', 'personal', 'meeting')"
        } else {
            let categoryNames = availableCategories.prefix(5).map { $0.name }.joined(separator: ", ")
            return "\(basePrompt)What category should '\(title)' be in? Available categories: \(categoryNames)"
        }
    }
    
    private func findCategoryFromUserInput(_ input: String, availableCategories: [Category]) -> String? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for category in availableCategories {
            if lowercased == category.name.lowercased() || category.name.lowercased().contains(lowercased) || lowercased.contains(category.name.lowercased()) {
                return category.name
            }
        }
        
        let commonCategoryMappings: [String: String] = [
            "homework": "Assignment", "assignment": "Assignment", "test": "Exam", "exam": "Exam",
            "quiz": "Exam", "personal": "Personal", "meeting": "Meeting"
        ]
        
        for (keyword, categoryName) in commonCategoryMappings {
            if lowercased.contains(keyword) {
                if let existingCategory = availableCategories.first(where: { $0.name.lowercased() == categoryName.lowercased() }) {
                    return existingCategory.name
                } else {
                    return categoryName
                }
            }
        }
        
        let words = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        if words.count == 1, let singleWord = words.first, singleWord.count >= 3 {
            return singleWord.capitalized
        }
        
        return nil
    }
    
    private func isEventNotGrade(text: String) -> Bool {
        let strongEventIndicators = [
            "remind me", "in 5 hours", "in 1 hour", "tomorrow", "complete homework", 
            "finish homework", "submit", "turn in", "meeting", "appointment", 
            "next tuesday", "next monday", "next wednesday", "next thursday", 
            "next friday", "next saturday", "next sunday", "at 3pm", "at 4pm",
            "no reminder", "personal category", "in the"
        ]
        
        if isActualGradeContext(text) {
            return false
        }
        
        for indicator in strongEventIndicators {
            if text.contains(indicator) {
                return true
            }
        }
        
        if text.contains("got") {
            let eventContext = ["meeting", "appointment", "interview", "class", "lecture"]
            for context in eventContext {
                if text.contains(context) {
                    return true
                }
            }
            
            let timeContext = ["next", "tomorrow", "today", "at ", "pm", "am", "tuesday", "monday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            for context in timeContext {
                if text.contains(context) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func isActualGradeContext(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        let gradePatterns = [
            "got.*\\d+/\\d+.*on",
            "got.*\\d+%.*on",
            "got.*[a-f][+-]?.*on",
            "received.*\\d+/\\d+.*on",
            "received.*\\d+%.*on",
            "received.*[a-f][+-]?.*on",
            "scored.*\\d+/\\d+.*on",
            "scored.*\\d+%.*on",
            "earned.*\\d+/\\d+.*on",
            "earned.*\\d+%.*on"
        ]
        
        for pattern in gradePatterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        if containsGradePattern(lowercased) {
            let academicContext = ["exam", "test", "quiz", "assignment", "homework", "project", "midterm", "final"]
            for context in academicContext {
                if lowercased.contains(context) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func parseSpecificTime(from text: String) -> DateComponents? {
        let lowercased = text.lowercased()
        
        if let range = lowercased.range(of: "(\\d{1,2}):(\\d{2})\\s*(am|pm)?", options: .regularExpression) {
            let match = String(lowercased[range])
            let components = match.components(separatedBy: ":")
            
            if components.count >= 2,
               let hour = Int(components[0]),
               let minute = Int(components[1].prefix(2)) {
                
                var finalHour = hour
                if match.contains("pm") && hour != 12 {
                    finalHour = hour + 12
                } else if match.contains("am") && hour == 12 {
                    finalHour = 0
                }
                
                return DateComponents(hour: finalHour, minute: minute)
            }
        }
        
        if let range = lowercased.range(of: "(\\d{1,2})\\s*(am|pm)", options: .regularExpression) {
            let match = String(lowercased[range])
            if let hourRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                let hourString = String(match[hourRange])
                if let hour = Int(hourString) {
                    var finalHour = hour
                    if match.contains("pm") && hour != 12 {
                        finalHour = hour + 12
                    } else if match.contains("am") && hour == 12 {
                        finalHour = 0
                    }
                    
                    return DateComponents(hour: finalHour, minute: 0)
                }
            }
        }
        
        if let range = lowercased.range(of: "(\\d{1,2}):(\\d{2})", options: .regularExpression) {
            let match = String(lowercased[range])
            let components = match.components(separatedBy: ":")
            
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]),
               hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 {
                return DateComponents(hour: hour, minute: minute)
            }
        }
        
        return nil
    }
}
