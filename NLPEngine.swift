import Foundation
import NaturalLanguage

// Define the possible outcomes of parsing
enum NLPResult {
    case parsedEvent(title: String, date: Date?, categoryName: String?, reminderTime: ReminderTime?)
    case parsedScheduleItem(title: String, days: Set<DayOfWeek>, startTimeComponents: DateComponents?, endTimeComponents: DateComponents?, duration: TimeInterval?, reminderTime: ReminderTime?)
    case parsedGrade(courseName: String, assignmentName: String, grade: String, weight: String?)
    case needsMoreInfo(prompt: String, originalInput: String, context: ParseContext?)
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

class NLPEngine {
    private var categories: [Category] = []

    func parse(inputText: String, availableCategories: [Category] = [], existingCourses: [Course] = []) -> NLPResult {
        self.categories = availableCategories
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedInput.isEmpty {
            return .notAttempted
        }
        
        if let gradeResult = tryParseAsGrade(text: trimmedInput, courses: existingCourses) {
            return gradeResult
        }
        
        if containsStrongScheduleKeywords(text: trimmedInput.lowercased()) {
            if let scheduleResult = tryParseAsScheduleItem(text: trimmedInput) {
                switch scheduleResult {
                case .parsedScheduleItem(_, let days, let startTime, _, _, _):
                    if !days.isEmpty || startTime != nil {
                        return scheduleResult
                    }
                case .needsMoreInfo(_, _, _):
                    return scheduleResult
                default:
                    break
                }
            }
        }

        if let eventResult = tryParseAsEvent(text: trimmedInput) {
            return eventResult
        }
        
        if let potentialScheduleResult = tryParseAsScheduleItem(text: trimmedInput) {
            switch potentialScheduleResult {
            case .parsedScheduleItem(_, let days, let startTimeComponents, let endTimeComponents, let duration, _):
                if !days.isEmpty || startTimeComponents != nil || endTimeComponents != nil || duration != nil {
                    return potentialScheduleResult
                }
            case .needsMoreInfo(_, _, _):
                return potentialScheduleResult
            default:
                break
            }
        }
        
        return .unrecognized(originalInput: inputText)
    }
    
    func parseFollowUp(inputText: String, context: ParseContext, existingCourses: [Course] = []) -> NLPResult {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch context {
        case .gradeNeedsWeight(let courseName, let assignmentName, let grade):
            if let weight = extractWeight(from: trimmedInput) {
                return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: weight)
            } else if trimmedInput.lowercased().contains("skip") || trimmedInput.lowercased().contains("no") {
                return .parsedGrade(courseName: courseName, assignmentName: assignmentName, grade: grade, weight: nil)
            } else {
                return .needsMoreInfo(prompt: "Please enter the weight as a percentage (e.g., '20%') or say 'skip' to continue without weight.", originalInput: trimmedInput, context: context)
            }
            
        case .gradeNeedsAssignmentName(let courseName, let grade):
            let assignmentName = trimmedInput.isEmpty ? "Assignment" : trimmedInput
            return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip')", originalInput: "", context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignmentName, grade: grade))
            
        case .gradeNeedsCourse(let assignmentName, let grade):
            if let course = existingCourses.first(where: { $0.name.lowercased().contains(trimmedInput.lowercased()) }) {
                let finalAssignmentName = assignmentName ?? "Assignment"
                return .needsMoreInfo(prompt: "What's the weight of this assignment? (e.g., '20%' or 'skip')", originalInput: "", context: .gradeNeedsWeight(courseName: course.name, assignmentName: finalAssignmentName, grade: grade))
            } else {
                return .needsMoreInfo(prompt: "Course '\(trimmedInput)' not found. Please enter an existing course name.", originalInput: trimmedInput, context: context)
            }
            
        case .eventNeedsReminder(let title, let date, let categoryName):
            let reminderTime = parseReminderTime(from: trimmedInput)
            return .parsedEvent(title: title, date: date, categoryName: categoryName, reminderTime: reminderTime)
            
        case .scheduleNeedsReminder(let title, let days, let startTime, let endTime, let duration):
            let reminderTime = parseReminderTime(from: trimmedInput)
            return .parsedScheduleItem(title: title, days: days, startTimeComponents: startTime, endTimeComponents: endTime, duration: duration, reminderTime: reminderTime)
            
        case .scheduleNeedsMoreTime(let title, let days, let startTime):
            let (newEndTime, _) = extractTime(from: trimmedInput, isEndTime: true)
            var duration: TimeInterval? = nil
            
            if newEndTime == nil {
                if let extractedDuration = extractDuration(from: trimmedInput) {
                    duration = extractedDuration.0
                }
            }
            
            if newEndTime != nil || duration != nil {
                return .needsMoreInfo(prompt: "Would you like to set a reminder? (e.g., '15 minutes before', '1 hour before', or 'no')", originalInput: "", context: .scheduleNeedsReminder(title: title, days: days, startTime: startTime, endTime: newEndTime, duration: duration))
            } else {
                return .needsMoreInfo(prompt: "Please specify an end time (e.g., 'until 3pm') or duration (e.g., 'for 1 hour')", originalInput: trimmedInput, context: context)
            }
        }
    }
    
    private func extractWeight(from text: String) -> String? {
        let weightPattern = #"(\d{1,3}(?:\.\d{1,2})?)\s*%?"#
        if let range = text.range(of: weightPattern, options: .regularExpression) {
            var weight = String(text[range])
            // Remove any existing % sign and add it back
            weight = weight.replacingOccurrences(of: "%", with: "")
            if let weightValue = Double(weight), weightValue <= 100 {
                return String(format: "%.0f%%", weightValue)
            }
        }
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
        } else {
            return .none // Default to no reminder if unclear
        }
    }
    
    private func containsStrongScheduleKeywords(text: String) -> Bool {
        let strongKeywords = ["every", "weekly", "schedule", "class"]
        return strongKeywords.contains { keyword in text.contains(keyword) }
    }

    private func tryParseAsEvent(text: String) -> NLPResult? {
        var textToParse = text
        var detectedDate: Date? = nil
        
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: textToParse, options: [], range: NSRange(location: 0, length: textToParse.utf16.count))

        if let match = matches?.first, let date = match.date {
            detectedDate = date
            if let range = Range(match.range, in: textToParse) {
                textToParse = textToParse.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        let title = textToParse.isEmpty ? (detectedDate != nil ? "Event" : text) : textToParse
        if detectedDate == nil && title.split(separator: " ").count < 2 && title.count < 10 { return nil }

        let eventKeywords = ["meeting", "appointment", "reminder", "deadline", "exam", "test", "quiz", "homework", "hw", "due", "call", "lunch", "dinner", "party"]
        var isLikelyEvent = detectedDate != nil
        
        if !isLikelyEvent {
            for keyword in eventKeywords {
                if title.lowercased().contains(keyword) {
                    isLikelyEvent = true
                    break
                }
            }
        }

        if !isLikelyEvent { return nil }

        var categoryName: String? = nil
        for category in categories {
            if title.lowercased().contains(category.name.lowercased()) {
                categoryName = category.name
                break
            }
        }
        
        return .needsMoreInfo(prompt: "Would you like to set a reminder for '\(title)'? (e.g., '15 minutes before', '1 hour before', or 'no')", originalInput: text, context: .eventNeedsReminder(title: title, date: detectedDate, categoryName: categoryName))
    }

    private func tryParseAsScheduleItem(text: String) -> NLPResult? {
        var remainingText = text.lowercased()
        
        let (days, textWithoutDays) = extractDaysOfWeek(from: remainingText)
        remainingText = textWithoutDays
        
        let (startTime, textWithoutStartTime) = extractTime(from: remainingText, isEndTime: false)
        remainingText = textWithoutStartTime
        
        var endTime: DateComponents? = nil
        var duration: TimeInterval? = nil
        
        let toPattern = #"(?i)\bto\b|\s-\s"#
        if let toRange = remainingText.range(of: toPattern, options: .regularExpression) {
            let textAfterTo = String(remainingText[toRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let (extractedEndTime, textWithoutEndTimeFromSubParse) = extractTime(from: textAfterTo, isEndTime: true)
            if extractedEndTime != nil {
                endTime = extractedEndTime
                let textBeforeTo = String(remainingText[..<toRange.lowerBound])
                remainingText = textBeforeTo + textWithoutEndTimeFromSubParse
                remainingText = remainingText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if endTime == nil {
            if let extractedDuration = extractDuration(from: remainingText) {
                duration = extractedDuration.0
                remainingText = extractedDuration.1
            }
        }

        let title = remainingText.trimmingCharacters(in: .whitespacesAndNewlines).capitalizedFirstLetter()

        if title.isEmpty && days.isEmpty && startTime == nil && endTime == nil && duration == nil {
            return .unrecognized(originalInput: text)
        }
        
        if days.isEmpty && endTime == nil && duration == nil && startTime != nil && !containsStrongScheduleKeywords(text: text.lowercased()) {
             let eventKeywords = ["meeting", "appointment", "deadline", "exam", "test", "call", "lunch"]
             if eventKeywords.contains(where: title.lowercased().contains) {
                 return nil
             }
        }

        let typicalClassKeywords = ["math", "physics", "english", "history", "cs ", "chem", "bio", "lecture", "seminar", "workshop"]
        var hasClassKeywordInTitle = false
        for keyword in typicalClassKeywords {
            if title.lowercased().contains(keyword) {
                hasClassKeywordInTitle = true; break
            }
        }
        
        let hasSufficientTimeInfo = startTime != nil && (endTime != nil || duration != nil || hasClassKeywordInTitle)
        if days.isEmpty && !hasSufficientTimeInfo {
            if title.isEmpty || (startTime == nil && endTime == nil && duration == nil) {
                 if days.count == 1 && title.isEmpty {
                     return .needsMoreInfo(prompt: "Please provide a title and time for your item on \(days.first!.shortName).", originalInput: text, context: nil)
                 }
            } else if startTime != nil && days.isEmpty && endTime == nil && duration == nil && !hasClassKeywordInTitle {
                 return .needsMoreInfo(prompt: "Please specify days or an end time/duration for '\(title)'.", originalInput: text, context: .scheduleNeedsMoreTime(title: title, days: days, startTime: startTime))
            }
            if title.lowercased() == "scheduled item" && days.isEmpty && startTime == nil {
                return .unrecognized(originalInput: text)
            }
        }
        
        let finalTitle = title.isEmpty ? "Scheduled Item" : title
        if !days.isEmpty && startTime != nil && (endTime != nil || duration != nil) {
            return .needsMoreInfo(prompt: "Would you like to set a reminder for '\(finalTitle)'? (e.g., '15 minutes before', '1 hour before', or 'no')", originalInput: text, context: .scheduleNeedsReminder(title: finalTitle, days: days, startTime: startTime, endTime: endTime, duration: duration))
        }

        return .parsedScheduleItem(title: finalTitle,
                                   days: days,
                                   startTimeComponents: startTime,
                                   endTimeComponents: endTime,
                                   duration: duration,
                                   reminderTime: nil)
    }

    private func tryParseAsGrade(text: String, courses: [Course]) -> NLPResult? {
        let lowercasedText = text.lowercased()
        let gradeKeywords = ["grade", "score", "got", "received", "earned", "scored"]
        var isLikelyGrade = false
        for keyword in gradeKeywords {
            if lowercasedText.contains(keyword) {
                isLikelyGrade = true
                break
            }
        }
        
        let gradePattern = #"(\b\d{1,3}(?:\.\d{1,2})?%?|\b[A-F][+-]?|\b\d{1,3}(?:\.\d{1,2})?(?:\s*out\s*of\s*\d+)?)\b"#
        let hasGradePattern = lowercasedText.range(of: gradePattern, options: .regularExpression) != nil
        
        if !isLikelyGrade && !hasGradePattern { return nil }

        var extractedGrade: String?
        if let range = lowercasedText.range(of: gradePattern, options: .regularExpression) {
            extractedGrade = String(lowercasedText[range]).uppercased()
            extractedGrade = normalizeGrade(extractedGrade!)
        }
        
        guard let grade = extractedGrade else {
            return .needsMoreInfo(prompt: "I couldn't find a grade in your input. Please include the grade (e.g., '95%', 'A+', '87').", originalInput: text, context: nil)
        }

        var identifiedCourseName: String?
        var identifiedAssignmentName: String?
        
        identifiedCourseName = findBestCourseMatch(from: lowercasedText, courses: courses)
        
        if let courseName = identifiedCourseName {
            identifiedAssignmentName = extractAssignmentName(from: lowercasedText, courseName: courseName, grade: grade, gradeKeywords: gradeKeywords)
        }
        
        // Handle missing information with follow-up questions
        if let courseName = identifiedCourseName {
            if let assignmentName = identifiedAssignmentName {
                // We have course, assignment, and grade - ask about weight
                return .needsMoreInfo(prompt: "What's the weight of '\(assignmentName)' in \(courseName)? (e.g., '20%' or 'skip' if you don't want to specify)", originalInput: text, context: .gradeNeedsWeight(courseName: courseName, assignmentName: assignmentName, grade: grade))
            } else {
                // We have course and grade but no assignment name
                return .needsMoreInfo(prompt: "What's the name of this assignment in \(courseName)?", originalInput: text, context: .gradeNeedsAssignmentName(courseName: courseName, grade: grade))
            }
        } else {
            // We have grade but no course
            if courses.isEmpty {
                return .needsMoreInfo(prompt: "No courses found. Please add some courses first in the Courses section.", originalInput: text, context: nil)
            } else {
                let courseNames = courses.map { $0.name }.joined(separator: ", ")
                return .needsMoreInfo(prompt: "Which course is this grade for? Available courses: \(courseNames)", originalInput: text, context: .gradeNeedsCourse(assignmentName: identifiedAssignmentName, grade: grade))
            }
        }
    }
    
    private func normalizeGrade(_ grade: String) -> String {
        var normalized = grade.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle "X out of Y" format
        if normalized.contains("out of") {
            let parts = normalized.components(separatedBy: "out of")
            if parts.count == 2,
               let numerator = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
               let denominator = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
               denominator > 0 {
                let percentage = (numerator / denominator) * 100
                return String(format: "%.1f%%", percentage)
            }
        }
        
        // Ensure percentage has % sign
        if normalized.range(of: #"^\d+(?:\.\d+)?$"#, options: .regularExpression) != nil {
            // If it's just a number, assume it's a percentage
            return normalized + "%"
        }
        
        // Letter grades should be uppercase
        if normalized.range(of: #"^[A-F][+-]?$"#, options: .regularExpression) != nil {
            return normalized.uppercased()
        }
        
        return normalized
    }
    
    private func findBestCourseMatch(from text: String, courses: [Course]) -> String? {
        var bestMatch: String?
        var bestScore = 0.0
        
        for course in courses {
            let courseName = course.name.lowercased()
            
            // Direct match
            if text.contains(courseName) {
                return course.name
            }
            
            // Check for acronyms and shortforms
            let score = calculateCourseMatchScore(text: text, courseName: courseName, fullCourseName: course.name)
            if score > bestScore && score > 0.6 { // Threshold for acceptable match
                bestScore = score
                bestMatch = course.name
            }
        }
        
        return bestMatch
    }
    
    private func calculateCourseMatchScore(text: String, courseName: String, fullCourseName: String) -> Double {
        // Generate potential acronyms and shortforms
        let words = fullCourseName.components(separatedBy: .whitespaces)
        
        // Check for acronym (first letters)
        let acronym = words.compactMap { $0.first?.lowercased() }.joined()
        if text.contains(acronym) && acronym.count >= 2 {
            return 0.8
        }
        
        // Check for number patterns (e.g., "101", "201")
        let numberPattern = #"\b\d{3}\b"#
        if let courseNumberRange = fullCourseName.range(of: numberPattern, options: .regularExpression),
           let textNumberRange = text.range(of: numberPattern, options: .regularExpression) {
            let courseNumber = String(fullCourseName[courseNumberRange])
            let textNumber = String(text[textNumberRange])
            if courseNumber == textNumber {
                return 0.7
            }
        }
        
        // Check for partial word matches
        for word in words {
            if word.count >= 3 && text.contains(word.lowercased()) {
                return 0.6
            }
        }
        
        // Check for common abbreviations
        let commonAbbreviations = [
            "mathematics": ["math", "maths"],
            "computer science": ["cs", "comp sci", "compsci"],
            "physics": ["phys"],
            "chemistry": ["chem"],
            "biology": ["bio"],
            "history": ["hist"],
            "english": ["eng"],
            "psychology": ["psych", "psyc"],
            "philosophy": ["phil"]
        ]
        
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
    
    private func extractAssignmentName(from text: String, courseName: String, grade: String, gradeKeywords: [String]) -> String? {
        let courseNameLower = courseName.lowercased()
        var cleanText = text
        
        // Remove course name
        cleanText = cleanText.replacingOccurrences(of: courseNameLower, with: "", options: .caseInsensitive)
        
        // Remove grade
        cleanText = cleanText.replacingOccurrences(of: grade.lowercased(), with: "")
        
        // Remove grade keywords
        for keyword in gradeKeywords {
            cleanText = cleanText.replacingOccurrences(of: keyword, with: "")
        }
        
        // Remove common prepositions and articles
        let wordsToRemove = ["on", "for", "in", "the", "a", "an", "my", "got", "received", "earned", "scored", "percent", "%"]
        for word in wordsToRemove {
            cleanText = cleanText.replacingOccurrences(of: "\\b\(word)\\b", with: "", options: .regularExpression)
        }
        
        // Clean up the text
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
        
        let dayMapping: [(String, DayOfWeek, Bool)] = [ // Bool: is it a compound keyword like "weekdays"?
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
        
        for (dayString, dayEnum, isCompound) in dayMapping {
            if remainingText.contains(dayString) {
                if dayString == "weekdays" {
                    DayOfWeek.allCases.filter { $0 != .saturday && $0 != .sunday }.forEach { days.insert($0) }
                } else if dayString == "mwf" {
                    days.insert(.monday); days.insert(.wednesday); days.insert(.friday)
                } else if dayString == "tth" || dayString == "tue/thu" || dayString == "tues/thurs" {
                    days.insert(.tuesday); days.insert(.thursday)
                } else {
                    days.insert(dayEnum)
                }
                // More robust removal: replace all occurrences of the standalone word
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: dayString) + "\\b"
                remainingText = remainingText.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            }
        }
        return (days, remainingText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func extractTime(from text: String, isEndTime: Bool) -> (DateComponents?, String) {
        var remainingText = text
        var components: DateComponents?

        let timePattern = #"(?i)(\b\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b)"#
        let regex = try! NSRegularExpression(pattern: timePattern, options: [])
        
        var searchRange = NSRange(location: 0, length: remainingText.utf16.count)
        
        let matches = regex.matches(in: remainingText, options: [], range: searchRange)
        
        // Find the first valid time match that isn't part of a day string (e.g. "thu")
        var bestMatch: NSTextCheckingResult? = nil
        for match in matches {
             if match.range(at: 1).location == NSNotFound { continue } // Ensure capture group 1 exists
             if let r = Range(match.range(at: 1), in: remainingText) {
                let matchedString = String(remainingText[r]).lowercased()
                // Avoid day abbreviations unless they are followed by am/pm or contain a colon
                if !(["mon", "tue", "wed", "thu", "fri", "sat", "sun"].contains(matchedString) && !matchedString.contains("am") && !matchedString.contains("pm") && !matchedString.contains(":")) {
                    bestMatch = match
                    break
                }
            }
        }

        if let validMatch = bestMatch {
            if let range = Range(validMatch.range(at: 1), in: remainingText) {
                let timeString = String(remainingText[range])
                components = parseTimeStringToComponents(timeString)
                
                // Smart removal of the matched time string and nearby prepositions/connectors
                var removalRange = range
                // Check for "at ", "from " before the time
                if let prefixRange = remainingText.range(of: #"\b(at|from)\s+"#, options: [.regularExpression, .caseInsensitive], range: remainingText.startIndex..<range.lowerBound) {
                    removalRange = prefixRange.lowerBound..<range.upperBound
                }
                remainingText = remainingText.replacingCharacters(in: removalRange, with: "")
                                     .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return (components, remainingText)
    }
    
    private func parseTimeStringToComponents(_ timeString: String) -> DateComponents? {
        var comp = DateComponents()
        let lowercased = timeString.lowercased()
        
        var hour: Int?
        var minute: Int?
        
        let cleanedTimeString = lowercased.filter { "0123456789:amp".contains($0) }
        
        let timeParts = cleanedTimeString.components(separatedBy: ":")
        
        if let firstPart = timeParts.first?.filter({ $0.isNumber }) , let h = Int(firstPart) {
            hour = h
            if timeParts.count > 1, let secondPart = timeParts.last?.filter({ $0.isNumber }), let m = Int(secondPart) {
                minute = m
            } else {
                minute = 0 // Default to :00 if no minutes specified (e.g., "9am")
            }
        } else {
            return nil // Could not parse hour
        }


        if var h = hour {
            if lowercased.contains("pm") && h < 12 {
                h += 12
            } else if lowercased.contains("am") && h == 12 { // 12am is midnight
                h = 0
            }
            comp.hour = h
            comp.minute = minute ?? 0
            return comp
        }
        return nil
    }

    private func extractDuration(from text: String) -> (TimeInterval, String)? {
        let regex = try! NSRegularExpression(pattern: #"(?i)(\d+(?:\.\d+)?)\s*(hour|hr|h|minute|min|m)"#, options: [])
        var remainingText = text
        var totalDuration: TimeInterval = 0

        // Iterate multiple times in case of "1 hour 30 minutes"
        var foundMatchInIteration: Bool
        repeat {
            foundMatchInIteration = false
            let matches = regex.matches(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count))
            
            if let currentMatch = matches.first { // Process one match at a time to simplify removal
                guard currentMatch.numberOfRanges == 3 else { continue }
                
                let valueRange = Range(currentMatch.range(at: 1), in: remainingText)!
                let unitRange = Range(currentMatch.range(at: 2), in: remainingText)!
                
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

extension String {
    func capitalizedFirstLetter() -> String {
        guard let first = first else { return "" }
        return first.uppercased() + self.dropFirst()
    }
}
