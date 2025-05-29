import SwiftUI
import Combine

// MARK: - Models & ViewModel
struct Category: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var color: Color
    
    enum CodingKeys: String, CodingKey {
        case id, name, color
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(UIColor(color).cgColor.components, forKey: .color)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let components = try container.decode([CGFloat].self, forKey: .color)
        color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
    }
    
    init(name: String, color: Color) {
        self.id = UUID()
        self.name = name
        self.color = color
    }
}

struct Event: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var title: String
    var categoryId: UUID

    func category(from categories: [Category]) -> Category {
        categories.first { $0.id == categoryId } ?? Category(name: "Unknown", color: .gray)
    }
}

struct ScheduleItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var daysOfWeek: Set<DayOfWeek>
    var color: Color
    
    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, daysOfWeek, color
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(Array(daysOfWeek), forKey: .daysOfWeek)
        try container.encode(UIColor(color).cgColor.components, forKey: .color)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        daysOfWeek = Set(try container.decode([DayOfWeek].self, forKey: .daysOfWeek))
        let components = try container.decode([CGFloat].self, forKey: .color)
        color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
    }
    
    init(title: String, startTime: Date, endTime: Date, daysOfWeek: Set<DayOfWeek>, color: Color = .blue) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.color = color
    }
}

enum DayOfWeek: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

class EventViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var events: [Event] = []
    @Published var scheduleItems: [ScheduleItem] = []
    
    private let categoriesKey = "savedCategories"
    private let eventsKey = "savedEvents"
    private let scheduleKey = "savedSchedule"
    
    init() {
        loadData()
    }
    
    private func loadData() {
        if let categoriesData = UserDefaults.standard.data(forKey: categoriesKey),
           let eventsData = UserDefaults.standard.data(forKey: eventsKey),
           let scheduleData = UserDefaults.standard.data(forKey: scheduleKey) {
            do {
                categories = try JSONDecoder().decode([Category].self, from: categoriesData)
                events = try JSONDecoder().decode([Event].self, from: eventsData)
                scheduleItems = try JSONDecoder().decode([ScheduleItem].self, from: scheduleData)
            } catch {
                print("Error loading data: \(error)")
                setupDefaultData()
            }
        } else {
            setupDefaultData()
        }
    }
    
    private func setupDefaultData() {
        categories = [
            Category(name: "Assignment", color: .blue),
            Category(name: "Lab", color: .orange),
            Category(name: "Exam", color: .red),
            Category(name: "Personal", color: .purple)
        ]
        
        let defaultCat = categories.first!
        events = [
            Event(date: Date(), title: "Math assignment due", categoryId: defaultCat.id),
            Event(date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!, title: "Physics lab", categoryId: categories[1].id),
            Event(date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!, title: "History essay draft", categoryId: defaultCat.id)
        ]
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        
        components.hour = 9
        components.minute = 0
        let mathStart = calendar.date(from: components)!
        components.hour = 10
        components.minute = 15
        let mathEnd = calendar.date(from: components)!
        
        components.hour = 14
        components.minute = 0
        let gymStart = calendar.date(from: components)!
        components.hour = 15
        components.minute = 30
        let gymEnd = calendar.date(from: components)!
        
        scheduleItems = [
            ScheduleItem(title: "Math 101",

                        startTime: mathStart,
                        endTime: mathEnd,
                        daysOfWeek: [.monday, .wednesday, .friday],
                        color: .blue),
            ScheduleItem(title: "Gym",
                        startTime: gymStart,
                        endTime: gymEnd,
                        daysOfWeek: [.tuesday, .thursday],
                        color: .orange)
        ]
        
        saveData()
    }
    
    private func saveData() {
        do {
            let categoriesData = try JSONEncoder().encode(categories)
            let eventsData = try JSONEncoder().encode(events)
            let scheduleData = try JSONEncoder().encode(scheduleItems)
            UserDefaults.standard.set(categoriesData, forKey: categoriesKey)
            UserDefaults.standard.set(eventsData, forKey: eventsKey)
            UserDefaults.standard.set(scheduleData, forKey: scheduleKey)
        } catch {
            print("Error saving data: \(error)")
        }
    }
    
    func addEvent(_ event: Event) {
        events.append(event)
        saveData()
    }
    
    func updateEvent(_ event: Event) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
            saveData()
        }
    }
    
    func deleteEvent(_ event: Event) {
        events.removeAll { $0.id == event.id }
        saveData()
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
        saveData()
    }
    
    func updateCategory(_ category: Category) {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
            saveData()
        }
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveData()
    }
    
    func addScheduleItem(_ item: ScheduleItem) {
        scheduleItems.append(item)
        saveData()
    }
    
    func updateScheduleItem(_ item: ScheduleItem) {
        if let idx = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            scheduleItems[idx] = item
            saveData()
        }
    }
    
    func deleteScheduleItem(_ item: ScheduleItem) {
        scheduleItems.removeAll { $0.id == item.id }
        saveData()
    }
    
    func todaysSchedule() -> [ScheduleItem] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let today = DayOfWeek(rawValue: weekday)!
        
        return scheduleItems
            .filter { $0.daysOfWeek.contains(today) }
            .sorted { $0.startTime < $1.startTime }
    }
    
    func todaysEvents() -> [Event] {
        let calendar = Calendar.current
        return events.filter {
            calendar.isDate($0.date, inSameDayAs: Date())
        }.sorted { $0.date < $1.date }
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
    @EnvironmentObject var viewModel: EventViewModel
    let events: [Event]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Events")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    // This could navigate to full events list
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                        .background(Circle().fill(.white.opacity(0.2)).frame(width: 32, height: 32))
                }
            }
            
            let sortedEvents = events.sorted { $0.date < $1.date }
            
            if sortedEvents.isEmpty {
                EmptyEventsView()
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedEvents.prefix(3)) { event in
                        EventPreviewCard(event: event)
                            .environmentObject(viewModel)
                    }
                    
                    if events.count > 3 {
                        HStack {
                            Spacer()
                            Text("View All Events...")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.secondaryGreen.opacity(0.9),
                    Color.secondaryGreen
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)

    }
    
    private func monthShort(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyEventsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.7))
            
            Text("No upcoming events")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Add events to stay organized")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct EventPreviewCard: View {
    @EnvironmentObject var viewModel: EventViewModel
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // Date block
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: event.date))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text(monthShort(from: event.date))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(.white.opacity(0.15))
            .cornerRadius(8)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.headline.weight(.medium))
                    .foregroundColor(.white)
                Text(timeString(from: event.date))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Category indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(event.category(from: viewModel.categories).color)
                .frame(width: 4, height: 35)
        }
        .padding(12)
        .background(.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func monthShort(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - EventsListView
struct EventsListView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @State private var showingAddEvent = false
    @State private var showingAddCategory = false

    var sortedEvents: [Event] {
        viewModel.events.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            Section(header: Text("Categories")) {
                ForEach(viewModel.categories.indices, id: \.self) { idx in
                    NavigationLink {
                        CategoryEditView(category: $viewModel.categories[idx], isNew: false)
                    } label: {
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
                ForEach(sortedEvents) { event in
                    NavigationLink {
                        EventEditView(event: event, isNew: false)
                            .environmentObject(viewModel)
                    } label: {
                        HStack {
                            Text(event.title)
                            Spacer()
                            Text(EventsListView.dateFormatter.string(from: event.date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indices in
                    indices.forEach { index in
                        let eventToDelete = sortedEvents[index]
                        viewModel.deleteEvent(eventToDelete)
                    }
                }
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
            AddEventView(isPresented: $showingAddEvent)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(isPresented: $showingAddCategory)
                .environmentObject(viewModel)
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
    @State private var selectedCategory: Category?

    var body: some View {
        NavigationView {
            Form {
                DatePicker("Date & Time", selection: $date)
                TextField("Event Title", text: $title)
                Picker("Category", selection: $selectedCategory) {
                    ForEach(viewModel.categories) { cat in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cat.color)
                                .frame(width: 16, height: 16)
                            Text(cat.name)
                        }
                        .tag(Optional(cat))
                    }
                }
            }
            .navigationTitle("Add Event")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let category = selectedCategory ?? viewModel.categories.first {
                            let newEvent = Event(date: date, title: title, categoryId: category.id)
                            viewModel.addEvent(newEvent)
                            isPresented = false
                        }
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
                        viewModel.addCategory(cat)
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
            let categoryBinding = Binding<Category>(
                get: { event.category(from: viewModel.categories) },
                set: { event.categoryId = $0.id }
            )
            Picker("Category", selection: categoryBinding) {
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
                        viewModel.deleteEvent(event)
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
                    if isNew { viewModel.addEvent(event) }
                    else { viewModel.updateEvent(event) }
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
            if !isNew {
                Button(action: {
                    viewModel.deleteCategory(category)
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
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") {
                    if isNew {
                        viewModel.addCategory(category)
                    } else {
                        viewModel.updateCategory(category)
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
