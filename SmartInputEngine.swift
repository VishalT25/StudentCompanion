import CoreML
import NaturalLanguage
import Foundation

class SmartInputEngine {
    
    // MARK: - ML Models
    
    // Replace your current model loading with this updated version
    lazy var intentModel: MLModel? = {
        print(" ML MODEL: Attempting to load IntentClassifier...")
        
        // Try both compiled (.mlmodelc) and uncompiled (.mlmodel) versions
        let modelNames = ["IntentClassifier"]
        
        for modelName in modelNames {
            // Try .mlmodelc first (iOS 13+)
            if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
                do {
                    let model = try MLModel(contentsOf: modelURL)
                    print(" ML MODEL: '\(modelName).mlmodelc' loaded successfully")
                    return model
                } catch {
                    print(" ML MODEL: Failed to load '\(modelName).mlmodelc': \(error)")
                }
            }
            
            // Fallback to .mlmodel
            if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
                do {
                    let model = try MLModel(contentsOf: modelURL)
                    print(" ML MODEL: '\(modelName).mlmodel' loaded successfully")
                    return model
                } catch {
                    print(" ML MODEL: Failed to load '\(modelName).mlmodel': \(error)")
                }
            }
        }
        
        print(" ML MODEL: No IntentClassifier model could be loaded")
        return nil
    }()

    
    // Grade entity extraction model
    lazy var gradeEntityModel: MLModel? = {
        print(" ML MODEL: Attempting to load GradeEntityExtractor...")
        
        guard let modelURL = Bundle.main.url(forResource: "GradeEntityExtractor", withExtension: "mlmodelc") else {
            print(" ML MODEL: GradeEntityExtractor.mlmodel not found in bundle")
            return nil
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL)
            print(" ML MODEL: GradeEntityExtractor loaded successfully")
            print(" ML MODEL: Model input description: \(model.modelDescription.inputDescriptionsByName)")
            print(" ML MODEL: Model output description: \(model.modelDescription.outputDescriptionsByName)")
            return model
        } catch {
            print(" ML MODEL: Failed to load GradeEntityExtractor: \(error)")
            return nil
        }
    }()
    
    // Event entity extraction model
    lazy var eventEntityModel: MLModel? = {
        print(" ML MODEL: Attempting to load EventEntityExtractor...")
        
        guard let modelURL = Bundle.main.url(forResource: "EventEntityExtractor", withExtension: "mlmodelc") else {
            print(" ML MODEL: EventEntityExtractor.mlmodel not found in bundle")
            return nil
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL)
            print(" ML MODEL: EventEntityExtractor loaded successfully")
            print(" ML MODEL: Model input description: \(model.modelDescription.inputDescriptionsByName)")
            print(" ML MODEL: Model output description: \(model.modelDescription.outputDescriptionsByName)")
            return model
        } catch {
            print(" ML MODEL: Failed to load EventEntityExtractor: \(error)")
            return nil
        }
    }()
    
    // Schedule entity extraction model
    lazy var scheduleEntityModel: MLModel? = {
        print(" ML MODEL: Attempting to load ScheduleEntityExtractor...")
        
        guard let modelURL = Bundle.main.url(forResource: "ScheduleEntityExtractor", withExtension: "mlmodelc") else {
            print(" ML MODEL: ScheduleEntityExtractor.mlmodel not found in bundle")
            return nil
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL)
            print(" ML MODEL: ScheduleEntityExtractor loaded successfully")
            print(" ML MODEL: Model input description: \(model.modelDescription.inputDescriptionsByName)")
            print(" ML MODEL: Model output description: \(model.modelDescription.outputDescriptionsByName)")
            return model
        } catch {
            print(" ML MODEL: Failed to load ScheduleEntityExtractor: \(error)")
            return nil
        }
    }()
    
    // MARK: - User Data
    
    // The rest of the file remains the same
    private var userCourses: [String] = []
    private var userCoursesLowercase: [String] = []
    private var userCourseObjects: [Course] = []
    var onCourseSelectionNeeded: ((String, String, [Course]) -> Void)?

    // MARK: - Aliases and Mappings
    
    private let dateAliases: [String: String] = [
        // Common abbreviations
        "td": "today",
        "tmrw": "tomorrow",
        "tmr": "tomorrow",
        "tn": "tonight",
        "nw": "next week",
        "tw": "this week",
        
        // Full forms
        "today": "today",
        "tomorrow": "tomorrow",
        "tonight": "tonight",
        "next week": "next week",
        "this week": "this week",
        
        // Days of week
        "monday": "Monday", "mon": "Monday",
        "tuesday": "Tuesday", "tue": "Tuesday", "tues": "Tuesday",
        "wednesday": "Wednesday", "wed": "Wednesday",
        "thursday": "Thursday", "thu": "Thursday", "thurs": "Thursday",
        "friday": "Friday", "fri": "Friday",
        "saturday": "Saturday", "sat": "Saturday",
        "sunday": "Sunday", "sun": "Sunday"
    ]
    
    private let timeAliases: [String: String] = [
        "morning": "9:00 AM",
        "afternoon": "2:00 PM",
        "evening": "6:00 PM",
        "night": "8:00 PM",
        "noon": "12:00 PM",
        "midnight": "12:00 AM"
    ]
    
    private var courseAliases: [String: String] = [
        // Standard subjects
        "math": "Mathematics",
        "calc": "Calculus",
        "cs": "Computer Science",
        "comp sci": "Computer Science",
        "programming": "Computer Science",
        "coding": "Computer Science",
        "chem": "Chemistry",
        "bio": "Biology",
        "phy": "Physics", "physics": "Physics",
        "eng": "English", "english": "English",
        "hist": "History", "history": "History",
        
        // Specific courses
        "orgo": "Organic Chemistry",
        "ochem": "Organic Chemistry",
        "organic": "Organic Chemistry",
        "stats": "Statistics",
        "psych": "Psychology",
        "econ": "Economics",
        "poli sci": "Political Science",
        "anthro": "Anthropology",
        "geo": "Geography",
        "autistic geo": "Autistic Geography"
    ]
    
    private let assignmentAliases: [String: String] = [
        "hw": "homework",
        "test": "exam",
        "quiz": "quiz",
        "midterm": "midterm",
        "final": "final exam",
        "project": "project",
        "paper": "paper",
        "essay": "essay",
        "lab": "lab",
        "assignment": "assignment",
        "exam": "exam"
    ]
    
    // MARK: - Public Methods
    
    private let aliasGenerator = RobustCourseAliasGenerator()

    func updateUserCourses(_ courses: [String]) {
        self.userCourses = courses
        // Generate comprehensive aliases
        let generatedAliases = aliasGenerator.generateCourseAliases(from: courses)
        // Merge with your existing courseAliases
        self.courseAliases = self.courseAliases.merging(generatedAliases) { (_, new) in new }
    }

    func setCourseSelectionCallback(_ callback: @escaping (String, String, [Course]) -> Void) {
        onCourseSelectionNeeded = callback
    }

    func updateUserCoursesWithObjects(_ courses: [Course]) {
        self.userCourseObjects = courses
        self.userCourses = courses.map { $0.name }
        self.userCoursesLowercase = courses.map { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Generate comprehensive aliases using both the old method and new generator
        let courseNames = courses.map { $0.name }
        let generatedAliases = aliasGenerator.generateCourseAliases(from: courseNames)
        let dynamicAliases = generateCourseAliases(from: courseNames)
        
        // Merge all aliases
        self.courseAliases = self.courseAliases
            .merging(generatedAliases) { (_, new) in new }
            .merging(dynamicAliases) { (_, new) in new }
        
        print("✅ Updated user courses with objects: \(courseNames)")
        print("✅ Generated comprehensive aliases: \(courseAliases)")
    }
    
    // MARK: - Main Processing Flow
    
    func process(_ utterance: String) async -> (intent: String, entities: [String: String], confidence: Double) {
        print(" ML ENGINE: ======= Starting Process =======")
        print(" ML ENGINE: Input utterance: '\(utterance)'")
        
        // Normalize input
        let normalizedInput = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        print(" ML ENGINE: Normalized input: '\(normalizedInput)'")
        
        // Handle empty input
        guard !normalizedInput.isEmpty else {
            print(" ML ENGINE: Empty input, returning unknown")
            return ("unknown", [:], 0.0)
        }
        
        // Handle single-word inputs (likely follow-up answers)
        if normalizedInput.split(separator: " ").count == 1 {
            print(" ML ENGINE: Single word input detected")
            let result = processSingleWordInput(normalizedInput)
            return (result.intent, result.entities, 1.0)
        }
        
        // STEP 2: Get intent using IntentClassifier
        let (intent, confidence) = classifyIntentWithConfidence(normalizedInput)
        print(" ML ENGINE: STEP 2: Classified intent: '\(intent)' (confidence: \(confidence))")
        
        // STEP 3: Extract entities based on intent
        var entities: [String: String] = [:]
        
        switch intent {
        case "grade_tracking":
            print(" ML ENGINE: STEP 3a: Extracting grade entities")
            entities = extractGradeEntities(normalizedInput)
            
        case "event_reminder":
            print(" ML ENGINE: STEP 3b: Extracting event entities")
            entities = extractEventEntities(normalizedInput)
            
        case "scheduled_event":
            print(" ML ENGINE: STEP 3c: Extracting schedule entities")
            entities = extractScheduleEntities(normalizedInput)
            
        default:
            print(" ML ENGINE: STEP 3: Unknown intent, trying to infer from content")
            entities = inferEntitiesFromContent(normalizedInput)
        }
        
        print(" ML ENGINE: STEP 4: Raw entities extracted: \(entities)")
        
        // STEP 4: Apply aliases and normalize
        // Existing steps
        entities = applyAliases(to: entities)
        entities = applyUserCourseMatching(to: entities)

        // Safety: make sure COURSE_NAME is populated
        if entities["COURSE_NAME"] == nil, let alias = entities["COURSE_ALIAS"] {
            entities["COURSE_NAME"] = alias.capitalized
        }

        // Then normalize
        if intent == "grade_tracking" {
            if let scoreStr = entities["SCORE_VALUE"]?.trimmingCharacters(in: .whitespaces),
               let score = Double(scoreStr.filter("0123456789.".contains)) {
                entities["SCORE_VALUE"] = String(score)
            }

            if let weightStr = entities["WEIGHT_PERCENT"]?.trimmingCharacters(in: .whitespaces),
               let weight = Double(weightStr.filter("0123456789.".contains)) {
                entities["WEIGHT_PERCENT"] = String(weight)
            }
        }

        print(" ML ENGINE: STEP 6: Normalized numeric entities: \(entities)")
        print(" ML ENGINE: ======= Process Complete =======")

        return (intent, entities, confidence)
    }
    
    // MARK: - Step 2: Intent Classification
    
    private func classifyIntentWithConfidence(_ text: String) -> (intent: String, confidence: Double) {
        print(" ML ENGINE: Starting intent classification...")
        print(" ML ENGINE: Intent model available: \(intentModel != nil)")
        
        guard let model = intentModel else {
            print(" ML ENGINE: Intent model not available, falling back to keyword detection")
            let intent = inferIntentFromKeywords(text)
            return (intent, 0.5) // Low confidence for keyword-based detection
        }
        
        do {
            print(" ML ENGINE: Creating ML input for text: '\(text)'")
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": text])
            print(" ML ENGINE: ML input created successfully")
            
            let prediction = try model.prediction(from: input)
            print(" ML ENGINE: ML prediction completed")
            
            // Debug: Print all available feature names
            print(" ML ENGINE: Available prediction features: \(prediction.featureNames)")
            
            var predictedIntent: String? = nil
            var confidence: Double = 0.0
            
            // Try to extract the label
            if let label = prediction.featureValue(for: "label")?.stringValue {
                predictedIntent = label
                print(" ML ENGINE: Found label: '\(label)'")
            } else if let classLabel = prediction.featureValue(for: "classLabel")?.stringValue {
                predictedIntent = classLabel
                print(" ML ENGINE: Found classLabel: '\(classLabel)'")
            }
            
            // Try to extract confidence/probability
            if let labelProbability = prediction.featureValue(for: "labelProbability")?.dictionaryValue {
                print(" ML ENGINE: Label probabilities: \(labelProbability)")
                if let intent = predictedIntent,
                   let prob = labelProbability[intent] as? Double {
                    confidence = prob
                }
            } else if let classProbability = prediction.featureValue(for: "classProbability")?.dictionaryValue {
                print(" ML ENGINE: Class probabilities: \(classProbability)")
                if let intent = predictedIntent,
                   let prob = classProbability[intent] as? Double {
                    confidence = prob
                }
            }
            
            if let intent = predictedIntent {
                print(" ML ENGINE: Intent classification successful: '\(intent)' (confidence: \(confidence))")
                return (intent, confidence)
            } else {
                print(" ML ENGINE: Could not extract label from prediction, falling back to keyword detection")
                let fallbackIntent = inferIntentFromKeywords(text)
                return (fallbackIntent, 0.3)
            }
            
        } catch {
            print(" ML ENGINE: Intent classification error: \(error)")
            print(" ML ENGINE: Error details: \(error.localizedDescription)")
            print(" ML ENGINE: Falling back to keyword detection")
            let fallbackIntent = inferIntentFromKeywords(text)
            return (fallbackIntent, 0.2)
        }
    }
    
    private func inferIntentFromKeywords(_ text: String) -> String {
        let lowercaseText = text.lowercased()
        
        // Grade indicators
        if lowercaseText.contains("%") ||
           lowercaseText.contains("got") ||
           lowercaseText.contains("scored") ||
           lowercaseText.contains("grade") ||
           lowercaseText.contains("received") ||
           lowercaseText.contains("exam") ||
           lowercaseText.contains("test") ||
           lowercaseText.contains("quiz") ||
           lowercaseText.contains("homework") ||
           lowercaseText.contains("assignment") {
            return "grade_tracking"
        }
        
        // Scheduled event indicators
        if lowercaseText.contains("every") ||
           lowercaseText.contains("weekly") ||
           lowercaseText.contains("daily") ||
           lowercaseText.contains("class") ||
           lowercaseText.contains("recurring") {
            return "scheduled_event"
        }
        
        // Default to event reminder
        return "event_reminder"
    }
    
    private func classifyIntent(_ text: String) -> String {
        let (intent, _) = classifyIntentWithConfidence(text)
        return intent
    }
    
    // MARK: - Step 3a: Grade Entity Extraction (FIXED for Sequence Output)

    private func extractGradeEntities(_ text: String) -> [String: String] {
        print(" Extracting grade entities from: '\(text)'")
        
        guard let model = gradeEntityModel else {
            print(" Grade entity model not available, using fallback extraction")
            return extractGradeEntitiesFallback(text)
        }
        
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": text])
            let prediction = try model.prediction(from: input)
            
            print(" Prediction completed successfully")
            print(" Prediction feature names: \(prediction.featureNames)")
            
            var entities: [String: String] = [:]
            
            // Check if this is a sequence-based Word Tagger model
            if prediction.featureNames.contains("tokens") && prediction.featureNames.contains("labels") {
                // Handle Word Tagger sequence output
                entities = parseWordTaggerOutput(prediction)
                print(" Grade entities extracted from Word Tagger: \(entities)")
            } else {
                // Handle other model types (string/double outputs)
                for feature in prediction.featureNames {
                    if let value = prediction.featureValue(for: feature) {
                        switch value.type {
                        case .string:
                            let stringValue = value.stringValue
                            if !stringValue.isEmpty && stringValue != "O" {
                                entities[feature] = stringValue
                            }
                        case .double:
                            entities[feature] = String(value.doubleValue)
                        case .int64:
                            entities[feature] = String(value.int64Value)
                        default:
                            break
                        }
                    }
                }
                print(" Grade entities extracted from ML model: \(entities)")
            }
            
            // Always run fallback extraction as well and merge results
            let fallbackEntities = extractGradeEntitiesFallback(text)
            print(" Grade entities from fallback: \(fallbackEntities)")
            
            // Merge entities (ML takes priority, fallback fills gaps)
            for (key, fallbackValue) in fallbackEntities {
                if let existing = entities[key], !existing.isEmpty {
                    // Special override rules for known weak ML fields
                    if key == "SCORE_VALUE", Int(fallbackValue) != nil {
                        entities[key] = fallbackValue
                    }
                    else if key == "WEIGHT_PERCENT", fallbackValue.contains("%") {
                        entities[key] = fallbackValue
                    }
                } else {
                    entities[key] = fallbackValue
                }
            }
            
            if let rawScoreStr = entities["SCORE_VALUE"] as? String,
               let maxScoreStr = entities["MAX_SCORE"] as? String,
               let rawScore = Double(rawScoreStr),
               let maxScore = Double(maxScoreStr),
               maxScore > 0 {
                
                let percentage = (rawScore / maxScore) * 100
                print("✅ Converted \(rawScore)/\(maxScore) to \(percentage)%")
                entities["SCORE_VALUE"] = String(format: "%.2f", percentage)
            }
            
            print(" Final merged grade entities: \(entities)")
            if let score = entities["SCORE_VALUE"],
               let weight = entities["WEIGHT_PERCENT"],
               weight.lowercased() == "percent",
               Double(score) != nil {

                // Move the score into WEIGHT_PERCENT, remove the accidental SCORE_VALUE
                entities["WEIGHT_PERCENT"] = score
                entities.removeValue(forKey: "SCORE_VALUE")
                print(" Fixed follow-up: moved SCORE_VALUE '\(score)' to WEIGHT_PERCENT")
            }
            return entities
            
        } catch {
            print(" Grade entity extraction error: \(error), using fallback")
            return extractGradeEntitiesFallback(text)
        }
    }

    // MARK: - Step 3b: Event Entity Extraction (FIXED)

    private func extractEventEntities(_ text: String) -> [String: String] {
        print(" Extracting event entities from: '\(text)'")
        
        guard let model = eventEntityModel else {
            print(" Event entity model not available, using fallback extraction")
            return extractEventEntitiesFallback(text)
        }
        
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": text])
            let prediction = try model.prediction(from: input)
            
            var entities: [String: String] = [:]
            
            // Check if this is a sequence-based Word Tagger model
            if prediction.featureNames.contains("tokens") && prediction.featureNames.contains("labels") {
                entities = parseWordTaggerOutput(prediction)
                print(" Event entities extracted from Word Tagger: \(entities)")
            } else {
                // Handle other model types
                for feature in prediction.featureNames {
                    if let value = prediction.featureValue(for: feature) {
                        switch value.type {
                        case .string:
                            let stringValue = value.stringValue
                            if !stringValue.isEmpty && stringValue != "O" {
                                entities[feature] = stringValue
                            }
                        case .double:
                            entities[feature] = String(value.doubleValue)
                        case .int64:
                            entities[feature] = String(value.int64Value)
                        default:
                            break
                        }
                    }
                }
                print(" Event entities extracted from ML model: \(entities)")
            }
            
            // Merge with fallback
            let fallbackEntities = extractEventEntitiesFallback(text)
            for (key, value) in fallbackEntities {
                if entities[key] == nil || entities[key]?.isEmpty == true {
                    entities[key] = value
                }
            }
            
            print(" Final merged event entities: \(entities)")
            return entities
            
        } catch {
            print(" Event entity extraction error: \(error), using fallback")
            return extractEventEntitiesFallback(text)
        }
    }

    // MARK: - Step 3c: Schedule Entity Extraction (FIXED)

    private func extractScheduleEntities(_ text: String) -> [String: String] {
        print(" Extracting schedule entities from: '\(text)'")
        
        guard let model = scheduleEntityModel else {
            print(" Schedule entity model not available, using fallback extraction")
            return extractScheduleEntitiesFallback(text)
        }
        
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": text])
            let prediction = try model.prediction(from: input)
            
            var entities: [String: String] = [:]
            
            // Check if this is a sequence-based Word Tagger model
            if prediction.featureNames.contains("tokens") && prediction.featureNames.contains("labels") {
                entities = parseWordTaggerOutput(prediction)
                print(" Schedule entities extracted from Word Tagger: \(entities)")
            } else {
                // Handle other model types
                for feature in prediction.featureNames {
                    if let value = prediction.featureValue(for: feature) {
                        switch value.type {
                        case .string:
                            let stringValue = value.stringValue
                            if !stringValue.isEmpty && stringValue != "O" {
                                entities[feature] = stringValue
                            }
                        case .double:
                            entities[feature] = String(value.doubleValue)
                        case .int64:
                            entities[feature] = String(value.int64Value)
                        default:
                            break
                        }
                    }
                }
                print(" Schedule entities extracted from ML model: \(entities)")
            }
            
            // Merge with fallback
            let fallbackEntities = extractScheduleEntitiesFallback(text)
            for (key, value) in fallbackEntities {
                if entities[key] == nil || entities[key]?.isEmpty == true {
                    entities[key] = value
                }
            }
            
            print(" Final merged schedule entities: \(entities)")
            return entities
            
        } catch {
            print(" Schedule entity extraction error: \(error), using fallback")
            return extractScheduleEntitiesFallback(text)
        }
    }


    
    private func extractGradeEntitiesFallback(_ text: String) -> [String: String] {
        var entities: [String: String] = [:]
        
        print(" Fallback grade extraction from: '\(text)'")
        
        // Extract grade/score (most specific patterns first)
        if let scoreMatch = extractScore(from: text) {
            entities["SCORE_VALUE"] = scoreMatch
            print(" Found score: '\(scoreMatch)'")
        }
        
        // Extract course (with improved matching)
        if let courseMatch = extractCourse(from: text) {
            entities["COURSE_NAME"] = courseMatch
            print(" Found course: '\(courseMatch)'")
        }
        
        // Extract assignment (look for multiple keywords)
        if let assignmentMatch = extractAssignment(from: text) {
            entities["ASSIGNMENT"] = assignmentMatch
            print(" Found assignment: '\(assignmentMatch)'")
        }
        
        // Extract weight
        if let weightMatch = extractWeight(from: text) {
            entities["WEIGHT_PERCENT"] = weightMatch
            print(" Found weight: '\(weightMatch)'")
        }
        
        print(" Grade entities extracted (fallback): \(entities)")
        return entities
    }
    
    
    private func extractEventEntitiesFallback(_ text: String) -> [String: String] {
        var entities: [String: String] = [:]
        
        // Extract event name
        if let eventMatch = extractEventName(from: text) {
            entities["EVENT"] = eventMatch
        }
        
        // Extract date
        if let dateMatch = extractDate(from: text) {
            if isAbsoluteDate(dateMatch) {
                entities["DATE_ABS"] = dateMatch
            } else {
                entities["DATE_REL"] = dateMatch
            }
        }
        
        // Extract time
        if let timeMatch = extractTime(from: text) {
            entities["TIME"] = timeMatch
        }
        
        print(" Event entities extracted (fallback): \(entities)")
        return entities
    }
    
    private func extractScheduleEntitiesFallback(_ text: String) -> [String: String] {
        var entities: [String: String] = [:]
        
        // Extract event name
        if let eventMatch = extractEventName(from: text) {
            entities["EVENT"] = eventMatch
        }
        
        // Extract days of week
        if let daysMatch = extractDaysOfWeek(from: text) {
            entities["DAY_OF_WEEK"] = daysMatch
        }
        
        // Extract time
        if let timeMatch = extractTime(from: text) {
            entities["TIME"] = timeMatch
        }
        
        // Extract duration
        if let durationMatch = extractDuration(from: text) {
            entities["REL_DURATION"] = durationMatch
        }
        
        print(" Schedule entities extracted (fallback): \(entities)")
        return entities
    }
    
    // MARK: - Fallback Entity Extraction Helpers
    
    private func extractScore(from text: String) -> String? {
        print(" Extracting score from: '\(text)'")
        let lower = text.lowercased()
        // 1. Look for patterns like '44.5%' or '44%' earlier in the sentence
        let percentPattern = #"(\d{1,3}(?:\.\d+)?)\s*%"#
        let percentRegex = try! NSRegularExpression(pattern: percentPattern)
        let matches = percentRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var mainScore: String?
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let candidate = String(text[range])
                // Exclude "X percent" that follows "worth" or "weight" (likely a weight)
                let prefix = lower[..<range.lowerBound]
                if !prefix.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("worth") {
                    mainScore = candidate
                    break
                }
            }
        }
        // 2. If you found a percentage before "worth", that's your main score
        if let mainScore { return mainScore }
        // 3. Next, try patterns like '44.5 percent'
        let wordPercentPattern = #"(\d{1,3}(?:\.\d+)?)\s+percent\b"#
        let wordPercentRegex = try! NSRegularExpression(pattern: wordPercentPattern)
        let wpmatches = wordPercentRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in wpmatches {
            if let range = Range(match.range(at: 1), in: text) {
                let candidate = String(text[range])
                let prefix = lower[..<range.lowerBound]
                if !prefix.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("worth") {
                    mainScore = candidate
                    break
                }
            }
        }
        if let mainScore { return mainScore }
        // 4. Fallback: fractions ('44/50')
        let fractionPattern = #"(\d+(?:\.\d+)?)/(\d+)"#
        let fractionRegex = try! NSRegularExpression(pattern: fractionPattern)
        if let match = fractionRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let numRange = Range(match.range(at: 1), in: text),
            let denRange = Range(match.range(at: 2), in: text),
            let denom = Double(text[denRange]), denom > 0,
            let num = Double(text[numRange]) {
            return String(format: "%.2f", (num / denom) * 100)
        }
        return nil
    }
    
    private func extractCourse(from text: String) -> String? {
        let words = text.split(separator: " ").map(String.init)
        
        print(" COURSE EXTRACTION: ======= Starting Course Extraction =======")
        print(" COURSE EXTRACTION: Input text: '\(text)'")
        print(" COURSE EXTRACTION: Words: \(words)")
        print(" COURSE EXTRACTION: Available user courses: \(userCourses)")
        print(" COURSE EXTRACTION: Course aliases available: \(Array(courseAliases.keys))")
        
        // PRIORITY 1: Check for a direct match of a user's course in the text
        for course in userCourses {
            if text.lowercased().contains(course.lowercased()) {
                print(" COURSE EXTRACTION: Found user course via direct text match: '\(course)'")
                return course
            }
        }
        print(" COURSE EXTRACTION: No direct user course matches found")
        
        // PRIORITY 2: Check for course aliases and find the best matching user course
        for word in words {
            let lowercasedWord = word.lowercased()
            print(" COURSE EXTRACTION: Checking word '\(lowercasedWord)' against aliases...")
            
            if let alias = courseAliases[lowercasedWord] {
                print(" COURSE EXTRACTION: Found course alias: '\(lowercasedWord)' → '\(alias)'")
                
                // Now find the best matching user course for this alias
                if let matchedUserCourse = findMatchingUserCourse(alias) {
                    print(" COURSE EXTRACTION: Mapped alias '\(alias)' to user course: '\(matchedUserCourse)'")
                    return matchedUserCourse
                } else {
                    print(" COURSE EXTRACTION: Could not find user course match for alias '\(alias)'")
                    print(" COURSE EXTRACTION: Available user courses: \(userCourses)")
                    print(" COURSE EXTRACTION: Searching for partial matches...")
                    
                    // Try partial matching for the alias
                    for userCourse in userCourses {
                        if userCourse.lowercased().contains(alias.lowercased()) ||
                           alias.lowercased().contains(userCourse.lowercased()) {
                            print(" COURSE EXTRACTION: Found partial match: '\(alias)' ↔ '\(userCourse)'")
                            return userCourse
                        }
                    }
                }
            } else {
                print(" COURSE EXTRACTION: No alias found for word '\(lowercasedWord)'")
            }
        }
        print(" COURSE EXTRACTION: No alias matches found")
        
        // PRIORITY 3: Fallback to checking individual words against user courses
        for word in words {
            print(" COURSE EXTRACTION: Checking word '\(word)' against user courses...")
            if let matchedCourse = findMatchingUserCourse(word) {
                print(" COURSE EXTRACTION: Found user course match for word '\(word)': '\(matchedCourse)'")
                return matchedCourse
            }
        }
        print(" COURSE EXTRACTION: No word-based matches found")
        
        // PRIORITY 4: Check for course codes (e.g., CS101, MATH201)
        let codeRegex = try! NSRegularExpression(pattern: "\\b[A-Z]{2,4}\\d{3,4}\\b")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = codeRegex.firstMatch(in: text, options: [], range: range) {
            if let codeRange = Range(match.range, in: text) {
                let courseCode = String(text[codeRange])
                print(" COURSE EXTRACTION: Found course code: '\(courseCode)'")
                
                // Try to match course code to user courses
                if let matchedCourse = findMatchingUserCourse(courseCode.lowercased()) {
                    print(" COURSE EXTRACTION: Matched course code to user course: '\(courseCode)' → '\(matchedCourse)'")
                    return matchedCourse
                }
                
                print(" COURSE EXTRACTION: Returning course code as-is: '\(courseCode)'")
                return courseCode
            }
        }
        
        print(" COURSE EXTRACTION: No course found in text")
        print(" COURSE EXTRACTION: ======= Course Extraction Complete =======")
        return nil
    }
    
    private func extractAssignment(from text: String) -> String? {
        print(" Extracting assignment from: '\(text)'")

        // 1. Extract assignment type
        let words = text.split(separator: " ").map { $0.lowercased() }
        for word in words {
            let cleanWord = word.lowercased().replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
            if let assignment = assignmentAliases[cleanWord] {
                print(" Found assignment type: '\(word)' → '\(assignment)'")
                return assignment
            }
        }
        
        // Extract compound assignment names (e.g., "midterm exam", "final test")
        let assignmentKeywords = Array(assignmentAliases.keys)
        for i in 0..<(words.count - 1) {
            let compound = "\(words[i].lowercased()) \(words[i+1].lowercased())"
            let cleanCompound = compound.replacingOccurrences(of: "[^a-z ]", with: "", options: .regularExpression)
            
            for keyword in assignmentKeywords {
                if cleanCompound.contains(keyword) {
                    if let assignment = assignmentAliases[keyword] {
                        print(" Found compound assignment: '\(compound)' → '\(assignment)'")
                        return assignment
                    }
                }
            }
        }
        
        print(" No assignment type found")
        return nil
    }
    
    private func extractWeight(from text: String) -> String? {
        // Look for weight patterns like "worth 25%", "25% of grade"
        let weightRegex = try! NSRegularExpression(pattern: "(?:worth|of grade|weight)\\s+(\\d+(?:\\.\\d+)?)%?")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = weightRegex.firstMatch(in: text, options: [], range: range) {
            if let weightRange = Range(match.range(at: 1), in: text) {
                return String(text[weightRange])
            }
        }
        
        return nil
    }
    
    private func extractEventName(from text: String) -> String? {
        // Simple extraction - remove common prefixes and suffixes
        let cleanedText = text
            .replacingOccurrences(of: "remind me to", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "i have", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "meeting", with: "meeting")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract the core event name
        let words = cleanedText.split(separator: " ")
        if words.count >= 2 {
            return String(words.prefix(2).joined(separator: " "))
        } else if words.count == 1 {
            return String(words[0])
        }
        
        return nil
    }
    
    private func extractDate(from text: String) -> String? {
        let words = text.split(separator: " ").map { $0.lowercased() }
        
        // Check for date aliases
        for word in words {
            if dateAliases[word] != nil {
                return word
            }
        }
        
        return nil
    }
    
    private func extractTime(from text: String) -> String? {
        // Look for time patterns
        let timeRegex = try! NSRegularExpression(pattern: "\\b(\\d{1,2}):?(\\d{2})\\s*(am|pm|AM|PM)\\b")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = timeRegex.firstMatch(in: text, options: [], range: range) {
            if let timeRange = Range(match.range, in: text) {
                return String(text[timeRange])
            }
        }
        
        // Check for time aliases
        let words = text.split(separator: " ").map { $0.lowercased() }
        for word in words {
            if let time = timeAliases[word] {
                return time
            }
        }
        
        return nil
    }
    
    private func extractDaysOfWeek(from text: String) -> String? {
        let words = text.split(separator: " ").map { $0.lowercased() }
        var days: [String] = []
        
        for word in words {
            if let day = dateAliases[word],
               ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].contains(day) {
                days.append(day)
            }
        }
        
        return days.joined(separator: ",")
    }
    
    private func extractDuration(from text: String) -> String? {
        // Look for duration patterns
        let durationRegex = try! NSRegularExpression(pattern: "(?:for|duration)\\s+(\\d+)\\s*(hour|hours|hr|hrs|minute|minutes|min|mins)")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = durationRegex.firstMatch(in: text, options: [], range: range) {
            if let durationRange = Range(match.range, in: text) {
                return String(text[durationRange])
            }
        }
        
        return nil
    }
    
    private func isAbsoluteDate(_ date: String) -> Bool {
        // Check if it's an absolute date (contains numbers or specific date formats)
        return date.contains("/") || date.contains("-") || date.rangeOfCharacter(from: .decimalDigits) != nil
    }
    
    // MARK: - Single Word Processing
    
    private func processSingleWordInput(_ word: String) -> (intent: String, entities: [String: String], confidence: Double) {
        print(" Processing single word input: '\(word)'")
        
        var entities: [String: String] = [:]
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // PRIORITY 1: Check user courses first
        if let matchedCourse = findMatchingUserCourse(normalizedWord) {
            entities["COURSE_NAME"] = matchedCourse
            print(" Single word matched user course: '\(word)' → '\(matchedCourse)'")
            return ("grade_tracking", entities, 1.0)
        }
        
        // PRIORITY 2: Check course aliases
        if let course = courseAliases[normalizedWord] {
            entities["COURSE_NAME"] = course
            print(" Single word identified as course: '\(word)' → '\(course)'")
            return ("grade_tracking", entities, 1.0)
        }
        
        // PRIORITY 3: Check assignment aliases
        if let assignment = assignmentAliases[normalizedWord] {
            entities["ASSIGNMENT"] = assignment
            print(" Single word identified as assignment: '\(word)' → '\(assignment)'")
            return ("grade_tracking", entities, 1.0)
        }
        
        // PRIORITY 4: Check date aliases
        if let date = dateAliases[normalizedWord] {
            if ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].contains(date) {
                entities["DAY_OF_WEEK"] = date
                return ("scheduled_event", entities, 1.0)
            } else {
                entities["DATE_REL"] = date
                return ("event_reminder", entities, 1.0)
            }
        }
        
        // PRIORITY 5: Check time aliases
        if let time = timeAliases[normalizedWord] {
            entities["TIME"] = time
            return ("event_reminder", entities, 1.0)
        }
        
        // PRIORITY 6: Check if it's a time pattern
        if word.contains(":") || normalizedWord.contains("am") || normalizedWord.contains("pm") {
            entities["TIME"] = word
            return ("event_reminder", entities, 1.0)
        }
        
        // PRIORITY 7: Check if it's a percentage/score
        if word.contains("%") || word.allSatisfy({ $0.isNumber || $0 == "." }) {
            entities["SCORE_VALUE"] = word
            return ("grade_tracking", entities, 1.0)
        }
        
        // Default: treat as event name
        entities["EVENT"] = word
        print(" Single word treated as event: '\(word)'")
        return ("event_reminder", entities, 1.0)
    }
    
    // MARK: - Step 4: Apply Aliases and Normalization
    
    private func applyAliases(to entities: [String: String]) -> [String: String] {
        var updated = entities
        
        // Apply date aliases
        for (key, value) in entities {
            if ["DATE_ABS", "DATE_REL", "DAY_OF_WEEK"].contains(key),
               let alias = dateAliases[value.lowercased()] {
                updated[key] = alias
                print(" Date alias applied: '\(value)' → '\(alias)'")
            }
        }
        
        // Apply time aliases
        if let time = entities["TIME"],
           let alias = timeAliases[time.lowercased()] {
            updated["TIME"] = alias
            print(" Time alias applied: '\(time)' → '\(alias)'")
        }
        
        // Apply course aliases
        for key in ["COURSE_NAME", "COURSE_CODE", "COURSE_ALIAS"] {
            if let course = entities[key],
               let alias = courseAliases[course.lowercased()] {
                updated["COURSE_NAME"] = alias
                print(" Course alias applied: '\(course)' → '\(alias)'")
                break
            }
        }
        
        // Apply assignment aliases
        if let assignment = entities["ASSIGNMENT"],
           let alias = assignmentAliases[assignment.lowercased()] {
            updated["ASSIGNMENT"] = alias
            print(" Assignment alias applied: '\(assignment)' → '\(alias)'")
        }
        
        return updated
    }
    
    private func applyUserCourseMatching(to entities: [String: String]) -> [String: String] {
        var updated = entities
        
        // Check if we have a course entity to match
        for key in ["COURSE_NAME", "COURSE_CODE", "COURSE_ALIAS"] {
            if let extractedCourse = entities[key] {
                if let matchedCourse = findMatchingUserCourse(extractedCourse) {
                    updated["COURSE_NAME"] = matchedCourse
                    print(" User course matched: '\(extractedCourse)' → '\(matchedCourse)'")
                    return updated
                } else {
                    // FIXED: Don't remove course entity when popup is triggered
                    // Let the popup handle the course selection, keep the original value
                    print(" No course match found for '\(extractedCourse)', keeping original value for popup")
                    // Keep the original course name so popup can use it
                    updated["COURSE_NAME"] = extractedCourse
                    return updated
                }
            }
        }
        
        return updated
    }
    
    private func findMatchingUserCourse(_ input: String) -> String? {
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 Finding match for '\(normalizedInput)' among courses: \(userCourses)")

        // 1. ✅ First, check if input is a known alias
        if let canonicalCourse = courseAliases[normalizedInput] {
            print("✅ Alias found: '\(normalizedInput)' → '\(canonicalCourse)'")

            // First check for exact match
            if let exact = userCourses.first(where: { $0.caseInsensitiveCompare(canonicalCourse) == .orderedSame }) {
                print("✅ Alias matched exactly to user course: '\(exact)'")
                return exact
            }

            // Then try fuzzy matching if no exact match
            if let fuzzyMatch = findBestCourseMatch(for: canonicalCourse.lowercased()) {
                print("🟡 Fuzzy matched alias to: '\(fuzzyMatch)'")
                return fuzzyMatch
            }
        }

        // 2. 🔍 If not an alias, check for exact match against course list
        if let exactMatchIndex = userCoursesLowercase.firstIndex(of: normalizedInput) {
            print("✅ Exact match found: \(userCourses[exactMatchIndex])")
            return userCourses[exactMatchIndex]
        }

        // 3. 🤖 Fuzzy match against course names
        if let fuzzyMatch = findBestCourseMatch(for: normalizedInput) {
            print("🟡 Fuzzy match result: '\(fuzzyMatch)'")
            return fuzzyMatch
        }

        print("❌ No suitable course match for input: '\(input)' - triggering course selection popup")
        
        // Trigger the popup if we have user courses and a callback
        if !userCourseObjects.isEmpty, let callback = onCourseSelectionNeeded {
            callback(input, normalizedInput, userCourseObjects)
            // Return nil instead of a special token to avoid displaying "POPUP_TRIGGERED"
            return nil
        }
        
        print("❌ No suitable course match for input: '\(input)'")
        return nil
    }
    
    private func findBestCourseMatch(for input: String) -> String? {
        let normalizedInput = input.lowercased()

        var bestMatch: (course: String, score: Int) = ("", 0)

        for (index, course) in userCoursesLowercase.enumerated() {
            let score = calculateSimilarityScore(normalizedInput, course)
            print("Similarity score for '\(normalizedInput)' vs '\(userCourses[index])': \(score)")

            if score > bestMatch.score {
                bestMatch = (userCourses[index], score)
            }
        }

        if bestMatch.score > 50 {
            print("✅ Best fuzzy match found: '\(bestMatch.course)' (score: \(bestMatch.score))")
            return bestMatch.course
        }

        print("❌ No suitable match found for '\(input)'")
        return nil
    }
  
    
    // Enhanced similarity scoring
    private func calculateSimilarityScore(_ input: String, _ course: String) -> Int {
        let inputLower = input.lowercased()
        let courseLower = course.lowercased()
        
        print(" Calculating similarity: '\(inputLower)' vs '\(courseLower)'")
        
        // Exact match
        if inputLower == courseLower {
            print(" Exact match: 100")
            return 100
        }
        
        // Input is contained in course name
        if courseLower.contains(inputLower) {
            let ratio = Double(inputLower.count) / Double(courseLower.count)
            let score = Int(90 * ratio)
            print(" Input contained in course: \(score)")
            return score
        }
        
        // Course name is contained in input
        if inputLower.contains(courseLower) {
            let ratio = Double(courseLower.count) / Double(inputLower.count)
            let score = Int(85 * ratio)
            print(" Course contained in input: \(score)")
            return score
        }
        
        // Word-based matching - check if input words are in course
        let inputWords = inputLower.split(separator: " ").map(String.init)
        let courseWords = courseLower.split(separator: " ").map(String.init)
        
        var matchingWords = 0
        var totalWords = max(inputWords.count, courseWords.count)
        if totalWords == 0 { return 0 }
        
        for inputWord in inputWords {
            for courseWord in courseWords {
                if courseWord.contains(inputWord) || inputWord.contains(courseWord) ||
                   levenshteinDistance(inputWord, courseWord) <= 2 {
                    matchingWords += 1
                    print(" Word match: '\(inputWord)' matches '\(courseWord)'")
                    break
                }
            }
        }
        
        if matchingWords > 0 {
            let ratio = Double(matchingWords) / Double(totalWords)
            let score = Int(80 * ratio)
            print(" Word-based match: \(score) (matched \(matchingWords) of \(totalWords) words)")
            return score
        }
        
        // Character overlap with better scoring
        let inputChars = Set(inputLower)
        let courseChars = Set(courseLower)
        let commonChars = inputChars.intersection(courseChars)
        
        if !commonChars.isEmpty {
            let ratio = Double(commonChars.count) / Double(max(inputChars.count, courseChars.count))
            let score = Int(60 * ratio)
            print(" Character overlap: \(score)")
            return score
        }
        
        print(" No similarity found: 0")
        return 0
    }
    
    // NEW: Levenshtein distance for fuzzy string matching
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
    
    private func generateCourseAliases(from courses: [String]) -> [String: String] {
        var aliases = [String: String]()

        for course in courses {
            let normalized = course.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let words = normalized.split(separator: " ").map(String.init)

            // Add full lowercase version
            aliases[normalized] = course

            // Remove common filler words
            let filteredWords = words.filter { !["to", "of", "the", "and", "a", "an"].contains($0) }

            // Add each filtered word as alias
            for word in filteredWords {
                aliases[word] = course
            }

            // Add abbreviation (first letter of each word)
            let abbreviation = filteredWords.map { String($0.prefix(1)) }.joined()
            if abbreviation.count >= 2 {
                aliases[abbreviation] = course
            }

            // Add compressed forms
            let joined = filteredWords.joined()
            aliases[joined] = course

            // Add last word (e.g. "Intro to Physics" → "physics")
            if let last = filteredWords.last {
                aliases[last] = course
            }
        }

        return aliases
    }

    
    // MARK: - Utility Methods
    
    private func inferEntitiesFromContent(_ text: String) -> [String: String] {
        var entities: [String: String] = [:]
        
        // Try to extract common entities regardless of intent
        if let course = extractCourse(from: text) {
            entities["COURSE_NAME"] = course
        }
        
        if let score = extractScore(from: text) {
            entities["SCORE_VALUE"] = score
        }
        
        if let assignment = extractAssignment(from: text) {
            entities["ASSIGNMENT"] = assignment
        }
        
        if let event = extractEventName(from: text) {
            entities["EVENT"] = event
        }
        
        if let time = extractTime(from: text) {
            entities["TIME"] = time
        }
        
        if let date = extractDate(from: text) {
            entities["DATE_REL"] = date
        }
        
        return entities
    }
    
    // MARK: - Follow-up Question Methods
    
    func getRequiredFields(for intent: String) -> [String] {
        switch intent {
        case "grade_tracking":
            return ["COURSE_NAME", "ASSIGNMENT", "SCORE_VALUE", "WEIGHT_PERCENT"]
        case "scheduled_event":
            return ["EVENT", "DAY_OF_WEEK", "TIME"]
        case "event_reminder":
            return ["EVENT", "TIME"]
        default:
            return []
        }
    }
    
    func getMissingFields(for intent: String, from entities: [String: String]) -> [String] {
        let required = getRequiredFields(for: intent)
        print(" MISSING FIELDS: Required fields for '\(intent)': \(required)")
        print(" MISSING FIELDS: Available entities: \(entities)")
        
        let missing = required.filter { field in
            let isMissing: Bool
            switch field {
            case "COURSE_NAME":
                isMissing = entities["COURSE_NAME"] == nil && entities["COURSE_CODE"] == nil && entities["COURSE_ALIAS"] == nil
            case "TIME":
                isMissing = entities["TIME"] == nil || entities["TIME"]?.isEmpty == true
            case "EVENT":
                isMissing = entities["EVENT"] == nil || entities["EVENT"]?.isEmpty == true
            case "WEIGHT_PERCENT":
                isMissing = entities["WEIGHT_PERCENT"] == nil && entities["WEIGHT"] == nil
            default:
                isMissing = entities[field] == nil || entities[field]?.isEmpty == true
            }
            
            if isMissing {
                print(" MISSING FIELDS: Field '\(field)' is missing")
            } else {
                print(" MISSING FIELDS: Field '\(field)' is present")
            }
            
            return isMissing
        }
        
        print(" MISSING FIELDS: Missing fields: \(missing)")
        return missing
    }
    
    func generateFollowUpQuestion(for field: String, intent: String) -> String {
        switch (intent, field) {
        // Grade tracking questions
        case ("grade_tracking", "COURSE_NAME"):
            return "What course is this grade for?"
        case ("grade_tracking", "ASSIGNMENT"):
            return "What's the assignment (exam, quiz, homework, etc.)?"
        case ("grade_tracking", "SCORE_VALUE"):
            return "What score did you get?"
        case ("grade_tracking", "WEIGHT_PERCENT"):
            return "What percentage is this assignment worth?"
            
        // Event reminder questions
        case ("event_reminder", "EVENT"):
            return "What's the event?"
        case ("event_reminder", "TIME"):
            return "What time?"
        case ("event_reminder", "DATE_REL"):
            return "When? (today, tomorrow, Monday, etc.)"
            
        // Scheduled event questions
        case ("scheduled_event", "EVENT"):
            return "What's the recurring activity?"
        case ("scheduled_event", "DAY_OF_WEEK"):
            return "Which days? (Monday, Tuesday, etc.)"
        case ("scheduled_event", "TIME"):
            return "What time does it start?"
        case ("scheduled_event", "REL_DURATION"):
            return "How long does it last?"
            
        default:
            return "Can you provide more details about \(field.lowercased().replacingOccurrences(of: "_", with: " "))?"
        }
    }
    
    func debugBundleContents() {
        print(" BUNDLE DEBUG: Starting bundle contents check...")
        
        guard let bundlePath = Bundle.main.resourcePath else {
            print(" BUNDLE DEBUG: Could not get bundle resource path")
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            print(" BUNDLE DEBUG: Bundle contents:")
            
            let mlFiles = contents.filter {
                $0.hasSuffix(".mlmodel") || $0.hasSuffix(".mlmodelc")
            }
            
            if mlFiles.isEmpty {
                print(" BUNDLE DEBUG: No ML model files found in bundle!")
                print(" BUNDLE DEBUG: All files in bundle: \(contents)")
            } else {
                print(" BUNDLE DEBUG: Found ML files: \(mlFiles)")
            }
            
        } catch {
            print(" BUNDLE DEBUG: Error reading bundle contents: \(error)")
        }
    }
    
    private func parseMultiArrayOutput(_ multiArray: MLMultiArray, for text: String) -> [String: String] {
        var entities: [String: String] = [:]
        
        // This is for models that output BIO tag indices
        let tokens = text.split(separator: " ").map(String.init)
        
        guard multiArray.count >= tokens.count else {
            print(" MultiArray count \(multiArray.count) < tokens count \(tokens.count)")
            return entities
        }
        
        // Create tag index to label mapping (adjust based on your model)
        let tagLabels = [
            0: "O",
            1: "B-COURSE",
            2: "I-COURSE",
            3: "B-ASSIGNMENT",
            4: "I-ASSIGNMENT",
            5: "B-SCORE_VALUE",
            6: "I-SCORE_VALUE",
            7: "B-WEIGHT_PERCENT",
            8: "I-WEIGHT_PERCENT"
        ]
        
        for i in 0..<min(tokens.count, multiArray.count) {
            let tagIndex = multiArray[i].intValue
            if let tag = tagLabels[tagIndex], tag != "O" {
                let entityType = tag.replacingOccurrences(of: "B-", with: "").replacingOccurrences(of: "I-", with: "")
                
                if let existing = entities[entityType] {
                    entities[entityType] = "\(existing) \(tokens[i])"
                } else {
                    entities[entityType] = tokens[i]
                }
                
                print(" Token '\(tokens[i])' tagged as '\(tag)' -> entity type '\(entityType)'")
            }
        }
        
        return entities
    }
    
    private func strings(from fv: MLFeatureValue) -> [String] {
        switch fv.type {
        case .sequence:
            guard let seq = fv.sequenceValue else { return [] }
            if !seq.stringValues.isEmpty {
                return seq.stringValues
            }
            if !seq.int64Values.isEmpty {
                return seq.int64Values.map { "\($0.int64Value)" }
            }
        case .multiArray:
            guard let array = fv.multiArrayValue else { return [] }
            let pointer = UnsafeMutablePointer<Double>(OpaquePointer(array.dataPointer))
            let buffer = UnsafeBufferPointer(start: pointer, count: array.count)
            return buffer.map { "\($0)" }
        default:
            break
        }
        return []
    }
  
    
    private func parseWordTaggerOutput(_ provider: MLFeatureProvider) -> [String:String] {

        guard
            let tokensFv = provider.featureValue(for: "tokens"),
            let labelsFv = provider.featureValue(for: "labels")
        else {
            print(" prediction lacks tokens / labels"); return [:]
        }

        let tokens = strings(from: tokensFv)
        let labels = strings(from: labelsFv)

        guard tokens.count == labels.count, !tokens.isEmpty else {
            print(" size mismatch tokens(\(tokens.count)) vs labels(\(labels.count))"); return [:]
        }

        var entities: [String:String] = [:]
        var currentType : String? = nil
        var currentBuf  : [String] = []

        for (tok, lab) in zip(tokens, labels) {

            switch lab {
            case "O":
                if let t = currentType, !currentBuf.isEmpty {
                    entities[t] = currentBuf.joined(separator: " ")
                }
                currentType = nil; currentBuf.removeAll()

            case _ where lab.hasPrefix("B-"):
                if let t = currentType, !currentBuf.isEmpty {
                    entities[t] = currentBuf.joined(separator: " ")
                }
                currentType = String(lab.dropFirst(2))
                currentBuf  = [tok]

            case _ where lab.hasPrefix("I-"):
                let t = String(lab.dropFirst(2))
                if currentType == t {
                    currentBuf.append(tok)
                } else {                        // broken BIO sequence, start anew
                    if let prev = currentType, !currentBuf.isEmpty {
                        entities[prev] = currentBuf.joined(separator: " ")
                    }
                    currentType = t
                    currentBuf  = [tok]
                }

            default:
                break
            }
        }

        if let t = currentType, !currentBuf.isEmpty {
            entities[t] = currentBuf.joined(separator: " ")
        }

        print(" parsed entities: \(entities)")
        return entities
    }
    
    private func ints(from feature: MLFeatureValue) -> [Int] {
        guard
            feature.type == .multiArray,
            let array = feature.multiArrayValue
        else { return [] }

        return (0..<array.count).map { array[$0].intValue }
    }

}
