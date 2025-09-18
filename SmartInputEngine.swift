//
//  SmartInputEngine.swift
//  Student Companion - Smart NLP Engine
//
//  Created by Alex, the AI Copilot, from the ground up.
//

import Foundation
import NaturalLanguage
import CoreML

// MARK: - Public Structs

public struct SmartInputResult {
    public let intent: String
    public let entities: [String: String]
    public let confidence: Double
    public let isComplete: Bool
    public let followUpQuestion: String?
}

// MARK: - SmartInputEngine

public final class SmartInputEngine {

    // MARK: - Properties

    // Public Callbacks
    var onCourseSelectionNeeded: ((_ originalInput: String, _ suggestedAlias: String, _ availableCourses: [Course]) -> Void)?

    // ML Models
    private lazy var intentModel: MLModel? = loadModel(named: "IntentClassifier")
    private lazy var gradeEntityModel: MLModel? = loadModel(named: "GradeEntityClassifier")
    private lazy var eventEntityModel: MLModel? = loadModel(named: "EventEntityClassifier")
    private lazy var scheduleEntityModel: MLModel? = loadModel(named: "ScheduleEntityClassifier")

    // User Data & Aliases
    private var userCourseObjects: [Course] = []
    private var userCourses: [String] = []
    private var userCoursesLowercase: [String] = []
    private var courseAliases: [String: String] = defaultCourseAliases()
    private var assignmentAliases: [String: String] = defaultAssignmentAliases()

    // MARK: - Initialization

    public init() {
        debugBundleContents()
    }

    // MARK: - Public API

    func setCourseSelectionCallback(_ callback: @escaping (String, String, [Course]) -> Void) {
        self.onCourseSelectionNeeded = callback
    }

    public func updateUserCourses(_ courses: [String]) {
        self.userCourses = courses
        self.userCoursesLowercase = courses.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        let generated = generateCourseAliases(from: courses)
        for (key, value) in generated { courseAliases[key] = value }
    }

    func updateUserCoursesWithObjects(_ courses: [Course]) {
        self.userCourseObjects = courses
        let courseNames = courses.map { $0.name }
        self.updateUserCourses(courseNames)
    }

    public func process(_ utterance: String, isFollowUp: Bool = false, currentField: String? = nil, context: [String: String] = [:]) async -> SmartInputResult {
        let normalizedUtterance = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUtterance.isEmpty else {
            return .init(intent: "unknown", entities: [:], confidence: 0.0, isComplete: false, followUpQuestion: "Could you please provide some input?")
        }

        if isFollowUp, let field = currentField {
            return await processFollowUp(for: field, with: normalizedUtterance, context: context)
        } else {
            return await processInitial(utterance: normalizedUtterance)
        }
    }
    
    // MARK: - Processing Logic

    private func processInitial(utterance: String) async -> SmartInputResult {
        // 1. Classify Intent
        let (intent, confidence) = classifyIntent(from: utterance)
        guard intent != "unknown" else {
            return .init(intent: "unknown", entities: [:], confidence: 0.0, isComplete: false, followUpQuestion: "I'm not sure I understand. Can you rephrase?")
        }

        // 2. Extract Entities from the model
        var entities = extractEntitiesFromModel(for: intent, from: utterance)

        // 3. Normalize and Refine Entities using fallbacks and logic
        entities = normalizeAndRefine(entities: entities, for: intent, from: utterance)
        
        // 4. Check for completion and generate follow-up if needed
        return checkCompletion(for: intent, with: entities, from: utterance)
    }

    private func processFollowUp(for field: String, with utterance: String, context: [String: String]) async -> SmartInputResult {
        var updatedContext = context
        let intent = intentFromField(field)

        // Process the follow-up utterance and update the context
        updatedContext[field] = utterance
        
        // Re-normalize and refine the updated context with the new information
        updatedContext = normalizeAndRefine(entities: updatedContext, for: intent, from: utterance)

        return checkCompletion(for: intent, with: updatedContext, from: utterance)
    }

    private func checkCompletion(for intent: String, with entities: [String: String], from utterance: String) -> SmartInputResult {
        let missingFields = getMissingFields(for: intent, from: entities)

        if missingFields.isEmpty {
            return .init(intent: intent, entities: entities, confidence: 1.0, isComplete: true, followUpQuestion: nil)
        } else {
            // Handle the special case where the course name is missing and needs user selection
            if missingFields.contains("COURSE_NAME"), let extractedCourse = entities["EXTRACTED_COURSE"], !userCourseObjects.isEmpty {
                onCourseSelectionNeeded?(utterance, extractedCourse, userCourseObjects)
                var tempEntities = entities
                tempEntities["AWAITING_COURSE_SELECTION"] = "true" // Signal to the view
                return .init(intent: intent, entities: tempEntities, confidence: 1.0, isComplete: false, followUpQuestion: nil)
            }
            
            let nextField = missingFields.first!
            let question = generateFollowUpQuestion(for: nextField, intent: intent)
            return .init(intent: intent, entities: entities, confidence: 1.0, isComplete: false, followUpQuestion: question)
        }
    }

    // MARK: - Normalization and Refinement

    private func normalizeAndRefine(entities: [String: String], for intent: String, from utterance: String) -> [String: String] {
        var newEntities = entities
        
        switch intent {
        case "grade_tracking":
            // Disambiguate Score vs. Weight. Prioritize explicit keywords.
            if newEntities["SCORE_VALUE"] == nil, let score = extractScore(from: utterance) { newEntities["SCORE_VALUE"] = score }
            if newEntities["WEIGHT_PERCENT"] == nil, let weight = extractWeight(from: utterance) { newEntities["WEIGHT_PERCENT"] = weight }

            // Normalize Score value (e.g., from fractions "18/20" to "90.00")
            if let score = newEntities["SCORE_VALUE"] { newEntities["SCORE_VALUE"] = normalizeGrade(from: score) }

            // Normalize Assignment using aliases
            if let assignment = newEntities["ASSIGNMENT"] { newEntities["ASSIGNMENT"] = assignmentAliases[assignment.lowercased()] ?? assignment }
            
            // Match Course Name using aliases and fuzzy matching
            if let courseName = newEntities["COURSE_NAME"] ?? newEntities["COURSE_ALIAS"] ?? newEntities["COURSE_CODE"] {
                if let matched = findMatchingUserCourse(courseName) {
                    newEntities["COURSE_NAME"] = matched
                } else {
                    newEntities["EXTRACTED_COURSE"] = courseName // Store for potential selection popup
                }
            }
        
        // Add normalization for other intents as needed
        default:
            break
        }
        
        return newEntities
    }

    // MARK: - Entity Extraction Fallbacks & Helpers

    private func extractScore(from text: String) -> String? {
        // Regex for "got 18/20", "scored 90%", "grade of 85"
        let patternWithKeyword = #"(?:got|scored|received|grade of)\s*([0-9/.]+\s*(?:%|percent)?)"#
        if let match = text.captureRegex(pattern: patternWithKeyword)?.last { return match.trimmingCharacters(in: .whitespaces) }
        
        // Regex for "18/20" or "90%" when "worth" is NOT present, to avoid confusion with weight.
        if !text.lowercased().contains("worth") {
            let patternWithoutKeyword = #"([0-9/.]+\s*(?:%|percent))"#
            if let match = text.captureRegex(pattern: patternWithoutKeyword)?.last { return match.trimmingCharacters(in: .whitespaces) }
        }
        return nil
    }

    private func extractWeight(from text: String) -> String? {
        // Regex for "worth 3%", "weight 10 percent"
        let pattern = #"(?:worth|weight)\s*([0-9.]+\s*(?:%|percent)?)"#
        if let match = text.captureRegex(pattern: pattern)?.last {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func normalizeGrade(from text: String) -> String {
        // Convert fraction "18/20" to percentage string "90.00"
        if text.contains("/") {
            let parts = text.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
                return String(format: "%.2f", (num / den) * 100.0)
            }
        }
        // Remove non-numeric characters from percentage or plain number strings
        return text.filter("0123456789.".contains)
    }

    // MARK: - Missing Fields and Follow-up Questions

    private func getRequiredFields(for intent: String) -> [String] {
        switch intent {
        case "grade_tracking": return ["COURSE_NAME", "ASSIGNMENT", "SCORE_VALUE"]
        case "scheduled_event": return ["EVENT", "DAY_OF_WEEK", "TIME_START", "TIME_END"]
        case "event_reminder": return ["EVENT", "DATE_ABS", "TIME"] // Simplified for this example
        default: return []
        }
    }
    
    public func getMissingFields(for intent: String, from entities: [String: String]) -> [String] {
        let required = getRequiredFields(for: intent)
        return required.filter { field in (entities[field] ?? "").isEmpty }
    }

    public func generateFollowUpQuestion(for field: String, intent: String) -> String {
        switch field {
        case "COURSE_NAME": return "What course is this for?"
        case "ASSIGNMENT": return "Which assignment is this (e.g., exam, quiz, project)?"
        case "SCORE_VALUE": return "What score did you get (e.g., 85% or 17/20)?"
        case "WEIGHT_PERCENT": return "What percent of the final grade is this worth? (This is optional)"
        case "EVENT": return "What's the name of the event?"
        case "DAY_OF_WEEK": return "Which days does this happen on (e.g., Mon, Wed, Fri)?"
        case "TIME_START": return "What time does it start?"
        case "TIME_END": return "And what time does it end?"
        case "DATE_ABS": return "When is it? (e.g., tomorrow, next Friday, Oct 31)"
        case "TIME": return "What time is the event?"
        case "CATEGORY": return "What category should this be in? (e.g., Personal, School)"
        case "REM_OFFSET": return "When should I remind you?"
        default: return "Could you provide more details about the \(field.lowercased().replacingOccurrences(of: "_", with: " "))?"
        }
    }
    
    // MARK: - CoreML and NLP Helpers
    
    private func loadModel(named modelName: String) -> MLModel? {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
             ("❌ Error: Could not find \(modelName).mlmodelc in bundle.")
            return nil
        }
        do {
            let model = try MLModel(contentsOf: url)
             ("✅ Successfully loaded \(modelName).")
            return model
        } catch {
             ("❌ Error loading model \(modelName): \(error)")
            return nil
        }
    }

    private func classifyIntent(from text: String) -> (String, Double) {
        guard let model = intentModel else { return ("unknown", 0.0) }
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": text])
            let prediction = try model.prediction(from: input)
            let label = prediction.featureValue(for: "label")?.stringValue ?? "unknown"
            let probability = prediction.featureValue(for: "labelProbability")?.dictionaryValue[label] as? Double ?? 0.0
            return (label, probability)
        } catch {
             ("❌ Intent classification failed: \(error)"); return ("unknown", 0.0)
        }
    }

    private func extractEntitiesFromModel(for intent: String, from text: String) -> [String: String] {
        let model: MLModel?
        let labelMapping: [String: String]
        switch intent {
        case "grade_tracking": (model, labelMapping) = (gradeEntityModel, gradeLabelToKeyMap())
        case "event_reminder": (model, labelMapping) = (eventEntityModel, eventLabelToKeyMap())
        case "scheduled_event": (model, labelMapping) = (scheduleEntityModel, scheduleLabelToKeyMap())
        default: return [:]
        }

        guard let entityModel = model else { return [:] }
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": text])
            let prediction = try entityModel.prediction(from: input)
            guard let tokens = prediction.featureValue(for: "tokens")?.stringValue.split(separator: " ").map(String.init),
                  let labels = prediction.featureValue(for: "labels")?.stringValue.split(separator: " ").map(String.init),
                  tokens.count == labels.count else { return [:] }
            
            return entitiesFromBIO(tokensAndLabels: Array(zip(tokens, labels)), labelMapping: labelMapping)
        } catch {
             ("❌ Entity extraction for intent '\(intent)' failed: \(error)"); return [:]
        }
    }

    private func entitiesFromBIO(tokensAndLabels: [(String, String)], labelMapping: [String: String]) -> [String: String] {
        var results: [String: String] = [:]
        var currentEntityParts: [String] = []
        var currentEntityType: String? = nil

        for (token, label) in tokensAndLabels {
            if label.starts(with: "B-") {
                if let type = currentEntityType, !currentEntityParts.isEmpty {
                    results[type] = currentEntityParts.joined(separator: " ")
                }
                let entityType = String(label.dropFirst(2))
                currentEntityType = labelMapping[entityType] ?? entityType
                currentEntityParts = [token]
            } else if label.starts(with: "I-") {
                let entityType = String(label.dropFirst(2))
                if currentEntityType == (labelMapping[entityType] ?? entityType) {
                    currentEntityParts.append(token)
                }
            } else { // "O" label
                if let type = currentEntityType, !currentEntityParts.isEmpty {
                    results[type] = currentEntityParts.joined(separator: " ")
                }
                currentEntityParts = []
                currentEntityType = nil
            }
        }
        if let type = currentEntityType, !currentEntityParts.isEmpty {
            results[type] = currentEntityParts.joined(separator: " ")
        }
        return results
    }

    // MARK: - Course fuzzy matching & alias generation

    private func findMatchingUserCourse(_ input: String) -> String? {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = userCoursesLowercase.firstIndex(of: normalized) { return userCourses[idx] }
        if let aliasResolve = courseAliases[normalized] {
            if let idx = userCourses.firstIndex(where: { $0.caseInsensitiveCompare(aliasResolve) == .orderedSame }) { return userCourses[idx] }
            return aliasResolve
        }
        var best: (course: String, score: Int) = ("", 0)
        for (i, course) in userCoursesLowercase.enumerated() {
            let score = similarityScore(between: normalized, and: course)
            if score > best.score { best = (userCourses[i], score) }
        }
        return best.score > 60 ? best.course : nil // Use a threshold
    }

    private func generateCourseAliases(from courses: [String]) -> [String: String] {
        var map: [String: String] = [:]
        for course in courses {
            let normalized = course.lowercased()
            map[normalized] = course
            let words = normalized.split(separator: " ").map(String.init)
            words.forEach { map[$0] = course }
            let abbr = words.map { String($0.prefix(1)) }.joined()
            if abbr.count > 1 { map[abbr] = course }
        }
        return map
    }

    private func similarityScore(between s1: String, and s2: String) -> Int {
        if s1 == s2 { return 100 }
        if s2.contains(s1) || s1.contains(s2) {
            return Int(90 * Double(min(s1.count, s2.count)) / Double(max(s1.count, s2.count)))
        }
        let w1 = Set(s1.split(separator: " ")), w2 = Set(s2.split(separator: " "))
        let common = w1.intersection(w2)
        return Int(80 * Double(common.count) / Double(max(1, max(w1.count, w2.count))))
    }

    // MARK: - Mappings
    
    private func intentFromField(_ field: String) -> String {
        switch field {
        case "COURSE_NAME", "ASSIGNMENT", "SCORE_VALUE", "WEIGHT_PERCENT": return "grade_tracking"
        case "DAY_OF_WEEK", "TIME_START", "TIME_END", "REC_FREQ": return "scheduled_event"
        default: return "event_reminder"
        }
    }
    
    private func gradeLabelToKeyMap() -> [String: String] { ["ASSIGNMENT": "ASSIGNMENT", "SCORE_VALUE": "SCORE_VALUE", "COURSE_CODE": "COURSE_CODE", "MAX_SCORE": "MAX_SCORE", "COURSE_NAME": "COURSE_NAME", "LETTER_GRADE": "LETTER_GRADE", "COURSE_ALIAS": "COURSE_ALIAS", "WEIGHT_PERCENT": "WEIGHT_PERCENT"] }
    private func eventLabelToKeyMap() -> [String: String] { ["EVENT": "EVENT", "DATE_ABS": "DATE_ABS", "REL_DURATION": "REL_DURATION", "DEADLINE_MARKER": "DEADLINE_MARKER", "DAY_OF_WEEK": "DAY_OF_WEEK", "TIME": "TIME", "DATE_REL": "DATE_REL", "REM_OFFSET": "REM_OFFSET", "CATEGORY": "CATEGORY"] }
    private func scheduleLabelToKeyMap() -> [String: String] { ["EVENT": "EVENT", "REC_FREQ": "REC_FREQ", "DAY_OF_WEEK": "DAY_OF_WEEK", "TIME_START": "TIME_START", "REM_OFFSET": "REM_OFFSET", "CATEGORY": "CATEGORY", "REM_NEEDED": "REM_NEEDED", "TIME_END": "TIME_END", "INTERVAL": "INTERVAL"] }

    // MARK: - Diagnostics
    public func debugBundleContents() { if let path = Bundle.main.resourcePath { do { let files = try FileManager.default.contentsOfDirectory(atPath: path); let ml = files.filter { $0.hasSuffix(".mlmodelc") };  ("🔎 Bundle ML files: \(ml.isEmpty ? "None found" : ml.joined(separator: ", "))") } catch {  ("❌ Bundle read error: \(error)") } } }
}

// MARK: - Default alias dictionaries
private func defaultAssignmentAliases() -> [String: String] { ["hw": "homework", "homework": "homework", "test": "exam", "quiz": "quiz", "midterm": "midterm exam", "final": "final exam", "project": "project", "paper": "paper", "lab": "lab report", "assignment": "assignment", "exam": "exam", "assessment": "assessment"] }
private func defaultCourseAliases() -> [String: String] { ["math": "Mathematics", "calc": "Calculus", "cs": "Computer Science", "comp sci": "Computer Science", "chem": "Chemistry", "bio": "Biology", "phys": "Physics", "eng": "English", "hist": "History"] }

// MARK: - String Extension
private extension String {
    func captureRegex(pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = self as NSString
        guard let match = re.firstMatch(in: self, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1...match.numberOfRanges-1).map { ns.substring(with: match.range(at: $0)) }
    }
}
