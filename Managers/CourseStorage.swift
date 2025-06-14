import Foundation

struct CourseStorage {
    static let key = "gpaCourses"
    
    static func save(_ courses: [Course]) {
        if let data = try? JSONEncoder().encode(courses) {
            UserDefaults.standard.set(data, forKey: key)
            NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastGradeUpdate")
        }
    }
    
    static func load() -> [Course] {
        if let data = UserDefaults.standard.data(forKey: key),
           let courses = try? JSONDecoder().decode([Course].self, from: data) {
            return courses
        }
        return []
    }
}
