import SwiftUI

struct GPAView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var courses: [Course] = [] // Array of Course class instances
    @State private var showingAddCourseSheet = false
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("lastGradeUpdate") private var lastGradeUpdate: Double = 0

    var body: some View {
        List {
            ForEach(courses) { course in // Iterate directly over class instances
                NavigationLink(destination: CourseDetailView(course: course)) { // Pass the course instance
                    CourseWidgetView(course: course, showGrade: showCurrentGPA, usePercentage: usePercentageGrades)
                }
            }
            .onDelete(perform: deleteCourse)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCourseSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .font(.title2)
                }
            }
        })
        .sheet(isPresented: $showingAddCourseSheet) {
            AddCourseView(courses: $courses)
                .environmentObject(themeManager)
        }
        .onAppear {
            loadCourses()
        }
        .onDisappear {
            // Removed notification observer removal
        }
        .refreshable {
            loadCourses()
        }
        // This onChange will now primarily handle add/delete of courses
        // or if the entire course array is replaced.
        // It won't automatically detect deep changes within Course objects themselves.
        .onChange(of: courses) { oldValue, newValue in
             saveCourses()
        }
    }

    private func deleteCourse(offsets: IndexSet) {
        courses.remove(atOffsets: offsets)
        // saveCourses() will be called by onChange
    }

    private let coursesUserDefaultsKey = "gpaCourses"

    private func saveCourses() {
        if let encoded = try? JSONEncoder().encode(courses) {
            UserDefaults.standard.set(encoded, forKey: coursesUserDefaultsKey)
            lastGradeUpdate = Date().timeIntervalSince1970
        }
    }

    private func loadCourses() {
        if let savedCoursesData = UserDefaults.standard.data(forKey: coursesUserDefaultsKey) {
            if let decodedCourses = try? JSONDecoder().decode([Course].self, from: savedCoursesData) {
                self.courses = decodedCourses
                return
            }
        }
        let defaultCourses: [Course] = [ // Create instances of the Course class
            Course(name: "Calculus I", iconName: "function", colorHex: "FF0000"),
            Course(name: "Intro to Physics", iconName: "atom", colorHex: "0000FF"),
            Course(name: "Organic Chem", iconName: "testtube.2", colorHex: "00FF00")
        ]
        self.courses = defaultCourses
        // saveCourses() // Save defaults if loaded for the first time
    }
}

struct CourseWidgetView: View {
    @ObservedObject var course: Course
    let showGrade: Bool
    let usePercentage: Bool
    
    // Determine foreground color based on the course's background color
    private var foregroundColor: Color {
        course.color.isDark ? .white : .black
    }
    
    private var currentGrade: String {
        if !showGrade {
            return ""
        }
        
        let grade = calculateCurrentGrade()
        if grade == "N/A" {
            return "N/A"
        }
        
        if usePercentage {
            return "\(grade)%"
        } else {
            // Convert percentage to GPA (simple 4.0 scale)
            if let gradeValue = Double(grade) {
                let gpa = (gradeValue / 100.0) * 4.0
                return String(format: "%.2f", gpa)
            }
            return "N/A"
        }
    }
    
    private func calculateCurrentGrade() -> String {
        var totalWeightedGrade = 0.0
        var totalWeight = 0.0
        
        // Access assignments through the ObservedObject
        for assignment in course.assignments {
            if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                totalWeightedGrade += grade * weight
                totalWeight += weight
            }
        }
        
        if totalWeight == 0 {
            return "N/A"
        }
        
        let currentGradeVal = totalWeightedGrade / totalWeight
        return String(format: "%.1f", currentGradeVal)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left side: Icon and Course Name
            HStack(spacing: 10) {
                Image(systemName: course.iconName) // Access properties from ObservedObject
                    .font(.title2)
                    .foregroundColor(foregroundColor)
                    .frame(width: 30, alignment: .center)

                Text(course.name) // Access properties from ObservedObject
                    .font(.headline)
                    .foregroundColor(foregroundColor)
                    .lineLimit(2)
            }

            Spacer()

            // Right side: Course Grade
            if showGrade && !currentGrade.isEmpty {
                Text(currentGrade)
                    .font(.headline.bold())
                    .foregroundColor(foregroundColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 80)
        .background(
            LinearGradient(
                // Access course.color from ObservedObject
                gradient: Gradient(colors: [course.color.lighter(by: 0.2), course.color]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
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

#Preview {
    GPAView()
        .environmentObject(ThemeManager())
}
