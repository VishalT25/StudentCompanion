import SwiftUI

struct Assignment: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var grade: String = "" // Store as String for TextField binding
    var weight: String = "" // Store as String for TextField binding

    // Helper computed properties for calculations
    var gradeValue: Double? {
        Double(grade)
    }
    var weightValue: Double? {
        Double(weight)
    }
}
