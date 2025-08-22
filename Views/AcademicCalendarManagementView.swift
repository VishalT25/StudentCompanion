import SwiftUI

struct AcademicCalendarManagementView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddCalendar = false
    @State private var showingDeleteAlert = false
    @State private var calendarToDelete: AcademicCalendar?
    @State private var showingImportOptions = false
    
    private var sortedCalendars: [AcademicCalendar] {
        academicCalendarManager.academicCalendars.sorted { $0.academicYear > $1.academicYear }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if academicCalendarManager.academicCalendars.isEmpty {
                    emptyStateView
                } else {
                    calendarListView
                }
            }
            .navigationTitle("Academic Calendars")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddCalendar = true
                        } label: {
                            Label("Create Manually", systemImage: "plus")
                        }
                        
                        Button {
                            showingImportOptions = true
                        } label: {
                            Label("Import with AI", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .sheet(isPresented: $showingAddCalendar) {
            AddEditAcademicCalendarView(calendar: .constant(nil))
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingImportOptions) {
            AcademicCalendarImportView()
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
        .alert("Delete Calendar", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                calendarToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let calendar = calendarToDelete {
                    academicCalendarManager.deleteCalendar(calendar)
                }
                calendarToDelete = nil
            }
        } message: {
            if let calendar = calendarToDelete {
                let usageCount = getUsageCount(for: calendar)
                let usageText = usageCount > 0 ? " This will affect \(usageCount) schedule\(usageCount == 1 ? "" : "s")." : ""
                Text("Are you sure you want to delete '\(calendar.name)'? This cannot be undone.\(usageText)")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("No Academic Calendars")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("Academic calendars help manage breaks, holidays, and schedule rotations across all your semesters.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: { showingAddCalendar = true }) {
                    Label("Create Manually", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.currentTheme.primaryColor)
                        .cornerRadius(12)
                }
                
                Button(action: { showingImportOptions = true }) {
                    Label("Import with AI", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.currentTheme.primaryColor, lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var calendarListView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(sortedCalendars) { calendar in
                    AcademicCalendarCard(
                        calendar: calendar,
                        usageCount: getUsageCount(for: calendar),
                        usedBySchedules: getSchedulesUsing(calendar),
                        onDelete: {
                            calendarToDelete = calendar
                            showingDeleteAlert = true
                        }
                    )
                    .environmentObject(themeManager)
                    .environmentObject(academicCalendarManager)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func getUsageCount(for calendar: AcademicCalendar) -> Int {
        return scheduleManager.scheduleCollections.filter { $0.academicCalendarID == calendar.id }.count
    }
    
    private func getSchedulesUsing(_ calendar: AcademicCalendar) -> [ScheduleCollection] {
        return scheduleManager.scheduleCollections.filter { $0.academicCalendarID == calendar.id }
    }
}

struct AcademicCalendarCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    let calendar: AcademicCalendar
    let usageCount: Int
    let usedBySchedules: [ScheduleCollection]
    let onDelete: () -> Void
    @State private var showingEditSheet = false
    @State private var isExpanded = false
    
    private var breakCount: Int {
        calendar.breaks.count
    }
    
    private var durationText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: calendar.startDate)) - \(formatter.string(from: calendar.endDate))"
    }
    
    private var upcomingBreaks: [AcademicBreak] {
        calendar.breaks
            .filter { $0.endDate >= Date() }
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Card Content
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(calendar.name)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            Text(calendar.academicYear)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                            
                            if usageCount > 0 {
                                Text("•")
                                    .foregroundColor(.secondary)
                                
                                Text("\(usageCount) schedule\(usageCount == 1 ? "" : "s")")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(durationText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("Edit Calendar", systemImage: "pencil") {
                            showingEditSheet = true
                        }
                        
                        if usageCount > 0 {
                            Button("View Usage", systemImage: "list.bullet") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExpanded.toggle()
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button("Delete Calendar", systemImage: "trash", role: .destructive) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Stats Row
                HStack(spacing: 24) {
                    StatView(
                        value: calendar.termType.displayName.components(separatedBy: " ").first ?? "Term",
                        label: "Type",
                        color: themeManager.currentTheme.secondaryColor
                    )
                    
                    StatView(
                        value: "\(breakCount)",
                        label: breakCount == 1 ? "Break" : "Breaks",
                        color: breakCount > 0 ? themeManager.currentTheme.primaryColor : .secondary
                    )
                    
                    if usageCount > 0 {
                        StatView(
                            value: "\(usageCount)",
                            label: usageCount == 1 ? "Schedule" : "Schedules",
                            color: .green
                        )
                    }
                    
                    Spacer()
                }
                
                // Upcoming Breaks Preview
                if !upcomingBreaks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Upcoming Breaks")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 6) {
                            ForEach(upcomingBreaks, id: \.id) { break_ in
                                HStack(spacing: 10) {
                                    Image(systemName: break_.type.icon)
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                        .frame(width: 16)
                                    
                                    Text(break_.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(break_.startDate, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(20)
            
            // Expandable Usage Section
            if isExpanded && usageCount > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Used by Schedules")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        ForEach(usedBySchedules) { schedule in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(schedule.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(schedule.displayName)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if schedule.isActive {
                                    Text("Active")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .background(Color(.systemGray6).opacity(0.5))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .sheet(isPresented: $showingEditSheet) {
            let calendarBinding = Binding<AcademicCalendar?>(
                get: { self.calendar },
                set: { _ in }
            )
            AddEditAcademicCalendarView(calendar: calendarBinding)
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
    }
}