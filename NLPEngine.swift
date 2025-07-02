//import Foundation
//
//// MARK: - Parse Results & Context
//enum NLPResult {
//    case parsedEvent(title: String, date: Date?, categoryName: String?, reminderTime: ReminderTime?)
//    case parsedScheduleItem(title: String, days: Set<DayOfWeek>, startTimeComponents: DateComponents?, endTimeComponents: DateComponents?, duration: TimeInterval?, reminderTime: ReminderTime?, colorHex: String?)
//    case parsedGrade(courseName: String, assignmentName: String, grade: String, weight: String?)
//    case needsMoreInfo(prompt: String, originalInput: String, context: ParseContext?, conversationId: UUID?)
//    case unrecognized(originalInput: String)
//    case notAttempted
//}
//
////enum ParseContext {
////    case gradeNeedsWeight(courseName: String, assignmentName: String, grade: String)
////    case gradeNeedsAssignmentName(courseName: String, grade: String)
////    case gradeNeedsCourse(assignmentName: String?, grade: String)
////    case eventNeedsDate(title: String, categoryName: String?, reminderTime: ReminderTime?)
////    case eventNeedsTime(title: String, date: Date, categoryName: String?, reminderTime: ReminderTime?)
////    case eventNeedsCategory(title: String, date: Date, reminderTime: ReminderTime?)
////    case eventNeedsReminder(title: String, date: Date, categoryName: String?)
////    case scheduleNeedsDays(title: String, startTime: DateComponents?, endTime: DateComponents?, duration: TimeInterval?)
////    case scheduleNeedsTime(title: String, days: Set<DayOfWeek>)
////    case scheduleNeedsEndTime(title: String, days: Set<DayOfWeek>, startTime: DateComponents)
////    case scheduleNeedsReminder(title: String, days: Set<DayOfWeek>, startTime: DateComponents?, endTime: DateComponents?, duration: TimeInterval?)
////    case scheduleNeedsColor(title: String, days: Set<DayOfWeek>, startTimeComponents: DateComponents?, endTimeComponents: DateComponents?, duration: TimeInterval?, reminderTime: ReminderTime?)
////    
////}
//
//// MARK: - NLP Engine
//class NLPEngine {
//    private var activeConversations: [UUID: Date] = [:]
//    private let conversationTimeout: TimeInterval = 300 // 5 minutes
//    
//    func parse(inputText: String, availableCategories: [Category] = [], existingCourses: [Course] = []) -> NLPResult {
//        let cleanInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !cleanInput.isEmpty else { return .notAttempted }
//        
//        cleanupExpiredConversations()
//        let lowerInput = cleanInput.lowercased()
//
//        // --- Prioritized Rules ---
//        
//        // Rule 1: Recurring Schedule (if "every" is present)
//        // "every" is a strong indicator for a schedule.
//        if lowerInput.contains("every") {
//            if let scheduleResult = tryParseSchedule(cleanInput, categories: availableCategories) {
//                // tryParseSchedule will return .needsMoreInfo if it identifies a schedule but needs details.
//                if resultIsNotUnrecognizedOrNotAttempted(scheduleResult) {
//                    return scheduleResult
//                }
//            }
//            // If "every" is present but tryParseSchedule failed to give a conclusive result,
//            // (e.g., returned nil or .unrecognized, though current tryParseSchedule is unlikely to do this if "every" passes its initial guard)
//            // we let it fall through. Other more specific rules (like grade) might still apply,
//            // or it will eventually be caught by the final .unrecognized.
//        }
//        
//        // Calculate dateRefWasFound after the "every" check, for use in subsequent rules.
//        let dateRefWasFound = hasDateReference(lowerInput)
//
//        // Rule 2: Explicit Grade Markers (e.g., %, or very specific grade patterns)
//        // This runs if "every" wasn't parsed as a schedule above, or if "every" wasn't present.
//        if lowerInput.contains("%") || containsActualGradePattern(lowerInput) {
//            if let gradeResult = tryParseGrade(cleanInput, courses: existingCourses, isConfidentParse: true) {
//                if resultIsNotUnrecognizedOrNotAttempted(gradeResult) { return gradeResult }
//            }
//        }
//        
//        // Rule 3: Likely Event (if date/time is present and "every" was NOT in the input)
//        // This ensures that if "every" was present (even if schedule parsing failed above),
//        // we don't immediately try to parse it as a simple event here.
//        if dateRefWasFound && !lowerInput.contains("every") {
//            if let eventResult = tryParseEvent(cleanInput, categories: availableCategories) {
//                 if resultIsNotUnrecognizedOrNotAttempted(eventResult) { return eventResult }
//            }
//        }
//
//        // --- Fallback / Broader Checks for inputs NOT containing "every" (or if "every" parsing failed) ---
//        // This block primarily targets inputs that did NOT contain "every".
//        // If "every" was present but failed both schedule and grade parsing above, it might also reach here,
//        // but it's less likely to be a standard event/schedule if `tryParseSchedule` already failed with "every".
//        if !lowerInput.contains("every") {
//            // Fallback for inputs with a date reference that weren't conclusively parsed as an event or grade yet.
//            if dateRefWasFound {
//                // Rule 3 already attempted event parsing. If it was inconclusive, try event again (broader attempt)
//                // then schedule (for non-recurring scheduled items).
//                if let eventResult = tryParseEvent(cleanInput, categories: availableCategories) {
//                    if resultIsNotUnrecognizedOrNotAttempted(eventResult) { return eventResult }
//                }
//                if let scheduleResult = tryParseSchedule(cleanInput, categories: availableCategories) {
//                     if resultIsNotUnrecognizedOrNotAttempted(scheduleResult) { return scheduleResult }
//                }
//            }
//
//            // Fallback: Try Grade (more conservative parse)
//            if let gradeResult = tryParseGrade(cleanInput, courses: existingCourses, isConfidentParse: false) {
//                if resultIsNotUnrecognizedOrNotAttempted(gradeResult) { return gradeResult }
//            }
//
//            // Fallback: For inputs without a date reference (or if date-based parsing above failed)
//            if !dateRefWasFound {
//                if let eventResult = tryParseEvent(cleanInput, categories: availableCategories) {
//                     if resultIsNotUnrecognizedOrNotAttempted(eventResult) { return eventResult }
//                }
//                if let scheduleResult = tryParseSchedule(cleanInput, categories: availableCategories) {
//                    if resultIsNotUnrecognizedOrNotAttempted(scheduleResult) { return scheduleResult }
//                }
//            }
//        }
//        
//        return .unrecognized(originalInput: inputText)
//    }
//    
//    func parseFollowUp(inputText: String, context: ParseContext, conversationId: UUID?, availableCategories: [Category] = [], existingCourses: [Course] = []) -> NLPResult {
//        let cleanInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        // Handle cancellation
//        if cleanInput.lowercased().contains("cancel") || cleanInput.lowercased().contains("nevermind") {
//            return .unrecognized(originalInput: "Cancelled")
//        }
//        
//        switch context {
//        // MARK: - Grade Follow-ups
//        case .gradeNeedsWeight(let courseName, let assignmentName, let grade):
//            if let weight = extractWeight(from: cleanInput, isFollowUpQuery: true) {
//                return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
//            } else if cleanInput.lowercased().contains("skip") || cleanInput.lowercased().contains("no weight") {
//                return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: nil)
//            } else {
//                return .needsMoreInfo(prompt: "Please enter the weight as a percentage (e.g., '20%') or say 'skip':", originalInput: cleanInput, context: context, conversationId: conversationId)
//            }
//            
//        case .gradeNeedsAssignmentName(let courseName, let grade):
//            let assignmentName = cleanInput.isEmpty ? "Assignment" : cleanInput
//            let conversationId = startNewConversation()
//            return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip'):", originalInput: cleanInput, context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignmentName, grade: grade), conversationId: conversationId)
//            
//        case .gradeNeedsCourse(let assignmentName, let grade):
//            if let course = findBestCourseMatch(cleanInput, courses: existingCourses) {
//                let finalAssignment = assignmentName ?? "Assignment"
//                let conversationId = startNewConversation()
//                return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip'):", originalInput: cleanInput, context: .gradeNeedsWeight(courseName: course.name, assignmentName: finalAssignment, grade: grade), conversationId: conversationId)
//            } else {
//                let availableCourses = existingCourses.prefix(5).map { $0.name }.joined(separator: ", ")
//                return .needsMoreInfo(prompt: "Course not found. Please choose from: \(availableCourses)", originalInput: cleanInput, context: context, conversationId: conversationId)
//            }
//            
//        // MARK: - Event Follow-ups
//        case .eventNeedsDate(let title, let categoryName, let reminderTime):
//            if let date = parseDate(from: cleanInput) {
//                if let category = categoryName, let reminder = reminderTime {
//                    return .parsedEvent(title: title, date: date, categoryName: category, reminderTime: reminder)
//                } else if let category = categoryName {
//                    let conversationId = startNewConversation()
//                    return .needsMoreInfo(prompt: "When would you like to be reminded about '\(title)'? (e.g., '15 minutes before', 'no reminder'):", originalInput: cleanInput, context: .eventNeedsReminder(title: title, date: date, categoryName: category), conversationId: conversationId)
//                } else {
//                    let conversationId = startNewConversation()
//                    return .needsMoreInfo(prompt: "What category should '\(title)' be in? \(buildCategoryPrompt(availableCategories)):", originalInput: cleanInput, context: .eventNeedsCategory(title: title, date: date, reminderTime: reminderTime), conversationId: conversationId)
//                }
//            } else {
//                return .needsMoreInfo(prompt: "I couldn't understand that date. Try formats like 'tomorrow', 'next Monday', or 'December 15':", originalInput: cleanInput, context: context, conversationId: conversationId)
//            }
//            
//        case .eventNeedsTime(let title, let date, let categoryName, let reminderTime):
//            if let timeComponents = parseTime(from: cleanInput) {
//                let calendar = Calendar.current
//                let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 12, minute: timeComponents.minute ?? 0, second: 0, of: date) ?? date
//                
//                if let category = categoryName, let reminder = reminderTime {
//                    return .parsedEvent(title: title, date: finalDate, categoryName: category, reminderTime: reminder)
//                } else if let category = categoryName {
//                    let conversationId = startNewConversation()
//                    return .needsMoreInfo(prompt: "When would you like to be reminded about '\(title)'? (e.g., '15 minutes before', 'no reminder'):", originalInput: cleanInput, context: .eventNeedsReminder(title: title, date: finalDate, categoryName: category), conversationId: conversationId)
//                } else {
//                    let conversationId = startNewConversation()
//                    return .needsMoreInfo(prompt: "What category should '\(title)' be in? \(buildCategoryPrompt(availableCategories)):", originalInput: cleanInput, context: .eventNeedsCategory(title: title, date: finalDate, reminderTime: reminderTime), conversationId: conversationId)
//                }
//            } else {
//                return .needsMoreInfo(prompt: "Please enter a time (e.g., '3:30 PM', '9am', '14:00'):", originalInput: cleanInput, context: context, conversationId: conversationId)
//            }
//            
//        case .eventNeedsCategory(let title, let date, let reminderTime):
//            if let categoryName = findCategoryMatch(cleanInput, categories: availableCategories) {
//                if let reminder = reminderTime {
//                    return .parsedEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminder)
//                } else {
//                    let conversationId = startNewConversation()
//                    return .needsMoreInfo(prompt: "When would you like to be reminded about '\(title)'? (e.g., '15 minutes before', 'no reminder'):", originalInput: cleanInput, context: .eventNeedsReminder(title: title, date: date, categoryName: categoryName), conversationId: conversationId)
//                }
//            } else {
//                return .needsMoreInfo(prompt: "Category not found. \(buildCategoryPrompt(availableCategories)):", originalInput: cleanInput, context: context, conversationId: conversationId)
//            }
//            
//        case .eventNeedsReminder(let title, let date, let categoryName):
//            let reminderTime = parseReminderTime(from: cleanInput)
//            return .parsedEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminderTime)
//            
//        // MARK: - Schedule Follow-ups
//        case .scheduleNeedsDays(let title, let startTime, let endTime, let duration):
//            let days = extractDaysOfWeek(from: cleanInput)
//            if !days.isEmpty {
//                if let start = startTime {
//                    if endTime != nil || duration != nil {
//                        let conversationId = startNewConversation()
//                        return .needsMoreInfo(prompt: "Would you like a reminder for '\(title)'? (e.g., '15 minutes before', 'no'):", originalInput: cleanInput, context: .scheduleNeedsReminder(title: title, days: days, startTime: start, endTime: endTime, duration: duration), conversationId: conversationId)
//                    } else {
//                        let conversationId = startNewConversation()
//                        return .needsMoreInfo(prompt: "When does '\(title)' end? (e.g., 'to 11am', 'for 1 hour'):", originalInput: cleanInput, context: .scheduleNeedsEndTime(title: title, days: days, startTime: start), conversationId: conversationId)
//                    }
//                } else {
//                    let conversationId = startNewConversation()
//                    return .needsMoreInfo(prompt: "What time does '\(title)' start? (e.g., '9am', 'at 10:30'):", originalInput: cleanInput, context: .scheduleNeedsTime(title: title, days: days), conversationId: conversationId)
//                }
//            } else {
//                return .needsMoreInfo(prompt: "Please specify days (e.g., 'Monday and Wednesday', 'MWF', 'weekdays'):", originalInput: cleanInput, context: context, conversationId: conversationId)
//            }
//            
//        case .scheduleNeedsTime(let title, let days):
//            if let startTime = parseTime(from: cleanInput) {
//                let conversationId = startNewConversation()
//                return .needsMoreInfo(prompt: "When does '\(title)' end? (e.g., 'to 11am', 'for 1 hour'):", originalInput: cleanInput, context: .scheduleNeedsEndTime(title: title, days: days, startTime: startTime), conversationId: conversationId)
//            } else {
//                return .needsMoreInfo(prompt: "Please enter a start time (e.g., '9am', '10:30', '14:00'):", originalInput: cleanInput, context: context, conversationId: conversationId)
//            }
//            
//        case .scheduleNeedsEndTime(let title, let days, let startTime):
//            let endTime = parseTime(from: cleanInput)
//            let duration = extractDuration(from: cleanInput)
//            
//            if endTime != nil || duration != nil {
//                let conversationId = startNewConversation()
//                return .needsMoreInfo(prompt: "Would you like a reminder for '\(title)'? (e.g., '15 minutes before', 'no'):", originalInput: cleanInput, context: .scheduleNeedsReminder(title: title, days: days, startTime: startTime, endTime: endTime, duration: duration), conversationId: conversationId)
//            } else {
//                return .needsMoreInfo(prompt: "When does '\(title)' end? (e.g., 'to 11am', 'for 1 hour', 'ends at 3pm'):", originalInput: cleanInput, context: context, conversationId: conversationId)
//            }
//            
//        case .scheduleNeedsReminder(let title, let days, let startTime, let endTime, let duration):
//            let reminderTime = parseReminderTime(from: cleanInput)
//            let conversationId = startNewConversation() // Or ensure conversationId is passed if continuing
//            return .needsMoreInfo(
//                prompt: "What color would you like for '\(title)'? (e.g., 'blue', '#FF0000', or 'skip'):",
//                originalInput: cleanInput, // User's input for reminder, context carries forward schedule details
//                context: .scheduleNeedsColor(
//                    title: title,
//                    days: days,
//                    startTimeComponents: startTime,
//                    endTimeComponents: endTime,
//                    duration: duration,
//                    reminderTime: reminderTime
//                ),
//                conversationId: conversationId
//            )
//
//        case .scheduleNeedsColor(let title, let days, let startTimeComponents, let endTimeComponents, let duration, let reminderTime):
//            if cleanInput.lowercased().contains("skip") || cleanInput.lowercased().contains("no color") || cleanInput.lowercased().contains("none") {
//                return .parsedScheduleItem(title: title, days: days, startTimeComponents: startTimeComponents, endTimeComponents: endTimeComponents, duration: duration, reminderTime: reminderTime, colorHex: nil)
//            }
//            
//            if let colorHex = extractColor(from: cleanInput) {
//                return .parsedScheduleItem(title: title, days: days, startTimeComponents: startTimeComponents, endTimeComponents: endTimeComponents, duration: duration, reminderTime: reminderTime, colorHex: colorHex)
//            } else {
//                // Re-prompt if color is not recognized and not skipped
//                return .needsMoreInfo(
//                    prompt: "Sorry, I didn't recognize that color. Try a common color name (e.g., 'red', 'blue'), a hex code (e.g., '#FFCC00'), or say 'skip':",
//                    originalInput: cleanInput,
//                    context: context, // Keep the same context to retry
//                    conversationId: conversationId
//                )
//            }
//        }
//    }
//    
//    // MARK: - Grade Parsing (Modified for Strictness)
//    private func tryParseGrade(_ input: String, courses: [Course], isConfidentParse: Bool) -> NLPResult? {
//        let lowerInput = input.lowercased()
//        let hasActualGradePattern = containsActualGradePattern(lowerInput) // Checks for %, A+, X/Y
//
//        // If it has a date reference, it should NOT be parsed as a grade
//        // UNLESS it ALSO has an actual, undeniable grade pattern (e.g., "got 95% on test tmrw" - unlikely phrasing, but pattern is key)
//        // OR if this is a confident parse call (e.g. from Rule 1 due to '%').
//        if hasDateReference(lowerInput) && !hasActualGradePattern && !isConfidentParse {
//            return nil // e.g., "math test on monday" is an event.
//        }
//
//        // Strong, direct grade keywords
//        let strongKeywords = ["grade for", "score for", "grade in", "score in", "gpa", "received"]
//        let hasStrongKeyword = strongKeywords.contains { lowerInput.contains($0) }
//        
//        // Weaker keywords that are only considered if a grade pattern is also present, or if it's a confident parse.
//        let weakerKeywords = ["test", "quiz", "exam", "assignment", "homework", "essay", "paper"]
//        let hasWeakerKeyword = weakerKeywords.contains { lowerInput.contains($0) }
//
//        // Determine likelihood of being a grade
//        var isLikelyGrade = hasActualGradePattern || hasStrongKeyword
//        if !isLikelyGrade && hasWeakerKeyword && (isConfidentParse || hasActualGradePattern) {
//            isLikelyGrade = true
//        }
//        
//        if !isLikelyGrade && lowerInput.contains("got") && hasWeakerKeyword {
//            if extractGrade(from: input) != nil {
//                isLikelyGrade = true
//            } else if !hasDateReference(lowerInput) {
//                 // let it try to extract, if extractGrade fails, it will return nil.
//            } else {
//                return nil
//            }
//        }
//
//
//        guard isLikelyGrade else { return nil }
//        
//        // AND we have an actual grade pattern or a strong keyword, we should ask for the grade value.
//        guard let grade = extractGrade(from: input) else {
//            if hasActualGradePattern || hasStrongKeyword { // if "B+" was found, or "received"
//                 let conversationId = startNewConversation()
//                 // Construct a context that we're missing the grade value, but know it's a grade entry.
//                 // For now, prompt directly. A more specific context could be added.
//                 let tempCourseName = findBestCourseMatch(input, courses: courses)?.name
//                 let tempAssignmentName = extractAssignmentName(from: input, forGradeContext: true)
//
//                 if let cName = tempCourseName, let aName = tempAssignmentName {
//                    return .needsMoreInfo(prompt: "What was the grade for '\(aName)' in '\(cName)'? (e.g., '95%', 'B+'):", originalInput: input, context: .gradeNeedsWeight(courseName: cName, assignmentName: aName, grade: ""), conversationId: conversationId) // Grade is empty, will be filled.
//                 } else if let cName = tempCourseName {
//                     return .needsMoreInfo(prompt: "What was the grade for the assignment in '\(cName)'? (e.g., '95%', 'B+'):", originalInput: input, context: .gradeNeedsAssignmentName(courseName: cName, grade: ""), conversationId: conversationId)
//                 }
//                // Fallback prompt if not enough info for context
//                return .needsMoreInfo(prompt: "What was the grade you received? (e.g., '95%', 'A+', '87/100'):", originalInput: input, context: nil, conversationId: conversationId)
//            }
//            return nil // Not enough evidence to ask for a grade value if no actual pattern/strong keyword
//        }
//        
//        let courseName = findBestCourseMatch(input, courses: courses)
//        let assignmentName = extractAssignmentName(from: input, forGradeContext: true) // Pass context
//        let weight = extractWeight(from: input, isFollowUpQuery: false)
//        
//        let conversationId = startNewConversation()
//        
//        if let course = courseName, let assignment = assignmentName {
//            if weight != nil {
//                return .parsedGrade(courseName: course.name, assignmentName: assignment, grade: grade, weight: weight)
//            } else {
//                return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip'):", originalInput: input, context: .gradeNeedsWeight(courseName: course.name, assignmentName: assignment, grade: grade), conversationId: conversationId)
//            }
//        } else if let course = courseName {
//            return .needsMoreInfo(prompt: "What's the name of this assignment in \(course.name)?", originalInput: input, context: .gradeNeedsAssignmentName(courseName: course.name, grade: grade), conversationId: conversationId)
//        } else if courses.isEmpty {
//             return .needsMoreInfo(prompt: "No courses found. Please add some courses first.", originalInput: input, context: nil, conversationId: conversationId)
//        } else {
//            let courseList = courses.prefix(5).map { $0.name }.joined(separator: ", ")
//            return .needsMoreInfo(prompt: "Which course is this grade for? Available: \(courseList)", originalInput: input, context: .gradeNeedsCourse(assignmentName: assignmentName, grade: grade), conversationId: conversationId)
//        }
//    }
//
//    private func extractAssignmentName(from input: String, forGradeContext: Bool) -> String? { // Added forGradeContext
//        let lowerInput = input.lowercased()
//        // If not for a grade context, be more general. For grades, be more specific to academic items.
//        let types = forGradeContext ?
//            ["test", "quiz", "exam", "homework", "assignment", "project", "paper", "lab", "midterm", "final", "essay"] :
//            ["meeting", "appointment", "presentation", "call", "event"] // More general types for events
//
//        for type in types {
//            if lowerInput.contains(type) {
//                let pattern = "\\b\(type)\\s*(\\d+|#\\d+)?\\b" // Ensure "type" is a whole word
//                if let range = lowerInput.range(of: pattern, options: .regularExpression) {
//                    let match = String(lowerInput[range])
//                    if let numberRange = match.range(of: "\\d+", options: .regularExpression) {
//                        let number = String(match[numberRange])
//                        return "\(type.capitalized) \(number)"
//                    }
//                    // If "type" itself is an item like "exam"
//                    if type.count > 2 { // Avoid single letters like "a"
//                         let potentialTitle = type.capitalized
//                         // Check if this type is followed by more descriptive words not part of typical details
//                         let substringAfterType = String(lowerInput[lowerInput.range(of: type)!.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
//                         if !substringAfterType.isEmpty && !hasDateReference(" "+substringAfterType) && !substringAfterType.starts(with: "with ") {
//                             // Consider if the "type" is part of a larger name, e.g. "final exam project"
//                             // This needs more sophisticated title extraction logic, for now, just return type
//                         }
//                         return potentialTitle
//                    }
//                } else if lowerInput.contains(type) && type.count > 2 { // Simpler contains check if regex fails
//                     return type.capitalized
//                }
//            }
//        }
//        // Fallback: If it's a grade context and no specific assignment type, but course was found.
//        if forGradeContext && findBestCourseMatch(input, courses: []) != nil { // Pass empty courses if only checking name match
//            return "Assignment" // Default
//        }
//        return nil
//    }
//    
//    // MARK: - Schedule Parsing (Simplified)
//    private func tryParseSchedule(_ input: String, categories: [Category]) -> NLPResult? {
//        let lowerInput = input.lowercased()
//        
//        // Primary rule: Must contain "every" for recurring events
//        // Secondary indicators
//        let scheduleKeywords = ["class", "course", "lecture", "weekly", "recurring", "schedule"]
//        let dayKeywords = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "mwf", "tth", "weekdays"]
//        
//        let hasScheduleKeyword = scheduleKeywords.contains { lowerInput.contains($0) }
//        let hasDayKeyword = dayKeywords.contains { lowerInput.contains($0) }
//        let hasTimeRange = lowerInput.contains("from") && (lowerInput.contains("to") || lowerInput.contains("-"))
//        
//        // Must have "every" OR strong schedule indicators
//        guard lowerInput.contains("every") || hasScheduleKeyword || (hasDayKeyword && hasTimeRange) else { return nil }
//        
//        let title = extractTitle(from: input, type: .schedule)
//        let days = extractDaysOfWeek(from: input)
//        let times = extractScheduleTimes(from: input)
//        
//        let conversationId = startNewConversation()
//        
//        // Check what's missing
//        if days.isEmpty {
//            return .needsMoreInfo(prompt: "What days is '\(title)' on? (e.g., 'Monday and Wednesday', 'MWF', 'weekdays'):", originalInput: input, context: .scheduleNeedsDays(title: title, startTime: times.start, endTime: times.end, duration: times.duration), conversationId: conversationId)
//        }
//        
//        if times.start == nil {
//            return .needsMoreInfo(prompt: "What time does '\(title)' start? (e.g., '9am', 'at 10:30'):", originalInput: input, context: .scheduleNeedsTime(title: title, days: days), conversationId: conversationId)
//        }
//        
//        if times.end == nil && times.duration == nil {
//            return .needsMoreInfo(prompt: "When does '\(title)' end? (e.g., 'to 11am', 'for 1 hour'):", originalInput: input, context: .scheduleNeedsEndTime(title: title, days: days, startTime: times.start!), conversationId: conversationId)
//        }
//        
//        // Ask for reminder
//        return .needsMoreInfo(prompt: "Would you like a reminder for '\(title)'? (e.g., '15 minutes before', 'no'):", originalInput: input, context: .scheduleNeedsReminder(title: title, days: days, startTime: times.start, endTime: times.end, duration: times.duration), conversationId: conversationId)
//    }
//    
//    
//    // MARK: - Event Parsing (Simplified)
//    private func tryParseEvent(_ input: String, categories: [Category]) -> NLPResult? {
//        let lowerInput = input.lowercased()
//        
//        // Assuming extractTitle and parseDate/parseTime are robust after previous fixes
//        let title = extractTitle(from: input, type: .event)
//        let date = parseDate(from: input)
//        let time = parseTime(from: input)
//        let extractedReminder = extractReminderTime(from: input) // Reminder from the initial phrase
//        
//        var finalDate = date
//        if let d = date, let t = time {
//            let calendar = Calendar.current
//            finalDate = calendar.date(bySettingHour: t.hour ?? 12, minute: t.minute ?? 0, second: 0, of: d)
//        } else if date != nil && time == nil {
//            // Date is present, but no specific time was parsed (e.g., "event tomorrow")
//            // finalDate will correctly be just the date part; time will be asked for below if not "all day"
//        }
//
//        let conversationId = startNewConversation()
//
//        // 1. Check if Date is missing
//        if finalDate == nil {
//            return .needsMoreInfo(prompt: "When is '\(title)'? (e.g., 'tomorrow at 3pm', 'next Monday', 'December 15'):",
//                                  originalInput: input,
//                                  context: .eventNeedsDate(title: title, categoryName: nil, reminderTime: extractedReminder),
//                                  conversationId: conversationId)
//        }
//
//        // 2. Check if Time is missing (and it's not an all-day event)
//        // finalDate is guaranteed to be non-nil here.
//        // We check `date` to ensure a date was initially parsed before asking for its time.
//        if date != nil && time == nil && !lowerInput.contains("all day") {
//            return .needsMoreInfo(prompt: "What time is '\(title)'? (e.g., '3:30 PM', '9am'):",
//                                  originalInput: input,
//                                  context: .eventNeedsTime(title: title, date: date!, categoryName: nil, reminderTime: extractedReminder),
//                                  conversationId: conversationId)
//        }
//        
//        // At this point, finalDate is resolved (either with a specific time, or it's an all-day event for a given date)
//
//        // 3. Determine Category
//        var identifiedCategoryName: String? = nil
//
//        // Step 3a: Check if the input string explicitly contains the name of one of the user's existing categories.
//        if !categories.isEmpty {
//            for cat in categories {
//                if lowerInput.contains(cat.name.lowercased()) {
//                    identifiedCategoryName = cat.name // User explicitly mentioned an existing category
//                    break
//                }
//            }
//        }
//
//        // Step 3b: If no explicit category from the user's list was mentioned,
//        // AND the user actually has categories to choose from, then ask for the category.
//        if identifiedCategoryName == nil && !categories.isEmpty {
//            return .needsMoreInfo(prompt: "What category should '\(title)' be in? \(buildCategoryPrompt(categories)):",
//                                  originalInput: input,
//                                  context: .eventNeedsCategory(title: title, date: finalDate!, reminderTime: extractedReminder),
//                                  conversationId: conversationId)
//        }
//
//        // Step 3c: If identifiedCategoryName is STILL nil at this point, it means either:
//        //   - User has no categories defined (so !categories.isEmpty was false).
//        //   - Or, the logic will proceed to follow-up (but this is initial parse).
//        // In the case where the user has no categories, we attempt to infer one using general keywords.
//        if identifiedCategoryName == nil {
//            identifiedCategoryName = findCategoryMatch(input, categories: categories)
//        }
//
//        // 4. Check for Reminder
//        // If reminderTime was not specified in the initial input, then ask.
//        if extractedReminder == nil {
//            return .needsMoreInfo(prompt: "When would you like to be reminded about '\(title)'? (e.g., '15 minutes before', 'no reminder'):",
//                                  originalInput: input,
//                                  context: .eventNeedsReminder(title: title, date: finalDate!, categoryName: identifiedCategoryName),
//                                  conversationId: conversationId)
//        }
//        
//        // All necessary information (title, date, time, category, reminder) is gathered.
//        return .parsedEvent(title: title, date: finalDate, categoryName: identifiedCategoryName, reminderTime: extractedReminder)
//    }
//        
//    // MARK: - Extraction Helper Functions
//    private enum TitleType {
//        case event, schedule
//    }
//    
//    private func extractTitle(from input: String, type: TitleType) -> String {
//        let originalTextForFallback = input
//        var textToProcess = input
//        let lowercasedInput = textToProcess.lowercased()
//
//        // 1. Define Anchor Patterns: phrases that typically precede the actual event name.
//        let anchorStarters = [
//            "yo croski i got a ", "yo croski i have an ", "yo croski i have a ",
//            "i'm going to have a ", "i am going to have a ",
//            "remind me to ", "remind me about ",
//            "i need to ", "i have to ", "i want to ", "i would like to ",
//            "set up a ", "schedule a ", "create an ", "add an ", "book a ",
//            "got an ", "got a ",
//            "have an ", "have a ",
//            "the ", "an ", "a ",
//            "my ", "your ", "his ", "her ", "its ", "our ", "their "
//        ]
//
//        var lastFoundAnchorEndIndex: String.Index? = nil
//
//        for starter in anchorStarters {
//            var searchStartIndex = lowercasedInput.startIndex
//            while searchStartIndex < lowercasedInput.endIndex {
//                if let range = lowercasedInput.range(of: starter, options: .literal, range: searchStartIndex..<lowercasedInput.endIndex) {
//                    if lastFoundAnchorEndIndex == nil || range.upperBound > lastFoundAnchorEndIndex! {
//                        lastFoundAnchorEndIndex = range.upperBound
//                    }
//                    searchStartIndex = range.upperBound
//                } else {
//                    break
//                }
//            }
//        }
//        
//        if let anchorEnd = lastFoundAnchorEndIndex {
//            let offset = lowercasedInput.distance(from: lowercasedInput.startIndex, to: anchorEnd)
//            if offset < textToProcess.count {
//                textToProcess = String(textToProcess.dropFirst(offset)).trimmingCharacters(in: .whitespacesAndNewlines)
//            }
//        }
//
//        // 2. Remove trailing details (end markers) from the (potentially) stripped phrase.
//        let endMarkers = [
//            " on ", " at ", " for ", " from ", " to ", " until ", " by ", " with ", " about ",
//            " today", " tonight", " tomorrow", " tmrw",
//            " next week", " next month", " this week", " this month",
//            " every", " each", // Added " every" and " each"
//            " monday", " tuesday", " wednesday", " thursday", " friday", " saturday", " sunday",
//            ", no reminder", " no reminder",
//            ", exam category", " exam category",
//            ", personal category", " personal category",
//            " category",
//            " reminder"
//        ]
//
//        var earliestEndMarkerActualPosition: String.Index? = nil
//        var textForEndMarkerCheck = textToProcess
//        let currentTextForEndMarkerCheckLowercased = textForEndMarkerCheck.lowercased()
//
//        for marker in endMarkers {
//            var patternToSearch = marker
//            if !marker.starts(with: ",") && !marker.starts(with: " ") {
//                 patternToSearch = " " + marker
//            }
//
//            if let range = currentTextForEndMarkerCheckLowercased.range(of: patternToSearch) {
//                // let isActualBoundary = range.lowerBound == currentTextForEndMarkerCheckLowercased.startIndex ||
//                //                       currentTextForEndMarkerCheckLowercased[currentTextForEndMarkerCheckLowercased.index(before: range.lowerBound)].isWhitespace
//                
//                // if isActualBoundary {
//                    if earliestEndMarkerActualPosition == nil || range.lowerBound < earliestEndMarkerActualPosition! {
//                        earliestEndMarkerActualPosition = range.lowerBound
//                    }
//                 // }
//            }
//            if marker.starts(with: " ") {
//                let markerWithoutLeadingSpace = String(marker.dropFirst())
//                 if let range = currentTextForEndMarkerCheckLowercased.range(of: markerWithoutLeadingSpace), range.lowerBound == currentTextForEndMarkerCheckLowercased.startIndex {
//                     if earliestEndMarkerActualPosition == nil || range.lowerBound < earliestEndMarkerActualPosition! {
//                        earliestEndMarkerActualPosition = range.lowerBound
//                    }
//                 }
//            }
//        }
//        
//        if let endPositionInLower = earliestEndMarkerActualPosition {
//            let distance = currentTextForEndMarkerCheckLowercased.distance(from: currentTextForEndMarkerCheckLowercased.startIndex, to: endPositionInLower)
//            if distance >= 0 {
//                let actualEndIndex = textToProcess.index(textToProcess.startIndex, offsetBy: distance, limitedBy: textToProcess.endIndex) ?? textToProcess.endIndex
//                textToProcess = String(textToProcess.prefix(upTo: actualEndIndex))
//            }
//        }
//        
//        textToProcess = textToProcess.trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        if textToProcess.isEmpty {
//            let commonWords = ["yo","croski","i","got","a","an","the","to","for","on","at","my","me","is","are","was","were"]
//            let dateFluffWords = [
//                "today", "tonight", "tomorrow", "tmrw",
//                "mon", "tue", "tues", "wed", "thu", "thurs", "fri", "sat", "sun",
//                "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
//            ]
//
//            var significantWords = originalTextForFallback.components(separatedBy: .whitespacesAndNewlines)
//                .filter { !$0.isEmpty && !commonWords.contains($0.lowercased()) }
//            
//            significantWords = significantWords.filter { !dateFluffWords.contains($0.lowercased()) }
//            
//            significantWords = Array(significantWords.prefix(4))
//        
//            if !significantWords.isEmpty {
//                textToProcess = significantWords.joined(separator: " ")
//            } else {
//                return type == .event ? "Event" : (type == .schedule ? "Class" : "Item")
//            }
//        }
//        
//        let words = textToProcess.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
//        if words.isEmpty {
//             return type == .event ? "Event" : (type == .schedule ? "Class" : "Item")
//        }
//
//        let capitalizedWords = words.map { word -> String in
//            let lowerWord = word.lowercased()
//            if words.count > 1 && words.first?.lowercased() != lowerWord &&
//               ["a", "an", "the", "of", "in", "on", "at", "to", "for", "with", "by", "from", "and", "or", "but"].contains(lowerWord) {
//                return lowerWord
//            }
//            return word.prefix(1).uppercased() + word.dropFirst().lowercased()
//        }
//        textToProcess = capitalizedWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
//
//        return textToProcess.isEmpty ? (type == .event ? "Event" : "Class") : textToProcess
//    }
//
//    private func containsGradePattern(_ text: String) -> Bool {
//        let patterns = [
//            "\\d+%",           // 95%
//            "\\b[A-F][+-]?\\b",
//            "\\d+/\\d+",       // 85/100
//            "\\b\\d{1,3}\\b"   // Just numbers that could be grade
//        ]
//        
//        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
//    }
//    
//    private func extractGrade(from input: String) -> String? {
//        // Order matters: more specific patterns first.
//        let lowerInput = input.lowercased()
//
//        // Pattern: 90 percent, 85 percent (extracts "number%")
//        if let range = lowerInput.range(of: "(\\d+(\\.\\d+)?)\\s+percent", options: .regularExpression) {
//            if let numberRange = lowerInput.range(of: "\\d+(\\.\\d+)?", options: .regularExpression, range: range) {
//                return String(lowerInput[numberRange]) + "%"
//            }
//        }
//
//        // Pattern: 95%
//        if let range = input.range(of: "\\d+(\\.\\d+)?%", options: .regularExpression) {
//            return String(input[range])
//        }
//        
//        // Pattern: A, B+, C- etc. (already good)
//        if let range = input.range(of: "\\b[A-F][+-]?\\b", options: .regularExpression) {
//            return String(input[range]).uppercased()
//        }
//        
//        // Pattern: 85/100 or 85 / 100
//        if let range = input.range(of: "(\\d+(\\.\\d+)?)\\s*/\\s*(\\d+(\\.\\d+)?)", options: .regularExpression) {
//            let fractionString = String(input[range]).replacingOccurrences(of: " ", with: "")
//            let parts = fractionString.components(separatedBy: "/")
//            if parts.count == 2, let numerator = Double(parts[0]), let denominator = Double(parts[1]), denominator != 0 {
//                let percentage = (numerator / denominator) * 100
//                return String(format: "%.0f%%", percentage.rounded()) // Rounded to nearest whole number
//            } else if parts.count == 2 { // Keep original if parsing to double fails but it was a valid fraction pattern match
//                 return fractionString
//            }
//        }
//        
//        // Pattern: X out of Y, X over Y (e.g., "8 out of 10", "45 over 50")
//        if let range = lowerInput.range(of: "(\\d+(\\.\\d+)?)\\s+(out\\s+of|over)\\s+(\\d+(\\.\\d+)?)", options: .regularExpression) {
//            let matchedText = String(lowerInput[range])
//            // Extract numbers using regex to be more robust with potential decimal points
//            let numberMatches = emociones(from: matchedText, withPattern: "\\d+(\\.\\d+)?")
//
//            if numberMatches.count == 2, let numerator = Double(numberMatches[0]), let denominator = Double(numberMatches[1]), denominator != 0 {
//                let percentage = (numerator / denominator) * 100
//                return String(format: "%.0f%%", percentage.rounded()) // Rounded to nearest whole number
//            } else if numberMatches.count == 2 { // Fallback to original fraction string if double conversion fails
//                 return "\(numberMatches[0])/\(numberMatches[1])"
//            }
//        }
//        
//        // Fallback for simple numbers if they might be a grade (e.g. "got 87 on the test")
//        // This is less specific, so it comes later.
//        if let range = input.range(of: "\\b(\\d{1,3})\\b", options: .regularExpression) {
//            let numberStr = String(input[range])
//            // Check context if it's just a number to avoid misinterpreting random numbers as grades.
//            // For example, if words like "test", "quiz", "exam", "assignment", "grade", "score" are nearby.
//            let gradeContextKeywords = ["test", "quiz", "exam", "assignment", "grade", "score", "got", "received"]
//            var contextFound = false
//            for keyword in gradeContextKeywords {
//                if lowerInput.contains(keyword) {
//                    contextFound = true
//                    break
//                }
//            }
//            if contextFound {
//                if let number = Int(numberStr), (number <= 100 || (number > 100 && lowerInput.contains("/"))) { // Allow > 100 if it might be part of X/Y that was missed
//                    return numberStr
//                }
//            }
//        }
//        
//        return nil
//    }
//    
//    // Added isFollowUpQuery parameter
//    private func extractWeight(from input: String, isFollowUpQuery: Bool = false) -> String? {
//        let patterns = [
//            "worth\\s+(\\d{1,3})%?",
//            "weighted\\s+(\\d{1,3})%?",
//            "(\\d{1,3})%\\s+weight",
//            "weight.*?(\\d{1,3})%?"
//        ]
//        
//        for pattern in patterns {
//            if let range = input.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
//                let match = String(input[range])
//                if let numberRange = match.range(of: "\\d{1,3}", options: .regularExpression) {
//                    return String(match[numberRange])
//                }
//            }
//        }
//        
//        // These patterns are more for direct answers to "What's the weight?"
//        if isFollowUpQuery {
//            // Pattern: "X percent"
//            let percentWordPattern = "(\\d{1,3})\\s+percent"
//            if let range = input.range(of: percentWordPattern, options: [.regularExpression, .caseInsensitive]) {
//                 let match = String(input[range])
//                 if let numberRange = match.range(of: "\\d{1,3}", options: .regularExpression) {
//                    return String(match[numberRange])
//                }
//            }
//            
//            // Pattern: "X%" or "X" when it's the entire input (or trimmed entire input)
//            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
//            let standalonePercentPattern = "^(\\d{1,3})%?$"
//            if let range = trimmed.range(of: standalonePercentPattern, options: .regularExpression) {
//                let match = String(trimmed[range])
//                if let numberRange = match.range(of: "\\d{1,3}", options: .regularExpression) {
//                    return String(match[numberRange])
//                }
//            }
//        }
//        
//        return nil
//    }
//    
//    private func findBestCourseMatch(_ input: String, courses: [Course]) -> Course? {
//        let lowerInput = input.lowercased()
//        
//        for course in courses {
//            if lowerInput.contains(course.name.lowercased()) {
//                return course
//            }
//        }
//        
//        let abbreviations = ["math", "calc", "physics", "chem", "bio", "english", "hist", "psych"]
//        for abbrev in abbreviations {
//            if lowerInput.contains(abbrev) {
//                for course in courses {
//                    if course.name.lowercased().contains(abbrev) {
//                        return course
//                    }
//                }
//            }
//        }
//        
//        return nil
//    }
//    
//    private func extractDaysOfWeek(from input: String) -> Set<DayOfWeek> {
//        let lowerInput = input.lowercased()
//        var days: Set<DayOfWeek> = []
//        
//        if lowerInput.contains("mwf") {
//            days = [.monday, .wednesday, .friday]
//        } else if lowerInput.contains("tth") || lowerInput.contains("tr") {
//            days = [.tuesday, .thursday]
//        } else if lowerInput.contains("weekdays") {
//            days = [.monday, .tuesday, .wednesday, .thursday, .friday]
//        } else if lowerInput.contains("weekend") {
//            days = [.saturday, .sunday]
//        } else {
//            let dayMap: [String: DayOfWeek] = [
//                "monday": .monday, "mon": .monday,
//                "tuesday": .tuesday, "tue": .tuesday, "tues": .tuesday,
//                "wednesday": .wednesday, "wed": .wednesday,
//                "thursday": .thursday, "thu": .thursday, "thur": .thursday,
//                "friday": .friday, "fri": .friday,
//                "saturday": .saturday, "sat": .saturday,
//                "sunday": .sunday, "sun": .sunday
//            ]
//            
//            for (dayName, dayEnum) in dayMap {
//                if lowerInput.contains(dayName) {
//                    days.insert(dayEnum)
//                }
//            }
//        }
//        
//        return days
//    }
//    
//    private func extractScheduleTimes(from input: String) -> (start: DateComponents?, end: DateComponents?, duration: TimeInterval?) {
//        let lowerInput = input.lowercased()
//        var startTime: DateComponents?
//        var endTime: DateComponents?
//        var duration: TimeInterval?
//        
//        if let range = lowerInput.range(of: "from\\s+(\\d{1,2}:?\\d{0,2}(?:am|pm)?)\\s+to\\s+(\\d{1,2}:?\\d{0,2}(?:am|pm)?)", options: .regularExpression) {
//            let match = String(lowerInput[range])
//            
//            if let startRange = match.range(of: "from\\s+(\\d{1,2}:?\\d{0,2}(?:am|pm)?)", options: .regularExpression) {
//                let startMatch = String(match[startRange])
//                if let timeRange = startMatch.range(of: "\\d{1,2}:?\\d{0,2}(?:am|pm)?", options: .regularExpression) {
//                    startTime = parseTime(from: String(startMatch[timeRange]))
//                }
//            }
//            
//            if let endRange = match.range(of: "to\\s+(\\d{1,2}:?\\d{0,2}(?:am|pm)?)", options: .regularExpression) {
//                let endMatch = String(match[endRange])
//                if let timeRange = endMatch.range(of: "\\d{1,2}:?\\d{0,2}(?:am|pm)?", options: .regularExpression) {
//                    endTime = parseTime(from: String(endMatch[timeRange]))
//                }
//            }
//        } else if let range = lowerInput.range(of: "(\\d{1,2}(?:am|pm)?)-(\\d{1,2}(?:am|pm)?)", options: .regularExpression) {
//            let match = String(lowerInput[range])
//            let components = match.components(separatedBy: "-")
//            
//            if components.count == 2 {
//                startTime = parseTime(from: components[0])
//                endTime = parseTime(from: components[1])
//            }
//        } else if let time = parseTime(from: input) {
//            startTime = time
//        }
//        
//        if let range = lowerInput.range(of: "for\\s+(\\d+)\\s+(hour|hr|minute|min)s?", options: .regularExpression) {
//            let match = String(lowerInput[range])
//            if let numberRange = match.range(of: "\\d+", options: .regularExpression) {
//                let numberStr = String(match[numberRange])
//                if let number = Int(numberStr) {
//                    if match.contains("hour") || match.contains("hr") {
//                        duration = TimeInterval(number * 3600)
//                    } else {
//                        duration = TimeInterval(number * 60)
//                    }
//                }
//            }
//        }
//        
//        return (start: startTime, end: endTime, duration: duration)
//    }
//    
//    private func parseDate(from input: String) -> Date? {
//        let lowerInput = input.lowercased()
//        let calendar = Calendar.current
//        let now = Date()
//        
//        if lowerInput.contains("today") {
//            return now
//        }
//        
//        if lowerInput.contains("tomorrow") || lowerInput.contains("tmrw") {
//            return calendar.date(byAdding: .day, value: 1, to: now)
//        }
//        
//        let dayMap: [String: Int] = [
//            "monday": 2, "mon": 2,
//            "tuesday": 3, "tue": 3, "tues": 3,
//            "wednesday": 4, "wed": 4,
//            "thursday": 5, "thu": 5, "thur": 5,
//            "friday": 6, "fri": 6,
//            "saturday": 7, "sat": 7,
//            "sunday": 1, "sun": 1
//        ]
//        
//        for (dayName, weekday) in dayMap {
//            if lowerInput.contains("next \(dayName)") ||
//               lowerInput.contains("this \(dayName)") ||
//               lowerInput.contains("on \(dayName)") ||
//               lowerInput.contains(" \(dayName)") ||
//               lowerInput.hasSuffix(dayName) ||
//               lowerInput.hasPrefix(dayName) {
//                let currentWeekday = calendar.component(.weekday, from: now)
//                var daysToAdd = weekday - currentWeekday
//                if daysToAdd <= 0 {
//                    daysToAdd += 7
//                }
//                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
//            }
//        }
//        
//        let months = ["january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
//                     "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
//                     "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7,
//                     "aug": 8, "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12]
//        
//        for (monthName, monthNumber) in months {
//            let pattern = "\(monthName)\\s+(\\d{1,2})"
//            if let range = lowerInput.range(of: pattern, options: .regularExpression) {
//                let match = String(lowerInput[range])
//                if let dayRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
//                    let dayStr = String(match[dayRange])
//                    if let day = Int(dayStr) {
//                        var dateComponents = DateComponents()
//                        dateComponents.year = calendar.component(.year, from: now)
//                        dateComponents.month = monthNumber
//                        dateComponents.day = day
//                        
//                        if let date = calendar.date(from: dateComponents) {
//                            if date < now {
//                                dateComponents.year = calendar.component(.year, from: now) + 1
//                                return calendar.date(from: dateComponents)
//                            }
//                            return date
//                        }
//                    }
//                }
//            }
//        }
//        
//        return nil
//    }
//    
//    private func parseTime(from input: String) -> DateComponents? {
//        let lowerInput = input.lowercased()
//        
//        if lowerInput.contains("noon") {
//            return DateComponents(hour: 12, minute: 0)
//        }
//        if lowerInput.contains("midnight") {
//            return DateComponents(hour: 0, minute: 0)
//        }
//        
//        if let range = lowerInput.range(of: "(\\d{1,2}):(\\d{2})\\s*(am|pm)", options: .regularExpression) {
//            let match = String(lowerInput[range])
//            let components = match.components(separatedBy: ":")
//            
//            if components.count >= 2,
//               let hour = Int(components[0]),
//               let minute = Int(String(components[1].prefix(2))) {
//                
//                var finalHour = hour
//                if match.contains("pm") && hour != 12 {
//                    finalHour = hour + 12
//                } else if match.contains("am") && hour == 12 {
//                    finalHour = 0
//                }
//                
//                if finalHour >= 0 && finalHour <= 23 && minute >= 0 && minute <= 59 {
//                    return DateComponents(hour: finalHour, minute: minute)
//                }
//            }
//        }
//        
//        if let range = lowerInput.range(of: "(\\d{1,2})\\s*(am|pm)", options: .regularExpression) {
//            let match = String(lowerInput[range])
//            if let hourRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
//                let hourStr = String(match[hourRange])
//                if let hour = Int(hourStr) {
//                    var finalHour = hour
//                    if match.contains("pm") && hour != 12 {
//                        finalHour = hour + 12
//                    } else if match.contains("am") && hour == 12 {
//                        finalHour = 0
//                    }
//                    
//                    if finalHour >= 0 && finalHour <= 23 {
//                        return DateComponents(hour: finalHour, minute: 0)
//                    }
//                }
//            }
//        }
//        
//        if let range = lowerInput.range(of: "(\\d{1,2}):(\\d{2})", options: .regularExpression) {
//            let match = String(lowerInput[range])
//            let components = match.components(separatedBy: ":")
//            
//            if components.count == 2,
//               let hour = Int(components[0]),
//               let minute = Int(components[1]),
//               hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 {
//                return DateComponents(hour: hour, minute: minute)
//            }
//        }
//        
//        return nil
//    }
//    
//    private func extractDuration(from input: String) -> TimeInterval? {
//        let lowerInput = input.lowercased()
//        
//        let patterns = [
//            "for\\s+(\\d+)\\s+(hour|hr)s?": 3600,
//            "for\\s+(\\d+)\\s+(minute|min)s?": 60,
//            "(\\d+)\\s+(hour|hr)s?": 3600,
//            "(\\d+)\\s+(minute|min)s?": 60
//        ]
//        
//        for (pattern, multiplier) in patterns {
//            if let range = lowerInput.range(of: pattern, options: .regularExpression) {
//                let match = String(lowerInput[range])
//                if let numberRange = match.range(of: "\\d+", options: .regularExpression) {
//                    let numberStr = String(match[numberRange])
//                    if let number = Int(numberStr) {
//                        return TimeInterval(number * multiplier)
//                    }
//                }
//            }
//        }
//        
//        return nil
//    }
//    
//    private func extractReminderTime(from input: String) -> ReminderTime? {
//        let lowerInput = input.lowercased()
//        
//        if lowerInput.contains("no reminder") {
//            return .none
//        }
//        
//        let positiveReminderPatterns = [
//            ("5\\s*min", ReminderTime.minutes(5)),
//            ("15\\s*min", ReminderTime.minutes(15)),
//            ("30\\s*min", ReminderTime.minutes(30)),
//            ("1\\s*hour", ReminderTime.hours(1)),
//            ("2\\s*hour", ReminderTime.hours(2)),
//            ("1\\s*day", ReminderTime.days(1)),
//            ("2\\s*day", ReminderTime.days(2)),
//            ("1\\s*week", ReminderTime.weeks(1))
//        ]
//        for (pattern, reminderTimeValue) in positiveReminderPatterns {
//            if lowerInput.range(of: pattern, options: .regularExpression) != nil {
//                return reminderTimeValue
//            }
//        }
//
//        if lowerInput.contains("remind") || lowerInput.contains("before") {
//            return .minutes(15)
//        }
//
//        return nil
//    }
//    
//    private func parseReminderTime(from input: String) -> ReminderTime {
//        if let reminderTime = extractReminderTime(from: input) {
//            return reminderTime
//        }
//        
//        let lowerInput = input.lowercased()
//        if lowerInput.contains("no") ||
//           lowerInput.contains("none") ||
//           lowerInput.contains("skip") ||
//           lowerInput.contains("don't") {
//            return .none
//        }
//        
//        return .minutes(15)
//    }
//    
//    private func findCategoryMatch(_ input: String, categories: [Category]) -> String? {
//        let lowerInput = input.lowercased()
//        
//        for category in categories {
//            if lowerInput.contains(category.name.lowercased()) {
//                return category.name
//            }
//        }
//        
//        let mappings: [String: String] = [
//            "assignment": "Assignment",
//            "homework": "Assignment",
//            "test": "Exam",
//            "exam": "Exam",
//            "quiz": "Exam",
//            "meeting": "Meeting",
//            "personal": "Personal"
//        ]
//        
//        for (keyword, categoryName) in mappings {
//            if lowerInput.contains(keyword) {
//                if let existing = categories.first(where: { $0.name.lowercased() == categoryName.lowercased() }) {
//                    return existing.name
//                }
//                return categoryName
//            }
//        }
//        
//        return nil
//    }
//    
//    private func buildCategoryPrompt(_ categories: [Category]) -> String {
//        if categories.isEmpty {
//            return "(e.g., 'Assignment', 'Exam', 'Personal')"
//        } else {
//            let categoryNames = categories.prefix(5).map { $0.name }.joined(separator: ", ")
//            return "Available: \(categoryNames)"
//        }
//    }
//    
//    // MARK: - Conversation Management
//    private func startNewConversation() -> UUID {
//        let conversationId = UUID()
//        activeConversations[conversationId] = Date()
//        return conversationId
//    }
//    
//    private func cleanupExpiredConversations() {
//        let now = Date()
//        activeConversations = activeConversations.filter { _, startTime in
//            now.timeIntervalSince(startTime) < conversationTimeout
//        }
//    }
//    
//    // MARK: - Helper to detect date references (ENHANCED)
//    private func hasDateReference(_ input: String) -> Bool {
//        let lowerInput = input.lowercased()
//        let dateKeywords = [
//            "today", "tomorrow", "tmrw", "yesterday",
//            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
//            "mon", "tue", "tues", "wed", "thu", "thurs", "fri", "sat", "sun",
//            "next ", "this ", "on ",
//            "january", "february", "march", "april", "may", "june",
//            "july", "august", "september", "october", "november", "december",
//            "jan ", "feb ", "mar ", "apr ", "may ", "jun ",
//            "jul ", "aug ", "sep ", "sept ", "oct ", "nov ", "dec ",
//            " am", " pm",
//            " o'clock", " oclock"
//        ]
//        
//        if dateKeywords.contains(where: { lowerInput.contains($0) }) {
//            return true
//        }
//        let timePattern = "\\b\\d{1,2}((:\\d{2})?(\\s*(am|pm))?|\\s*o[''']?clock)\\b"
//        if lowerInput.range(of: timePattern, options: .regularExpression) != nil {
//            return true
//        }
//        let fullDatePattern = "\\b(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}|\\d{4}[-/]\\d{1,2}[-/]\\d{1,2})\\b"
//        if lowerInput.range(of: fullDatePattern, options: .regularExpression) != nil {
//            return true
//        }
//        return false
//    }
//
//    private func containsActualGradePattern(_ text: String) -> Bool {
//        let lowerText = text.lowercased()
//        let patterns = [
//            "\\b[A-F][+-]?\\b",                                     // A, B+, C- (Corrected to A-F)
//            "\\b\\d+\\s*(\\.\\d+)?\\s*/\\s*\\d+(\\.\\d+)?\\b",       // X/Y or X.Y / Z.W (Corrected to d+)
//            "\\b(pass|fail)(ed)?\\b",                               // pass, failed
//            "%",                                                    // % symbol
//            "\\b\\d+\\s+percent\\b",                      // "90 percent"
//            "\\b\\d+\\s+(out\\s+of|over)\\s+\\d+\\b"                // "X out of Y", "X over Y"
//        ]
//        
//        return patterns.contains { lowerText.range(of: $0, options: .regularExpression) != nil }
//    }
//    
//    private func resultIsNotUnrecognizedOrNotAttempted(_ result: NLPResult?) -> Bool {
//        guard let result = result else { return false }
//        switch result {
//        case .unrecognized, .notAttempted:
//            return false
//        default:
//            return true
//        }
//    }
//    
//    // Helper function to extract all matches of a regex pattern from a string
//    private func emociones(from text: String, withPattern pattern: String) -> [String] {
//        do {
//            let regex = try NSRegularExpression(pattern: pattern, options: [])
//            let results = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
//            return results.map {
//                String(text[Range($0.range, in: text)!])
//            }
//        } catch {
//            print("Invalid regex: \(error.localizedDescription)")
//            return []
//        }
//    }
//}
//
//private func extractColor(from input: String) -> String? {
//    let lowerInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//    
//    // Direct hex code match first
//    let hexPattern = "^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$" // Matches only if input IS a hex code
//    if lowerInput.range(of: hexPattern, options: .regularExpression) != nil {
//        return lowerInput.uppercased()
//    }
//
//    let colorMap: [String: String] = [
//        "red": "#FF3B30", "orange": "#FF9500", "yellow": "#FFCC00",
//        "green": "#34C759", "mint": "#00C7BE", "teal": "#30B0C7",
//        "cyan": "#32ADE6", "blue": "#007AFF", "indigo": "#5856D6",
//        "purple": "#AF52DE", "pink": "#FF2D55", "brown": "#A2845E",
//        "gray": "#8E8E93", "grey": "#8E8E93", "black": "#000000",
//        "white": "#FFFFFF", "light blue": "#5AC8FA", "dark blue": "#0A2A4C",
//        "light green": "#90EE90", "dark green": "#006400",
//        "light gray": "#D3D3D3", "dark gray": "#A9A9A9", "silver": "#C0C0C0",
//        "gold": "#FFD700", "magenta": "#FF00FF", "violet": "#EE82EE"
//    ]
//
//    // Check for exact color name matches
//    if let hexValue = colorMap[lowerInput] {
//        return hexValue
//    }
//
//    // Check for color names contained in the input (less strict)
//    for (colorName, hexValue) in colorMap {
//        if lowerInput.contains(colorName) {
//            // To avoid partial matches like "redo" for "red", check word boundaries if color name is short
//            if colorName.count <= 3 {
//                if lowerInput.range(of: "\\b\(colorName)\\b", options: .regularExpression) != nil {
//                    return hexValue
//                }
//            } else {
//                return hexValue
//            }
//        }
//    }
//    return nil
//}
