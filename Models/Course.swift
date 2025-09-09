import SwiftUI
import Combine
import Foundation

class Course: Identifiable, ObservableObject, Codable, Equatable {
    @Published var id: UUID
    @Published var scheduleId: UUID // Required reference to schedule
    @Published var name: String
    @Published var iconName: String
    @Published var colorHex: String
    
    // Academic Properties
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

    // NEW: Schedule Properties (unified with ScheduleItem)
    @Published var startTime: Date?
    @Published var endTime: Date?
    @Published var daysOfWeek: [DayOfWeek] = []
    @Published var location: String = ""
    @Published var instructor: String = ""
    @Published var reminderTime: ReminderTime = .none
    @Published var isLiveActivityEnabled: Bool = true
    @Published var skippedInstanceIdentifiers: Set<String> = []
    
    // Academic Analytics
    @Published var creditHours: Double = 3.0
    @Published var courseCode: String = "" // e.g., "CS 101"
    @Published var section: String = ""    // e.g., "Section A"
    
    private var cancellables = Set<AnyCancellable>()

    init(
        id: UUID = UUID(), 
        scheduleId: UUID, 
        name: String = "New Course", 
        iconName: String = "book.closed.fill", 
        colorHex: String = Color.blue.toHex() ?? "007AFF", 
        assignments: [Assignment] = [], 
        finalGradeGoal: String = "", 
        weightOfRemainingTasks: String = "",
        // NEW: Schedule parameters
        startTime: Date? = nil,
        endTime: Date? = nil,
        daysOfWeek: [DayOfWeek] = [],
        location: String = "",
        instructor: String = "",
        creditHours: Double = 3.0,
        courseCode: String = "",
        section: String = ""
    ) {
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
        
        // NEW: Schedule properties
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.location = location
        self.instructor = instructor
        self.creditHours = creditHours
        self.courseCode = courseCode
        self.section = section
        
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
    
    func addAssignment(_ assignment: Assignment) {
        var newAssignment = assignment
        newAssignment.courseId = self.id
        
        // Prevent duplicates by checking ID
        if !assignments.contains(where: { $0.id == newAssignment.id }) {
            assignments.append(newAssignment)
            #if DEBUG
            print("✅ Added assignment \(newAssignment.name) to course \(self.name)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ Attempted to add duplicate assignment with ID: \(newAssignment.id.uuidString.prefix(8))")
            #endif
        }
    }
    
    func removeAssignment(withId id: UUID) {
        assignments.removeAll { $0.id == id }
        #if DEBUG
        print("🗑️ Removed assignment with ID: \(id.uuidString.prefix(8)) from course \(self.name)")
        #endif
    }

    enum CodingKeys: String, CodingKey {
        case id, scheduleId, name, iconName, colorHex, assignments, finalGradeGoal, weightOfRemainingTasks
        case startTime, endTime, daysOfWeek, location, instructor, reminderTime, isLiveActivityEnabled
        case skippedInstanceIdentifiers, creditHours, courseCode, section
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        scheduleId = try container.decode(UUID.self, forKey: .scheduleId)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        
        let decodedAssignments = try container.decode([Assignment].self, forKey: .assignments)
        finalGradeGoal = try container.decode(String.self, forKey: .finalGradeGoal)
        weightOfRemainingTasks = try container.decode(String.self, forKey: .weightOfRemainingTasks)
        
        // NEW: Schedule properties with backward compatibility
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        daysOfWeek = try container.decodeIfPresent([DayOfWeek].self, forKey: .daysOfWeek) ?? []
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        instructor = try container.decodeIfPresent(String.self, forKey: .instructor) ?? ""
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
        isLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveActivityEnabled) ?? true
        skippedInstanceIdentifiers = Set(try container.decodeIfPresent([String].self, forKey: .skippedInstanceIdentifiers) ?? [])
        creditHours = try container.decodeIfPresent(Double.self, forKey: .creditHours) ?? 3.0
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode) ?? ""
        section = try container.decodeIfPresent(String.self, forKey: .section) ?? ""
        
        assignments = decodedAssignments
        
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
        
        // NEW: Schedule properties
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(daysOfWeek, forKey: .daysOfWeek)
        try container.encode(location, forKey: .location)
        try container.encode(instructor, forKey: .instructor)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(isLiveActivityEnabled, forKey: .isLiveActivityEnabled)
        try container.encode(Array(skippedInstanceIdentifiers), forKey: .skippedInstanceIdentifiers)
        try container.encode(creditHours, forKey: .creditHours)
        try container.encode(courseCode, forKey: .courseCode)
        try container.encode(section, forKey: .section)
    }

    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id &&
        lhs.scheduleId == rhs.scheduleId &&
        lhs.name == rhs.name &&
        lhs.iconName == rhs.iconName &&
        lhs.colorHex == rhs.colorHex &&
        lhs.assignments == rhs.assignments &&
        lhs.finalGradeGoal == rhs.finalGradeGoal &&
        lhs.weightOfRemainingTasks == rhs.weightOfRemainingTasks &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.daysOfWeek == rhs.daysOfWeek &&
        lhs.location == rhs.location &&
        lhs.instructor == rhs.instructor
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    // MARK: - Schedule Integration Methods
    
    var hasScheduleInfo: Bool {
        return startTime != nil && endTime != nil && !daysOfWeek.isEmpty
    }
    
    var isScheduledToday: Bool {
        guard hasScheduleInfo else { return false }
        let today = DayOfWeek.from(weekday: Calendar.current.component(.weekday, from: Date()))
        return daysOfWeek.contains(today) && !isSkippedToday
    }
    
    var isSkippedToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let identifier = Course.instanceIdentifier(for: id, onDate: today)
        return skippedInstanceIdentifiers.contains(identifier)
    }
    
    var timeRange: String {
        guard let start = startTime, let end = endTime else { return "Time TBD" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    var duration: String {
        guard let start = startTime, let end = endTime else { return "" }
        let components = Calendar.current.dateComponents([.hour, .minute], from: start, to: end)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var weeklyHours: Double {
        guard let start = startTime, let end = endTime else { return 0.0 }
        let duration = end.timeIntervalSince(start) / 3600.0
        return duration * Double(daysOfWeek.count)
    }
    
    var daysString: String {
        if daysOfWeek.isEmpty { return "No days scheduled" }
        return daysOfWeek.sorted { $0.rawValue < $1.rawValue }
                          .map { $0.short }
                          .joined(separator: ", ")
    }
    
    // Convert to ScheduleItem for backward compatibility
    func toScheduleItem() -> ScheduleItem {
        return ScheduleItem(
            id: self.id, // Use the same ID to maintain the link
            title: name,
            startTime: startTime ?? Date(),
            endTime: endTime ?? Date().addingTimeInterval(3600),
            daysOfWeek: daysOfWeek,
            location: location,
            instructor: instructor,
            color: color,
            skippedInstanceIdentifiers: skippedInstanceIdentifiers,
            isLiveActivityEnabled: isLiveActivityEnabled,
            reminderTime: reminderTime
        )
    }
    
    // Create from ScheduleItem
    static func from(scheduleItem: ScheduleItem, scheduleId: UUID) -> Course {
        let course = Course(
            id: scheduleItem.id, // Use the same ID to maintain the link
            scheduleId: scheduleId,
            name: scheduleItem.title,
            iconName: "book.closed.fill",
            colorHex: scheduleItem.color.toHex() ?? Color.blue.toHex()!,
            assignments: [], // New course starts with no assignments
            finalGradeGoal: "",
            weightOfRemainingTasks: "",
            startTime: scheduleItem.startTime,
            endTime: scheduleItem.endTime,
            daysOfWeek: scheduleItem.daysOfWeek,
            location: scheduleItem.location,
            instructor: scheduleItem.instructor
        )
        
        // Set additional schedule properties that aren't in the main initializer
        course.skippedInstanceIdentifiers = scheduleItem.skippedInstanceIdentifiers
        course.isLiveActivityEnabled = scheduleItem.isLiveActivityEnabled
        course.reminderTime = scheduleItem.reminderTime
        
        return course
    }
    
    func isSkipped(onDate date: Date) -> Bool {
        let identifier = Course.instanceIdentifier(for: id, onDate: date)
        return skippedInstanceIdentifiers.contains(identifier)
    }
    
    static func instanceIdentifier(for id: UUID, onDate date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(id.uuidString)_\(year)-\(month)-\(day)"
    }
    
    // MARK: - Grade Analytics
    
    func calculateCurrentGrade() -> Double? {
        var totalWeightedGrade = 0.0
        var totalWeight = 0.0
        
        for assignment in assignments {
            if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                totalWeightedGrade += grade * weight
                totalWeight += weight
            }
        }
        
        guard totalWeight > 0 else { return nil }
        return totalWeightedGrade / totalWeight
    }
    
    var currentGradeString: String {
        guard let grade = calculateCurrentGrade() else { return "N/A" }
        return String(format: "%.1f", grade)
    }
    
    var letterGrade: String {
        guard let grade = calculateCurrentGrade() else { return "N/A" }
        
        switch grade {
        case 97...100: return "A+"
        case 93..<97: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 65..<67: return "D"
        case 60..<65: return "D-"
        default: return "F"
        }
    }
    
    var gradeColor: Color {
        guard let grade = calculateCurrentGrade() else { return .gray }
        
        switch grade {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }
    
    // Calculate GPA points for this course
    var gpaPoints: Double? {
        guard let grade = calculateCurrentGrade() else { return nil }
        
        switch grade {
        case 97...100: return 4.0  // A+
        case 93..<97: return 4.0   // A
        case 90..<93: return 3.7   // A-
        case 87..<90: return 3.3   // B+
        case 83..<87: return 3.0   // B
        case 80..<83: return 2.7   // B-
        case 77..<80: return 2.3   // C+
        case 73..<77: return 2.0   // C
        case 70..<73: return 1.7   // C-
        case 67..<70: return 1.3   // D+
        case 65..<67: return 1.0   // D
        case 60..<65: return 0.7   // D-
        default: return 0.0        // F
        }
    }
    
    var fullDisplayName: String {
        var components: [String] = []
        
        if !courseCode.isEmpty {
            components.append(courseCode)
        }
        
        components.append(name)
        
        if !section.isEmpty {
            components.append("(\(section))")
        }
        
        return components.joined(separator: " ")
    }
}

// MARK: - Schedule Model Extensions for unified system
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
    var isDark: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.5
    }

    func lighter(by percentage: CGFloat = 0.2) -> Color {
        return self.adjust(by: abs(percentage))
    }

    private func adjust(by percentage: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) {
            return Color(UIColor(red: min(r + percentage, 1.0),
                               green: min(g + percentage, 1.0),
                               blue: min(b + percentage, 1.0),
                               alpha: a))
        } else {
            return self
        }
    }
}