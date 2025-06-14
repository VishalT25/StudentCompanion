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
    let rawScore: String?           // "18/20" or "85"
    let percentage: Double?         // 90.0
    let letterGrade: String?        // "A+"
    let passFail: String?          // "Pass", "Fail", "S", "U"
    let normalized: String          // Final normalized representation
    let confidence: Double          // Confidence score (0.0 - 1.0)
    
    init(from input: String) {
        let sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Initialize all properties
        var rawScore: String? = nil
        var percentage: Double? = nil
        var letterGrade: String? = nil
        var passFail: String? = nil
        var confidence: Double = 0.0
        
        // Try to extract multiple grade formats
        let mixedGradeMatches = GradeParser.extractMixedGrades(from: sanitized)
        
        if !mixedGradeMatches.isEmpty {
            // Handle mixed format like "18/20 (90%)"
            confidence = 0.9
            for match in mixedGradeMatches {
                if match.contains("/") {
                    rawScore = match
                }
                if match.contains("%") {
                    percentage = GradeParser.extractPercentage(from: match)
                }
            }
        } else {
            // Single format parsing
            if let passFailMatch = GradeParser.extractPassFail(from: sanitized) {
                passFail = passFailMatch
                confidence = 0.8
            } else if let letterMatch = GradeParser.extractLetterGrade(from: sanitized) {
                letterGrade = letterMatch
                confidence = 0.85
            } else if let percentMatch = GradeParser.extractPercentage(from: sanitized) {
                percentage = percentMatch
                confidence = 0.9
            } else if sanitized.contains("/") {
                rawScore = sanitized
                percentage = GradeParser.fractionToPercentage(sanitized)
                confidence = 0.8
            }
        }
        
        // Set properties
        self.rawScore = rawScore
        self.percentage = percentage
        self.letterGrade = letterGrade
        self.passFail = passFail
        self.confidence = confidence
        
        // Create normalized representation
        if let passFail = passFail {
            self.normalized = passFail
        } else if let letter = letterGrade {
            self.normalized = letter
        } else if let pct = percentage {
            self.normalized = String(format: "%.1f%%", pct)
        } else if let raw = rawScore {
            self.normalized = raw
        } else {
            self.normalized = sanitized
        }
    }
}

// MARK: - Compiled Regex Patterns (Performance Optimization)
struct CompiledPatterns {
    private static let config = NLPConfiguration.shared.getRegexPatterns()
    
    static let weightPattern = try! NSRegularExpression(pattern: config["weightPattern"] ?? #"(\d{1,3}(?:\.\d{1,2})?)\s*%?"#)
    static let gradePattern = try! NSRegularExpression(pattern: config["gradePattern"] ?? #"(\b\d{1,3}(?:\.\d{1,2})?%?|\b[A-F][+-]?|\b\d{1,3}(?:\.\d{1,2})?(?:\s*out\s*of\s*\d+)?)\b"#)
    static let mixedGradePattern = try! NSRegularExpression(pattern: config["mixedGradePattern"] ?? #"(\d+(?:\.\d+)?/\d+(?:\.\d+)?|\d+(?:\.\d+)?%|[A-F][+-]?)"#, options: .caseInsensitive)
    static let timePattern = try! NSRegularExpression(pattern: config["timePattern"] ?? #"(?i)(\b\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b)"#)
    static let time24HourPattern = try! NSRegularExpression(pattern: config["time24HourPattern"] ?? #"(?i)(\b(?:[01]\d|2[0-3]):[0-5]\d\b)"#)
    static let timeRangePattern = try! NSRegularExpression(pattern: config["timeRangePattern"] ?? #"(?i)\b(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\s*(?:to|until|till|-|–)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b"#)
    static let durationPattern = try! NSRegularExpression(pattern: config["durationPattern"] ?? #"(?i)(\d+(?:\.\d+)?)\s*(hour|hr|h|minute|min|m)"#)
    static let iso8601DurationPattern = try! NSRegularExpression(pattern: config["iso8601DurationPattern"] ?? #"(?i)PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#)
    static let relativeDatePattern = try! NSRegularExpression(pattern: config["relativeDatePattern"] ?? #"(?i)\b(next|this|last)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month)\b"#)
    static let dateOffsetPattern = try! NSRegularExpression(pattern: config["dateOffsetPattern"] ?? #"(?i)\b(\d+)\s+(days?|weeks?|months?)\s+(from\s+now|ago|later)\b"#)
    static let dateDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
}

// MARK: - Enhanced Temporal Parser
struct TemporalParser {
    static func parseRelativeDate(from text: String, baseDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let lowercased = text.lowercased()
        
        // Handle relative date patterns
        let matches = CompiledPatterns.relativeDatePattern.matches(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.utf16.count))
        
        guard let match = matches.first,
              match.numberOfRanges == 3,
              let relativeRange = Range(match.range(at: 1), in: lowercased),
              let unitRange = Range(match.range(at: 2), in: lowercased) else {
            return nil
        }
        
        let relative = String(lowercased[relativeRange])
        let unit = String(lowercased[unitRange])
        
        let relativeMappings = NLPConfiguration.shared.getRelativeDateMappings()
        let offset = relativeMappings[relative] ?? 0
        
        switch unit {
        case "week":
            return calendar.date(byAdding: .weekOfYear, value: offset, to: baseDate)
        case "month":
            return calendar.date(byAdding: .month, value: offset, to: baseDate)
        case let day where ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].contains(day):
            return getNextWeekday(day, relative: relative, from: baseDate)
        default:
            return nil
        }
    }
    
    static func parseDateOffset(from text: String, baseDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let lowercased = text.lowercased()
        
        let matches = CompiledPatterns.dateOffsetPattern.matches(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.utf16.count))
        
        guard let match = matches.first,
              match.numberOfRanges == 4,
              let numberRange = Range(match.range(at: 1), in: lowercased),
              let unitRange = Range(match.range(at: 2), in: lowercased),
              let directionRange = Range(match.range(at: 3), in: lowercased) else {
            return nil
        }
        
        let numberString = String(lowercased[numberRange])
        let unit = String(lowercased[unitRange])
        let direction = String(lowercased[directionRange])
        
        guard let number = Int(numberString) else { return nil }
        
        let multiplier = (direction.contains("ago")) ? -1 : 1
        let value = number * multiplier
        
        switch unit {
        case let u where u.hasPrefix("day"):
            return calendar.date(byAdding: .day, value: value, to: baseDate)
        case let u where u.hasPrefix("week"):
            return calendar.date(byAdding: .weekOfYear, value: value, to: baseDate)
        case let u where u.hasPrefix("month"):
            return calendar.date(byAdding: .month, value: value, to: baseDate)
        default:
            return nil
        }
    }
    
    private static func getNextWeekday(_ weekday: String, relative: String, from date: Date) -> Date? {
        let calendar = Calendar.current
        let weekdayMap: [String: Int] = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        
        guard let targetWeekday = weekdayMap[weekday.lowercased()] else { return nil }
        
        let relativeMappings = NLPConfiguration.shared.getRelativeDateMappings()
        let weekOffset = relativeMappings[relative] ?? 0
        
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekOfYear! += weekOffset
        components.weekday = targetWeekday
        
        return calendar.date(from: components)
    }
}

// MARK: - Enhanced Grade Parser with International Support
struct GradeParser {
    static func extractMixedGrades(from text: String) -> [String] {
        let matches = CompiledPatterns.mixedGradePattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { match in
            if let range = Range(match.range, in: text) {
                return String(text[range])
            }
            return nil
        }
    }
    
    static func extractLetterGrade(from text: String) -> String? {
        let grading = NLPConfiguration.shared.getInternationalGrading()
        
        // Check all international grading systems
        if let letterGrades = grading["letterGrades"] as? [String: [String]] {
            for (_, grades) in letterGrades {
                for grade in grades {
                    let pattern = "\\b" + NSRegularExpression.escapedPattern(for: grade) + "\\b"
                    if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                        return grade.uppercased()
                    }
                }
            }
        }
        
        // Fallback to simple A-F pattern
        let letterPattern = #"(?i)\b([A-F][+-]?)\b"#
        if let range = text.range(of: letterPattern, options: .regularExpression) {
            return String(text[range]).uppercased()
        }
        
        return nil
    }
    
    static func extractPassFail(from text: String) -> String? {
        let grading = NLPConfiguration.shared.getInternationalGrading()
        
        if let passFailGrades = grading["passFail"] as? [String] {
            for grade in passFailGrades {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: grade) + "\\b"
                if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    return grade.uppercased()
                }
            }
        }
        
        return nil
    }
    
    static func extractPercentage(from text: String) -> Double? {
        let percentPattern = #"(\d{1,3}(?:\.\d{1,2})?)\s*%"#
        if let range = text.range(of: percentPattern, options: .regularExpression) {
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

// MARK: - Enhanced Time Parser with ISO-8601 Support
struct TimeParser {
    static func extractTimeRange(from text: String) -> (start: DateComponents?, end: DateComponents?) {
        let matches = CompiledPatterns.timeRangePattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        guard let match = matches.first,
              match.numberOfRanges == 3,
              let startRange = Range(match.range(at: 1), in: text),
              let endRange = Range(match.range(at: 2), in: text) else {
            return (nil, nil)
        }
        
        let startTimeString = String(text[startRange])
        let endTimeString = String(text[endRange])
        
        return (
            parseTimeStringToComponents(startTimeString),
            parseTimeStringToComponents(endTimeString)
        )
    }
    
    static func extract24HourTime(from text: String) -> DateComponents? {
        let matches = CompiledPatterns.time24HourPattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        guard let match = matches.first,
              let range = Range(match.range, in: text) else {
            return nil
        }
        
        let timeString = String(text[range])
        let components = timeString.components(separatedBy: ":")
        
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              hour >= 0 && hour <= 23,
              minute >= 0 && minute <= 59 else {
            return nil
        }
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        return dateComponents
    }
    
    static func parseISO8601Duration(from text: String) -> TimeInterval? {
        let matches = CompiledPatterns.iso8601DurationPattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        guard let match = matches.first else { return nil }
        
        var duration: TimeInterval = 0
        
        // Extract hours
        if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound,
           let hoursRange = Range(match.range(at: 1), in: text),
           let hours = Int(String(text[hoursRange])) {
            duration += TimeInterval(hours * 3600)
        }
        
        // Extract minutes
        if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound,
           let minutesRange = Range(match.range(at: 2), in: text),
           let minutes = Int(String(text[minutesRange])) {
            duration += TimeInterval(minutes * 60)
        }
        
        // Extract seconds
        if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound,
           let secondsRange = Range(match.range(at: 3), in: text),
           let seconds = Int(String(text[secondsRange])) {
            duration += TimeInterval(seconds)
        }
        
        return duration > 0 ? duration : nil
    }
    
    static func parseTimeStringToComponents(_ timeString: String) -> DateComponents? {
        var comp = DateComponents()
        let lowercased = timeString.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Try 24-hour format first
        if let twentyFourHour = extract24HourTime(from: lowercased) {
            return twentyFourHour
        }
        
        // Fall back to 12-hour format
        let cleanedTimeString = lowercased.filter { "0123456789:amp".contains($0) }
        let timeParts = cleanedTimeString.components(separatedBy: ":")
        
        guard let firstPart = timeParts.first?.filter({ $0.isNumber }),
              let hour = Int(firstPart) else {
            return nil
        }
        
        var finalHour = hour
        let minute = timeParts.count > 1 ? Int(timeParts.last?.filter({ $0.isNumber }) ?? "0") ?? 0 : 0
        
        if lowercased.contains("pm") && hour < 12 {
            finalHour += 12
        } else if lowercased.contains("am") && hour == 12 {
            finalHour = 0
        }
        
        comp.hour = finalHour
        comp.minute = minute
        return comp
    }
}

// MARK: - Enhanced Category Matcher with Fuzzy Logic
struct CategoryMatcher {
    static func findBestMatch(for text: String, in categories: [Category]) -> String? {
        let lowercasedText = text.lowercased()
        
        // Direct match first
        for category in categories {
            if lowercasedText.contains(category.name.lowercased()) {
                return category.name
            }
        }
        
        // Fuzzy matching with synonyms from configuration
        let synonymMap = NLPConfiguration.shared.getCategorySynonyms()
        
        for category in categories {
            let categoryName = category.name.lowercased()
            
            if let synonyms = synonymMap[categoryName] {
                for synonym in synonyms {
                    if lowercasedText.contains(synonym) {
                        return category.name
                    }
                }
            }
        }
        
        return nil
    }
}

// MARK: - Robustness Testing Framework
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
        
        // Test with typos
        let typoVariants = generateTypoVariants(input)
        for variant in typoVariants {
            let perturbedResult = engine.parse(inputText: variant, availableCategories: categories, existingCourses: courses)
            let isConsistent = areResultsConsistent(originalResult, perturbedResult)
            
            results.append(TestResult(
                originalInput: input,
                perturbedInput: variant,
                originalResult: originalResult,
                perturbedResult: perturbedResult,
                isConsistent: isConsistent,
                confidence: calculateConsistencyScore(originalResult, perturbedResult)
            ))
        }
        
        // Test with synonym replacements
        let synonymVariants = generateSynonymVariants(input)
        for variant in synonymVariants {
            let perturbedResult = engine.parse(inputText: variant, availableCategories: categories, existingCourses: courses)
            let isConsistent = areResultsConsistent(originalResult, perturbedResult)
            
            results.append(TestResult(
                originalInput: input,
                perturbedInput: variant,
                originalResult: originalResult,
                perturbedResult: perturbedResult,
                isConsistent: isConsistent,
                confidence: calculateConsistencyScore(originalResult, perturbedResult)
            ))
        }
        
        return results
    }
    
    private static func generateTypoVariants(_ input: String) -> [String] {
        var variants: [String] = []
        let perturbationConfig = NLPConfiguration.shared.getPerturbationTests()
        
        if let typoVariations = perturbationConfig["typoVariations"] as? [String] {
            // Replace common words with their typo variants
            for typo in typoVariations {
                let corrected = typo.replacingOccurrences(of: "recieved", with: "received")
                    .replacingOccurrences(of: "tomorow", with: "tomorrow")
                    .replacingOccurrences(of: "assigment", with: "assignment")
                
                let variantInput = input.replacingOccurrences(of: corrected, with: typo, options: .caseInsensitive)
                if variantInput != input {
                    variants.append(variantInput)
                }
            }
        }
        
        return variants
    }
    
    private static func generateSynonymVariants(_ input: String) -> [String] {
        var variants: [String] = []
        let perturbationConfig = NLPConfiguration.shared.getPerturbationTests()
        
        if let synonymReplacements = perturbationConfig["synonymReplacements"] as? [String: [String]] {
            for (original, synonyms) in synonymReplacements {
                for synonym in synonyms {
                    let variantInput = input.replacingOccurrences(of: original, with: synonym, options: .caseInsensitive)
                    if variantInput != input {
                        variants.append(variantInput)
                    }
                }
            }
        }
        
        return variants
    }
    
    private static func areResultsConsistent(_ result1: NLPResult, _ result2: NLPResult) -> Bool {
        switch (result1, result2) {
        case (.parsedEvent, .parsedEvent),
             (.parsedScheduleItem, .parsedScheduleItem),
             (.parsedGrade, .parsedGrade):
            return true
        case (.needsMoreInfo, .needsMoreInfo):
            return true
        case (.unrecognized, .unrecognized),
             (.notAttempted, .notAttempted):
            return true
        default:
            return false
        }
    }
    
    private static func calculateConsistencyScore(_ result1: NLPResult, _ result2: NLPResult) -> Double {
        if areResultsConsistent(result1, result2) {
            return 1.0
        }
        
        // Partial consistency scoring
        switch (result1, result2) {
        case (.needsMoreInfo, _), (_, .needsMoreInfo):
            return 0.5 // Partial match - might need clarification
        case (.unrecognized, _), (_, .unrecognized):
            return 0.3 // Low match - couldn't parse
        default:
            return 0.0 // Complete mismatch
        }
    }
}

// MARK: - Enhanced NLP Engine
class NLPEngine {
    private let conversationTimeoutInterval: TimeInterval = 300 // 5 minutes
    private var activeConversations: [UUID: Date] = [:]
    private let config = NLPConfiguration.shared
    
    func parse(inputText: String, availableCategories: [Category] = [], existingCourses: [Course] = []) -> NLPResult {
        let sanitizedInput = sanitizeInput(inputText)
        
        guard !sanitizedInput.isEmpty else {
            return .notAttempted
        }
        
        // Clean up expired conversations
        cleanupExpiredConversations()
        
        let hasTimeInfo = CompiledPatterns.timePattern.firstMatch(in: sanitizedInput, options: [], range: NSRange(location: 0, length: sanitizedInput.utf16.count)) != nil ||
                         CompiledPatterns.time24HourPattern.firstMatch(in: sanitizedInput, options: [], range: NSRange(location: 0, length: sanitizedInput.utf16.count)) != nil
        
        let hasDayInfo = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "mon", "tue", "wed", "thu", "fri", "sat", "sun", "today", "tomorrow"].contains { sanitizedInput.lowercased().contains($0) }
        
        // If we have time and day info, prioritize event parsing
        if hasTimeInfo && hasDayInfo {
            if let eventResult = tryParseAsEvent(text: sanitizedInput, categories: availableCategories) {
                return eventResult
            }
        }
        
        // Try parsing in order of specificity
        if let gradeResult = tryParseAsGrade(text: sanitizedInput, courses: existingCourses) {
            return gradeResult
        }
        
        if containsStrongScheduleKeywords(text: sanitizedInput.lowercased()) {
            if let scheduleResult = tryParseAsScheduleItem(text: sanitizedInput, categories: availableCategories) {
                return scheduleResult
            }
        }
        
        if let eventResult = tryParseAsEvent(text: sanitizedInput, categories: availableCategories) {
            return eventResult
        }
        
        // Fallback to schedule parsing
        if let potentialScheduleResult = tryParseAsScheduleItem(text: sanitizedInput, categories: availableCategories) {
            return potentialScheduleResult
        }
        
        return .unrecognized(originalInput: inputText)
    }
    
    func parseFollowUp(inputText: String, context: ParseContext, conversationId: UUID?, existingCourses: [Course] = []) -> NLPResult {
        // Validate conversation
        if let convId = conversationId, !isConversationActive(convId) {
            return .unrecognized(originalInput: "Conversation expired. Please start over.")
        }
        
        let sanitizedInput = sanitizeInput(inputText)
        
        // Handle global cancellation
        if sanitizedInput.lowercased().contains("cancel") || sanitizedInput.lowercased().contains("start over") {
            if let convId = conversationId {
                activeConversations.removeValue(forKey: convId)
            }
            return .unrecognized(originalInput: "Cancelled. You can start a new request.")
        }
        
        switch context {
        case .gradeNeedsWeight(let courseName, let assignmentName, let grade):
            return handleWeightFollowUp(sanitizedInput, courseName: courseName, assignmentName: assignmentName, grade: grade, conversationId: conversationId)
            
        case .gradeNeedsAssignmentName(let courseName, let grade):
            return handleAssignmentNameFollowUp(sanitizedInput, courseName: courseName, grade: grade, conversationId: conversationId)
            
        case .gradeNeedsCourse(let assignmentName, let grade):
            return handleCourseFollowUp(sanitizedInput, assignmentName: assignmentName, grade: grade, existingCourses: existingCourses, conversationId: conversationId)
            
        case .eventNeedsReminder(let title, let date, let categoryName):
            let reminderTime = parseReminderTime(from: sanitizedInput)
            return .parsedEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminderTime)
            
        case .scheduleNeedsReminder(let title, let days, let startTime, let endTime, let duration):
            let reminderTime = parseReminderTime(from: sanitizedInput)
            return .parsedScheduleItem(title: title, days: days, startTimeComponents: startTime, endTimeComponents: endTime, duration: duration, reminderTime: reminderTime)
            
        case .scheduleNeedsMoreTime(let title, let days, let startTime):
            return handleScheduleTimeFollowUp(sanitizedInput, title: title, days: days, startTime: startTime, conversationId: conversationId)
        }
    }
    
    // MARK: - Robustness Testing Interface
    func runRobustnessTests(on input: String, categories: [Category], courses: [Course]) -> [RobustnessTest.TestResult] {
        return RobustnessTest.runPerturbationTests(on: input, engine: self, categories: categories, courses: courses)
    }
    
    // MARK: - Input Sanitization with Enhanced Security
    private func sanitizeInput(_ input: String) -> String {
        // First expand common abbreviations
        let expandedInput = expandAbbreviations(input)
        
        // Remove potential injection patterns and normalize whitespace
        let sanitized = expandedInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[\"'`]+"#, with: "", options: .regularExpression) // Remove quotes
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) // Normalize whitespace
            .replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression) // Remove HTML tags
            .replacingOccurrences(of: #"[^\w\s\d\.\,\!\?\:\;\(\)\-\+\/\%]+"#, with: "", options: .regularExpression) // Keep only safe characters
        
        return sanitized
    }
    
    private func expandAbbreviations(_ input: String) -> String {
        let abbreviations = config.getCommonAbbreviations()  // Modified to call new function in NLPConfiguration
        var expandedInput = input
        
        // Expand abbreviations (case-insensitive)
        for (abbrev, expansion) in abbreviations {
            // Match whole words only to avoid partial replacements
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: abbrev) + "\\b"
            expandedInput = expandedInput.replacingOccurrences(
                of: pattern,
                with: expansion,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return expandedInput
    }
    
    // MARK: - Conversation Management
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
    
    // MARK: - Enhanced Parsing Methods
    private func tryParseAsGrade(text: String, courses: [Course]) -> NLPResult? {
        let lowercasedText = text.lowercased()
        let gradeKeywords = config.getKeywords()["gradeKeywords"] ?? ["grade", "score", "got", "received", "earned", "scored", "percent", "%"]
        
        let isLikelyGrade = gradeKeywords.contains { lowercasedText.contains($0) }
        let hasGradePattern = CompiledPatterns.gradePattern.firstMatch(in: lowercasedText, options: [], range: NSRange(location: 0, length: lowercasedText.utf16.count)) != nil
        
        let hasTimePattern = CompiledPatterns.timePattern.firstMatch(in: lowercasedText, options: [], range: NSRange(location: 0, length: lowercasedText.utf16.count)) != nil ||
                            CompiledPatterns.time24HourPattern.firstMatch(in: lowercasedText, options: [], range: NSRange(location: 0, length: lowercasedText.utf16.count)) != nil
        
        let hasDayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "mon", "tue", "wed", "thu", "fri", "sat", "sun"].contains { lowercasedText.contains($0) }
        
        guard (isLikelyGrade || hasGradePattern) && (!hasTimePattern || isLikelyGrade) && (!hasDayNames || isLikelyGrade) else {
            return nil
        }
        
        let parsedGrade = ParsedGrade(from: text)
        
        guard !parsedGrade.normalized.isEmpty && parsedGrade.confidence > 0.7 else {
            // Only suggest grade parsing if we have strong grade keywords
            if isLikelyGrade {
                let conversationId = startNewConversation()
                return .needsMoreInfo(prompt: "I couldn't find a clear grade in your input. Please include the grade (e.g., '95%', 'A+', '87', '18/20', 'Pass').", originalInput: text, context: nil, conversationId: conversationId)
            }
            return nil
        }
        
        let identifiedCourseName = findBestCourseMatch(from: lowercasedText, courses: courses)
        let identifiedAssignmentName = extractAssignmentName(from: lowercasedText, courseName: identifiedCourseName, grade: parsedGrade.normalized, gradeKeywords: gradeKeywords)
        
        return handleGradeFollowUp(courseName: identifiedCourseName, assignmentName: identifiedAssignmentName, grade: parsedGrade.normalized, originalInput: text, courses: courses)
    }
    
    private func tryParseAsEvent(text: String, categories: [Category]) -> NLPResult? {
        var textToParse = text
        var detectedDate: Date? = nil
        
        // Try enhanced temporal parsing first
        if let relativeDate = TemporalParser.parseRelativeDate(from: text) {
            detectedDate = relativeDate
            // Remove relative date phrases from text
            textToParse = CompiledPatterns.relativeDatePattern.stringByReplacingMatches(in: textToParse, options: [], range: NSRange(location: 0, length: textToParse.utf16.count), withTemplate: "")
        } else if let offsetDate = TemporalParser.parseDateOffset(from: text) {
            detectedDate = offsetDate
            textToParse = CompiledPatterns.dateOffsetPattern.stringByReplacingMatches(in: textToParse, options: [], range: NSRange(location: 0, length: textToParse.utf16.count), withTemplate: "")
        } else {
            // Fall back to NSDataDetector
            let matches = CompiledPatterns.dateDetector.matches(in: textToParse, options: [], range: NSRange(location: 0, length: textToParse.utf16.count))
            
            if let match = matches.first, let date = match.date {
                detectedDate = date
                if let range = Range(match.range, in: textToParse) {
                    textToParse = textToParse.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        let title = textToParse.isEmpty ? (detectedDate != nil ? "Event" : text) : textToParse
        
        // Improved heuristics for event detection
        guard isLikelyEvent(title: title, hasDate: detectedDate != nil) else { return nil }
        
        let categoryName = CategoryMatcher.findBestMatch(for: title, in: categories)
        let conversationId = startNewConversation()
        
        return .needsMoreInfo(prompt: "Would you like to set a reminder for '\(title)'? (e.g., '15 minutes before', '1 hour before', 'PT30M', or 'no')", originalInput: text, context: .eventNeedsReminder(title: title, date: detectedDate, categoryName: categoryName), conversationId: conversationId)
    }
    
    private func tryParseAsScheduleItem(text: String, categories: [Category]) -> NLPResult? {
        var remainingText = text.lowercased()
        
        let (days, textWithoutDays) = extractDaysOfWeek(from: remainingText)
        remainingText = textWithoutDays
        
        // Try time range parsing first
        let (startTime, endTime) = TimeParser.extractTimeRange(from: remainingText)
        if startTime != nil && endTime != nil {
            // Remove the time range from text
            remainingText = CompiledPatterns.timeRangePattern.stringByReplacingMatches(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count), withTemplate: "")
        }
        
        var finalStartTime = startTime
        var finalEndTime = endTime
        var duration: TimeInterval? = nil
        
        // If no range found, try individual time parsing
        if finalStartTime == nil {
            let (extractedStart, textWithoutStart) = extractTime(from: remainingText, isEndTime: false)
            finalStartTime = extractedStart
            remainingText = textWithoutStart
        }
        
        if finalEndTime == nil {
            // Try ISO-8601 duration first
            if let iso8601Duration = TimeParser.parseISO8601Duration(from: remainingText) {
                duration = iso8601Duration
                remainingText = CompiledPatterns.iso8601DurationPattern.stringByReplacingMatches(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count), withTemplate: "")
            } else if let extractedDuration = extractDuration(from: remainingText) {
                duration = extractedDuration.0
                remainingText = extractedDuration.1
            }
        }
        
        let title = remainingText.trimmingCharacters(in: .whitespacesAndNewlines).capitalizedFirstLetter()
        
        return handleScheduleItemResult(title: title, days: days, startTime: finalStartTime, endTime: finalEndTime, duration: duration, originalText: text, categories: categories)
    }
    
    // MARK: - Helper Methods
    private func isLikelyEvent(title: String, hasDate: Bool) -> Bool {
        if hasDate { return true }
        
        let eventKeywords = config.getKeywords()["eventKeywords"] ?? ["meeting", "appointment", "reminder", "deadline", "exam", "test", "quiz", "homework", "hw", "due", "call", "lunch", "dinner", "party"]
        
        return eventKeywords.contains { title.lowercased().contains($0) } || (title.split(separator: " ").count >= 2 && title.count >= 10)
    }
    
    private func containsStrongScheduleKeywords(text: String) -> Bool {
        let strongKeywords = config.getKeywords()["scheduleKeywords"] ?? ["every", "weekly", "schedule", "class", "recurring"]
        return strongKeywords.contains { text.contains($0) }
    }
    
    private func handleGradeFollowUp(courseName: String?, assignmentName: String?, grade: String, originalInput: String, courses: [Course]) -> NLPResult {
        let conversationId = startNewConversation()
        
        if let courseName = courseName {
            if let assignmentName = assignmentName {
                return .needsMoreInfo(prompt: "What's the weight of '\(assignmentName)' in \(courseName)? (e.g., '20%' or 'skip' if you don't want to specify)", originalInput: originalInput, context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignmentName, grade: grade), conversationId: conversationId)
            } else {
                return .needsMoreInfo(prompt: "What's the name of this assignment in \(courseName)?", originalInput: originalInput, context: .gradeNeedsAssignmentName(courseName: courseName, grade: grade), conversationId: conversationId)
            }
        } else {
            if courses.isEmpty {
                return .needsMoreInfo(prompt: "No courses found. Please add some courses first in the Courses section.", originalInput: originalInput, context: nil, conversationId: conversationId)
            } else {
                let courseNames = courses.map { $0.name }.joined(separator: ", ")
                return .needsMoreInfo(prompt: "Which course is this grade for? Available courses: \(courseNames)", originalInput: originalInput, context: .gradeNeedsCourse(assignmentName: assignmentName, grade: grade), conversationId: conversationId)
            }
        }
    }
    
    private func handleScheduleItemResult(title: String, days: Set<DayOfWeek>, startTime: DateComponents?, endTime: DateComponents?, duration: TimeInterval?, originalText: String, categories: [Category]) -> NLPResult {
        let finalTitle = title.isEmpty ? "Scheduled Item" : title
        let conversationId = startNewConversation()
        
        if !days.isEmpty && startTime != nil && (endTime != nil || duration != nil) {
            return .needsMoreInfo(prompt: "Would you like to set a reminder for '\(finalTitle)'? (e.g., '15 minutes before', '1 hour before', 'PT30M', or 'no')", originalInput: originalText, context: .scheduleNeedsReminder(title: finalTitle, days: days, startTime: startTime, endTime: endTime, duration: duration), conversationId: conversationId)
        } else if startTime != nil && days.isEmpty && endTime == nil && duration == nil {
            return .needsMoreInfo(prompt: "Please specify days or an end time/duration for '\(finalTitle)'.", originalInput: originalText, context: .scheduleNeedsMoreTime(title: finalTitle, days: days, startTime: startTime), conversationId: conversationId)
        }
        
        return .parsedScheduleItem(title: finalTitle, days: days, startTimeComponents: startTime, endTimeComponents: endTime, duration: duration, reminderTime: nil)
    }
    
    // MARK: - Follow-up Handlers
    private func handleWeightFollowUp(_ input: String, courseName: String, assignmentName: String, grade: String, conversationId: UUID?) -> NLPResult {
        if let weight = extractWeight(from: input) {
            return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
        } else if input.lowercased().contains("skip") || input.lowercased().contains("no") {
            return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: nil)
        } else {
            return .needsMoreInfo(prompt: "Please enter the weight as a percentage (e.g., '20%') or say 'skip' to continue without weight.", originalInput: input, context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignmentName, grade: grade), conversationId: conversationId)
        }
    }
    
    private func handleAssignmentNameFollowUp(_ input: String, courseName: String, grade: String, conversationId: UUID?) -> NLPResult {
        let assignmentName = input.isEmpty ? "Assignment" : input
        return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip')", originalInput: "", context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignmentName, grade: grade), conversationId: conversationId)
    }
    
    private func handleCourseFollowUp(_ input: String, assignmentName: String?, grade: String, existingCourses: [Course], conversationId: UUID?) -> NLPResult {
        if let course = existingCourses.first(where: { $0.name.lowercased().contains(input.lowercased()) }) {
            let finalAssignmentName = assignmentName ?? "Assignment"
            return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip')", originalInput: "", context: .gradeNeedsWeight(courseName: course.name, assignmentName: finalAssignmentName, grade: grade), conversationId: conversationId)
        } else {
            return .needsMoreInfo(prompt: "Course '\(input)' not found. Please enter an existing course name.", originalInput: input, context: .gradeNeedsCourse(assignmentName: assignmentName, grade: grade), conversationId: conversationId)
        }
    }
    
    private func handleScheduleTimeFollowUp(_ input: String, title: String, days: Set<DayOfWeek>, startTime: DateComponents?, conversationId: UUID?) -> NLPResult {
        let (newEndTime, _) = extractTime(from: input, isEndTime: true)
        var duration: TimeInterval? = nil
        
        if newEndTime == nil {
            // Try ISO-8601 duration first
            if let iso8601Duration = TimeParser.parseISO8601Duration(from: input) {
                duration = iso8601Duration
            } else if let extractedDuration = extractDuration(from: input) {
                duration = extractedDuration.0
            }
        }
        
        if newEndTime != nil || duration != nil {
            return .needsMoreInfo(prompt: "Would you like to set a reminder? (e.g., '15 minutes before', '1 hour before', 'PT30M', or 'no')", originalInput: "", context: .scheduleNeedsReminder(title: title, days: days, startTime: startTime, endTime: newEndTime, duration: duration), conversationId: conversationId)
        } else {
            return .needsMoreInfo(prompt: "Please specify an end time (e.g., 'until 3pm', '15:30') or duration (e.g., 'for 1 hour', 'PT45M')", originalInput: input, context: .scheduleNeedsMoreTime(title: title, days: days, startTime: startTime), conversationId: conversationId)
        }
    }
    
    // MARK: - Utility Methods (Enhanced)
    private func extractWeight(from text: String) -> String? {
        let matches = CompiledPatterns.weightPattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        guard let match = matches.first,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        
        let weightString = String(text[range])
        guard let weightValue = Double(weightString), weightValue <= 100 else {
            return nil
        }
        
        return String(format: "%.0f%%", weightValue)
    }
    
    private func parseReminderTime(from text: String) -> ReminderTime {
        let lowercased = text.lowercased()
        
        // Try ISO-8601 duration first
        if let iso8601Duration = TimeParser.parseISO8601Duration(from: text) {
            let minutes = Int(iso8601Duration / 60)
            switch minutes {
            case 5: return .fiveMinutes
            case 15: return .fifteenMinutes
            case 30: return .thirtyMinutes
            case 60: return .oneHour
            case 120: return .twoHours
            case 1440: return .oneDay
            case 2880: return .twoDays
            case 10080: return .oneWeek
            default: return .none
            }
        }
        
        // Fall back to text parsing
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
    
    private func findBestCourseMatch(from text: String, courses: [Course]) -> String? {
        var bestMatch: String?
        var bestScore = 0.0
        
        for course in courses {
            let courseName = course.name.lowercased()
            
            if text.contains(courseName) {
                return course.name
            }
            
            let score = calculateCourseMatchScore(text: text, courseName: courseName, fullCourseName: course.name)
            if score > bestScore && score > 0.6 {
                bestScore = score
                bestMatch = course.name
            }
        }
        
        return bestMatch
    }
    
    private func calculateCourseMatchScore(text: String, courseName: String, fullCourseName: String) -> Double {
        let words = fullCourseName.components(separatedBy: .whitespaces)
        
        // Special case for "calc" -> "calculus"
        if text.contains("calc") && courseName.contains("calculus") {
            return 0.95
        }
        
        // Acronym matching
        let acronym = words.compactMap { $0.first?.lowercased() }.joined()
        if text.contains(acronym) && acronym.count >= 2 {
            return 0.8
        }
        
        // Number pattern matching
        let numberPattern = #"\b\d{3}\b"#
        if let courseNumberRange = fullCourseName.range(of: numberPattern, options: .regularExpression),
           let textNumberRange = text.range(of: numberPattern, options: .regularExpression) {
            let courseNumber = String(fullCourseName[courseNumberRange])
            let textNumber = String(text[textNumberRange])
            if courseNumber == textNumber {
                return 0.7
            }
        }
        
        // Partial word matching
        for word in words {
            if word.count >= 3 && text.contains(word.lowercased()) {
                return 0.6
            }
        }
        
        // Enhanced abbreviations from configuration
        let commonAbbreviations = config.getCourseAbbreviations()
        
        for (full, abbrevs) in commonAbbreviations {
            if courseName.contains(full) {
                for abbrev in abbrevs {
                    if text.contains(abbrev) {
                        return 0.9
                    }
                }
            }
        }
        
        return 0.0
    }
    
    private func extractAssignmentName(from text: String, courseName: String?, grade: String, gradeKeywords: [String]) -> String? {
        var cleanText = text
        
        if let courseName = courseName {
            cleanText = cleanText.replacingOccurrences(of: courseName.lowercased(), with: "")
        }
        
        cleanText = cleanText.replacingOccurrences(of: grade.lowercased(), with: "")
        
        for keyword in gradeKeywords {
            cleanText = cleanText.replacingOccurrences(of: keyword, with: "")
        }
        
        let wordsToRemove = ["on", "for", "in", "the", "a", "an", "my", "got", "received", "earned", "scored", "percent", "%"]
        for word in wordsToRemove {
            cleanText = cleanText.replacingOccurrences(of: "\\b\(word)\\b", with: "", options: .regularExpression)
        }
        
        let cleanedAssignmentName = cleanText
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        if !cleanedAssignmentName.isEmpty && cleanedAssignmentName.count < 50 && cleanedAssignmentName.count > 1 {
            return cleanedAssignmentName.capitalizedFirstLetter()
        }
        
        return nil
    }
    
    private func extractDaysOfWeek(from text: String) -> (Set<DayOfWeek>, String) {
        var days = Set<DayOfWeek>()
        var remainingText = text
        
        let dayMapping: [(String, DayOfWeek, Bool)] = [
            ("weekdays", .monday, true),
            ("mwf", .monday, true),
            ("tth", .tuesday, true), ("tue/thu", .tuesday, true), ("tues/thurs", .tuesday, true),
            ("monday", .monday, false), ("mon", .monday, false),
            ("tuesday", .tuesday, false), ("tue", .tuesday, false), ("tues", .tuesday, false),
            ("wednesday", .wednesday, false), ("wed", .wednesday, false),
            ("thursday", .thursday, false), ("thu", .thursday, false), ("thur", .thursday, false), ("thurs", .thursday, false),
            ("friday", .friday, false), ("fri", .friday, false),
            ("saturday", .saturday, false), ("sat", .saturday, false),
            ("sunday", .sunday, false), ("sun", .sunday, false)
        ]
        
        for (dayString, dayEnum, _) in dayMapping {
            if remainingText.contains(dayString) {
                switch dayString {
                case "weekdays":
                    DayOfWeek.allCases.filter { $0 != .saturday && $0 != .sunday }.forEach { days.insert($0) }
                case "mwf":
                    days.insert(.monday); days.insert(.wednesday); days.insert(.friday)
                case "tth", "tue/thu", "tues/thurs":
                    days.insert(.tuesday); days.insert(.thursday)
                default:
                    days.insert(dayEnum)
                }
                
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: dayString) + "\\b"
                remainingText = remainingText.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            }
        }
        
        return (days, remainingText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private func extractTime(from text: String, isEndTime: Bool) -> (DateComponents?, String) {
        var remainingText = text
        
        // Try 24-hour format first
        if let time24 = TimeParser.extract24HourTime(from: text) {
            let pattern24 = CompiledPatterns.time24HourPattern
            remainingText = pattern24.stringByReplacingMatches(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count), withTemplate: "")
            return (time24, remainingText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Fall back to 12-hour format
        let matches = CompiledPatterns.timePattern.matches(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count))
        
        var bestMatch: NSTextCheckingResult? = nil
        for match in matches {
            if match.range(at: 1).location == NSNotFound { continue }
            if let range = Range(match.range(at: 1), in: remainingText) {
                let matchedString = String(remainingText[range]).lowercased()
                if !["mon", "tue", "wed", "thu", "fri", "sat", "sun"].contains(matchedString) || matchedString.contains("am") || matchedString.contains("pm") || matchedString.contains(":") {
                    bestMatch = match
                    break
                }
            }
        }
        
        guard let validMatch = bestMatch,
              let range = Range(validMatch.range(at: 1), in: remainingText) else {
            return (nil, remainingText)
        }
        
        let timeString = String(remainingText[range])
        let components = TimeParser.parseTimeStringToComponents(timeString)
        
        var removalRange = range
        if let prefixRange = remainingText.range(of: #"\b(at|from)\s+"#, options: [.regularExpression, .caseInsensitive], range: remainingText.startIndex..<range.lowerBound) {
            removalRange = prefixRange.lowerBound..<range.upperBound
        }
        
        remainingText = remainingText.replacingCharacters(in: removalRange, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (components, remainingText)
    }
    
    private func extractDuration(from text: String) -> (TimeInterval, String)? {
        var remainingText = text
        var totalDuration: TimeInterval = 0
        
        var foundMatchInIteration: Bool
        repeat {
            foundMatchInIteration = false
            let matches = CompiledPatterns.durationPattern.matches(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count))
            
            if let currentMatch = matches.first {
                guard currentMatch.numberOfRanges == 3,
                      let valueRange = Range(currentMatch.range(at: 1), in: remainingText),
                      let unitRange = Range(currentMatch.range(at: 2), in: remainingText) else {
                    continue
                }
                
                let valueString = String(remainingText[valueRange])
                let unitString = String(remainingText[unitRange]).lowercased()
                
                if let value = Double(valueString) {
                    if unitString.starts(with: "h") {
                        totalDuration += value * 3600
                    } else if unitString.starts(with: "m") {
                        totalDuration += value * 60
                    }
                    
                    let combinedRange = Range(currentMatch.range, in: remainingText)!
                    remainingText.removeSubrange(combinedRange)
                    remainingText = remainingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    foundMatchInIteration = true
                }
            }
        } while foundMatchInIteration && !remainingText.isEmpty
        
        return totalDuration > 0 ? (totalDuration, remainingText) : nil
    }
}

// MARK: - Extensions
extension String {
    func capitalizedFirstLetter() -> String {
        guard let first = first else { return "" }
        return first.uppercased() + self.dropFirst()
    }
}
