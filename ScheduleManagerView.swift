import SwiftUI
import Combine

struct ScheduleManagerView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSchedule = false
    @State private var showingDeleteAlert = false
    @State private var scheduleToDelete: ScheduleCollection?
    @State private var showingArchiveAlert = false
    @State private var scheduleToArchive: ScheduleCollection?
    
    // State for the new enhancement flow
    @State private var newScheduleID: UUID?
    @State private var showingEnhancementView = false
    
    private var activeSchedules: [ScheduleCollection] {
        scheduleManager.activeSchedules.sorted { first, second in
            if scheduleManager.activeScheduleID == first.id { return true }
            if scheduleManager.activeScheduleID == second.id { return false }
            return first.lastModified > second.lastModified
        }
    }
    
    private var archivedSchedules: [ScheduleCollection] {
        scheduleManager.archivedSchedules.sorted { $0.lastModified > $1.lastModified }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Active Schedules Section
                    if !activeSchedules.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Active Schedules")
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVStack(spacing: 16) {
                                ForEach(activeSchedules) { schedule in
                                    ScheduleCard(
                                        schedule: schedule,
                                        isActive: scheduleManager.activeScheduleID == schedule.id,
                                        isArchived: false,
                                        onSetActive: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                scheduleManager.setActiveSchedule(schedule.id)
                                            }
                                        },
                                        onArchive: {
                                            scheduleToArchive = schedule
                                            showingArchiveAlert = true
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
                        }
                    }
                    
                    // Archived Schedules Section
                    if !archivedSchedules.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Archived Schedules")
                                    .font(.title2.bold())
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(archivedSchedules.count)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray4))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(archivedSchedules) { schedule in
                                    ScheduleCard(
                                        schedule: schedule,
                                        isActive: false,
                                        isArchived: true,
                                        onSetActive: {},
                                        onArchive: {},
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
                        }
                    }
                }
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
                    Button(action: {
                        let newSchedule = createNewSchedule()
                        scheduleManager.addSchedule(newSchedule)
                        scheduleManager.setActiveSchedule(newSchedule.id)
                        newScheduleID = newSchedule.id
                        showingEnhancementView = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEnhancementView) {
            if let scheduleID = newScheduleID {
                ProgressiveEnhancementView(scheduleID: scheduleID, importedItems: []) {
                    // This closure is called when enhancement is complete.
                    // The view dismisses itself, so we just reset the state.
                    newScheduleID = nil
                }
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
                .environmentObject(academicCalendarManager)
            }
        }
        .alert("Archive Schedule", isPresented: $showingArchiveAlert) {
            Button("Cancel", role: .cancel) {
                scheduleToArchive = nil
            }
            Button("Archive") {
                if let schedule = scheduleToArchive {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scheduleManager.archiveSchedule(schedule)
                    }
                }
                scheduleToArchive = nil
            }
        } message: {
            if let schedule = scheduleToArchive {
                Text("Archive '\(schedule.displayName)'? It will be moved to archived schedules and no longer appear in your active schedules.")
            }
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
                if scheduleManager.activeSchedules.count == 1 && !schedule.isArchived {
                    Text("This is your last active schedule. Deleting it will create a new default schedule.")
                } else {
                    Text("Are you sure you want to delete '\(schedule.displayName)'? This will remove all \(schedule.totalClasses) classes and cannot be undone.")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissScheduleManager"))) { _ in
            dismiss()
        }
    }

    private func createNewSchedule() -> ScheduleCollection {
        return ScheduleCollection(
            name: "New Schedule",
            semester: getCurrentSemester(),
            color: themeManager.currentTheme.primaryColor
        )
    }
    
    private func getCurrentSemester() -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        
        if month >= 8 || month <= 1 {
            return "Fall \(year)"
        } else if month >= 2 && month <= 5 {
            return "Spring \(year)"
        } else {
            return "Summer \(year)"
        }
    }
}

struct ScheduleCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    let schedule: ScheduleCollection
    let isActive: Bool
    let isArchived: Bool
    let onSetActive: () -> Void
    let onArchive: () -> Void
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
                            .foregroundColor(isArchived ? .secondary : .primary)
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
                        
                        if isArchived {
                            Text("ARCHIVED")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray4))
                                .foregroundColor(.secondary)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(lastModifiedText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    if isArchived {
                        Button("Unarchive Schedule", systemImage: "arrow.up.bin") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scheduleManager.unarchiveSchedule(schedule)
                            }
                        }
                    } else {
                        if !isActive {
                            Button("Set as Active", systemImage: "checkmark.circle") {
                                onSetActive()
                            }
                        }
                        
                        Button("Edit Schedule", systemImage: "pencil") {
                            showingEditSheet = true
                        }
                        
                        Button("Archive Schedule", systemImage: "archivebox") {
                            onArchive()
                        }
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
                    color: isArchived ? .secondary : themeManager.currentTheme.primaryColor
                )
                
                StatView(
                    value: String(format: "%.1f", schedule.weeklyHours),
                    label: "Hours/Week",
                    color: isArchived ? .secondary : themeManager.currentTheme.secondaryColor
                )
                
                Spacer()
            }
            
            // Quick day overview and actions
            if !schedule.scheduleItems.isEmpty {
                HStack(spacing: 4) {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        let hasClasses = schedule.scheduleItems.contains { $0.daysOfWeek.contains(day) }
                        
                        Circle()
                            .fill(hasClasses ? (isArchived ? Color(.systemGray4) : themeManager.currentTheme.primaryColor.opacity(0.8)) : Color(.systemGray5))
                            .frame(width: 8, height: 8)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    if isArchived {
                        Button("Unarchive") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scheduleManager.unarchiveSchedule(schedule)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray2))
                        .cornerRadius(8)
                    } else if !isActive {
                        Button("Set Active") {
                            onSetActive()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeManager.currentTheme.primaryColor)
                        .cornerRadius(8)
                    }
                }
            } else {
                // Empty schedule section
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No classes scheduled")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(isArchived ? "Archived schedule" : "Add classes to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isArchived {
                        Button("Unarchive") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scheduleManager.unarchiveSchedule(schedule)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray2))
                        .cornerRadius(8)
                    } else if !isActive {
                        Button("Set Active") {
                            onSetActive()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeManager.currentTheme.primaryColor)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isArchived ? Color(.systemGray6) : (isActive ? themeManager.currentTheme.quaternaryColor : Color(.systemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isArchived ? Color(.systemGray4) : (isActive ? themeManager.currentTheme.primaryColor.opacity(0.3) : Color(.systemGray5)), lineWidth: isActive ? 2 : 1)
                )
                .shadow(color: isActive ? themeManager.currentTheme.primaryColor.opacity(0.1) : Color.black.opacity(0.05), radius: isActive ? 8 : 4, x: 0, y: isActive ? 4 : 2)
        )
        .scaleEffect(isActive ? 1.02 : (isArchived ? 0.98 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isArchived)
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