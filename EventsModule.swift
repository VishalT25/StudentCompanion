import SwiftUI

// MARK: - Models & ViewModel
struct Category: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var color: Color
}

struct Event: Identifiable {
    var id = UUID()
    var date: Date
    var title: String
    var category: Category
}

class EventViewModel: ObservableObject {
    @Published var categories: [Category] = [
        Category(name: "Assignment", color: .blue),
        Category(name: "Lab", color: .orange),
        Category(name: "Exam", color: .red),
        Category(name: "Personal", color: .purple)
    ]
    @Published var events: [Event] = []

    init() {
        // Sample data
        let defaultCat = categories.first!
        events = [
            Event(date: Date(), title: "Math assignment due", category: defaultCat),
            Event(date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!, title: "Physics lab", category: categories[1]),
            Event(date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!, title: "History essay draft", category: defaultCat)
        ]
    }
}

// MARK: - Color Palette
extension Color {
    static let primaryGreen = Color(red: 134/255, green: 167/255, blue: 137/255)
    static let secondaryGreen = Color(red: 178/255, green: 200/255, blue: 186/255)
    static let tertiaryGreen = Color(red: 210/255, green: 227/255, blue: 200/255)
    static let quaternaryGreen = Color(red: 235/255, green: 243/255, blue: 232/255)
}

// MARK: - EventsPreviewView
struct EventsPreviewView: View {
    let events: [Event]
    private let dayFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d"; return f }()
    private let monthFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM"; return f }()

    var body: some View {
        let sorted = events.sorted { $0.date < $1.date }
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming Events")
                .font(.subheadline).bold()
                .foregroundColor(.white)

            ForEach(sorted.prefix(3)) { event in
                HStack(alignment: .center, spacing: 8) {
                    VStack {
                        Text(dayFormatter.string(from: event.date))
                            .font(.headline).bold()
                        Text(monthFormatter.string(from: event.date))
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.secondaryGreen.opacity(0.8))
                    .cornerRadius(6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                        Text(timeString(from: event.date))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 2)
                        .fill(event.category.color)
                        .frame(width: 3)
                }
                .frame(height: 38)
            }

            if events.count > 3 {
                Text("View All Events...")
                    .font(.caption2).italic()
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)
            }
        }
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }
}

// MARK: - EventsListView
struct EventsListView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @State private var showingAddEvent = false
    @State private var showingAddCategory = false

    var body: some View {
        List {
            Section(header: Text("Categories")) {
                ForEach(viewModel.categories.indices, id: \.self) { idx in
                    NavigationLink(destination: CategoryEditView(category: $viewModel.categories[idx], isNew: false)) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewModel.categories[idx].color)
                                .frame(width: 24, height: 24)
                            Text(viewModel.categories[idx].name)
                        }
                    }
                }
                Button(action: { showingAddCategory = true }) {
                    Label("Add Category", systemImage: "plus.circle")
                }
            }
            Section(header: Text("Events")) {
                ForEach(viewModel.events) { event in
                    NavigationLink(destination: EventEditView(event: event, isNew: false).environmentObject(viewModel)) {
                        HStack {
                            Text(event.title)
                            Spacer()
                            Text(EventsListView.dateFormatter.string(from: event.date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indices in viewModel.events.remove(atOffsets: indices) }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("All Events")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button { showingAddEvent = true } label: { Image(systemName: "plus.circle") }
                    Button { showingAddCategory = true } label: { Image(systemName: "tag.circle") }
                }
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(isPresented: $showingAddEvent).environmentObject(viewModel)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(isPresented: $showingAddCategory).environmentObject(viewModel)
        }
    }
}

extension EventsListView {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()
}

// MARK: - AddEventView
struct AddEventView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @Binding var isPresented: Bool
    @State private var date = Date()
    @State private var title = ""
    @State private var category: Category = Category(name: "", color: .gray)

    var body: some View {
        NavigationView {
            Form {
                DatePicker("Date & Time", selection: $date)
                TextField("Event Title", text: $title)
                Picker("Category", selection: $category) {
                    ForEach(viewModel.categories, id: \.self) { cat in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cat.color)
                                .frame(width: 16, height: 16)
                            Text(cat.name)
                        }
                        .tag(cat)
                    }
                }
            }
            .navigationTitle("Add Event")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newEvent = Event(date: date, title: title, category: viewModel.categories.first ?? category)
                        viewModel.events.append(newEvent)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - AddCategoryView
struct AddCategoryView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var color: Color = .blue

    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $name)
                ColorPicker("Color", selection: $color)
            }
            .navigationTitle("Add Category")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let cat = Category(name: name.isEmpty ? "Unnamed" : name, color: color)
                        viewModel.categories.append(cat)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - EventEditView
struct EventEditView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @State var event: Event
    @Environment(\.presentationMode) var presentationMode
    var isNew = false

    var body: some View {
        Form {
            DatePicker("Date & Time", selection: Binding(
                get: { event.date },
                set: { event.date = $0 }
            ))
            TextField("Event Title", text: Binding(
                get: { event.title },
                set: { event.title = $0 }
            ))
            Picker("Category", selection: Binding(
                get: { event.category },
                set: { event.category = $0 }
            )) {
                ForEach(viewModel.categories, id: \.self) { cat in
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cat.color)
                            .frame(width: 16, height: 16)
                        Text(cat.name)
                    }
                    .tag(cat)
                }
            }

            if !isNew {
                Section {
                    Button(role: .destructive) {
                        viewModel.events.removeAll { $0.id == event.id }
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Delete Event")
                    }
                }
            }
        }
        .navigationTitle(isNew ? "Add Event" : "Edit Event")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") {
                    if isNew { viewModel.events.append(event) }
                    else if let idx = viewModel.events.firstIndex(where: { $0.id == event.id }) {
                        viewModel.events[idx] = event
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - CategoryEditView
struct CategoryEditView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @Binding var category: Category
    @Environment(\.presentationMode) var presentationMode
    var isNew: Bool

    var body: some View {
        VStack {
            Form {
                TextField("Category Name", text: $category.name)
                ColorPicker("Color", selection: $category.color)
            }
            // Delete button for existing
            if !isNew {
                Button(action: {
                    viewModel.categories.removeAll { $0.id == category.id }
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Delete Category")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding()
            }
            Spacer()
        }
        .navigationTitle(isNew ? "Add Category" : "Edit Category")
        .toolbar {
            // Cancel on leading for new only
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
            // Add/Save
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") {
                    if isNew {
                        viewModel.categories.append(category)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Previews
struct EventsModule_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EventsListView()
                .environmentObject(EventViewModel())
        }
    }
}
//struct EventsModule_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationView {
//            EventsListView()
//                .environmentObject(EventViewModel())
//        }
//    }
//}
