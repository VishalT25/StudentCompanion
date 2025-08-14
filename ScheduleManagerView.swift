import SwiftUI

struct ScheduleManagerView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSchedule = false
    @State private var showingDeleteAlert = false
    @State private var scheduleToDelete: ScheduleCollection?
    
    private var sortedSchedules: [ScheduleCollection] {
        scheduleManager.scheduleCollections.sorted { first, second in
            // Active schedule always comes first
            if scheduleManager.activeScheduleID == first.id {
                return true
            }
            if scheduleManager.activeScheduleID == second.id {
                return false
            }
            // Then sort by last modified date (most recent first)
            return first.lastModified > second.lastModified
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sortedSchedules) { schedule in
                        ScheduleCard(
                            schedule: schedule,
                            isActive: scheduleManager.activeScheduleID == schedule.id,
                            onSetActive: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    scheduleManager.setActiveSchedule(schedule.id)
                                }
                            },
                            onDelete: {
                                scheduleToDelete = schedule
                                showingDeleteAlert = true
                            }
                        )
                        .environmentObject(themeManager)
                        .environmentObject(scheduleManager)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Schedules")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSchedule = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSchedule) {
            CreateScheduleView()
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
        .alert("Delete Schedule", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                scheduleToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let schedule = scheduleToDelete {
                    scheduleManager.deleteSchedule(schedule)
                }
                scheduleToDelete = nil
            }
        } message: {
            if let schedule = scheduleToDelete {
                if scheduleManager.scheduleCollections.count == 1 {
                    Text("This is your last schedule. Deleting it will create a new default schedule.")
                } else {
                    Text("Are you sure you want to delete '\(schedule.displayName)'? This will remove all \(schedule.totalClasses) classes and cannot be undone.")
                }
            }
        }
    }
}

struct ScheduleCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    let schedule: ScheduleCollection
    let isActive: Bool
    let onSetActive: () -> Void
    let onDelete: () -> Void
    @State private var showingEditSheet = false
    
    private var lastModifiedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: schedule.lastModified, relativeTo: Date()))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(schedule.displayName)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if isActive {
                            Text("ACTIVE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(lastModifiedText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    if !isActive {
                        Button("Set as Active", systemImage: "checkmark.circle") {
                            onSetActive()
                        }
                    }
                    
                    Button("Edit Schedule", systemImage: "pencil") {
                        showingEditSheet = true
                    }
                    
                    Button("Delete Schedule", systemImage: "trash", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Stats
            HStack(spacing: 24) {
                StatView(
                    value: "\(schedule.totalClasses)",
                    label: "Classes",
                    color: themeManager.currentTheme.primaryColor
                )
                
                StatView(
                    value: String(format: "%.1f", schedule.weeklyHours),
                    label: "Hours/Week",
                    color: themeManager.currentTheme.secondaryColor
                )
                
                Spacer()
            }
            
            // Quick day overview
            if !schedule.scheduleItems.isEmpty {
                HStack(spacing: 4) {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        let hasClasses = schedule.scheduleItems.contains { $0.daysOfWeek.contains(day) }
                        
                        Circle()
                            .fill(hasClasses ? themeManager.currentTheme.primaryColor.opacity(0.8) : Color(.systemGray5))
                            .frame(width: 8, height: 8)
                    }
                    
                    Spacer()
                    
                    if !isActive {
                        Button("Set Active") {
                            onSetActive()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isActive ? themeManager.currentTheme.quaternaryColor : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? themeManager.currentTheme.primaryColor.opacity(0.3) : Color(.systemGray5), lineWidth: isActive ? 2 : 1)
                )
                .shadow(color: isActive ? themeManager.currentTheme.primaryColor.opacity(0.1) : Color.black.opacity(0.05), radius: isActive ? 8 : 4, x: 0, y: isActive ? 4 : 2)
        )
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
        .sheet(isPresented: $showingEditSheet) {
            EditScheduleView(schedule: schedule)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
    }
}

struct StatView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CreateScheduleView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var semester = ""
    @State private var setAsActive = true
    @State private var showingAIImport = false
    @State private var tempScheduleID: UUID?
    
    private var suggestedSemesters: [String] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        return [
            "Fall \(currentYear)",
            "Spring \(currentYear + 1)",
            "Summer \(currentYear + 1)",
            "Fall \(currentYear + 1)"
        ]
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Schedule Details")) {
                    TextField("Schedule Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Semester", text: $semester)
                        .textInputAutocapitalization(.words)
                }
                
                Section(header: Text("Suggested Semesters")) {
                    ForEach(suggestedSemesters, id: \.self) { suggestion in
                        Button(suggestion) {
                            semester = suggestion
                            if name.isEmpty {
                                name = "My Schedule"
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section(header: Text("Import Options")) {
                    Button(action: startAIImport) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import using AI")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Take a photo of your schedule and let AI do the work")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                Section(header: Text("Options")) {
                    Toggle("Set as Active Schedule", isOn: $setAsActive)
                        .tint(themeManager.currentTheme.primaryColor)
                }
            }
            .navigationTitle("New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createSchedule()
                    }
                    .disabled(semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .sheet(isPresented: $showingAIImport) {
            if let scheduleID = tempScheduleID {
                AIImportTutorialView(scheduleID: scheduleID)
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
                    .onDisappear {
                        // Dismiss the main view when AI import is done
                        dismiss()
                    }
            } else {
                // Fallback view if something goes wrong
                Text("Error: Schedule not found")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            // Auto-fill with current semester
            if semester.isEmpty {
                semester = suggestedSemesters.first ?? ""
            }
            if name.isEmpty {
                name = "My Schedule"
            }
        }
    }
    
    private func createSchedule() {
        let newSchedule = ScheduleCollection(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            semester: semester.trimmingCharacters(in: .whitespacesAndNewlines),
            color: themeManager.currentTheme.primaryColor
        )
        
        scheduleManager.addSchedule(newSchedule)
        
        if setAsActive {
            scheduleManager.setActiveSchedule(newSchedule.id)
        }
        
        dismiss()
    }
    
    private func startAIImport() {
        // Create the schedule first
        let newSchedule = ScheduleCollection(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Schedule" : name.trimmingCharacters(in: .whitespacesAndNewlines),
            semester: semester.trimmingCharacters(in: .whitespacesAndNewlines),
            color: themeManager.currentTheme.primaryColor
        )
        
        scheduleManager.addSchedule(newSchedule)
        
        if setAsActive {
            scheduleManager.setActiveSchedule(newSchedule.id)
        }
        
        // Store the schedule ID and show AI import
        tempScheduleID = newSchedule.id
        showingAIImport = true
    }
}

struct EditScheduleView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let schedule: ScheduleCollection
    @State private var name: String
    @State private var semester: String
    
    init(schedule: ScheduleCollection) {
        self.schedule = schedule
        self._name = State(initialValue: schedule.name)
        self._semester = State(initialValue: schedule.semester)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Schedule Details")) {
                    TextField("Schedule Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Semester", text: $semester)
                        .textInputAutocapitalization(.words)
                }
                
                Section(header: Text("Statistics")) {
                    HStack {
                        Text("Total Classes")
                        Spacer()
                        Text("\(schedule.totalClasses)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Weekly Hours")
                        Spacer()
                        Text(String(format: "%.1f hours", schedule.weeklyHours))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(schedule.createdDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedSchedule = schedule
                        updatedSchedule.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updatedSchedule.semester = semester.trimmingCharacters(in: .whitespacesAndNewlines)
                        updatedSchedule.color = themeManager.currentTheme.primaryColor
                        
                        scheduleManager.updateSchedule(updatedSchedule)
                        dismiss()
                    }
                    .disabled(semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
    }
}