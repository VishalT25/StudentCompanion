import SwiftUI

class Assignment: Identifiable, ObservableObject, Codable, Equatable {
    @Published var id: UUID
    @Published var name: String
    @Published var grade: String
    @Published var weight: String

    // Default initializer
    init(id: UUID = UUID(), name: String = "", grade: String = "", weight: String = "") {
        self.id = id
        self.name = name
        self.grade = grade
        self.weight = weight
    }

    // Codable
    enum CodingKeys: String, CodingKey {
        case id, name, grade, weight
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        grade = try container.decode(String.self, forKey: .grade)
        weight = try container.decode(String.self, forKey: .weight)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(grade, forKey: .grade)
        try container.encode(weight, forKey: .weight)
    }

    // Equatable
    static func == (lhs: Assignment, rhs: Assignment) -> Bool {
        lhs.id == rhs.id &&
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
