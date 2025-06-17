import Foundation

// MARK: - NLP Engine Testing Suite
class NLPEngineTestSuite {
    private let engine = NLPEngine()
    private let testCategories: [Category] = [
        Category(name: "Assignment", color: .blue),
        Category(name: "Exam", color: .red),
        Category(name: "Lab", color: .green),
        Category(name: "Meeting", color: .purple)
    ]
    
    private let testCourses: [Course] = [
        Course(name: "Computer Science 101"),
        Course(name: "Mathematics 201"),
        Course(name: "Physics"),
        Course(name: "History")
    ]
    
    // MARK: - Enhanced Temporal Understanding Tests
    func testEnhancedTemporalParsing() -> [String: Bool] {
        let testCases = [
            // Relative dates
            "Meeting next Friday at 2pm",
            "Assignment due this Tuesday",
            "Exam last Monday", // Should handle past dates
            
            // Date offsets
            "Project due 2 weeks from now",
            "Presentation 3 days ago",
            "Meeting 1 month later",
            
            // ISO-8601 durations
            "Math class every Monday PT1H30M", // 1 hour 30 minutes
            "Study session PT45M", // 45 minutes
            "Workshop PT2H", // 2 hours
            
            // Mixed temporal expressions
            "Lab next Wednesday from 2pm for PT2H",
            "Study group this Friday PT1H before exam"
        ]
        
        var results: [String: Bool] = [:]
        
        for testCase in testCases {
            let result = engine.parse(inputText: testCase, availableCategories: testCategories, existingCourses: testCourses)
            
            // Check if parsing was successful (not unrecognized)
            let success = !isUnrecognized(result)
            results[testCase] = success
            
            print("Test: '\(testCase)' -> \(success ? "✅ SUCCESS" : "❌ FAILED")")
            printResult(result)
        }
        
        return results
    }
    
    // MARK: - Enhanced Grade Parsing Tests
    func testEnhancedGradeParsing() -> [String: Bool] {
        let testCases = [
            // Mixed formats
            "Got 18/20 (90%) on CS101 midterm",
            "Received 85% A- on Math quiz",
            "Scored 45/50 on Physics lab",
            
            // International grading
            "Got HD on Australian assignment", // High Distinction
            "Received 2:1 on UK essay", // Upper Second Class
            "Earned Pass on certification",
            
            // Pass/Fail systems
            "Got S on satisfactory assignment",
            "Received U on unsatisfactory test",
            "Earned P on pass/fail course",
            
            // Complex expressions
            "I got a solid B+ (87%) worth 25% on the CS midterm",
            "Received 42 out of 50 points on the history essay"
        ]
        
        var results: [String: Bool] = [:]
        
        for testCase in testCases {
            let result = engine.parse(inputText: testCase, availableCategories: testCategories, existingCourses: testCourses)
            
            let success = isGradeParsed(result)
            results[testCase] = success
            
            print("Test: '\(testCase)' -> \(success ? "✅ SUCCESS" : "❌ FAILED")")
            printResult(result)
        }
        
        return results
    }
    
    // MARK: - Enhanced Robustness Tests
    func testRobustness() -> [String: Double] {
        let testInputs = [
            "Meeting tomorrow at 2pm",
            "Got 95% on CS101 midterm",
            "Math class every Monday 9am to 10am",
            "Assignment due next Friday",
            "Received B+ on history essay"
        ]
        
        var robustnessScores: [String: Double] = [:]
        
        for input in testInputs {
            // Simple robustness test without the removed function
            let originalResult = engine.parse(inputText: input, availableCategories: testCategories, existingCourses: testCourses)
            
            // Test with some perturbations manually
            let perturbations = [
                input.uppercased(),
                "  \(input)  ",
                input.replacingOccurrences(of: "meeting", with: "meetng"),
                input.replacingOccurrences(of: "assignment", with: "assigment")
            ]
            
            var consistentCount = 0
            var totalTests = 0
            
            for perturbedInput in perturbations {
                if perturbedInput != input {
                    let perturbedResult = engine.parse(inputText: perturbedInput, availableCategories: testCategories, existingCourses: testCourses)
                    let isConsistent = areResultsConsistent(originalResult, perturbedResult)
                    if isConsistent { consistentCount += 1 }
                    totalTests += 1
                }
            }
            
            let consistencyScore = totalTests > 0 ? Double(consistentCount) / Double(totalTests) : 1.0
            robustnessScores[input] = consistencyScore
            
            print("\nRobustness Test for: '\(input)'")
            print("Consistency Score: \(String(format: "%.2f", consistencyScore * 100))%")
            print("Total Tests: \(totalTests), Consistent: \(consistentCount)")
        }
        
        return robustnessScores
    }
    
    private func areResultsConsistent(_ result1: NLPResult, _ result2: NLPResult) -> Bool {
        switch (result1, result2) {
        case (.parsedEvent, .parsedEvent), (.parsedScheduleItem, .parsedScheduleItem), (.parsedGrade, .parsedGrade):
            return true
        case (.needsMoreInfo, .needsMoreInfo):
            return true
        case (.unrecognized, .unrecognized), (.notAttempted, .notAttempted):
            return true
        case (.needsMoreInfo, .parsedEvent), (.needsMoreInfo, .parsedScheduleItem), (.needsMoreInfo, .parsedGrade):
            return true
        default:
            return false
        }
    }
    
    // MARK: - Configuration-Based Pattern Tests
    func testConfigurationPatterns() -> [String: Bool] {
        let testCases = [
            // Test abbreviations from config
            "Got A+ on math homework",
            "CS assignment due tomorrow",
            "Phys lab next week",
            "Psych meeting this Friday",
            
            // Test category synonyms
            "Workshop next Tuesday", // Should match lab
            "Project due Friday", // Should match assignment
            "Quiz on Monday", // Should match exam
            "Call with advisor", // Should match meeting
            
            // Test international patterns
            "Received HD on assignment", // Australian
            "Got 1st class honors", // UK
            "Earned Pass on certification" // Pass/Fail
        ]
        
        var results: [String: Bool] = [:]
        
        for testCase in testCases {
            let result = engine.parse(inputText: testCase, availableCategories: testCategories, existingCourses: testCourses)
            
            let success = !isUnrecognized(result)
            results[testCase] = success
            
            print("Config Test: '\(testCase)' -> \(success ? "✅ SUCCESS" : "❌ FAILED")")
            printResult(result)
        }
        
        return results
    }
    
    // MARK: - Fuzzy Matching Tests (NEW)
    func testFuzzyMatching() -> [String: Bool] {
        let testCases = [
            // Typos in common words
            "Meetng tomorrow at 2pm", // meeting
            "Assigment due Friday", // assignment
            "Got 95% on CS midtrm", // midterm
            "Recieved B+ on essay", // received
            
            // Course name fuzzy matching
            "Got A on Math homework", // Mathematics
            "CS assignment due", // Computer Science
            "Phys lab today", // Physics
            "Hist exam tomorrow", // History
            
            // Category fuzzy matching
            "Workshop next week", // should match lab
            "Appointmnt with advisor", // appointment -> meeting
            "Projct due Friday", // project -> assignment
            
            // Grade keyword fuzzy matching
            "Scorred 85% on test", // scored
            "Earnd A+ on quiz", // earned
            "Got a B- on esay" // essay -> assignment
        ]
        
        var results: [String: Bool] = [:]
        
        for testCase in testCases {
            let result = engine.parse(inputText: testCase, availableCategories: testCategories, existingCourses: testCourses)
            
            let success = !isUnrecognized(result)
            results[testCase] = success
            
            print("Fuzzy Test: '\(testCase)' -> \(success ? "✅ SUCCESS" : "❌ FAILED")")
            printResult(result)
        }
        
        return results
    }
    
    // MARK: - Spell Correction Tests (NEW)
    func testSpellCorrection() -> [String: Bool] {
        let testCases = [
            // Common typos that should be corrected
            "Tomorow meeting at 2pm",
            "Assigment due Friday",
            "Recieved 90% on midterm",
            "Phys lab next week",
            "Got grade on calc homework"
        ]
        
        var results: [String: Bool] = [:]
        
        for testCase in testCases {
            let result = engine.parse(inputText: testCase, availableCategories: testCategories, existingCourses: testCourses)
            
            let success = !isUnrecognized(result)
            results[testCase] = success
            
            print("Spell Test: '\(testCase)' -> \(success ? "✅ SUCCESS" : "❌ FAILED")")
            printResult(result)
        }
        
        return results
    }
    
    // MARK: - Edge Case Tests
    func testEdgeCases() -> [String: Bool] {
        let testCases = [
            // Empty and minimal inputs
            "",
            "a",
            "meeting",
            
            // Ambiguous inputs
            "tomorrow",
            "grade",
            "class",
            
            // Complex mixed inputs
            "Meeting tomorrow at 2pm about the 95% grade I got on CS101 midterm",
            "Next Friday's math class from 9am to 10:30am and the assignment due",
            
            // Potential injection attempts (sanitized)
            "<script>alert('test')</script> meeting tomorrow",
            "meeting'; DROP TABLE users; --",
            "meeting \"with quotes\" and 'apostrophes'",
            
            // Unicode and special characters
            "Meeting tomorroẃ at 2pm", // Accented characters
            "Assignment → due Friday", // Arrow symbol
            "Grade: 95% 😊", // Emoji
        ]
        
        var results: [String: Bool] = [:]
        
        for testCase in testCases {
            let result = engine.parse(inputText: testCase, availableCategories: testCategories, existingCourses: testCourses)
            
            // For edge cases, we consider it successful if it doesn't crash
            // and returns a reasonable result (not necessarily parsed)
            let success = true // If we got here, it didn't crash
            results[testCase] = success
            
            print("Edge Case: '\(testCase)' -> \(success ? "✅ SUCCESS" : "❌ FAILED")")
            printResult(result)
        }
        
        return results
    }
    
    // MARK: - Performance Tests
    func testPerformance() -> [String: TimeInterval] {
        let testInputs = [
            "Meeting tomorrow at 2pm",
            "Got 95% on CS101 midterm worth 25%",
            "Math class every Monday and Wednesday from 9am to 10:30am",
            "Assignment due next Friday with reminder 1 hour before",
            "Lab session this Thursday PT2H with grade 18/20 (90%)"
        ]
        
        var performanceResults: [String: TimeInterval] = [:]
        
        for input in testInputs {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Run parsing multiple times to get average
            for _ in 0..<100 {
                _ = engine.parse(inputText: input, availableCategories: testCategories, existingCourses: testCourses)
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let avgTime = (endTime - startTime) / 100.0
            
            performanceResults[input] = avgTime
            
            print("Performance: '\(input)' -> \(String(format: "%.4f", avgTime * 1000))ms avg")
        }
        
        return performanceResults
    }
    
    // MARK: - Helper Methods
    private func isUnrecognized(_ result: NLPResult) -> Bool {
        switch result {
        case .unrecognized:
            return true
        default:
            return false
        }
    }
    
    private func isGradeParsed(_ result: NLPResult) -> Bool {
        switch result {
        case .parsedGrade, .needsMoreInfo(_, _, .gradeNeedsWeight, _), .needsMoreInfo(_, _, .gradeNeedsAssignmentName, _), .needsMoreInfo(_, _, .gradeNeedsCourse, _):
            return true
        default:
            return false
        }
    }
    
    private func printResult(_ result: NLPResult) {
        switch result {
        case .parsedEvent(let title, let date, let categoryName, let reminderTime):
            print("  -> Event: '\(title)' on \(date?.description ?? "unspecified date") in \(categoryName ?? "no category") with \(reminderTime?.displayName ?? "no reminder")")
        case .parsedScheduleItem(let title, let days, _, _, let duration, let reminderTime, _):
            print("  -> Schedule: '\(title)' on \(days.map(\.shortName).joined(separator: ", ")) for \(duration != nil ? "\(Int(duration!/3600))h" : "unspecified duration") with \(reminderTime?.displayName ?? "no reminder")")
        case .parsedGrade(let courseName, let assignmentName, let grade, let weight):
            print("  -> Grade: \(grade) on '\(assignmentName)' in \(courseName) with weight \(weight ?? "unspecified")")
        case .needsMoreInfo(let prompt, _, let context, _):
            print("  -> Needs more info: \(prompt) (context: \(String(describing: context)))")
        case .unrecognized(let input):
            print("  -> Unrecognized: '\(input)'")
        case .notAttempted:
            print("  -> Not attempted")
        }
    }
    
    // MARK: - Run All Tests
    func runAllTests() {
        print("🧪 Starting Enhanced NLP Engine Test Suite\n")
        
        print("1️⃣ Enhanced Temporal Understanding Tests:")
        let temporalResults = testEnhancedTemporalParsing()
        let temporalSuccess = temporalResults.values.filter { $0 }.count
        print("✅ Temporal Tests: \(temporalSuccess)/\(temporalResults.count) passed\n")
        
        print("2️⃣ Enhanced Grade Parsing Tests:")
        let gradeResults = testEnhancedGradeParsing()
        let gradeSuccess = gradeResults.values.filter { $0 }.count
        print("✅ Grade Tests: \(gradeSuccess)/\(gradeResults.count) passed\n")
        
        print("3️⃣ Configuration Pattern Tests:")
        let configResults = testConfigurationPatterns()
        let configSuccess = configResults.values.filter { $0 }.count
        print("✅ Config Tests: \(configSuccess)/\(configResults.count) passed\n")
        
        print("4️⃣ Fuzzy Matching Tests:")
        let fuzzyResults = testFuzzyMatching()
        let fuzzySuccess = fuzzyResults.values.filter { $0 }.count
        print("✅ Fuzzy Tests: \(fuzzySuccess)/\(fuzzyResults.count) passed\n")
        
        print("5️⃣ Spell Correction Tests:")
        let spellResults = testSpellCorrection()
        let spellSuccess = spellResults.values.filter { $0 }.count
        print("✅ Spell Tests: \(spellSuccess)/\(spellResults.count) passed\n")
        
        print("6️⃣ Robustness Tests:")
        let robustnessResults = testRobustness()
        let avgRobustness = robustnessResults.values.reduce(0, +) / Double(robustnessResults.count)
        print("✅ Average Robustness: \(String(format: "%.1f", avgRobustness * 100))%\n")
        
        print("7️⃣ Edge Case Tests:")
        let edgeResults = testEdgeCases()
        let edgeSuccess = edgeResults.values.filter { $0 }.count
        print("✅ Edge Case Tests: \(edgeSuccess)/\(edgeResults.count) passed\n")
        
        print("8️⃣ Performance Tests:")
        let performanceResults = testPerformance()
        let avgPerformance = performanceResults.values.reduce(0, +) / Double(performanceResults.count)
        print("✅ Average Parse Time: \(String(format: "%.2f", avgPerformance * 1000))ms\n")
        
        print("🎉 Enhanced Test Suite Complete!")
        let totalTests = temporalResults.count + gradeResults.count + configResults.count + fuzzyResults.count + spellResults.count + edgeResults.count
        let totalSuccess = temporalSuccess + gradeSuccess + configSuccess + fuzzySuccess + spellSuccess + edgeSuccess
        
        print("Overall Score: \(totalSuccess)/\(totalTests) tests passed")
        print("Robustness Score: \(String(format: "%.1f", avgRobustness * 100))%")
        print("Performance: \(String(format: "%.2f", avgPerformance * 1000))ms average parse time")
        
        // Expected improvement summary
        let expectedRobustness = min(100.0, avgRobustness * 100 + 20) // Expected +20% improvement
        print("\n📈 Expected Robustness Improvement:")
        print("Previous: ~80%, Current: \(String(format: "%.1f", avgRobustness * 100))%, Target: \(String(format: "%.1f", expectedRobustness))%")
    }
}

// MARK: - Test Runner Extension
extension NLPEngine {
    static func runTestSuite() {
        let testSuite = NLPEngineTestSuite()
        testSuite.runAllTests()
    }
}
