import SwiftUI
import Combine
import Foundation

// MARK: - Supporting Types (Simplified)
struct CourseTimeSlot: Codable, Equatable {
    let start: Date
    let end: Date
    
    init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

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

    // SIMPLIFIED: Traditional Schedule Properties Only
    @Published var startTime: Date?
    @Published var endTime: Date?
    @Published var daysOfWeek: [DayOfWeek] = [] // Monday through Friday
    @Published var location: String = ""
    @Published var instructor: String = ""
    @Published var reminderTime: ReminderTime = .none
    @Published var isLiveActivityEnabled: Bool = true
    @Published var skippedInstanceIdentifiers: Set<String> = []
    
    @Published var isRotating: Bool = false
    @Published var day1StartTime: Date?
    @Published var day1EndTime: Date?
    @Published var day2StartTime: Date?
    @Published var day2EndTime: Date?
    
    // Academic Analytics
    @Published var creditHours: Double = 3.0
    @Published var courseCode: String = "" // e.g., "CS 101"
    @Published var section: String = ""    // e.g., "Section A"
    
    // DEPRECATED: Keep for backward compatibility but don't use
    @Published var meetings: [CourseMeeting] = []
    
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
        // Schedule parameters
        startTime: Date? = nil,
        endTime: Date? = nil,
        daysOfWeek: [DayOfWeek] = [],
        location: String = "",
        instructor: String = "",
        creditHours: Double = 3.0,
        courseCode: String = "",
        section: String = "",
        isRotating: Bool = false,
        day1StartTime: Date? = nil,
        day1EndTime: Date? = nil,
        day2StartTime: Date? = nil,
        day2EndTime: Date? = nil
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
        
        // Schedule properties
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.location = location
        self.instructor = instructor
        self.creditHours = creditHours
        self.courseCode = courseCode
        self.section = section
        
        self.isRotating = isRotating
        self.day1StartTime = day1StartTime
        self.day1EndTime = day1EndTime
        self.day2StartTime = day2StartTime
        self.day2EndTime = day2EndTime
        
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
        case meetings // Keep for backward compatibility
        case isRotating, day1StartTime, day1EndTime, day2StartTime, day2EndTime
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
        
        // Schedule properties with backward compatibility
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
        
        isRotating = try container.decodeIfPresent(Bool.self, forKey: .isRotating) ?? false
        day1StartTime = try container.decodeIfPresent(Date.self, forKey: .day1StartTime)
        day1EndTime = try container.decodeIfPresent(Date.self, forKey: .day1EndTime)
        day2StartTime = try container.decodeIfPresent(Date.self, forKey: .day2StartTime)
        day2EndTime = try container.decodeIfPresent(Date.self, forKey: .day2EndTime)
        
        // Backward compatibility - try to load meetings but don't require them
        meetings = try container.decodeIfPresent([CourseMeeting].self, forKey: .meetings) ?? []
        
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
        
        // Schedule properties
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
        
        try container.encode(isRotating, forKey: .isRotating)
        try container.encodeIfPresent(day1StartTime, forKey: .day1StartTime)
        try container.encodeIfPresent(day1EndTime, forKey: .day1EndTime)
        try container.encodeIfPresent(day2StartTime, forKey: .day2StartTime)
        try container.encodeIfPresent(day2EndTime, forKey: .day2EndTime)
        
        // Backward compatibility
        try container.encode(meetings, forKey: .meetings)
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
    
    // MARK: - Simplified Schedule Logic (Traditional Only)
    
    var hasScheduleInfo: Bool {
        if isRotating {
            let participatesDay1 = (day1StartTime != nil && day1EndTime != nil)
            let participatesDay2 = (day2StartTime != nil && day2EndTime != nil)
            return participatesDay1 || participatesDay2
        }
        return startTime != nil && endTime != nil && !daysOfWeek.isEmpty
    }
    
    func shouldAppear(on date: Date, in schedule: ScheduleCollection, calendar: AcademicCalendar?) -> Bool {
        if isSkipped(onDate: date) {
            return false
        }
        
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return false
        }
        
        if let start = schedule.semesterStartDate, let end = schedule.semesterEndDate {
            let day = cal.startOfDay(for: date)
            let s = cal.startOfDay(for: start)
            let e = cal.startOfDay(for: end)
            if day < s || day > e {
                return false
            }
        }
        
        if let calendar {
            if !calendar.isDateWithinSemester(date) { return false }
            if calendar.isBreakDay(date) { return false }
        }
        
        if isRotating {
            let day = cal.component(.day, from: date)
            let isDay1 = day % 2 == 1
            if isDay1 {
                return day1StartTime != nil && day1EndTime != nil
            } else {
                return day2StartTime != nil && day2EndTime != nil
            }
        } else {
            let dayOfWeek = DayOfWeek.from(weekday: weekday)
            return daysOfWeek.contains(dayOfWeek)
        }
    }
    
    func toScheduleItem(for date: Date, in schedule: ScheduleCollection, calendar: AcademicCalendar?) -> ScheduleItem? {
        guard shouldAppear(on: date, in: schedule, calendar: calendar) else { return nil }
        
        if isRotating {
            let cal = Calendar.current
            let day = cal.component(.day, from: date)
            let isDay1 = day % 2 == 1
            let s = isDay1 ? day1StartTime : day2StartTime
            let e = isDay1 ? day1EndTime : day2EndTime
            guard let start = s, let end = e else { return nil }
            
            return ScheduleItem(
                id: self.id,
                title: name,
                startTime: start,
                endTime: end,
                daysOfWeek: [],
                location: location,
                instructor: instructor,
                color: color,
                skippedInstanceIdentifiers: skippedInstanceIdentifiers,
                isLiveActivityEnabled: isLiveActivityEnabled,
                reminderTime: reminderTime
            )
        } else {
            guard let start = startTime, let end = endTime else { return nil }
            return ScheduleItem(
                id: self.id,
                title: name,
                startTime: start,
                endTime: end,
                daysOfWeek: daysOfWeek,
                location: location,
                instructor: instructor,
                color: color,
                skippedInstanceIdentifiers: skippedInstanceIdentifiers,
                isLiveActivityEnabled: isLiveActivityEnabled,
                reminderTime: reminderTime
            )
        }
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    var isScheduledToday: Bool {
        let today = Date()
        let dayOfWeek = DayOfWeek.from(weekday: Calendar.current.component(.weekday, from: today))
        return daysOfWeek.contains(dayOfWeek) && !isSkippedToday
    }
    
    var isSkippedToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let identifier = Course.instanceIdentifier(for: id, onDate: today)
        return skippedInstanceIdentifiers.contains(identifier)
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
    
    // MARK: - Grade Analytics (Unchanged)
    
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

// MARK: - Extensions and Supporting Types (unchanged)
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

// MARK: - Legacy Support
struct Schedule: Identifiable, Codable {
    var id = UUID()
    var name: String
    var semester: String
    var isActive: Bool = false
    var isArchived: Bool = false
    var colorHex: String = Color.blue.toHex() ?? "007AFF"
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

extension Course {
    static func from(scheduleItem: ScheduleItem, scheduleId: UUID) -> Course {
        let colorHex = scheduleItem.color.toHex() ?? "007AFF"
        let course = Course(
            id: scheduleItem.id,
            scheduleId: scheduleId,
            name: scheduleItem.title,
            iconName: "book.closed.fill",
            colorHex: colorHex,
            assignments: [],
            finalGradeGoal: "",
            weightOfRemainingTasks: "",
            startTime: scheduleItem.startTime,
            endTime: scheduleItem.endTime,
            daysOfWeek: scheduleItem.daysOfWeek,
            location: scheduleItem.location,
            instructor: scheduleItem.instructor,
            creditHours: 3.0,
            courseCode: "",
            section: ""
        )
        course.skippedInstanceIdentifiers = scheduleItem.skippedInstanceIdentifiers
        course.reminderTime = scheduleItem.reminderTime
        course.isLiveActivityEnabled = scheduleItem.isLiveActivityEnabled
        return course
    }
    
    func toScheduleItem() -> ScheduleItem {
        let calendar = Calendar.current
        func defaultTimes() -> (Date, Date) {
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 9
            components.minute = 0
            let start = calendar.date(from: components) ?? Date()
            let end = calendar.date(byAdding: .minute, value: 60, to: start) ?? start.addingTimeInterval(3600)
            return (start, end)
        }
        
        let s = startTime ?? defaultTimes().0
        let e = endTime ?? calendar.date(byAdding: .minute, value: 60, to: s) ?? s.addingTimeInterval(3600)
        
        return ScheduleItem(
            id: self.id,
            title: self.name,
            startTime: s,
            endTime: e,
            daysOfWeek: self.daysOfWeek,
            location: self.location,
            instructor: self.instructor,
            color: self.color,
            skippedInstanceIdentifiers: self.skippedInstanceIdentifiers,
            isLiveActivityEnabled: self.isLiveActivityEnabled,
            reminderTime: self.reminderTime
        )
    }
}

// MARK: - Date Extension for Time Setting
extension Date {
    func setting(hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }
}