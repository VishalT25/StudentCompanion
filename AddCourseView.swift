import SwiftUI

struct AddCourseView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var courses: [Course] // To add the new course to the main list

    @State private var courseName: String = ""
    @State private var selectedIconName: String = "book.closed.fill" // Default icon
    @State private var selectedColor: Color = .blue // Default color

    // A sample list of SF Symbols for the icon picker
    // You can expand this list or use a more dynamic way to get symbols if needed
    let sfSymbolNames: [String] = [
        "book.closed.fill", "studentdesk", "laptopcomputer", "function",
        "atom", "testtube.2", "flame.fill", "brain.head.profile",
        "paintbrush.fill", "music.mic", "sportscourt.fill", "globe.americas.fill",
        "hammer.fill", "briefcase.fill", "creditcard.fill", "figure.walk"
    ]
    
    let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown, .gray
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Course Details")) {
                    TextField("Course Name", text: $courseName)
                }

                Section(header: Text("Icon")) {
                    // A simple way to pick an icon using a Picker
                    Picker("Select Icon", selection: $selectedIconName) {
                        ForEach(sfSymbolNames, id: \.self) { symbolName in
                            Image(systemName: symbolName).tag(symbolName)
                        }
                    }
                    // Display the selected icon
                    Image(systemName: selectedIconName)
                        .font(.title)
                        .foregroundColor(selectedColor)
                        .padding(.vertical)
                }

                Section(header: Text("Color")) {
                    ColorPicker("Select Course Color", selection: $selectedColor, supportsOpacity: false)
                    
                    // Optional: Predefined colors for quick selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(predefinedColors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                                    .padding(.horizontal, 2)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Add New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCourse()
                        dismiss()
                    }
                    .disabled(courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveCourse() {
        guard !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newCourse = Course(
            name: courseName,
            iconName: selectedIconName,
            colorHex: selectedColor.toHex() ?? Color.blue.toHex()! // Fallback hex
        )
        courses.append(newCourse)
        // Note: The saveCourses() function in GPAView will need to be called after this append.
        // We'll handle this by making GPAView save when its `courses` @State array changes,
        // or explicitly calling it. For now, `GPAView`'s `onDisappear` or `onChange` for `courses`
        // would be a good place to trigger a save.
    }
}

struct AddCourseView_Previews: PreviewProvider {
    static var previews: some View {
        AddCourseView(courses: .constant([]))
    }
}
