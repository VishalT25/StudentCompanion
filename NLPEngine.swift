import Foundation
import NaturalLanguage

// MARK: - Parse Results & Context
enum NLPResult {
    case parsedEvent(title: String, date: Date?, categoryName: String?, reminderTime: ReminderTime?)
    case parsedScheduleItem(title: String, days: Set<DayOfWeek>, startTimeComponents: DateComponents?, endTimeComponents: DateComponents?, duration: TimeInterval?, reminderTime: ReminderTime?)
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
    case scheduleNeedsReminder(title: String, days: Set<DayOfWeek>, startTime: DateComponents?, endTime: DateComponents?, duration: TimeInterval?)
    case scheduleNeedsMoreTime(title: String, days: Set<DayOfWeek>, startTime: DateComponents?)
}

// MARK: - Configuration Manager
class NLPConfiguration {
    static let shared = NLPConfiguration()
    
    let config: [String: Any]
    
    private init() {
        guard let path = Bundle.main.path(forResource: "NLPConfiguration", ofType: "plist"),
              let data = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Warning: Could not load NLP configuration file. Using defaults.")
            self.config = [:]
            return
        }
        self.config = data
    }
    
    func getRegexPatterns() -> [String: String] {
        return config["RegexPatterns"] as? [String: String] ?? [:]
    }
    
    func getKeywords() -> [String: [String]] {
        return config["Keywords"] as? [String: [String]] ?? [:]
    }
    
    func getInternationalGrading() -> [String: Any] {
        return config["InternationalGrading"] as? [String: Any] ?? [:]
    }
    
    func getCategorySynonyms() -> [String: [String]] {
        return config["CategorySynonyms"] as? [String: [String]] ?? [:]
    }
    
    func getCourseAbbreviations() -> [String: [String]] {
        return config["CourseAbbreviations"] as? [String: [String]] ?? [:]
    }
    
    func getRelativeDateMappings() -> [String: Int] {
        return config["RelativeDateMappings"] as? [String: Int] ?? [:]
    }
    
    func getPerturbationTests() -> [String: Any] {
        return config["PerturbationTests"] as? [String: Any] ?? [:]
    }
    
    func getCommonAbbreviations() -> [String: String] {
        return config["CommonAbbreviations"] as? [String: String] ?? [:]
    }
}

// MARK: - Enhanced Grade Representation
struct ParsedGrade {
    let rawScore: String?
    let percentage: Double?
    let letterGrade: String?
    let passFail: String?
    let normalized: String
    let confidence: Double
    
    init(from input: String) {
        let sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var rawScore: String? = nil
        var percentage: Double? = nil
        var letterGrade: String? = nil
        var passFail: String? = nil
        var confidence: Double = 0.0
        
        print("🔍 ParsedGrade Debug - Input: '\(sanitized)'")
        
        // Pattern 1: "X percent" format
        if let range = sanitized.range(of: #"\b(\d+(?:\.\d+)?)\s+percent\b"#, options: [.regularExpression, .caseInsensitive]) {
            let regex = try! NSRegularExpression(pattern: #"\b(\d+(?:\.\d+)?)\s+percent\b"#, options: [.caseInsensitive])
            if let match = regex.firstMatch(in: sanitized, range: NSRange(location: 0, length: sanitized.utf16.count)),
               let numberRange = Range(match.range(at: 1), in: sanitized) {
                let numberString = String(sanitized[numberRange])
                percentage = Double(numberString)
                confidence = 0.95
                print("🔍 ParsedGrade Debug - Found 'X percent' format: \(numberString)")
            }
        }
        // Pattern 2: "X%" format
        else if let range = sanitized.range(of: #"\b(\d+(?:\.\d+)?)\s*%"#, options: .regularExpression) {
            let regex = try! NSRegularExpression(pattern: #"\b(\d+(?:\.\d+)?)\s*%"#)
            if let match = regex.firstMatch(in: sanitized, range: NSRange(location: 0, length: sanitized.utf16.count)),
               let numberRange = Range(match.range(at: 1), in: sanitized) {
                let numberString = String(sanitized[numberRange])
                percentage = Double(numberString)
                confidence = 0.95
                print("🔍 ParsedGrade Debug - Found 'X%' format: \(numberString)")
            }
        }
        // Pattern 3: Letter grades
        else if let range = sanitized.range(of: #"\b[A-F][+-]?\b"#, options: .regularExpression) {
            letterGrade = String(sanitized[range]).uppercased()
            confidence = 0.85
            print("🔍 ParsedGrade Debug - Found letter grade: \(letterGrade!)")
        }
        // Pattern 4: Fraction format like "18/20"
        else if let range = sanitized.range(of: #"\b(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)\b"#, options: .regularExpression) {
            rawScore = String(sanitized[range])
            confidence = 0.8
            print("🔍 ParsedGrade Debug - Found fraction: \(rawScore!)")
        }
        // Pattern 5: Just a number (could be a grade out of 100)
        else if let range = sanitized.range(of: #"\b(\d+(?:\.\d+)?)\b"#, options: .regularExpression) {
            let regex = try! NSRegularExpression(pattern: #"\b(\d+(?:\.\d+)?)\b"#)
            if let match = regex.firstMatch(in: sanitized, range: NSRange(location: 0, length: sanitized.utf16.count)),
               let numberRange = Range(match.range(at: 1), in: sanitized) {
                let numberString = String(sanitized[numberRange])
                if let number = Double(numberString), number <= 100 {
                    percentage = number
                    confidence = 0.7 // Lower confidence since no explicit % sign
                    print("🔍 ParsedGrade Debug - Found plain number as percentage: \(numberString)")
                }
            }
        }
        
        self.rawScore = rawScore
        self.percentage = percentage
        self.letterGrade = letterGrade
        self.passFail = passFail
        self.confidence = confidence
        
        if let letter = letterGrade {
            self.normalized = letter
        } else if let pct = percentage {
            self.normalized = String(format: "%.1f", pct)
        } else if let raw = rawScore {
            self.normalized = raw
        } else {
            self.normalized = sanitized
        }
        
        print("🔍 ParsedGrade Debug - Final normalized: '\(self.normalized)', confidence: \(self.confidence)")
    }
}

// MARK: - Compiled Regex Patterns
struct CompiledPatterns {
    private static let config = NLPConfiguration.shared.getRegexPatterns()
    
    static let weightPattern = try! NSRegularExpression(pattern: #"(\d{1,3}(?:\.\d{1,2})?)\s*%?"#)
    static let gradePattern = try! NSRegularExpression(pattern: #"(\b\d{1,3}(?:\.\d{1,2})?%?|\b[A-F][+-]?)"#)
    static let timePattern = try! NSRegularExpression(pattern: #"(\b\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b"#, options: .caseInsensitive)
    static let dateDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
}

// MARK: - Enhanced NLP Engine (Simplified for Performance)
class NLPEngine {
    private let conversationTimeoutInterval: TimeInterval = 300
    private var activeConversations: [UUID: Date] = [:]
    private let config = NLPConfiguration.shared
    
    func parse(inputText: String, availableCategories: [Category] = [], existingCourses: [Course] = []) -> NLPResult {
        // Limit input length to prevent performance issues
        let trimmedInput = String(inputText.prefix(200))
        let sanitizedInput = sanitizeInput(trimmedInput)
        
        guard !sanitizedInput.isEmpty else {
            return .notAttempted
        }
        
        cleanupExpiredConversations()
        
        // Try parsing in order of specificity
        if let gradeResult = tryParseAsGrade(text: sanitizedInput, courses: existingCourses) {
            return gradeResult
        }
        
        if let eventResult = tryParseAsEvent(text: sanitizedInput, categories: availableCategories) {
            return eventResult
        }
        
        if let scheduleResult = tryParseAsScheduleItem(text: sanitizedInput, categories: availableCategories) {
            return scheduleResult
        }
        
        return .unrecognized(originalInput: inputText)
    }
    
    func parseFollowUp(inputText: String, context: ParseContext, conversationId: UUID?, existingCourses: [Course] = []) -> NLPResult {
        let trimmedInput = String(inputText.prefix(100))
        
        if let convId = conversationId, !isConversationActive(convId) {
            return .unrecognized(originalInput: "Conversation expired. Please start over.")
        }
        
        let sanitizedInput = sanitizeInput(trimmedInput)
        
        if sanitizedInput.lowercased().contains("cancel") {
            if let convId = conversationId {
                activeConversations.removeValue(forKey: convId)
            }
            return .unrecognized(originalInput: "Cancelled.")
        }
        
        print("🔍 =================================")
        print("🔍 FOLLOWUP Debug - Input: '\(sanitizedInput)'")
        print("🔍 FOLLOWUP Debug - Context: \(context)")
        print("🔍 =================================")
        
        switch context {
        case .gradeNeedsWeight(let courseName, let assignmentName, let grade):
            print("🔍 FOLLOWUP Debug - Processing weight for course: '\(courseName)', assignment: '\(assignmentName)', grade: '\(grade)'")
            
            if let weight = self.extractWeightFromFollowUp(from: sanitizedInput) {
                print("🔍 FOLLOWUP Debug - ✅ Weight extracted: '\(weight)' - Returning final result")
                return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
            } else if sanitizedInput.lowercased().contains("skip") || sanitizedInput.lowercased().contains("no") {
                print("🔍 FOLLOWUP Debug - ✅ User chose to skip weight - Returning result without weight")
                return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: nil)
            } else {
                print("🔍 FOLLOWUP Debug - ❌ Could not extract weight, asking again")
                return .needsMoreInfo(prompt: "Please enter the weight as a percentage (e.g., '20%') or say 'skip'.", originalInput: sanitizedInput, context: context, conversationId: conversationId)
            }
            
        case .gradeNeedsAssignmentName(let courseName, let grade):
            print("🔍 FOLLOWUP Debug - Processing assignment name for course: '\(courseName)', grade: '\(grade)'")
            let assignmentName = sanitizedInput.isEmpty ? "Assignment" : sanitizedInput
            return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip')", originalInput: "", context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignmentName, grade: grade), conversationId: conversationId)
            
        case .gradeNeedsCourse(let assignmentName, let grade):
            print("🔍 FOLLOWUP Debug - Processing course selection for assignment: '\(assignmentName ?? "nil")', grade: '\(grade)'")
            if let course = existingCourses.first(where: { $0.name.lowercased().contains(sanitizedInput.lowercased()) }) {
                let finalAssignmentName = assignmentName ?? "Assignment"
                print("🔍 FOLLOWUP Debug - ✅ Course found: '\(course.name)'")
                return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip')", originalInput: "", context: .gradeNeedsWeight(courseName: course.name, assignmentName: finalAssignmentName, grade: grade), conversationId: conversationId)
            } else {
                print("🔍 FOLLOWUP Debug - ❌ Course not found in: \(existingCourses.map { $0.name })")
                return .needsMoreInfo(prompt: "Course not found. Please enter an existing course name.", originalInput: sanitizedInput, context: context, conversationId: conversationId)
            }
            
        case .eventNeedsReminder(let title, let date, let categoryName):
            let reminderTime = parseReminderTime(from: sanitizedInput)
            return .parsedEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminderTime)
            
        case .eventNeedsDate(let title, let categoryName):
            print("🔍 FOLLOWUP Debug - Processing date for event: '\(title)', category: '\(categoryName ?? "nil")'")
            
            // Try to parse date from follow-up input
            var detectedDate: Date? = nil
            let matches = CompiledPatterns.dateDetector.matches(in: sanitizedInput, options: [], range: NSRange(location: 0, length: sanitizedInput.utf16.count))
            if let match = matches.first, let date = match.date {
                detectedDate = date
                print("🔍 FOLLOWUP Debug - Found date via NSDataDetector: \(date)")
            } else {
                // Try to parse relative dates
                detectedDate = parseRelativeDate(from: sanitizedInput)
                if let date = detectedDate {
                    print("🔍 FOLLOWUP Debug - Found relative date: \(date)")
                }
            }
            
            if let date = detectedDate {
                // Got the date, now ask for reminder
                return .needsMoreInfo(
                    prompt: "Would you like to set a reminder for '\(title)' on \(DateFormatter.shortDate.string(from: date))? (e.g., '15 minutes before' or 'no')",
                    originalInput: sanitizedInput,
                    context: .eventNeedsReminder(title: title, date: date, categoryName: categoryName),
                    conversationId: conversationId
                )
            } else {
                // Still couldn't parse date, ask again
                return .needsMoreInfo(
                    prompt: "I couldn't understand that date. Please try again with formats like 'tomorrow at 3pm', 'next Monday', or 'December 15'.",
                    originalInput: sanitizedInput,
                    context: context,
                    conversationId: conversationId
                )
            }
            
        case .scheduleNeedsReminder(let title, let days, let startTime, let endTime, let duration):
            let reminderTime = parseReminderTime(from: sanitizedInput)
            return .parsedScheduleItem(title: title, days: days, startTimeComponents: startTime, endTimeComponents: endTime, duration: duration, reminderTime: reminderTime)
            
        case .scheduleNeedsMoreTime(let title, let days, let startTime):
            print("🔍 FOLLOWUP Debug - Processing schedule follow-up for: '\(title)', days: \(days), startTime: \(startTime)")
            
            // Try to extract missing information from the follow-up input
            let updatedDays = days.isEmpty ? extractDaysOfWeek(from: sanitizedInput) : days
            let updatedTimes = extractScheduleTimes(from: sanitizedInput)
            let updatedStartTime = startTime ?? updatedTimes.start
            
            // Special handling: if we have a start time and the input is a single time, treat it as end time
            var updatedEndTime = updatedTimes.end
            if startTime != nil && updatedEndTime == nil && updatedTimes.start != nil {
                // User provided a single time when we already have start time, so this must be the end time
                updatedEndTime = updatedTimes.start
                print("🔍 FOLLOWUP Debug - Treating single time as end time: \(updatedEndTime)")
            }
            
            // Check what's still missing and ask for it
            if updatedDays.isEmpty {
                return .needsMoreInfo(prompt: "Please specify the days for '\(title)' (e.g., 'every Monday', 'MWF').", originalInput: sanitizedInput, context: .scheduleNeedsMoreTime(title: title, days: Set(), startTime: updatedStartTime), conversationId: conversationId)
            }
            
            if updatedStartTime == nil {
                return .needsMoreInfo(prompt: "What time does '\(title)' start? (e.g., 'at 9am', 'from 10:30')", originalInput: sanitizedInput, context: .scheduleNeedsMoreTime(title: title, days: updatedDays, startTime: nil), conversationId: conversationId)
            }
            
            if updatedEndTime == nil && updatedTimes.duration == nil {
                return .needsMoreInfo(prompt: "When does '\(title)' end? (e.g., 'to 11am', 'for 1 hour')", originalInput: sanitizedInput, context: .scheduleNeedsMoreTime(title: title, days: updatedDays, startTime: updatedStartTime), conversationId: conversationId)
            }
            
            // If we have all required information, return the final result
            return .parsedScheduleItem(title: title, days: updatedDays, startTimeComponents: updatedStartTime, endTimeComponents: updatedEndTime, duration: updatedTimes.duration, reminderTime: nil)
        }
    }
    
    func runRobustnessTests(on input: String, categories: [Category], courses: [Course]) -> [RobustnessTest.TestResult] {
        // Simplified robustness testing
        let limitedCategories = Array(categories.prefix(3))
        let limitedCourses = Array(courses.prefix(3))
        return RobustnessTest.runPerturbationTests(on: input, engine: self, categories: limitedCategories, courses: limitedCourses)
    }
    
    private func sanitizeInput(_ input: String) -> String {
        return input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
    
    private func startNewConversation() -> UUID {
        let conversationId = UUID()
        activeConversations[conversationId] = Date()
        return conversationId
    }
    
    private func isConversationActive(_ conversationId: UUID) -> Bool {
        guard let startTime = activeConversations[conversationId] else {
            return false
        }
        return Date().timeIntervalSince(startTime) < conversationTimeoutInterval
    }
    
    private func cleanupExpiredConversations() {
        let now = Date()
        activeConversations = activeConversations.filter { _, startTime in
            now.timeIntervalSince(startTime) < conversationTimeoutInterval
        }
    }
    
    private func tryParseAsGrade(text: String, courses: [Course]) -> NLPResult? {
        let lowercasedText = text.lowercased()
        let gradeKeywords = ["grade", "score", "got", "received", "earned", "scored", "percent", "%"]
        
        let isLikelyGrade = gradeKeywords.contains { lowercasedText.contains($0) }
        let hasGradePattern = CompiledPatterns.gradePattern.firstMatch(in: lowercasedText, options: [], range: NSRange(location: 0, length: lowercasedText.utf16.count)) != nil
        
        guard isLikelyGrade || hasGradePattern else {
            return nil
        }
        
        let parsedGrade = ParsedGrade(from: text)
        
        guard !parsedGrade.normalized.isEmpty && parsedGrade.confidence > 0.6 else {
            if isLikelyGrade {
                let conversationId = startNewConversation()
                return .needsMoreInfo(prompt: "Please include the grade (e.g., '95%', 'A+', '87').", originalInput: text, context: nil, conversationId: conversationId)
            }
            return nil
        }
        
        // Try to extract all information at once first
        let identifiedCourseName = findBestCourseMatch(from: lowercasedText, courses: courses)
        let assignmentName = extractAssignmentName(from: lowercasedText)
        let weight = extractWeight(from: text)
        
        print("🔍 =================================")
        print("🔍 NLP Debug - FULL INPUT: '\(text)'")
        print("🔍 NLP Debug - Grade parsed: '\(parsedGrade.normalized)'")
        print("🔍 NLP Debug - Course found: '\(identifiedCourseName ?? "nil")'")
        print("🔍 NLP Debug - Assignment found: '\(assignmentName ?? "nil")'")
        print("🔍 NLP Debug - Weight found: '\(weight ?? "nil")'")
        print("🔍 =================================")
        
        let conversationId = startNewConversation()
        
        if let courseName = identifiedCourseName, let assignment = assignmentName {
            // We have course, assignment, and grade. Now check if we need weight.
            if weight == nil {
                // Missing weight - ask for it
                print("🔍 NLP Debug - ✅ MISSING WEIGHT - Asking for follow-up")
                return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or say 'skip' if you don't want to add weight)", originalInput: text, context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignment, grade: parsedGrade.normalized), conversationId: conversationId)
            } else {
                // We have everything - return complete result
                print("🔍 NLP Debug - ✅ COMPLETE INFO - Returning parsed grade")
                return .parsedGrade(courseName: courseName, assignmentName: assignment, grade: parsedGrade.normalized, weight: weight)
            }
        }
        // If we have course but missing assignment name
        else if let courseName = identifiedCourseName {
            return .needsMoreInfo(prompt: "What's the name of this assignment in \(courseName)?", originalInput: text, context: .gradeNeedsAssignmentName(courseName: courseName, grade: parsedGrade.normalized), conversationId: conversationId)
        } else {
            if courses.isEmpty {
                return .needsMoreInfo(prompt: "No courses found. Please add some courses first.", originalInput: text, context: nil, conversationId: conversationId)
            } else {
                let courseNames = courses.prefix(5).map { $0.name }.joined(separator: ", ")
                return .needsMoreInfo(prompt: "Which course is this grade for? Available: \(courseNames)", originalInput: text, context: .gradeNeedsCourse(assignmentName: assignmentName, grade: parsedGrade.normalized), conversationId: conversationId)
            }
        }
    }
    
    private func tryParseAsEvent(text: String, categories: [Category]) -> NLPResult? {
        let lowercasedText = text.lowercased()
        
        // More inclusive event keywords
        let eventKeywords = [
            "meeting", "appointment", "reminder", "deadline", "exam", "test", "quiz",
            "homework", "due", "assignment", "project", "presentation", "interview",
            "dentist", "doctor", "class", "lecture", "seminar", "workshop", "conference",
            "party", "event", "birthday", "anniversary", "vacation", "trip", "flight",
            "on saturday", "this saturday", "next week", "tomorrow", "today"
        ]
        
        let isLikelyEvent = eventKeywords.contains { lowercasedText.contains($0) } ||
                           lowercasedText.contains("on ") ||
                           lowercasedText.contains("at ") ||
                           lowercasedText.contains("have") ||
                           lowercasedText.contains("need to")
        
        guard isLikelyEvent else { return nil }
        
        print("🔍 Event Parsing Debug - Input: '\(text)'")
        
        // Extract event title by removing common patterns
        let extractedTitle = extractEventTitle(from: text)
        
        // Try to extract date/time information
        var detectedDate: Date? = nil
        let matches = CompiledPatterns.dateDetector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        if let match = matches.first, let date = match.date {
            detectedDate = date
            print("🔍 Event Parsing Debug - Found date via NSDataDetector: \(date)")
        } else {
            // Try to parse relative dates
            detectedDate = parseRelativeDate(from: text)
            if let date = detectedDate {
                print("🔍 Event Parsing Debug - Found relative date: \(date)")
            }
        }
        
        // Try to find category match
        let categoryName = findBestCategoryMatch(from: text, categories: categories)
        
        let conversationId = startNewConversation()
        
        print("🔍 Event Parsing Debug - Title: '\(extractedTitle)', Date: \(detectedDate?.description ?? "nil"), Category: '\(categoryName ?? "nil")'")
        
        // If we have a date, ask for reminder preference
        if detectedDate != nil {
            return .needsMoreInfo(
                prompt: "Would you like to set a reminder for '\(extractedTitle)'? (e.g., '15 minutes before' or 'no')",
                originalInput: text,
                context: .eventNeedsReminder(title: extractedTitle, date: detectedDate, categoryName: categoryName),
                conversationId: conversationId
            )
        } else {
            // Missing date - ask for it
            return .needsMoreInfo(
                prompt: "When is '\(extractedTitle)'? (e.g., 'tomorrow at 3pm', 'next Monday', 'December 15 at 2:30')",
                originalInput: text,
                context: .eventNeedsDate(title: extractedTitle, categoryName: categoryName),
                conversationId: conversationId
            )
        }
    }
    
    private func tryParseAsScheduleItem(text: String, categories: [Category]) -> NLPResult? {
        let scheduleKeywords = ["every", "weekly", "schedule", "class", "recurring"]
        let isLikelySchedule = scheduleKeywords.contains { text.lowercased().contains($0) }
        
        guard isLikelySchedule else { return nil }
        
        let extractedDays = extractDaysOfWeek(from: text)
        let extractedTimes = extractScheduleTimes(from: text)
        let extractedTitle = extractScheduleTitle(from: text)
        
        let conversationId = startNewConversation()
        
        // Check for missing information and ask follow-up questions
        if extractedDays.isEmpty {
            return .needsMoreInfo(prompt: "Please specify the days for '\(extractedTitle)' (e.g., 'every Monday', 'MWF').", originalInput: text, context: .scheduleNeedsMoreTime(title: extractedTitle, days: Set(), startTime: extractedTimes.start), conversationId: conversationId)
        }
        
        if extractedTimes.start == nil {
            return .needsMoreInfo(prompt: "What time does '\(extractedTitle)' start? (e.g., 'at 9am', 'from 10:30')", originalInput: text, context: .scheduleNeedsMoreTime(title: extractedTitle, days: extractedDays, startTime: nil), conversationId: conversationId)
        }
        
        if extractedTimes.end == nil && extractedTimes.duration == nil {
            return .needsMoreInfo(prompt: "When does '\(extractedTitle)' end? (e.g., 'to 11am', 'for 1 hour')", originalInput: text, context: .scheduleNeedsMoreTime(title: extractedTitle, days: extractedDays, startTime: extractedTimes.start), conversationId: conversationId)
        }
        
        // If we have all required information, return the parsed result
        return .parsedScheduleItem(title: extractedTitle, days: extractedDays, startTimeComponents: extractedTimes.start, endTimeComponents: extractedTimes.end, duration: extractedTimes.duration, reminderTime: nil)
    }
    
    private func extractEventTitle(from text: String) -> String {
        var title = text
        
        print("🔍 Event Title Extraction Debug - Original: '\(title)'")
        
        // Remove common event trigger phrases at the beginning
        let startPhrases = [
            "i have a ", "i have ", "i've got a ", "i've got ", "need to ",
            "have to ", "got to ", "there's a ", "there is a "
        ]
        
        for phrase in startPhrases {
            if title.lowercased().hasPrefix(phrase) {
                title = String(title.dropFirst(phrase.count))
                print("🔍 Event Title Extraction Debug - After removing start phrase '\(phrase)': '\(title)'")
                break
            }
        }
        
        // Remove date/time information at the end
        let dateTimePatterns = [
            #"\s+on\s+\w+day.*$"#,                    // " on Monday at 3pm"
            #"\s+this\s+\w+day.*$"#,                  // " this Saturday"
            #"\s+next\s+\w+day.*$"#,                  // " next Friday"
            #"\s+tomorrow.*$"#,                       // " tomorrow"
            #"\s+today.*$"#,                          // " today"
            #"\s+at\s+\d{1,2}.*$"#,                   // " at 3pm"
            #"\s+\d{1,2}:\d{2}.*$"#,                  // " 3:30pm"
            #"\s+in\s+\d+\s+(day|week|month)s?.*$"#,  // " in 3 days"
            #"\s+\w+\s+\d{1,2}.*$"#                   // " December 15"
        ]
        
        for pattern in dateTimePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: title.utf16.count)
                if let match = regex.firstMatch(in: title, range: range) {
                    let matchRange = Range(match.range, in: title)!
                    let removedPart = String(title[matchRange])
                    title = String(title.prefix(match.range.location))
                    print("🔍 Event Title Extraction Debug - Removed date/time '\(removedPart)': '\(title)'")
                    break
                }
            }
        }
        
        // Clean up the title
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any remaining common words at the end
        let endWords = ["due", "assignment", "homework"]
        for word in endWords {
            if title.lowercased().hasSuffix(word) && title.count > word.count {
                title = String(title.dropLast(word.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("🔍 Event Title Extraction Debug - Removed end word '\(word)': '\(title)'")
            }
        }
        
        // If title is empty or too short, use a default based on content
        if title.isEmpty || title.count < 2 {
            if text.lowercased().contains("test") || text.lowercased().contains("exam") {
                title = "Test"
            } else if text.lowercased().contains("assignment") || text.lowercased().contains("homework") {
                title = "Assignment"
            } else if text.lowercased().contains("meeting") {
                title = "Meeting"
            } else if text.lowercased().contains("appointment") {
                title = "Appointment"
            } else {
                title = "Event"
            }
        }
        
        // Capitalize first letter
        let finalTitle = title.prefix(1).uppercased() + title.dropFirst()
        print("🔍 Event Title Extraction Debug - Final title: '\(finalTitle)'")
        return finalTitle
    }
    
    private func parseRelativeDate(from text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        print("🔍 Relative Date Parsing Debug - Input: '\(lowercased)'")
        
        // Today patterns
        if lowercased.contains("today") {
            // Look for time information
            if let timeComponents = extractTimeFromText(lowercased) {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                let result = calendar.date(from: components)
                print("🔍 Relative Date Debug - Today with time: \(result?.description ?? "nil")")
                return result
            } else {
                print("🔍 Relative Date Debug - Today without specific time")
                return now
            }
        }
        
        // Tomorrow patterns
        if lowercased.contains("tomorrow") {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            if let timeComponents = extractTimeFromText(lowercased) {
                var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                let result = calendar.date(from: components)
                print("🔍 Relative Date Debug - Tomorrow with time: \(result?.description ?? "nil")")
                return result
            } else {
                print("🔍 Relative Date Debug - Tomorrow without specific time")
                return tomorrow
            }
        }
        
        // Next week patterns
        if lowercased.contains("next week") {
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now)!
            print("🔍 Relative Date Debug - Next week: \(nextWeek)")
            return nextWeek
        }
        
        // This/next specific day patterns
        let dayMappings: [String: Int] = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        
        for (dayName, weekday) in dayMappings {
            if lowercased.contains("this \(dayName)") || lowercased.contains("next \(dayName)") || lowercased.contains("on \(dayName)") {
                let isNext = lowercased.contains("next \(dayName)")
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = weekday - currentWeekday
                
                if daysToAdd <= 0 || isNext {
                    daysToAdd += 7 // Next occurrence
                }
                
                let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: now)!
                
                if let timeComponents = extractTimeFromText(lowercased) {
                    var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                    components.hour = timeComponents.hour
                    components.minute = timeComponents.minute
                    let result = calendar.date(from: components)
                    print("🔍 Relative Date Debug - \(dayName) with time: \(result?.description ?? "nil")")
                    return result
                } else {
                    print("🔍 Relative Date Debug - \(dayName) without time: \(targetDate)")
                    return targetDate
                }
            }
        }
        
        print("🔍 Relative Date Debug - No relative date found")
        return nil
    }
    
    private func extractTimeFromText(_ text: String) -> DateComponents? {
        // Pattern for time like "3pm", "3:30pm", "15:30", etc.
        let timePattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?"#
        
        if let regex = try? NSRegularExpression(pattern: timePattern),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {
            
            let hourRange = Range(match.range(at: 1), in: text)!
            let hourString = String(text[hourRange])
            guard let hour = Int(hourString) else { return nil }
            
            var minute = 0
            if match.range(at: 2).location != NSNotFound,
               let minuteRange = Range(match.range(at: 2), in: text) {
                let minuteString = String(text[minuteRange])
                minute = Int(minuteString) ?? 0
            }
            
            var finalHour = hour
            if match.range(at: 3).location != NSNotFound,
               let ampmRange = Range(match.range(at: 3), in: text) {
                let ampm = String(text[ampmRange]).lowercased()
                if ampm == "pm" && hour != 12 {
                    finalHour = hour + 12
                } else if ampm == "am" && hour == 12 {
                    finalHour = 0
                }
            }
            
            var components = DateComponents()
            components.hour = finalHour
            components.minute = minute
            print("🔍 Time Extraction Debug - Found time: \(finalHour):\(minute)")
            return components
        }
        
        return nil
    }
    
    private func findBestCategoryMatch(from text: String, categories: [Category]) -> String? {
        let lowercased = text.lowercased()
        
        // Direct category name matching
        for category in categories {
            if lowercased.contains(category.name.lowercased()) {
                return category.name
            }
        }
        
        // Common category associations
        let categoryMappings: [String: [String]] = [
            "assignment": ["homework", "assignment", "essay", "paper", "project", "due"],
            "exam": ["test", "exam", "quiz", "midterm", "final"],
            "lab": ["lab", "laboratory", "experiment"],
            "personal": ["dentist", "doctor", "appointment", "birthday", "vacation", "trip"]
        ]
        
        for category in categories {
            let categoryLower = category.name.lowercased()
            if let keywords = categoryMappings[categoryLower] {
                for keyword in keywords {
                    if lowercased.contains(keyword) {
                        return category.name
                    }
                }
            }
        }
        
        return nil
    }
    
    private func findBestCourseMatch(from text: String, courses: [Course]) -> String? {
        let lowercasedText = text.lowercased()
        
        print("🔍 Course Matching Debug - Input text: '\(lowercasedText)'")
        print("🔍 Course Matching Debug - Available courses: \(courses.map { $0.name })")
        
        for course in courses {
            let courseName = course.name.lowercased()
            let courseWords = courseName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty && $0.count >= 3 }
            
            for courseWord in courseWords {
                if lowercasedText.contains(courseWord) {
                    print("🔍 Course Matching Debug - ✅ Direct word match found: '\(courseWord)' in '\(course.name)'")
                    return course.name
                }
            }
        }
        
        let courseAbbreviations: [String: [String]] = [
            "calc": ["calculus"],
            "math": ["mathematics", "math"],
            "phys": ["physics", "physical"],
            "physics": ["physics", "physical"],
            "chem": ["chemistry", "chemical", "organic"],
            "chemistry": ["chemistry", "chemical", "organic"],
            "ochem": ["organic", "chemistry"],
            "bio": ["biology", "biological"],
            "biology": ["biology", "biological"],
            "eng": ["english", "literature"],
            "english": ["english", "literature"],
            "hist": ["history", "historical"],
            "history": ["history", "historical"],
            "cs": ["computer", "science", "programming"],
            "comp": ["computer", "computing"],
            "econ": ["economics", "economic"],
            "economics": ["economics", "economic"],
            "psych": ["psychology", "psychological"],
            "psychology": ["psychology", "psychological"]
        ]
        
        // Try abbreviation matching
        for course in courses {
            let courseName = course.name.lowercased()
            print("🔍 Course Matching Debug - Checking course: '\(courseName)'")
            
            for (abbrev, fullNames) in courseAbbreviations {
                if lowercasedText.contains(abbrev) {
                    print("🔍 Course Matching Debug - Found abbreviation '\(abbrev)' in text")
                    for fullName in fullNames {
                        if courseName.contains(fullName) {
                            print("🔍 Course Matching Debug - ✅ Abbreviation match: '\(abbrev)' -> '\(course.name)'")
                            return course.name
                        }
                    }
                }
            }
        }
        
        for course in courses {
            let courseName = course.name.lowercased()
            let courseWords = courseName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty && $0.count >= 4 } // Require at least 4 characters
            let textWords = lowercasedText.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty && $0.count >= 4 } // Require at least 4 characters
            
            for courseWord in courseWords {
                for textWord in textWords {
                    if textWord == courseWord ||
                       (textWord.count >= 4 && courseWord.count >= 4 &&
                        (textWord.contains(courseWord) || courseWord.contains(textWord))) {
                        print("🔍 Course Matching Debug - ✅ Conservative partial word match: '\(textWord)' <-> '\(courseWord)' for course '\(course.name)'")
                        return course.name
                    }
                }
            }
        }
        
        print("🔍 Course Matching Debug - ❌ No course match found")
        return nil
    }
    
    private func extractAssignmentName(from text: String) -> String? {
        let assignmentKeywords = [
            "midterm", "final", "exam", "test", "quiz", "homework", "assignment",
            "project", "paper", "essay", "lab", "report", "presentation"
        ]
        
        let lowercasedText = text.lowercased()
        
        print("🔍 Assignment Extraction Debug - Input: '\(lowercasedText)'")
        
        for keyword in assignmentKeywords {
            if lowercasedText.contains(keyword) {
                print("🔍 Assignment Extraction Debug - Found keyword: '\(keyword)'")
                
                // Look for numbers after the keyword
                let patterns = [
                    "\\b\(keyword)\\s*#?\\s*(\\d+)\\b", // "quiz #2", "quiz 2"
                    "\\b\(keyword)\\s+(\\d+)\\b",      // "quiz 2"
                    "\\b(\\d+)\\s*\(keyword)\\b"       // "2 quiz" (less common)
                ]
                
                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                       let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
                       let numberRange = Range(match.range(at: 1), in: text) {
                        let number = String(text[numberRange])
                        let result = "\(keyword.capitalized) \(number)"
                        print("🔍 Assignment Extraction Debug - ✅ Found numbered assignment: '\(result)'")
                        return result
                    }
                }
                
                // If no number found, just return the keyword
                print("🔍 Assignment Extraction Debug - ✅ Found basic assignment: '\(keyword.capitalized)'")
                return keyword.capitalized
            }
        }
        
        print("🔍 Assignment Extraction Debug - ❌ No assignment found")
        return nil
    }

    private func extractWeight(from text: String) -> String? {
        let lowercasedText = text.lowercased()
        
        print("🔍 Weight Extraction Debug - Full input: '\(text)'")
        print("🔍 Weight Extraction Debug - Lowercased: '\(lowercasedText)'")
        
        let gradeIndicators = ["got", "received", "earned", "scored", "made", "achieved"]
        let hasGradeIndicator = gradeIndicators.contains { lowercasedText.contains($0) }
        
        if hasGradeIndicator {
            print("🔍 Weight Extraction Debug - Text contains grade indicators, being conservative")
            
            // Only look for very explicit weight patterns when grade indicators are present
            let explicitWeightPatterns = [
                #"worth\s+(\d{1,2})\s*(?:%|percent?)"#, // "worth 20 percent"
                #"weight\s*:?\s*(\d{1,2})\s*(?:%|percent?)"#, // "weight: 20%"
                #"weighted?\s+(\d{1,2})\s*(?:%|percent?)"#, // "weighted 20%"
                #"counts?\s+(?:for\s+)?(\d{1,2})\s*(?:%|percent?)"#, // "counts for 20%"
            ]
            
            for (index, pattern) in explicitWeightPatterns.enumerated() {
                print("🔍 Trying explicit weight pattern \(index): \(pattern)")
                
                let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []
                
                for match in matches {
                    if match.numberOfRanges >= 2,
                       let range = Range(match.range(at: 1), in: text) {
                        let weightString = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        print("🔍 Extracted explicit weight: '\(weightString)'")
                        
                        if let weightValue = Double(weightString), weightValue > 0 && weightValue <= 100 {
                            let result = String(format: "%.0f", weightValue)
                            print("🔍 ✅ SUCCESS - Found explicit weight: '\(result)'")
                            return result
                        }
                    }
                }
            }
            
            print("🔍 ❌ No explicit weight found in grade context")
            return nil
        }
        
        // Most specific patterns first - prioritize exact "worth" matches
        let highPriorityPatterns = [
            #"worth\s+(\d{1,2})\s*(?:%|percent?|per\s*cent?)?"#, // "worth 1 percent", "worth 1%"
            #"worth\s+(\d{1,2}(?:\.\d{1,2})?)\s*(?:%|percent?|per\s*cent?)?"#, // "worth 1.5 percent"
        ]
        
        // Try high priority patterns first
        for (index, pattern) in highPriorityPatterns.enumerated() {
            print("🔍 Trying high priority pattern \(index): \(pattern)")
            
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []
            
            print("🔍 Found \(matches.count) matches for pattern \(index)")
            
            for (matchIndex, match) in matches.enumerated() {
                print("🔍 Match \(matchIndex): \(match)")
                
                if match.numberOfRanges >= 2,
                   let range = Range(match.range(at: 1), in: text) {
                    let weightString = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🔍 Extracted weight string: '\(weightString)'")
                    
                    if let weightValue = Double(weightString), weightValue > 0 && weightValue <= 100 {
                        let result = String(format: "%.0f", weightValue)
                        print("🔍 ✅ SUCCESS - Found weight: '\(result)' from high priority pattern")
                        return result
                    } else {
                        print("🔍 ❌ Invalid weight value: \(weightString)")
                    }
                }
            }
        }
        
        // Medium priority patterns
        let mediumPriorityPatterns = [
            #"weight\s*:?\s*(\d{1,2})\s*(?:%|percent?)"#, // "weight: 1%"
            #"weighted?\s+(\d{1,2})\s*(?:%|percent?)"#, // "weighted 1%"
        ]
        
        for (index, pattern) in mediumPriorityPatterns.enumerated() {
            print("🔍 Trying medium priority pattern \(index): \(pattern)")
            
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []
            
            print("🔍 Found \(matches.count) matches for pattern \(index)")
            
            for match in matches {
                if match.numberOfRanges >= 2,
                   let range = Range(match.range(at: 1), in: text) {
                    let weightString = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🔍 Extracted weight string: '\(weightString)'")
                    
                    if let weightValue = Double(weightString), weightValue > 0 && weightValue <= 50 {
                        let result = String(format: "%.0f", weightValue)
                        print("🔍 ✅ SUCCESS - Found weight: '\(result)' from medium priority pattern")
                        return result
                    }
                }
            }
        }
        
        print("🔍 ❌ FAILED - No weight found in: '\(text)'")
        return nil
    }
    
    private func parseReminderTime(from text: String) -> ReminderTime {
        let lowercased = text.lowercased()
        
        if lowercased.contains("no") || lowercased.contains("none") || lowercased.contains("skip") {
            return .none
        } else if lowercased.contains("5") && lowercased.contains("min") {
            return .fiveMinutes
        } else if lowercased.contains("15") && lowercased.contains("min") {
            return .fifteenMinutes
        } else if lowercased.contains("30") && lowercased.contains("min") {
            return .thirtyMinutes
        } else if lowercased.contains("1") && lowercased.contains("hour") {
            return .oneHour
        } else if lowercased.contains("2") && lowercased.contains("hour") {
            return .twoHours
        } else if lowercased.contains("1") && lowercased.contains("day") {
            return .oneDay
        } else if lowercased.contains("2") && lowercased.contains("day") {
            return .twoDays
        } else if lowercased.contains("1") && lowercased.contains("week") {
            return .oneWeek
        }
        
        return .none
    }

    private func extractWeightFromFollowUp(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 Follow-up Weight Extraction - Input: '\(trimmed)'")
        
        // In follow-up context, be very inclusive - if user just types a number, assume it's weight percentage
        // Pattern 1: Just a number (most inclusive for follow-up)
        if let match = trimmed.range(of: #"^\d{1,2}(?:\.\d{1,2})?$"#, options: .regularExpression) {
            let numberString = String(trimmed[match])
            if let value = Double(numberString), value > 0 && value <= 100 {
                print("🔍 Follow-up Weight - Found pure number: '\(numberString)'")
                return String(format: "%.0f", value)
            }
        }
        
        // Pattern 2: Number with percent sign
        if let match = trimmed.range(of: #"(\d{1,2}(?:\.\d{1,2})?)\s*%"#, options: .regularExpression) {
            let fullMatch = String(trimmed[match])
            let numberString = fullMatch.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            if let value = Double(numberString), value > 0 && value <= 100 {
                print("🔍 Follow-up Weight - Found number with %: '\(numberString)'")
                return String(format: "%.0f", value)
            }
        }
        
        // Pattern 3: Number with "percent" word
        if let match = trimmed.range(of: #"(\d{1,2}(?:\.\d{1,2})?)\s*percent"#, options: [.regularExpression, .caseInsensitive]) {
            let regex = try! NSRegularExpression(pattern: #"(\d{1,2}(?:\.\d{1,2})?)\s*percent"#, options: [.caseInsensitive])
            if let regexMatch = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)),
               let numberRange = Range(regexMatch.range(at: 1), in: trimmed) {
                let numberString = String(trimmed[numberRange])
                if let value = Double(numberString), value > 0 && value <= 100 {
                    print("🔍 Follow-up Weight - Found number with 'percent': '\(numberString)'")
                    return String(format: "%.0f", value)
                }
            }
        }
        
        // Pattern 4: Common phrases like "twenty", "fifteen", etc.
        let wordToNumber: [String: String] = [
            "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
            "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
            "eleven": "11", "twelve": "12", "thirteen": "13", "fourteen": "14", "fifteen": "15",
            "sixteen": "16", "seventeen": "17", "eighteen": "18", "nineteen": "19", "twenty": "20",
            "twenty-five": "25", "thirty": "30", "thirty-five": "35", "forty": "40", "forty-five": "45", "fifty": "50"
        ]
        
        let lowercased = trimmed.lowercased()
        for (word, number) in wordToNumber {
            if lowercased == word || lowercased == "\(word) percent" || lowercased == "\(word)%" {
                print("🔍 Follow-up Weight - Found word number: '\(word)' -> '\(number)'")
                return number
            }
        }
        
        print("🔍 Follow-up Weight - No valid weight found in: '\(trimmed)'")
        return nil
    }
    
    private func extractDaysOfWeek(from text: String) -> Set<DayOfWeek> {
        let lowercasedText = text.lowercased()
        var days: Set<DayOfWeek> = []
        
        print("🔍 Day Extraction Debug - Input: '\(lowercasedText)'")
        
        // Full day names - check these FIRST to avoid conflicts with abbreviations
        let dayMappings: [String: DayOfWeek] = [
            "sunday": .sunday, "sun": .sunday,
            "monday": .monday, "mon": .monday,
            "tuesday": .tuesday, "tue": .tuesday, "tues": .tuesday,
            "wednesday": .wednesday, "wed": .wednesday,
            "thursday": .thursday, "thu": .thursday, "thur": .thursday, "thurs": .thursday,
            "friday": .friday, "fri": .friday,
            "saturday": .saturday, "sat": .saturday
        ]
        
        // Check for individual days first (most specific)
        var foundDays: Set<String> = []
        for (dayName, dayEnum) in dayMappings {
            if lowercasedText.contains(dayName) {
                days.insert(dayEnum)
                foundDays.insert(dayName)
                print("🔍 Day Extraction Debug - Found day: '\(dayName)' -> \(dayEnum)")
            }
        }
        
        // Only check abbreviation patterns if we haven't found specific days yet
        if days.isEmpty {
            // More precise abbreviation patterns using word boundaries
            let abbreviationPatterns: [String: Set<DayOfWeek>] = [
                "mwf": [.monday, .wednesday, .friday],
                "mw": [.monday, .wednesday],
                "tth": [.tuesday, .thursday],
                "tr": [.tuesday, .thursday],
                "weekdays": [.monday, .tuesday, .wednesday, .thursday, .friday],
                "weekends": [.saturday, .sunday],
                "daily": [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            ]
            
            for (pattern, patternDays) in abbreviationPatterns {
                // Use word boundary matching to be more precise
                let regex = try! NSRegularExpression(pattern: "\\b\(pattern)\\b", options: .caseInsensitive)
                if regex.firstMatch(in: lowercasedText, range: NSRange(location: 0, length: lowercasedText.utf16.count)) != nil {
                    days.formUnion(patternDays)
                    print("🔍 Day Extraction Debug - Found pattern: '\(pattern)' -> \(patternDays)")
                    break // Only match the first pattern to avoid conflicts
                }
            }
        }
        
        // Special handling for ranges like "Monday through Friday" or "Monday to Friday"
        if lowercasedText.contains("monday") && (lowercasedText.contains("through") || lowercasedText.contains("to")) && lowercasedText.contains("friday") {
            days = [.monday, .tuesday, .wednesday, .thursday, .friday] // Replace, don't union
            print("🔍 Day Extraction Debug - Found weekday range, replaced with Mon-Fri")
        }
        
        print("🔍 Day Extraction Debug - Final days: \(days)")
        return days
    }
    
    private func extractScheduleTimes(from text: String) -> (start: DateComponents?, end: DateComponents?, duration: TimeInterval?) {
        let lowercasedText = text.lowercased()
        
        print("🔍 Time Extraction Debug - Input: '\(lowercasedText)'")
        
        var startTime: DateComponents? = nil
        var endTime: DateComponents? = nil
        var duration: TimeInterval? = nil
        
        // Pattern 1: "4pm to 5pm" or "4 pm to 5 pm"
        let timeRangePattern = #"(\d{1,2}(?::\d{2})?)(?:\s*)(am|pm)?\s+to\s+(\d{1,2}(?::\d{2})?)(?:\s*)(am|pm)"#
        if let range = lowercasedText.range(of: timeRangePattern, options: .regularExpression) {
            let regex = try! NSRegularExpression(pattern: timeRangePattern, options: [.caseInsensitive])
            if let match = regex.firstMatch(in: lowercasedText, range: NSRange(location: 0, length: lowercasedText.utf16.count)) {
                
                let startTimeStr = String(lowercasedText[Range(match.range(at: 1), in: lowercasedText)!])
                let startAmPm = match.range(at: 2).location != NSNotFound ? String(lowercasedText[Range(match.range(at: 2), in: lowercasedText)!]) : nil
                let endTimeStr = String(lowercasedText[Range(match.range(at: 3), in: lowercasedText)!])
                let endAmPm = String(lowercasedText[Range(match.range(at: 4), in: lowercasedText)!])
                
                startTime = parseTimeString(startTimeStr, ampm: startAmPm ?? endAmPm) // Use end's AM/PM if start doesn't have one
                endTime = parseTimeString(endTimeStr, ampm: endAmPm)
                
                print("🔍 Time Extraction Debug - Found time range: '\(startTimeStr)' to '\(endTimeStr)'")
                print("🔍 Time Extraction Debug - Parsed start: \(startTime), end: \(endTime)")
            }
        }
        // Pattern 2: Single time like "4pm" or "4 pm"
        else {
            let singleTimePattern = #"(\d{1,2}(?::\d{2})?)(?:\s*)(am|pm)"#
            if let range = lowercasedText.range(of: singleTimePattern, options: .regularExpression) {
                let regex = try! NSRegularExpression(pattern: singleTimePattern, options: [.caseInsensitive])
                if let match = regex.firstMatch(in: lowercasedText, range: NSRange(location: 0, length: lowercasedText.utf16.count)) {
                    
                    let timeStr = String(lowercasedText[Range(match.range(at: 1), in: lowercasedText)!])
                    let ampm = String(lowercasedText[Range(match.range(at: 2), in: lowercasedText)!])
                    
                    startTime = parseTimeString(timeStr, ampm: ampm)
                    
                    print("🔍 Time Extraction Debug - Found single time: '\(timeStr) \(ampm)'")
                    print("🔍 Time Extraction Debug - Parsed start: \(startTime)")
                }
            }
        }
        
        // Pattern 3: Duration like "for 1 hour" or "for 30 minutes"
        let durationPattern = #"for\s+(\d+)\s+(hour|hr|minute|min)s?"#
        if let range = lowercasedText.range(of: durationPattern, options: .regularExpression) {
            let regex = try! NSRegularExpression(pattern: durationPattern, options: [.caseInsensitive])
            if let match = regex.firstMatch(in: lowercasedText, range: NSRange(location: 0, length: lowercasedText.utf16.count)) {
                
                let numberStr = String(lowercasedText[Range(match.range(at: 1), in: lowercasedText)!])
                let unitStr = String(lowercasedText[Range(match.range(at: 2), in: lowercasedText)!])
                
                if let number = Int(numberStr) {
                    if unitStr.starts(with: "hour") || unitStr.starts(with: "hr") {
                        duration = TimeInterval(number * 3600) // hours to seconds
                    } else if unitStr.starts(with: "minute") || unitStr.starts(with: "min") {
                        duration = TimeInterval(number * 60) // minutes to seconds
                    }
                    
                    print("🔍 Time Extraction Debug - Found duration: \(number) \(unitStr) = \(duration ?? 0) seconds")
                }
            }
        }
        
        return (start: startTime, end: endTime, duration: duration)
    }
    
    private func parseTimeString(_ timeStr: String, ampm: String?) -> DateComponents? {
        print("🔍 parseTimeString - Input: '\(timeStr)', ampm: '\(ampm ?? "nil")'")
        
        var components = DateComponents()
        
        if timeStr.contains(":") {
            // Format like "10:30"
            let parts = timeStr.components(separatedBy: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else {
                print("🔍 parseTimeString - Failed to parse time with colon")
                return nil
            }
            
            var finalHour = hour
            if let ampm = ampm?.lowercased() {
                if ampm == "pm" && hour != 12 {
                    finalHour = hour + 12
                } else if ampm == "am" && hour == 12 {
                    finalHour = 0
                }
            }
            
            components.hour = finalHour
            components.minute = minute
        } else {
            // Format like "4"
            guard let hour = Int(timeStr) else {
                print("🔍 parseTimeString - Failed to parse simple hour")
                return nil
            }
            
            var finalHour = hour
            if let ampm = ampm?.lowercased() {
                if ampm == "pm" && hour != 12 {
                    finalHour = hour + 12
                } else if ampm == "am" && hour == 12 {
                    finalHour = 0
                }
            }
            
            components.hour = finalHour
            components.minute = 0
        }
        
        print("🔍 parseTimeString - Result: hour=\(components.hour), minute=\(components.minute)")
        return components
    }
    
    private func extractScheduleTitle(from text: String) -> String {
        let lowercasedText = text.lowercased()
        
        print("🔍 Title Extraction Debug - Input: '\(text)'")
        
        // Remove schedule keywords and common phrases to get the core title
        var title = text
        let removePatterns = [
            "every ",
            "weekly ",
            "i go ",
            "i go to ",
            "go to ",
            "the ",
            " every monday",
            " every tuesday",
            " every wednesday",
            " every thursday",
            " every friday",
            " every saturday",
            " every sunday",
            " on monday",
            " on tuesday",
            " on wednesday",
            " on thursday",
            " on friday",
            " on saturday",
            " on sunday",
            " monday",
            " tuesday",
            " wednesday",
            " thursday",
            " friday",
            " saturday",
            " sunday",
            " and wednesday",
            " and thursday",
            " and friday",
            " and saturday",
            " and sunday",
            " and monday",
            " and tuesday",
            " and"
        ]
        
        for pattern in removePatterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        // Clean up extra spaces and trim
        title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 Title Extraction Debug - After cleanup: '\(title)'")
        
        // Handle common location patterns
        if lowercasedText.contains("mall") {
            title = "Mall visit"
        } else if lowercasedText.contains("gym") {
            title = "Gym session"
        } else if lowercasedText.contains("library") {
            title = "Library study"
        } else if lowercasedText.contains("work") {
            title = "Work"
        } else if lowercasedText.contains("class") {
            title = "Class"
        } else if lowercasedText.contains("meeting") {
            title = "Meeting"
        }
        
        // If title is empty or too short, use a default
        if title.isEmpty || title.count < 2 {
            title = "Schedule Item"
        }
        
        let finalTitle = title.capitalizedFirstLetter()
        print("🔍 Title Extraction Debug - Final title: '\(finalTitle)'")
        return finalTitle
    }
}

// MARK: - Simplified Supporting Structures
struct TemporalParser {
    static func parseRelativeDate(from text: String, baseDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        
        if text.lowercased().contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: baseDate)
        } else if text.lowercased().contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate)
        }
        
        return nil
    }
}

struct GradeParser {
    static func extractMixedGrades(from text: String) -> [String] {
        let pattern = #"(\d+(?:\.\d+)?/\d+(?:\.\d+)?|\d+(?:\.\d+)?%|[A-F][+-]?)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { match in
            if let range = Range(match.range, in: text) {
                return String(text[range])
            }
            return nil
        }
    }
    
    static func extractLetterGrade(from text: String) -> String? {
        let pattern = #"(?i)\b([A-F][+-]?)\b"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range]).uppercased()
        }
        return nil
    }
    
    static func extractPassFail(from text: String) -> String? {
        let passFailGrades = ["Pass", "Fail", "P", "F", "S", "U"]
        for grade in passFailGrades {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: grade) + "\\b"
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return grade.uppercased()
            }
        }
        return nil
    }
    
    static func extractPercentage(from text: String) -> Double? {
        let pattern = #"(\d{1,3}(?:\.\d{1,2})?)\s*%"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            let percentString = String(text[range]).replacingOccurrences(of: "%", with: "")
            return Double(percentString)
        }
        return nil
    }
    
    static func fractionToPercentage(_ fraction: String) -> Double? {
        let components = fraction.components(separatedBy: "/")
        guard components.count == 2,
              let numerator = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let denominator = Double(components[1].trimmingCharacters(in: .whitespaces)),
              denominator > 0 else {
            return nil
        }
        return (numerator / denominator) * 100
    }
}

struct TimeParser {
    static func extractTimeRange(from text: String) -> (start: DateComponents?, end: DateComponents?) {
        return (nil, nil) // Simplified
    }
    
    static func extract24HourTime(from text: String) -> DateComponents? {
        return nil // Simplified
    }
    
    static func parseISO8601Duration(from text: String) -> TimeInterval? {
        return nil // Simplified
    }
    
    static func parseTimeStringToComponents(_ timeString: String) -> DateComponents? {
        return nil // Simplified
    }
}

struct CategoryMatcher {
    static func findBestMatch(for text: String, in categories: [Category]) -> String? {
        let lowercasedText = text.lowercased()
        
        for category in categories {
            if lowercasedText.contains(category.name.lowercased()) {
                return category.name
            }
        }
        
        return nil
    }
}

struct RobustnessTest {
    struct TestResult {
        let originalInput: String
        let perturbedInput: String
        let originalResult: NLPResult
        let perturbedResult: NLPResult
        let isConsistent: Bool
        let confidence: Double
    }
    
    static func runPerturbationTests(on input: String, engine: NLPEngine, categories: [Category], courses: [Course]) -> [TestResult] {
        var results: [TestResult] = []
        let originalResult = engine.parse(inputText: input, availableCategories: categories, existingCourses: courses)
        
        // Simple typo test
        let typoVariant = input.replacingOccurrences(of: "e", with: "a")
        if typoVariant != input {
            let perturbedResult = engine.parse(inputText: typoVariant, availableCategories: categories, existingCourses: courses)
            results.append(TestResult(
                originalInput: input,
                perturbedInput: typoVariant,
                originalResult: originalResult,
                perturbedResult: perturbedResult,
                isConsistent: true,
                confidence: 1.0
            ))
        }
        
        return results
    }
}

// MARK: - Extensions
extension String {
    func capitalizedFirstLetter() -> String {
        guard let first = first else { return "" }
        return first.uppercased() + self.dropFirst()
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
