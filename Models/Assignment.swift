import SwiftUI

class Assignment: Identifiable, ObservableObject, Codable, Equatable {
    @Published var id: UUID
    @Published var courseId: UUID // NEW: Required reference to course
    @Published var name: String
    @Published var grade: String
    @Published var weight: String

    // Default initializer
    init(id: UUID = UUID(), courseId: UUID, name: String = "", grade: String = "", weight: String = "") {
        self.id = id
        self.courseId = courseId // NEW: Required parameter
        self.name = name
        self.grade = grade
        self.weight = weight
    }

    // Codable
    enum CodingKeys: String, CodingKey {
        case id, courseId, name, grade, weight
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        name = try container.decode(String.self, forKey: .name)
        grade = try container.decode(String.self, forKey: .grade)
        weight = try container.decode(String.self, forKey: .weight)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encode(name, forKey: .name)
        try container.encode(grade, forKey: .grade)
        try container.encode(weight, forKey: .weight)
    }

    // Equatable
    static func == (lhs: Assignment, rhs: Assignment) -> Bool {
        lhs.id == rhs.id &&
        lhs.courseId == rhs.courseId &&
        lhs.name == rhs.name &&
        lhs.grade == rhs.grade &&
        lhs.weight == rhs.weight
    }
    
    // Helper computed properties for calculations
    var gradeValue: Double? {
        Double(grade)
    }
    var weightValue: Double? {
        Double(weight)
    }
}