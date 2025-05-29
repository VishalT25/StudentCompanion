import SwiftUI

struct GPAView: View {
    @State private var courses: [Course] = []
    @State private var showingAddCourseSheet = false

    var body: some View {
        NavigationView {
            List {
                ForEach(courses) { course in
                    NavigationLink(destination: CourseDetailView(course: course)) {
                        CourseWidgetView(course: course)
                    }
                    // Apply listRowInsets to remove default padding if you want the widget to span closer to edges,
                    // or let List handle default row appearance.
                    // .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)) // Example
                }
                .onDelete(perform: deleteCourse)
                // Set listRowBackground to Color.clear if you want custom backgrounds to show fully without List's default row BG
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden) // Hide default separators if widgets are distinct enough
            }
            .listStyle(.plain) // Use .plain list style for less chrome
            .navigationTitle("GPA Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCourseSheet = true
                    } label: {
                        Label("Add Course", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddCourseSheet) {
                // Placeholder for AddCourseView - we'll create this later
                // AddCourseView(courses: $courses)
                AddCourseView(courses: $courses)
            }
            .onAppear(perform: loadCourses)
            .onChange(of: courses) { oldValue, newValue in
                 saveCourses()
            }
        }
    }

    private func deleteCourse(offsets: IndexSet) {
        courses.remove(atOffsets: offsets)
        saveCourses()
    }

    private let coursesUserDefaultsKey = "gpaCourses"

    private func saveCourses() {
        if let encoded = try? JSONEncoder().encode(courses) {
            UserDefaults.standard.set(encoded, forKey: coursesUserDefaultsKey)
        }
    }

    private func loadCourses() {
        if let savedCoursesData = UserDefaults.standard.data(forKey: coursesUserDefaultsKey) {
            if let decodedCourses = try? JSONDecoder().decode([Course].self, from: savedCoursesData) {
                self.courses = decodedCourses
                return
            }
        }
        // If no saved data, or decoding fails, load default sample data (or an empty array)
        self.courses = [
            Course(name: "Calculus I", iconName: "function", colorHex: Color.red.toHex()!),
            Course(name: "Intro to Physics", iconName: "atom", colorHex: Color.blue.toHex()!),
            Course(name: "Organic Chem", iconName: "testtube.2", colorHex: Color.green.toHex()!)
        ]
    }
}

struct CourseWidgetView: View {
    let course: Course
    
    // Determine foreground color based on the course's background color
    private var foregroundColor: Color {
        course.color.isDark ? .white : .black
    }

    var body: some View {
        HStack(spacing: 12) { // Main container for left and right content
            // Left side: Icon and Course Name
            HStack(spacing: 10) {
                Image(systemName: course.iconName)
                    .font(.title2) // Adjusted for horizontal layout
                    .foregroundColor(foregroundColor)
                    .frame(width: 30, alignment: .center) // Consistent icon width

                Text(course.name)
                    .font(.headline)
                    .foregroundColor(foregroundColor)
                    .lineLimit(2) // Allow name to wrap if long
            }

            Spacer() // Pushes the grade to the right

            // Right side: Course Grade (Placeholder for now)
            // We'll integrate the actual calculation in a later step
            Text("Grade") // Placeholder text
                .font(.headline.bold())
                .foregroundColor(foregroundColor)
        }
        .padding() // Generous padding inside the widget
        .frame(maxWidth: .infinity) // Ensure it fills the width of the list row
        .frame(minHeight: 80) // Adjusted minimum height for a horizontal layout
        .background(
            LinearGradient(
                // Adjusted gradient direction for a horizontal widget
                gradient: Gradient(colors: [course.color.lighter(by: 0.2), course.color]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12) // Standard corner radius
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

    // func darker(by percentage: CGFloat = 0.2) -> Color {
    //     return self.adjust(by: -1 * abs(percentage))
    // }

    private func adjust(by percentage: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) {
            return Color(UIColor(red: min(r + percentage, 1.0),
                               green: min(g + percentage, 1.0),
                               blue: min(b + percentage, 1.0),
                               alpha: a))
        } else {
            return self // Return self if deconstruction fails
        }
    }
}

#Preview {
    GPAView()
}
