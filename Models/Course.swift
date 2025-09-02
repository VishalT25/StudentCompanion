import SwiftUI
import Combine

class Course: Identifiable, ObservableObject, Codable, Equatable {
    @Published var id: UUID
    @Published var scheduleId: UUID // NEW: Required reference to schedule
    @Published var name: String
    @Published var iconName: String
    @Published var colorHex: String
    
    @Published var assignments: [Assignment] {
        didSet {
            oldValue.forEach { assignment in 
                cancellables.filter { $0.hashValue == assignment.id.hashValue }.forEach { $0.cancel() } 
            }
            setupAssignmentsObservation()
            triggerGradeUpdate()
        }
    }
    
    @Published var finalGradeGoal: String {
        didSet {
            triggerGradeUpdate()
        }
    }
    @Published var weightOfRemainingTasks: String {
        didSet {
            triggerGradeUpdate()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    init(id: UUID = UUID(), scheduleId: UUID, name: String = "New Course", iconName: String = "book.closed.fill", colorHex: String = Color.blue.toHex() ?? "007AFF", assignments: [Assignment] = [], finalGradeGoal: String = "", weightOfRemainingTasks: String = "") {
        self.id = id
        self.scheduleId = scheduleId
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        
        // Ensure all assignments have the correct courseId
        self.assignments = assignments.map { assignment in
            var updatedAssignment = assignment
            updatedAssignment.courseId = id
            return updatedAssignment
        }
        
        self.finalGradeGoal = finalGradeGoal
        self.weightOfRemainingTasks = weightOfRemainingTasks
        DispatchQueue.main.async { [weak self] in
            self?.setupAssignmentsObservation()
        }
    }

    private func setupAssignmentsObservation() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        assignments.forEach { assignment in
            assignment.objectWillChange
                .receive(on: DispatchQueue.main) 
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                    self?.debouncedGradeUpdate()
                }
                .store(in: &cancellables)
        }
    }
    
    private func triggerGradeUpdate() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastGradeUpdate")
    }
    
    private func debouncedGradeUpdate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.triggerGradeUpdate()
        }
    }
    
    func refreshObservationsAndSignalChange() {
        setupAssignmentsObservation()
        triggerGradeUpdate()
    }
    
    // NEW: Method to add assignment with proper courseId
    func addAssignment(_ assignment: Assignment) {
        var newAssignment = assignment
        newAssignment.courseId = self.id
        assignments.append(newAssignment)
    }

    enum CodingKeys: String, CodingKey {
        case id, scheduleId, name, iconName, colorHex, assignments, finalGradeGoal, weightOfRemainingTasks
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        scheduleId = try container.decode(UUID.self, forKey: .scheduleId)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        
        // Decode to a temporary, then finish initializing all stored properties
        let decodedAssignments = try container.decode([Assignment].self, forKey: .assignments)
        finalGradeGoal = try container.decode(String.self, forKey: .finalGradeGoal)
        weightOfRemainingTasks = try container.decode(String.self, forKey: .weightOfRemainingTasks)
        
        // Initialize assignments first to complete stored property initialization
        assignments = decodedAssignments
        
        // Now it's safe to use self; update each assignment's courseId without using closures
        for i in assignments.indices {
            assignments[i].courseId = id
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.setupAssignmentsObservation()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(assignments, forKey: .assignments)
        try container.encode(finalGradeGoal, forKey: .finalGradeGoal)
        try container.encode(weightOfRemainingTasks, forKey: .weightOfRemainingTasks)
    }

    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id &&
        lhs.scheduleId == rhs.scheduleId &&
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

// MARK: - Schedule Model
struct Schedule: Identifiable, Codable {
    var id = UUID()
    var name: String
    var semester: String
    var isActive: Bool = false
    var isArchived: Bool = false
    var colorHex: String = Color.blue.toHex() ?? "007AFF"
    var scheduleType: String = "traditional"
    var academicCalendarId: UUID?
    var createdDate: Date = Date()
    var lastModified: Date = Date()
    
    init(name: String, semester: String, isActive: Bool = false) {
        self.name = name
        self.semester = semester
        self.isActive = isActive
    }
    
    var displayName: String {
        if name.isEmpty {
            return semester
        }
        return "\(name) - \(semester)"
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
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
}