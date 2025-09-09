import SwiftUI

class Assignment: Identifiable, ObservableObject, Codable, Equatable {
    @Published var id: UUID
    @Published var courseId: UUID
    @Published var name: String
    @Published var grade: String
    @Published var weight: String
    @Published var notes: String

    // Default initializer
    init(id: UUID = UUID(), courseId: UUID, name: String = "", grade: String = "", weight: String = "", notes: String = "") {
        self.id = id
        self.courseId = courseId
        self.name = name
        self.grade = grade
        self.weight = weight
        self.notes = notes
        
        // Debug logging to track duplicates
        #if DEBUG
        print("🆔 Created Assignment with ID: \(id.uuidString.prefix(8)) - Name: \(name.isEmpty ? "Untitled" : name)")
        #endif
    }

    // Codable
    enum CodingKeys: String, CodingKey {
        case id, courseId, name, grade, weight, notes
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        name = try container.decode(String.self, forKey: .name)
        grade = try container.decode(String.self, forKey: .grade)
        weight = try container.decode(String.self, forKey: .weight)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        
        #if DEBUG
        print("🆔 Decoded Assignment with ID: \(id.uuidString.prefix(8)) - Name: \(name.isEmpty ? "Untitled" : name)")
        #endif
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encode(name, forKey: .name)
        try container.encode(grade, forKey: .grade)
        try container.encode(weight, forKey: .weight)
        try container.encode(notes, forKey: .notes)
    }

    // Equatable - use ONLY id for comparison to prevent duplicate issues
    static func == (lhs: Assignment, rhs: Assignment) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Helper computed properties for calculations
    var gradeValue: Double? {
        Double(grade)
    }
    var weightValue: Double? {
        Double(weight)
    }
    
    // Hash implementation to help with Set operations
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}