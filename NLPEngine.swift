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
    
    // Fuzzy matching cache for performance
    private var fuzzyMatchCache: [String: Bool] = [:]
    
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
            let extractedTimes = extractScheduleTimes(from: trimmed)
            let updatedStartTime = startTime ?? extractedTimes.start
            
            var updatedEndTime = extractedTimes.end
            if startTime != nil && updatedEndTime == nil && extractedTimes.start != nil {
                updatedEndTime = extractedTimes.start
            }
            
            if let startTime = updatedStartTime, let endTime = updatedEndTime {
                if startTime.hour == endTime.hour && startTime.minute == endTime.minute {
                    let conversationId = startNewConversation()
                    return .needsMoreInfo(
                        prompt: "The start and end times are the same (\(formatTime(startTime))). Please provide different start and end times (e.g., 'from 9am to 10am', '2-3pm').",
                        originalInput: trimmed,
                        context: .scheduleNeedsMoreTime(title: title, days: updatedDays, startTime: nil),
                        conversationId: conversationId
                    )
                }
            }
            
            if updatedDays.isEmpty {
                return .needsMoreInfo(prompt: "Please specify the days for '\(title)' (e.g., 'every Monday', 'MWF').", originalInput: trimmed, context: .scheduleNeedsMoreTime(title: title, days: Set<DayOfWeek>(), startTime: updatedStartTime), conversationId: conversationId)
            }
            
            if updatedStartTime == nil {
                return .needsMoreInfo(prompt: "What time does '\(title)' start? (e.g., 'at 9am', 'from 10:30')", originalInput: trimmed, context: .scheduleNeedsMoreTime(title: title, days: updatedDays, startTime: nil), conversationId: conversationId)
            }
            
            if updatedEndTime == nil && extractedTimes.duration == nil {
                return .needsMoreInfo(prompt: "When does '\(title)' end? (e.g., 'to 11am', 'for 1 hour')", originalInput: trimmed, context: .scheduleNeedsMoreTime(title: title, days: updatedDays, startTime: updatedStartTime), conversationId: conversationId)
            }
            
            return .needsMoreInfo(
                prompt: "Would you like to set a reminder for '\(title)'? (e.g., '15 minutes before', 'at start time', or 'no')",
                originalInput: trimmed,
                context: .scheduleNeedsReminderAndColor(title: title, days: updatedDays, startTime: updatedStartTime, endTime: updatedEndTime, duration: extractedTimes.duration),
                conversationId: conversationId
            )
        }
    }
    
    // MARK: - Levenshtein Distance and Fuzzy Matching
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count { matrix[i][0] = i }
        for j in 0...b.count { matrix[0][j] = j }
        
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[a.count][b.count]
    }
    
    private func fuzzyMatches(_ text: String, _ target: String, maxDistance: Int = 1) -> Bool {
        let cacheKey = "\(text.lowercased()):\(target.lowercased())"
        
        if let cached = fuzzyMatchCache[cacheKey] {
            return cached
        }
        
        let distance = levenshteinDistance(text.lowercased(), target.lowercased())
        let result = distance <= maxDistance
        
        fuzzyMatchCache[cacheKey] = result
        return result
    }
    
    private func containsFuzzyKeyword(_ text: String, keywords: [String]) -> Bool {
        let lowercased = text.lowercased()
        
        // First try exact matches
        for keyword in keywords {
            if lowercased.contains(keyword.lowercased()) {
                return true
            }
        }
        
        // Then try fuzzy matches for individual words
        let textWords = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count >= 3 }
        
        for textWord in textWords {
            for keyword in keywords {
                if fuzzyMatches(textWord, keyword) {
                    return true
                }
                
                let keywordWords = keyword.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty && $0.count >= 3 }
                
                for keywordWord in keywordWords {
                    if fuzzyMatches(textWord, keywordWord) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // MARK: - Grade Parsing
    private func tryParseAsGrade(text: String, lowercased: String, courses: [Course]) -> NLPResult? {
        let specificGradeKeywords = ["grade", "score", "received", "earned", "scored", "percent", "%"]
        let contextualGradeWords = ["got"]
        
        let hasSpecificGradeKeyword = containsFuzzyKeyword(lowercased, keywords: specificGradeKeywords)
        let hasContextualGradeWord = containsFuzzyKeyword(lowercased, keywords: contextualGradeWords)
        
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
    
    // MARK: - Assignment Name Extraction
    private func extractAssignmentName(from text: String) -> String? {
        let lowercased = text.lowercased()
        
        // Common assignment keywords with variations
        let assignmentTypes = [
            ("homework", ["homework", "hw", "assignment"]),
            ("quiz", ["quiz", "test", "exam"]),
            ("project", ["project", "paper"]),
            ("lab", ["lab", "laboratory"]),
            ("midterm", ["midterm", "midterm exam"]),
            ("final", ["final", "final exam"])
        ]
        
        // Look for assignment type mentions
        for (baseType, variations) in assignmentTypes {
            for variation in variations {
                if lowercased.contains(variation) {
                    // Look for numbers after the assignment type
                    let pattern = "\(variation)\\s*(\\d+|#\\d+)"
                    if let range = lowercased.range(of: pattern, options: .regularExpression) {
                        let match = String(lowercased[range])
                        if let numberRange = match.range(of: "\\d+", options: .regularExpression) {
                            let number = String(match[numberRange])
                            return "\(baseType.capitalized) \(number)"
                        }
                    }
                    
                    // If no number found, just return the type
                    return baseType.capitalized
                }
            }
        }
        
        // Look for "on [subject]" patterns
        let onPatterns = ["on the ", "on "]
        for pattern in onPatterns {
            if let range = lowercased.range(of: pattern) {
                let afterOn = String(lowercased[range.upperBound...])
                let words = afterOn.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                
                if let firstWord = words.first, firstWord.count >= 3 {
                    return firstWord.capitalized
                }
            }
        }
        
        // Look for quoted assignment names
        let quotedPattern = "\"([^\"]+)\""
        if let range = text.range(of: quotedPattern, options: .regularExpression) {
            let match = String(text[range])
            let cleanMatch = match.replacingOccurrences(of: "\"", with: "")
            if !cleanMatch.isEmpty {
                return cleanMatch
            }
        }
        
        // Look for "for [assignment]" patterns
        if let range = lowercased.range(of: "for ") {
            let afterFor = String(lowercased[range.upperBound...])
            let words = afterFor.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty && $0.count >= 3 }
            
            if let firstWord = words.first {
                // Skip common course-related words
                let skipWords = ["the", "our", "my", "this", "that", "math", "science", "english", "history"]
                if !skipWords.contains(firstWord) {
                    return firstWord.capitalized
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Schedule Parsing
    private func tryParseAsScheduleItem(text: String, lowercased: String) -> NLPResult? {
        let strongScheduleKeywords = ["every", "weekly", "recurring", "weekday", "weekdays", "daily"]
        let scheduleKeywords = ["schedule", "class", "course", "lecture", "tutorial", "lab", "seminar"]
        
        let hasStrongScheduleKeyword = containsFuzzyKeyword(lowercased, keywords: strongScheduleKeywords)
        let hasScheduleKeyword = containsFuzzyKeyword(lowercased, keywords: scheduleKeywords)
        
        let dayPatterns = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "mwf", "tth", "tr"]
        let hasDayPattern = containsFuzzyKeyword(lowercased, keywords: dayPatterns)
        
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
        
        if let startTime = extractedTimes.start, let endTime = extractedTimes.end {
            if startTime.hour == endTime.hour && startTime.minute == endTime.minute {
                let conversationId = startNewConversation()
                return .needsMoreInfo(
                    prompt: "The start and end times are the same (\(formatTime(startTime))). Please provide different start and end times (e.g., 'from 9am to 10am', '2-3pm').",
                    originalInput: text,
                    context: .scheduleNeedsMoreTime(title: extractedTitle, days: extractedDays, startTime: nil),
                    conversationId: conversationId
                )
            }
        }
        
        let extractedReminderTime = extractReminderFromScheduleText(from: lowercased)
        let extractedColor = extractColorFromText(from: lowercased)
        
        let explicitlyDeclinedReminder = containsFuzzyKeyword(lowercased, keywords: [
            "don't need to be reminded", "no reminder needed", "don't remind me",
            "no reminder", "don't need reminder", "no need to remind"
        ])
        
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
        
        let hasStrongIndicator = containsFuzzyKeyword(lowercased, keywords: strongEventKeywords)
        let hasEventKeyword = containsFuzzyKeyword(lowercased, keywords: eventKeywords)
        let isLikelyEvent = hasStrongIndicator || hasEventKeyword || lowercased.contains("on ") || lowercased.contains("at ") || lowercased.contains("have") || lowercased.contains("need to")
        
        guard isLikelyEvent else { return nil }
        
        let extractedTitle = extractEventTitle(from: text)
        let detectedDate = parseDate(from: text)
        let categoryName = findBestCategoryMatch(from: text, categories: categories)
        let specificTime = parseSpecificTime(from: text)
        
        let explicitlyDeclinedReminder = containsFuzzyKeyword(lowercased, keywords: [
            "don't need to be reminded", "no reminder needed", "don't remind me",
            "no reminder", "don't need reminder", "no need to remind"
        ])
        
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
        let colorMappings: [String: (String, [String])] = [
            "red": ("FF0000", ["red", "rd", "reed"]),
            "blue": ("0000FF", ["blue", "blu", "bleu"]),
            "green": ("00FF00", ["green", "grn", "gren"]),
            "yellow": ("FFFF00", ["yellow", "yello", "yelow"]),
            "orange": ("FFA500", ["orange", "orng", "ornge"]),
            "purple": ("800080", ["purple", "purpl", "prple"]),
            "pink": ("FFC0CB", ["pink", "pnk", "pinc"]),
            "cyan": ("00FFFF", ["cyan", "cyn"]),
            "magenta": ("FF00FF", ["magenta", "mgenta"]),
            "lime": ("00FF00", ["lime", "lim"]),
            "indigo": ("4B0082", ["indigo", "indgo"]),
            "violet": ("8A2BE2", ["violet", "violett"]),
            "brown": ("A52A2A", ["brown", "brwn", "broun"]),
            "gray": ("808080", ["gray", "grey", "gry"]),
            "black": ("000000", ["black", "blck", "blac"]),
            "white": ("FFFFFF", ["white", "whte", "wht"])
        ]
        
        for (_, (colorHex, variants)) in colorMappings {
            if containsFuzzyKeyword(text, keywords: variants) {
                return colorHex
            }
        }
        
        return nil
    }
    
    private func parseDate(from text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        if containsFuzzyKeyword(lowercased, keywords: ["today", "tday", "todey"]) {
            return now
        }
        
        if containsFuzzyKeyword(lowercased, keywords: ["tomorrow", "tommorow", "tommorrow", "tomorow"]) {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        
        if containsFuzzyKeyword(lowercased, keywords: ["next week", "nxt week", "next wk"]) {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }
        
        if let monthDate = parseMonthDate(from: lowercased, currentYear: calendar.component(.year, from: now)) {
            return monthDate
        }
        
        if let relativeDate = parseRelativeTime(from: lowercased, baseDate: now) {
            return relativeDate
        }
        
        let dayMappings: [String: (Int, [String])] = [
            "monday": (2, ["monday", "mon", "mnday", "moday"]),
            "tuesday": (3, ["tuesday", "tue", "tues", "tusday", "teusday"]),
            "wednesday": (4, ["wednesday", "wed", "wednesdey", "wednsday"]),
            "thursday": (5, ["thursday", "thu", "thur", "thursdy", "thrusday"]),
            "friday": (6, ["friday", "fri", "fridey", "friady"]),
            "saturday": (7, ["saturday", "sat", "saturdy", "satruday"]),
            "sunday": (1, ["sunday", "sun", "sundy", "suday"])
        ]
        
        for (_, (weekday, variants)) in dayMappings {
            let nextVariants = variants.map { "next \($0)" }
            let onVariants = variants.map { "on \($0)" }
            let thisVariants = variants.map { "this \($0)" }
            let allVariants = nextVariants + onVariants + thisVariants
            
            if containsFuzzyKeyword(lowercased, keywords: allVariants) {
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
    
    private func parseMonthDate(from text: String, currentYear: Int) -> Date? {
        let monthMappings: [String: Int] = [
            // Full month names
            "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
            "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
            // Common abbreviations
            "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7,
            "aug": 8, "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12
        ]
        
        let calendar = Calendar.current
        
        for (monthName, monthNumber) in monthMappings {
            let yearPatterns = [
                // Regex to capture "month day(ordinal) year" or "month day, year"
                // Group 1: Day, Group 2: Year
                "\\b\(monthName)\\s+(\\d{1,2})(?:st|nd|rd|th)?[,]?\\s+(\\d{4})\\b",
                // Regex to capture "month day year" (no ordinal or comma)
                // Group 1: Day, Group 2: Year
                "\\b\(monthName)\\s+(\\d{1,2})\\s+(\\d{4})\\b"
            ]

            for patternString in yearPatterns {
                do {
                    let regex = try NSRegularExpression(pattern: patternString, options: .caseInsensitive)
                    let nsText = text as NSString
                    if let matchResult = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                        if matchResult.numberOfRanges == 3 {
                            let dayString = nsText.substring(with: matchResult.range(at: 1))
                            let yearString = nsText.substring(with: matchResult.range(at: 2))

                            if let day = Int(dayString), let year = Int(yearString) {
                                var dateComponents = DateComponents()
                                dateComponents.year = year
                                dateComponents.month = monthNumber
                                dateComponents.day = day
                                if let date = calendar.date(from: dateComponents) {
                                    return date
                                }
                            }
                        }
                    }
                } catch {
                    print("NLPEngine: Regex error for pattern '\(patternString)': \(error)")
                }
            }

            let monthDayPatterns = [
                "\\b\(monthName)\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b",
                "\\b\(monthName)\\.\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b",
                "\\bon\\s+\(monthName)\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b"
            ]
            
            for pattern in monthDayPatterns {
                if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    let match = String(text[range])
                    if let dayString = match.components(separatedBy: CharacterSet.decimalDigits.inverted).filter({ !$0.isEmpty }).first,
                       let day = Int(dayString) {
                        var dateComponents = DateComponents()
                        dateComponents.year = currentYear
                        dateComponents.month = monthNumber
                        dateComponents.day = day
                        
                        if let date = calendar.date(from: dateComponents) {
                            if date < Date() && calendar.component(.year, from: date) == currentYear {
                                dateComponents.year = currentYear + 1
                                return calendar.date(from: dateComponents)
                            }
                            return date
                        }
                    }
                }
            }
        }
        
        for (monthName, monthNumber) in monthMappings {
            let dayMonthPatterns = [
                "\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+\(monthName)\\b",
                "\\b(\\d{1,2})(?:st|nd|rd|th)?\\.\\s+\(monthName)\\b"
            ]
            
            for pattern in dayMonthPatterns {
                if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    let match = String(text[range])
                    if let dayString = match.components(separatedBy: CharacterSet.decimalDigits.inverted).filter({ !$0.isEmpty }).first,
                       let day = Int(dayString) {
                        var dateComponents = DateComponents()
                        dateComponents.year = currentYear
                        dateComponents.month = monthNumber
                        dateComponents.day = day
                        
                        if let date = calendar.date(from: dateComponents) {
                            if date < Date() && calendar.component(.year, from: date) == currentYear {
                                dateComponents.year = currentYear + 1
                                return calendar.date(from: dateComponents)
                            }
                            return date
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func parseRelativeTime(from text: String, baseDate: Date) -> Date? {
        let calendar = Calendar.current
        
        if containsFuzzyKeyword(text, keywords: ["in "]) {
            if let range = text.range(of: "in\\s+(\\d+(?:\\.\\d+)?(?:\\s+and\\s+a\\s+half)?)\\s+(hour|hr|minute|min|day)s?", options: .regularExpression) {
                let match = String(text[range])
                
                var timeValue: Double = 0
                var timeUnit: Calendar.Component = .hour
                
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
        
        let noVariants = ["no", "none", "skip", "dont", "don't"]
        if containsFuzzyKeyword(lowercased, keywords: noVariants) {
            return .none
        }
        
        let startVariants = ["at the start", "when it starts", "at start time", "exactly at", "at start"]
        if containsFuzzyKeyword(lowercased, keywords: startVariants) {
            return .minutes(0)
        }
        
        if lowercased.contains("5") && containsFuzzyKeyword(lowercased, keywords: ["min", "minute", "minutes"]) {
            return .minutes(5)
        } else if lowercased.contains("15") && containsFuzzyKeyword(lowercased, keywords: ["min", "minute", "minutes"]) {
            return .minutes(15)
        } else if lowercased.contains("30") && containsFuzzyKeyword(lowercased, keywords: ["min", "minute", "minutes"]) {
            return .minutes(30)
        } else if lowercased.contains("1") && containsFuzzyKeyword(lowercased, keywords: ["hour", "hr", "hours"]) {
            return .hours(1)
        } else if lowercased.contains("2") && containsFuzzyKeyword(lowercased, keywords: ["hour", "hr", "hours"]) {
            return .hours(2)
        } else if lowercased.contains("1") && containsFuzzyKeyword(lowercased, keywords: ["day", "days"]) {
            return .days(1)
        } else if lowercased.contains("2") && containsFuzzyKeyword(lowercased, keywords: ["day", "days"]) {
            return .days(2)
        } else if lowercased.contains("1") && containsFuzzyKeyword(lowercased, keywords: ["week", "weeks", "wk"]) {
            return .weeks(1)
        }
        
        return .minutes(15)
    }
    
    private func findBestCourseMatch(from text: String, courses: [Course]) -> String? {
        let lowercaseText = text.lowercased()
        
        for course in courses {
            if lowercaseText.contains(course.name.lowercased()) {
                return course.name
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
        
        let textWords = lowercaseText.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        
        for course in courses {
            let courseName = course.name.lowercased()
            let courseWords = courseName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            
            // Check if any text word matches any course word
            for textWord in textWords {
                for courseWord in courseWords {
                    if courseWord.hasPrefix(textWord) && textWord.count >= 3 {
                        return course.name
                    }
                    if textWord.hasPrefix(courseWord) && courseWord.count >= 3 {
                        return course.name
                    }
                    // Keep existing fuzzy matching as fallback
                    if fuzzyMatches(textWord, courseWord) && textWord.count >= 3 {
                        return course.name
                    }
                }
            }
        }
        
        let courseKeywords = extractCourseKeywords(from: lowercaseText)
        
        for keyword in courseKeywords {
            for course in courses {
                let courseName = course.name.lowercased()
                if courseName.contains(keyword) || fuzzyMatches(courseName, keyword) {
                    return course.name
                }
            }
        }
        
        return nil
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
        
        let textWords = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count >= 3 }
        
        for textWord in textWords {
            for subject in commonSubjects {
                if fuzzyMatches(textWord, subject) && !keywords.contains(subject) {
                    keywords.append(subject)
                }
                
                let subjectWords = subject.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty && $0.count >= 3 }
                
                for subjectWord in subjectWords {
                    if fuzzyMatches(textWord, subjectWord) {
                        keywords.append(subject)
                    }
                }
            }
        }
        
        return keywords
    }
    
    private func extractCourseAbbreviations(from text: String) -> [String] {
        var abbreviations: [String] = []
        
        let commonAbbreviations = [
            "ochem", "orgo", "gen chem", "genchem", "bio", "phys", "calc", "pre calc", "precalc",
            "stats", "psych", "soc", "anthro", "poli sci", "polisci",
            "comp sci", "compsci", "lit", "hist", "geo", "trig", "alg", "eng",
            "chem", "math", "cs", "ap", "honors"
        ]
        
        for abbrev in commonAbbreviations {
            if text.contains(abbrev) {
                abbreviations.append(abbrev)
            }
        }
        
        let textWords = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count >= 3 } // Only consider words with 3+ characters
        
        for textWord in textWords {
            // Check if this word is a known abbreviation
            if commonAbbreviations.contains(textWord.lowercased()) && !abbreviations.contains(textWord.lowercased()) {
                abbreviations.append(textWord.lowercased())
            }
            
            // Check fuzzy matches only if no exact match found
            if abbreviations.isEmpty {
                for abbrev in commonAbbreviations {
                    if fuzzyMatches(textWord, abbrev) && !abbreviations.contains(abbrev) {
                        abbreviations.append(abbrev)
                    }
                }
            }
        }
        
        return abbreviations
    }
    
    private func courseMatchesAbbreviation(courseName: String, abbreviation: String) -> Bool {
        let lowercaseCourseName = courseName.lowercased()
        let lowercaseAbbrev = abbreviation.lowercased()
        
        if lowercaseCourseName.hasPrefix(lowercaseAbbrev) && lowercaseAbbrev.count >= 3 {
            return true
        }
        
        let abbreviationMappings: [String: [String]] = [
            "ochem": ["organic chemistry", "organic chem", "org chem"],
            "orgo": ["organic chemistry", "organic chem", "org chem"],
            "gen chem": ["general chemistry", "general chem"],
            "genchem": ["general chemistry", "general chem"],
            "bio": ["biology", "biological"],
            "phys": ["physics", "physical"],
            "calc": ["calculus", "calc"],
            "precalc": ["precalculus", "pre-calculus", "pre calculus"],
            "stats": ["statistics", "statistical"],
            "psych": ["psychology", "psychological"],
            "econ": ["economics", "economic"],
            "comp sci": ["computer science", "computing"],
            "compsci": ["computer science", "computing"],
            "lit": ["literature", "literary"],
            "hist": ["history", "historical"],
            "geo": ["geography", "geological"],
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
        
        for (abbrev, mappings) in abbreviationMappings {
            if fuzzyMatches(lowercaseAbbrev, abbrev) {
                for mapping in mappings {
                    if lowercaseCourseName.contains(mapping) {
                        return true
                    }
                }
            }
        }
        
        let courseWords = lowercaseCourseName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        for word in courseWords {
            if word.hasPrefix(lowercaseAbbrev) && lowercaseAbbrev.count >= 3 {
                return true
            }
            if fuzzyMatches(word, lowercaseAbbrev) && lowercaseAbbrev.count >= 3 {
                return true
            }
        }
        
        return false
    }
    
    private func parseSpecificTime(from text: String) -> DateComponents? {
        let lowercased = text.lowercased()
        
        if containsFuzzyKeyword(lowercased, keywords: ["noon", "12pm", "12:00pm"]) {
            return DateComponents(hour: 12, minute: 0)
        }
        
        if containsFuzzyKeyword(lowercased, keywords: ["midnight", "12am", "12:00am"]) {
            return DateComponents(hour: 0, minute: 0)
        }
        
        if let range = lowercased.range(of: "(\\d{1,2}):(\\d{2})\\b", options: .regularExpression) {
            let match = String(lowercased[range])
            let components = match.components(separatedBy: ":")
            
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]),
               hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 {
                return DateComponents(hour: hour, minute: minute)
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
    
    private func findBestCategoryMatch(from text: String, categories: [Category]) -> String? {
        let lowercased = text.lowercased()
        
        for category in categories {
            if lowercased.contains(category.name.lowercased()) {
                return category.name
            }
        }
        
        let textWords = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        
        for category in categories {
            let categoryWords = category.name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            
            for textWord in textWords {
                for categoryWord in categoryWords {
                    if fuzzyMatches(textWord, categoryWord) {
                        return category.name
                    }
                
                }
            }
        }
        
        return nil
    }
    
    private func extractEventTitle(from text: String) -> String {
        let lowercased = text.lowercased()
        
        let conversationalPhrases = [
            "yo croski i have an ", "yo croski i have a ", "yo croski i have ",
            "remind me to ", "remind me about ", "remind me ", "i need to remember to ",
            "i have an ", "i have a ", "i have ", "need to ", "have to ", "gotta ",
            "got an ", "got a ", "got ", "there's an ", "there's a ", "there's ",
            "i need an ", "i need a ", "i need ", "i should ", "i must ",
            "don't forget to ", "remember to ", "make sure to "
        ]
        
        var cleanedText = LeadInStripperModel.shared.stripLeadIn(from: text)
        for phrase in conversationalPhrases {
            if cleanedText.lowercased().hasPrefix(phrase) {
                cleanedText = String(cleanedText.dropFirst(phrase.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        let timeAndDatePatterns = [
            "\\s+at\\s+\\d{1,2}:\\d{2}\\s*(am|pm).*",
            "\\s+at\\s+\\d{1,2}\\s*(am|pm).*",
            "\\s+\\d{1,2}:\\d{2}\\s*(am|pm).*",
            "\\s+\\d{1,2}\\s*(am|pm).*",
            "\\s+at\\s+\\d{1,2}:\\d{2}.*",
            "\\s+\\d{1,2}:\\d{2}.*",
            // Date patterns
            "\\s+on\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday).*",
            "\\s+this\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday).*",
            "\\s+next\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday).*",
            "\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday).*",
            "\\s+(today|tomorrow).*",
            "\\s+on\\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\\s+\\d{1,2}.*",
            "\\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\\s+\\d{1,2}.*",
            // Relative time
            "\\s+in\\s+\\d+.*",
            "\\s+after\\s+\\d+.*"
        ]
        
        for pattern in timeAndDatePatterns {
            if let range = cleanedText.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                cleanedText = String(cleanedText[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        cleanedText = extractCoreSubject(from: cleanedText)
        
        cleanedText = properlyCapitalize(cleanedText)
        
        if cleanedText.isEmpty || cleanedText.count < 2 {
            cleanedText = inferTitleFromKeywords(text)
        }
        
        return cleanedText
    }
    
    private func extractScheduleTitle(from text: String) -> String {
        let lowercased = text.lowercased()
        
        var cleanedText = LeadInStripperModel.shared.stripLeadIn(from: text)
        
        let conversationalPhrases = [
            "yo croski i have ", "i have an ", "i have a ", "i have ",
            "i've got an ", "i've got a ", "i've got ", "i got an ", "i got a ", "i got ",
            "there's an ", "there's a ", "there's ", "my ", "our ", "the ",
            "every ", "weekly ", "recurring "
        ]
        
        for phrase in conversationalPhrases {
            if cleanedText.lowercased().hasPrefix(phrase) {
                cleanedText = String(cleanedText.dropFirst(phrase.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        let redundantDescriptors = ["class", "course", "lecture", "tutorial", "lab session", "seminar"]
        for descriptor in redundantDescriptors {
            if cleanedText.lowercased().hasSuffix(" " + descriptor) {
                let range = cleanedText.lowercased().range(of: " " + descriptor + "$", options: .regularExpression)!
                cleanedText = String(cleanedText[..<range.lowerBound])
                break
            }
        }
        
        let timeAndDayPatterns = [
            "\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|weekday|weekdays|weekend|weekends|mwf|tth|tr).*",
            "\\s+from\\s+\\d+.*",
            "\\s+at\\s+\\d+.*",
            "\\s+\\d{1,2}:\\d{2}.*",
            "\\s+\\d{1,2}\\s*(am|pm).*",
            "\\s+every\\s+.*"
        ]
        
        for pattern in timeAndDayPatterns {
            if let range = cleanedText.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                cleanedText = String(cleanedText[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        cleanedText = extractCoreSubject(from: cleanedText)
        
        cleanedText = properlyCapitalize(cleanedText)
        
        if cleanedText.isEmpty || cleanedText.count < 2 {
            cleanedText = "Class"
        }
        
        return cleanedText
    }
    
    private func extractCoreSubject(from text: String) -> String {
        var cleanedText = text.trimmingCharacters(in: .whitespaces)
        
        let unnecessaryWords = ["an ", "a ", "the ", "my ", "our ", "their ", "some ", "this ", "that "]
        for word in unnecessaryWords {
            if cleanedText.lowercased().hasPrefix(word) {
                cleanedText = String(cleanedText.dropFirst(word.count))
                break
            }
        }
        
        let subjectExpansions: [String: String] = [
            "autistic geo": "Autistic Geography",
            "ochem": "Organic Chemistry",
            "orgo": "Organic Chemistry", 
            "gen chem": "General Chemistry",
            "bio": "Biology",
            "phys": "Physics",
            "calc": "Calculus",
            "precalc": "Pre-Calculus",
            "stats": "Statistics",
            "psych": "Psychology",
            "comp sci": "Computer Science",
            "lit": "Literature",
            "hist": "History",
            "geo": "Geography",
            "trig": "Trigonometry",
            "alg": "Algebra"
        ]
        
        let lowercased = cleanedText.lowercased()
        for (abbrev, fullName) in subjectExpansions {
            if lowercased.contains(abbrev) {
                cleanedText = cleanedText.replacingOccurrences(of: abbrev, with: fullName, options: .caseInsensitive)
                break
            }
        }
        
        return cleanedText.trimmingCharacters(in: .whitespaces)
    }
    
    private func properlyCapitalize(_ text: String) -> String {
        let words = text.components(separatedBy: " ").filter { !$0.isEmpty }
        
        let capitalizedWords = words.map { word in
            let lowercaseWord = word.lowercased()
            let dontCapitalize = ["of", "in", "on", "at", "to", "for", "with", "by", "from", "and", "or", "but", "the", "a", "an"]
            
            if words.first == word || !dontCapitalize.contains(lowercaseWord) {
                return word.prefix(1).uppercased() + word.dropFirst()
            } else {
                return lowercaseWord
            }
        }
        
        return capitalizedWords.joined(separator: " ")
    }
    
    private func inferTitleFromKeywords(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if containsFuzzyKeyword(lowercased, keywords: ["test", "exam", "quiz"]) {
            return "Test"
        } else if containsFuzzyKeyword(lowercased, keywords: ["meeting", "appointment"]) {
            return "Meeting"
        } else if containsFuzzyKeyword(lowercased, keywords: ["homework", "assignment", "project"]) {
            return "Assignment" 
        } else if containsFuzzyKeyword(lowercased, keywords: ["presentation", "present"]) {
            return "Presentation"
        } else if containsFuzzyKeyword(lowercased, keywords: ["interview"]) {
            return "Interview"
        } else if containsFuzzyKeyword(lowercased, keywords: ["doctor", "dentist", "appointment"]) {
            return "Appointment"
        } else {
            return "Event"
        }
    }
    
    // MARK: - Levenshtein Distance and Fuzzy Matching
    private func cleanAndNormalizeTitle(_ title: String) -> String {
        return properlyCapitalize(extractCoreSubject(from: title))
    }
    
    private func extractDaysOfWeek(from text: String) -> Set<DayOfWeek> {
        let lowercased = text.lowercased()
        var days: Set<DayOfWeek> = []
        
        if containsFuzzyKeyword(lowercased, keywords: ["weekday", "weekdays", "wkday", "wkdays", "week day", "week days"]) {
            days.formUnion([.monday, .tuesday, .wednesday, .thursday, .friday])
            return days
        }
        
        if containsFuzzyKeyword(lowercased, keywords: ["weekend", "weekends", "wkend", "wkends", "week end", "week ends"]) {
            days.formUnion([.saturday, .sunday])
            return days
        }
        
        let dayMappings: [String: (DayOfWeek, [String])] = [
            "monday": (.monday, ["monday", "mon", "mnday", "moday"]),
            "tuesday": (.tuesday, ["tuesday", "tue", "tues", "tusday", "teusday"]),
            "wednesday": (.wednesday, ["wednesday", "wed", "wednesdey", "wednsday"]),
            "thursday": (.thursday, ["thursday", "thu", "thur", "thursdy", "thrusday"]),
            "friday": (.friday, ["friday", "fri", "fridey", "friady"]),
            "saturday": (.saturday, ["saturday", "sat", "saturdy", "satruday"]),
            "sunday": (.sunday, ["sunday", "sun", "sundy", "suday"])
        ]
        
        for (_, (dayEnum, variants)) in dayMappings {
            if containsFuzzyKeyword(lowercased, keywords: variants) {
                days.insert(dayEnum)
            }
        }
        
        let abbreviations = ["mwf", "tth", "tr", "mw", "wf", "th"]
        for abbrev in abbreviations {
            let textWords = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            
            for word in textWords {
                if fuzzyMatches(word, abbrev) {
                    switch abbrev {
                    case "mwf":
                        days.formUnion([.monday, .wednesday, .friday])
                    case "tth", "tr":
                        days.formUnion([.tuesday, .thursday])
                    case "mw":
                        days.formUnion([.monday, .wednesday])
                    case "wf":
                        days.formUnion([.wednesday, .friday])
                    case "th":
                        days.insert(.thursday)
                    default:
                        break
                    }
                }
            }
        }
        
        return days
    }
    
    private func extractScheduleTimes(from text: String) -> (start: DateComponents?, end: DateComponents?, duration: TimeInterval?) {
        var startTime: DateComponents? = nil
        var endTime: DateComponents? = nil
        var duration: TimeInterval? = nil
        
        if let hyphenRange = text.range(of: "(\\d{1,2}(?::\\d{2})?)-?(\\d{1,2}(?::\\d{2})?)\\s*(am|pm)?", options: .regularExpression) {
            let match = String(text[hyphenRange])
            let components = match.components(separatedBy: "-")
            
            if components.count == 2 {
                let startPart = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let endPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                let amPmSuffix = match.lowercased().contains("am") ? "am" : (match.lowercased().contains("pm") ? "pm" : "")
                
                if !amPmSuffix.isEmpty {
                    let startTimeString = startPart + amPmSuffix
                    startTime = parseTimeString(startTimeString)
                    
                    let endTimeString = endPart + amPmSuffix
                    endTime = parseTimeString(endTimeString)
                } else {
                    startTime = parseTimeString(startPart)
                    endTime = parseTimeString(endPart)
                }
            }
        } else if let fromToRange = text.range(of: "from\\s+(\\d{1,2}:\\d{2}(?:am|pm)?|\\d{1,2}(?:am|pm))\\s+to\\s+(\\d{1,2}:\\d{2}(?:am|pm)?|\\d{1,2}(?:am|pm))", options: .regularExpression) {
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
        } else if let range = text.range(of: "(\\d{1,2})\\s*(am|pm)", options: .regularExpression) {
            let match = String(text[range])
            if let hourRange = match.range(of: "\\d{1,2}", options: .regularExpression) {
                let hourString = String(match[hourRange])
                if let hour = Int(hourString) {
                    var finalHour = hour
                    if match.contains("pm") && hour != 12 {
                        finalHour = hour + 12
                    } else if match.contains("am") && hour == 12 {
                        finalHour = 0
                    }
                    
                    startTime = DateComponents(hour: finalHour, minute: 0)
                }
            }
        } else if let range = text.range(of: "\\b(\\d{1,2}):(\\d{2})\\b", options: .regularExpression) {
            let match = String(text[range])
            let components = match.components(separatedBy: ":")
            
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]),
               hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 {
                startTime = DateComponents(hour: hour, minute: minute)
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
        
        if containsFuzzyKeyword(cleaned, keywords: ["noon", "12pm", "12:00pm"]) {
            return DateComponents(hour: 12, minute: 0)
        }
        
        if containsFuzzyKeyword(cleaned, keywords: ["midnight", "12am", "12:00am"]) {
            return DateComponents(hour: 0, minute: 0)
        }
        
        if let range = cleaned.range(of: "(\\d{1,2}):(\\d{2})\\s*(am|pm)?", options: .regularExpression) {
            let match = String(cleaned[range])
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
        
        if let range = cleaned.range(of: "(\\d{1,2})\\s*(am|pm)", options: .regularExpression) {
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
        
        if let range = cleaned.range(of: "(\\d{1,2}):(\\d{2})", options: .regularExpression) {
            let match = String(cleaned[range])
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
    
    private func formatTime(_ timeComponents: DateComponents) -> String {
        guard let hour = timeComponents.hour, let minute = timeComponents.minute else {
            return "Unknown time"
        }
        
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        
        if minute == 0 {
            return "\(displayHour) \(period)"
        } else {
            return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
        }
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
        
        for category in availableCategories {
            if fuzzyMatches(lowercased, category.name.lowercased()) {
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
        
        for (keyword, categoryName) in commonCategoryMappings {
            if containsFuzzyKeyword(lowercased, keywords: [keyword]) {
                if let existingCategory = availableCategories.first(where: { $0.name.lowercased() == categoryName.lowercased() }) {
                    return existingCategory.name
                } else {
                    return categoryName
                }
            }
        }
        
        let words = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
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
        
        if containsFuzzyKeyword(text, keywords: strongEventIndicators) {
            return true
        }
        
        if text.contains("got") {
            let eventContext = ["meeting", "appointment", "interview", "class", "lecture"]
            if containsFuzzyKeyword(text, keywords: eventContext) {
                return true
            }
            
            let timeContext = ["next", "tomorrow", "today", "at ", "pm", "am", "tuesday", "monday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            if containsFuzzyKeyword(text, keywords: timeContext) {
                return true
            }
        }
        
        return false
    }
    
    private func isActualGradeContext(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        let gradePatterns = [
            "got.*\\d+/\\d+.*on",
            "got.*\\d+%.*on",
            "got.*[a-f][+-)?.*on",
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
            if containsFuzzyKeyword(lowercased, keywords: academicContext) {
                return true
            }
        }
        
        return false
    }
}
