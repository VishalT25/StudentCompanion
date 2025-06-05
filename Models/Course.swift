import SwiftUI
import Combine

class Course: Identifiable, ObservableObject, Codable, Equatable {
    @Published var id: UUID
    @Published var name: String
    @Published var iconName: String
    @Published var colorHex: String
    
    @Published var assignments: [Assignment] {
        didSet {
            oldValue.forEach { assignment in // Cancel subscriptions from old assignments if any were replaced
                cancellables.filter { $0.hashValue == assignment.id.hashValue }.forEach { $0.cancel() } // Simplistic way to find; better to store cancellables per assignment if needed
            }
            setupAssignmentsObservation()
        }
    }
    
    @Published var finalGradeGoal: String
    @Published var weightOfRemainingTasks: String

    private var cancellables = Set<AnyCancellable>()

    init(id: UUID = UUID(), name: String = "New Course", iconName: String = "book.closed.fill", colorHex: String = Color.blue.toHex() ?? "007AFF", assignments: [Assignment] = [], finalGradeGoal: String = "", weightOfRemainingTasks: String = "") {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.assignments = assignments // didSet will call setupAssignmentsObservation
        self.finalGradeGoal = finalGradeGoal
        self.weightOfRemainingTasks = weightOfRemainingTasks
        // setupAssignmentsObservation() // Called by didSet of assignments
    }

    private func setupAssignmentsObservation() {
        // Clear existing subscriptions for assignments to avoid duplicates if this is called multiple times
        // A more robust way would be to manage cancellables per assignment if assignments can be individually replaced.
        // For now, clearing all and re-subscribing is simpler if the entire array is often reset.
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        assignments.forEach { assignment in
            assignment.objectWillChange
                .receive(on: DispatchQueue.main) // Ensure sink and send operate on main thread
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
        // If the assignments array itself changes (add/remove), Course already publishes.
        // This explicitly makes Course publish if an *element* of assignments changes.
        // Also, good practice to send objectWillChange if assignments array count changes too.
        // For example, after an append or remove, explicitly call self.objectWillChange.send()
        // if just relying on @Published for the array reference change isn't enough for some views.
        // However, the sink above should cover internal changes to Assignment objects.
    }
    
    // Call this method explicitly after adding or removing an assignment if needed
    // to ensure views observing Course update, beyond what @Published on the array does.
    func refreshObservationsAndSignalChange() {
        setupAssignmentsObservation()
        // Optionally, you can force a signal if just re-observing isn't enough
        // DispatchQueue.main.async {
        //    self.objectWillChange.send()
        // }
    }


    // Codable
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, colorHex, assignments, finalGradeGoal, weightOfRemainingTasks
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        assignments = try container.decode([Assignment].self, forKey: .assignments)
        finalGradeGoal = try container.decode(String.self, forKey: .finalGradeGoal)
        weightOfRemainingTasks = try container.decode(String.self, forKey: .weightOfRemainingTasks)
        setupAssignmentsObservation()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(assignments, forKey: .assignments)
        try container.encode(finalGradeGoal, forKey: .finalGradeGoal)
        try container.encode(weightOfRemainingTasks, forKey: .weightOfRemainingTasks)
    }

    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.iconName == rhs.iconName &&
        lhs.colorHex == rhs.colorHex &&
        lhs.assignments == rhs.assignments &&
        lhs.finalGradeGoal == rhs.finalGradeGoal &&
        lhs.weightOfRemainingTasks == rhs.weightOfRemainingTasks
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// Color extension remains unchanged
extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }

    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r, g, b, a: CGFloat
        let length = hexSanitized.count
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
